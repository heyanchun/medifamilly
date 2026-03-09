/**
 * functions/call/index.js
 * PSTN 电话外呼 + DeepSeek 实时对话桥接
 */
const https = require('https');
const { db, COLLECTIONS } = require('./shared/db');
const { ERRORS, ok, fail } = require('./shared/response');
const { verifyToken } = require('./shared/auth-middleware');
const { sendVoiceNotification } = require('./shared/vms');
const { synthesize } = require('./shared/voice');
const { uploadBuffer, getTempUrl } = require('./shared/cos');

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;
const CALL_MAX_SECONDS = 180;

exports.main = async (event) => {
  const { path, httpMethod, body: rawBody } = event;
  const body = typeof rawBody === 'string' ? JSON.parse(rawBody || '{}') : (rawBody || {});

  // 内部调用（来自 reminder 云函数）
  if (body.action === 'initiateCall') return await initiateCall(body.logId);
  // VMS 通话状态回调（腾讯云推送）
  if (path === '/call/vms-callback') return await vmsCallback(body);
  // 查询通话记录
  if (path === '/call/records' && httpMethod === 'GET') return await listCallRecords(event, event.queryStringParameters || {});

  return fail('接口不存在', 404);
};

// ── 发起外呼 ─────────────────────────────────────────────────────
async function initiateCall(logId) {
  const logRes = await db.collection(COLLECTIONS.REMINDER_LOGS).doc(logId).get();
  if (!logRes.data) return ERRORS.NOT_FOUND;
  const log = logRes.data;

  // 获取长辈手机号
  const elderRes = await db.collection(COLLECTIONS.USERS).doc(log.elderId).get();
  if (!elderRes.data) return ERRORS.NOT_FOUND;

  // 获取子女音色 ID
  const profileRes = await db.collection(COLLECTIONS.CHILD_PROFILES)
    .where({ userId: log.childId }).get();
  const voiceModelId = profileRes.data?.[0]?.voiceModelId || null;

  // 获取子女画像（用于 AI 对话 system prompt）
  const childRes = await db.collection(COLLECTIONS.USERS).doc(log.childId).get();
  const bindingRes = await db.collection(COLLECTIONS.BINDINGS)
    .where({ childId: log.childId, elderId: log.elderId, status: 'active' }).get();
  const elderNickname = bindingRes.data?.[0]?.elderNickname || '长辈';
  const childProfile = profileRes.data?.[0] || {};

  // 构建通话脚本（开场白合规提示 + 提醒内容）
  const openingText = `您好，这是一条由AI模拟${childRes.data?.name || '您的家人'}发出的提醒电话。${elderNickname}，该吃药了，是${log.medName}，${log.dosage}，记得${log.mealTiming}服用。`;

  // 创建通话记录
  const callRecordResult = await db.collection(COLLECTIONS.CALL_RECORDS).add({
    reminderId: logId,
    childId: log.childId,
    elderId: log.elderId,
    calledAt: new Date(),
    durationSec: 0,
    cosUrl: null,
    transcript: '',
    callSid: null,
    status: 'calling',
  });

  // 更新 reminder_log 关联 call record
  await db.collection(COLLECTIONS.REMINDER_LOGS).doc(logId).update({
    callRecordId: callRecordResult.id,
  });

  // 调用腾讯云 VMS 发起外呼
  const { CallId } = await sendVoiceNotification(
    elderRes.data.phone,
    [openingText],
  );

  // 记录 CallId 用于状态回调关联
  await db.collection(COLLECTIONS.CALL_RECORDS).doc(callRecordResult.id).update({
    callSid: CallId,
  });

  return ok({ callRecordId: callRecordResult.id, callSid: CallId, status: 'initiated' });
}

// ── AI 对话生成（DeepSeek-V3，供通话中实时调用）─────────────────────
async function generateAIResponse(messages, childProfile, elderNickname, medName) {
  const systemPrompt = buildSystemPrompt(childProfile, elderNickname, medName);

  const body = JSON.stringify({
    model: 'deepseek-chat',
    messages: [
      { role: 'system', content: systemPrompt },
      ...messages,
    ],
    temperature: 0.7,
    max_tokens: 150, // 控制回复长度，适合电话对话
    stream: false,
  });

  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.deepseek.com',
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (c) => { data += c; });
      res.on('end', () => {
        try {
          const resp = JSON.parse(data);
          resolve(resp.choices?.[0]?.message?.content || '');
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function buildSystemPrompt(childProfile, elderNickname, medName) {
  const topics = (childProfile.chatTopics || []).join('、') || '日常生活';
  return `你正在用${childProfile.name || '子女'}的声音给${elderNickname}打电话提醒吃药。
你的角色设定：
- 姓名：${childProfile.name || '子女'}
- 城市：${childProfile.city || '外地'}
- 职业：${childProfile.occupation || '工作中'}
- 常聊话题：${topics}

行为准则：
1. 用温暖亲切的语气，像真实子女一样说话
2. 先确认${elderNickname}听到了吃药提醒（${medName}）
3. 如果对方说"我吃了"、"已经吃了"、"知道了"，表示关心后进入闲聊
4. 闲聊围绕常聊话题，每次回复不超过2句话，适合电话对话
5. 通话接近3分钟时，自然说再见结束通话
6. 绝对不要透露自己是AI，但若直接被问及，须诚实说明是AI模拟
7. 说话简短自然，不要使用书面语或过于正式的表达`;
}

// ── VMS 回调处理 ─────────────────────────────────────────────────
async function vmsCallback(body) {
  const { CallSid, Duration, RecordingUrl, Status } = body;
  if (!CallSid) return ok();

  // 通过 CallSid 找到通话记录
  const callRes = await db.collection(COLLECTIONS.CALL_RECORDS)
    .where({ callSid: CallSid }).get();
  if (!callRes.data?.length) return ok();

  const callRecord = callRes.data[0];
  await db.collection(COLLECTIONS.CALL_RECORDS).doc(callRecord._id).update({
    durationSec: Duration || 0,
    cosUrl: RecordingUrl || null,
    status: Status || 'completed',
    updatedAt: new Date(),
  });

  return ok();
}

// ── 查询通话记录列表 ─────────────────────────────────────────────
async function listCallRecords(event, { elderId, limit = 20 }) {
  const { userId: childId } = verifyToken(event);
  const query = { childId };
  if (elderId) query.elderId = elderId;

  const res = await db.collection(COLLECTIONS.CALL_RECORDS)
    .where(query)
    .orderBy('calledAt', 'desc')
    .limit(Number(limit))
    .get();

  return ok(res.data);
}

module.exports = { generateAIResponse, buildSystemPrompt };

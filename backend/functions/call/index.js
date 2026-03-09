/**
 * functions/call/index.js
 * PSTN 电话外呼 + DeepSeek 实时对话桥接
 */
const https = require('https');
const { db, COLLECTIONS, docGet, whereGet } = require('./shared/db');
const { ERRORS, ok, fail } = require('./shared/response');
const { verifyToken } = require('./shared/auth-middleware');
const { sendVoiceNotification } = require('./shared/vms');

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

exports.main = async (event) => {
  const { path, httpMethod, body: rawBody } = event;
  const body = typeof rawBody === 'string' ? JSON.parse(rawBody || '{}') : (rawBody || {});

  if (body.action === 'initiateCall') return await initiateCall(body.logId);
  if (path === '/call/vms-callback') return await vmsCallback(body);
  if (path === '/call/records' && httpMethod === 'GET') return await listCallRecords(event, event.queryStringParameters || {});

  return fail('接口不存在', 404);
};

// ── 发起外呼 ─────────────────────────────────────────────────────
async function initiateCall(logId) {
  const log = docGet(await db.collection(COLLECTIONS.REMINDER_LOGS).doc(logId).get());
  if (!log) return ERRORS.NOT_FOUND;

  const elder = docGet(await db.collection(COLLECTIONS.USERS).doc(log.elderId).get());
  if (!elder) return ERRORS.NOT_FOUND;

  const profiles = whereGet(await db.collection(COLLECTIONS.CHILD_PROFILES)
    .where({ userId: log.childId }).get());
  const voiceModelId = profiles[0]?.voiceModelId || null;

  const child = docGet(await db.collection(COLLECTIONS.USERS).doc(log.childId).get());
  const bindings = whereGet(await db.collection(COLLECTIONS.BINDINGS)
    .where({ childId: log.childId, elderId: log.elderId, status: 'active' }).get());
  const elderNickname = bindings[0]?.elderNickname || '长辈';

  const openingText = `您好，这是一条由AI模拟${child?.name || '您的家人'}发出的提醒电话。${elderNickname}，该吃药了，是${log.medName}，${log.dosage}，记得${log.mealTiming}服用。`;

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

  await db.collection(COLLECTIONS.REMINDER_LOGS).doc(logId).update({
    callRecordId: callRecordResult.id,
  });

  const { CallId } = await sendVoiceNotification(elder.phone, [openingText]);

  await db.collection(COLLECTIONS.CALL_RECORDS).doc(callRecordResult.id).update({
    callSid: CallId,
  });

  return ok({ callRecordId: callRecordResult.id, callSid: CallId, status: 'initiated' });
}

// ── AI 对话生成 ───────────────────────────────────────────────────
async function generateAIResponse(messages, childProfile, elderNickname, medName) {
  const systemPrompt = buildSystemPrompt(childProfile, elderNickname, medName);

  const body = JSON.stringify({
    model: 'deepseek-chat',
    messages: [{ role: 'system', content: systemPrompt }, ...messages],
    temperature: 0.7,
    max_tokens: 150,
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
        try { resolve(JSON.parse(data).choices?.[0]?.message?.content || ''); }
        catch (e) { reject(e); }
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

  const calls = whereGet(await db.collection(COLLECTIONS.CALL_RECORDS)
    .where({ callSid: CallSid }).get());
  if (!calls.length) return ok();

  await db.collection(COLLECTIONS.CALL_RECORDS).doc(calls[0]._id).update({
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
    .where(query).orderBy('calledAt', 'desc').limit(Number(limit)).get();

  return ok(whereGet(res));
}

module.exports = { generateAIResponse, buildSystemPrompt };

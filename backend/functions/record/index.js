/**
 * functions/record/index.js
 * 打卡确认、服药记录查询、声音上传状态
 */
const { db, COLLECTIONS, app } = require('../../shared/db');
const { ok, fail, ERRORS } = require('../../shared/response');
const { verifyToken } = require('../../shared/auth-middleware');

const COS_BUCKET = process.env.COS_BUCKET;
const COS_REGION = process.env.COS_REGION;

exports.main = async (event) => {
  const { path, httpMethod, body: rawBody } = event;
  const body = typeof rawBody === 'string' ? JSON.parse(rawBody || '{}') : (rawBody || {});
  const query = event.queryStringParameters || {};

  try {
    if (path === '/record/confirm'     && httpMethod === 'POST') return await confirmMed(event, body);
    if (path === '/record/logs'        && httpMethod === 'GET')  return await getLogs(event, query);
    if (path === '/record/call/:id'    && httpMethod === 'GET')  return await getCallRecord(event, path.split('/')[3]);
    if (path === '/voice/upload'       && httpMethod === 'POST') return await uploadVoice(event, body);
    if (path === '/voice/status'       && httpMethod === 'GET')  return await getVoiceStatus(event);
    return fail('接口不存在', 404);
  } catch (e) {
    console.error('[record] error:', e);
    if (e.httpCode === 401) return ERRORS.UNAUTHORIZED;
    return ERRORS.SERVER_ERROR(e.message);
  }
};

// ── 长辈打卡确认 ─────────────────────────────────────────────────
async function confirmMed(event, { logId }) {
  const { userId: elderId } = verifyToken(event);
  if (!logId) return ERRORS.INVALID_PARAMS('缺少 logId');

  const logRes = await db.collection(COLLECTIONS.REMINDER_LOGS).doc(logId).get();
  if (!logRes.data) return ERRORS.NOT_FOUND;
  if (logRes.data.elderId !== elderId) return ERRORS.FORBIDDEN;

  if (logRes.data.status === 'confirmed') {
    return ok({ logId, message: '已确认过，无需重复操作' });
  }

  await db.collection(COLLECTIONS.REMINDER_LOGS).doc(logId).update({
    status: 'confirmed',
    confirmedAt: new Date(),
  });

  return ok({ logId, status: 'confirmed', confirmedAt: new Date() });
}

// ── 查询服药记录（子女端看长辈记录）─────────────────────────────────
async function getLogs(event, { elderId, date, limit = 30 }) {
  const { userId: childId } = verifyToken(event);

  const query = { childId };
  if (elderId) query.elderId = elderId;

  if (date) {
    // date 格式 YYYY-MM-DD，查当天
    const start = new Date(date);
    const end = new Date(date);
    end.setDate(end.getDate() + 1);
    query.scheduledAt = db.command.and([
      db.command.gte(start),
      db.command.lt(end),
    ]);
  }

  const res = await db.collection(COLLECTIONS.REMINDER_LOGS)
    .where(query)
    .orderBy('scheduledAt', 'desc')
    .limit(Number(limit))
    .get();

  // 统计依从率
  const total = res.data.length;
  const confirmed = res.data.filter(l => l.status === 'confirmed').length;
  const adherenceRate = total > 0 ? Math.round((confirmed / total) * 100) : 100;

  return ok({
    logs: res.data,
    stats: { total, confirmed, adherenceRate },
  });
}

// ── 获取单条通话记录详情 ─────────────────────────────────────────
async function getCallRecord(event, callId) {
  const { userId: childId } = verifyToken(event);
  const callRes = await db.collection(COLLECTIONS.CALL_RECORDS).doc(callId).get();
  if (!callRes.data) return ERRORS.NOT_FOUND;
  if (callRes.data.childId !== childId) return ERRORS.FORBIDDEN;

  // 生成录音文件的临时访问 URL（COS 签名 URL，有效期 1 小时）
  let audioUrl = null;
  if (callRes.data.cosUrl) {
    try {
      const storage = app.storage();
      audioUrl = await storage.getTempFileURL({
        fileList: [callRes.data.cosUrl],
      });
    } catch (e) {
      console.warn('[record] 获取录音 URL 失败:', e.message);
    }
  }

  return ok({ ...callRes.data, audioUrl });
}

// ── 上传声音采集文件，提交音色复刻训练 ──────────────────────────────
async function uploadVoice(event, { audioFileId }) {
  const { userId: childId } = verifyToken(event);
  if (!audioFileId) return ERRORS.INVALID_PARAMS('缺少 audioFileId');

  // 调用腾讯云音色复刻 API 提交训练
  // 文档：https://cloud.tencent.com/document/product/1073
  // 生产中使用 tencentcloud-sdk-nodejs 的 Tts 模块
  console.log('[voice] 提交音色复刻训练, childId:', childId, 'fileId:', audioFileId);

  // Mock: 实际应调用 CreateCustomizationV2 接口
  const mockVoiceModelId = `voice_${childId}_${Date.now()}`;

  // 更新 child_profile，标记训练中
  const profileRes = await db.collection(COLLECTIONS.CHILD_PROFILES)
    .where({ userId: childId }).get();

  if (profileRes.data.length > 0) {
    await db.collection(COLLECTIONS.CHILD_PROFILES)
      .doc(profileRes.data[0]._id)
      .update({ voiceModelId: mockVoiceModelId, voiceReady: false, updatedAt: new Date() });
  } else {
    await db.collection(COLLECTIONS.CHILD_PROFILES).add({
      userId: childId,
      voiceModelId: mockVoiceModelId,
      voiceReady: false,
      city: '',
      occupation: '',
      chatTopics: [],
      createdAt: new Date(),
    });
  }

  return ok({ voiceModelId: mockVoiceModelId, status: 'training' });
}

// ── 查询音色复刻训练状态 ─────────────────────────────────────────
async function getVoiceStatus(event) {
  const { userId: childId } = verifyToken(event);
  const profileRes = await db.collection(COLLECTIONS.CHILD_PROFILES)
    .where({ userId: childId }).get();

  if (!profileRes.data?.length || !profileRes.data[0].voiceModelId) {
    return ok({ voiceReady: false, voiceModelId: null });
  }

  const profile = profileRes.data[0];

  // 生产中应调用腾讯云 API 查询训练状态并更新 voiceReady
  // DescribeCustomizationsV2

  return ok({
    voiceReady: profile.voiceReady,
    voiceModelId: profile.voiceModelId,
  });
}

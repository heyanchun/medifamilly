/**
 * functions/record/index.js
 * 打卡确认、服药记录查询、声音上传状态
 */
const { db, COLLECTIONS, app, docGet, whereGet } = require('./shared/db');
const { ok, fail, ERRORS } = require('./shared/response');
const { verifyToken } = require('./shared/auth-middleware');

exports.main = async (event) => {
  // 去掉 HTTP 访问服务路径前缀 /record
  const rawPath = (event.path || '').replace(/^\/record/, '') || '/';
  const path = rawPath || '/';
  const httpMethod = event.httpMethod;
  const body = typeof event.body === 'string' ? JSON.parse(event.body || '{}') : (event.body || {});
  const query = event.queryStringParameters || {};

  try {
    if (path === '/confirm'  && httpMethod === 'POST') return await confirmMed(event, body);
    if (path === '/logs'     && httpMethod === 'GET')  return await getLogs(event, query);
    if (path.startsWith('/call/') && httpMethod === 'GET') return await getCallRecord(event, path.split('/')[2]);
    if (path === '/voice/upload'    && httpMethod === 'POST') return await uploadVoice(event, body);
    if (path === '/voice/status'    && httpMethod === 'GET')  return await getVoiceStatus(event);
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

  const log = docGet(await db.collection(COLLECTIONS.REMINDER_LOGS).doc(logId).get());
  if (!log) return ERRORS.NOT_FOUND;
  if (log.elderId !== elderId) return ERRORS.FORBIDDEN;

  if (log.status === 'confirmed') {
    return ok({ logId, message: '已确认过，无需重复操作' });
  }

  await db.collection(COLLECTIONS.REMINDER_LOGS).doc(logId).update({
    status: 'confirmed',
    confirmedAt: new Date(),
  });

  return ok({ logId, status: 'confirmed', confirmedAt: new Date() });
}

// ── 查询服药记录（子女端）────────────────────────────────────────
async function getLogs(event, { elderId, date, limit = 30 }) {
  const { userId: childId } = verifyToken(event);

  const q = { childId };
  if (elderId) q.elderId = elderId;
  if (date) {
    const start = new Date(date);
    const end = new Date(date);
    end.setDate(end.getDate() + 1);
    q.scheduledAt = db.command.and([db.command.gte(start), db.command.lt(end)]);
  }

  const res = await db.collection(COLLECTIONS.REMINDER_LOGS)
    .where(q).orderBy('scheduledAt', 'desc').limit(Number(limit)).get();

  const logs = whereGet(res);
  const total = logs.length;
  const confirmed = logs.filter(l => l.status === 'confirmed').length;
  const adherenceRate = total > 0 ? Math.round((confirmed / total) * 100) : 100;

  return ok({ logs, stats: { total, confirmed, adherenceRate } });
}

// ── 获取单条通话记录详情 ─────────────────────────────────────────
async function getCallRecord(event, callId) {
  const { userId: childId } = verifyToken(event);
  const call = docGet(await db.collection(COLLECTIONS.CALL_RECORDS).doc(callId).get());
  if (!call) return ERRORS.NOT_FOUND;
  if (call.childId !== childId) return ERRORS.FORBIDDEN;

  let audioUrl = null;
  if (call.cosUrl) {
    try {
      const storage = app.storage();
      audioUrl = await storage.getTempFileURL({ fileList: [call.cosUrl] });
    } catch (e) {
      console.warn('[record] 获取录音 URL 失败:', e.message);
    }
  }

  return ok({ ...call, audioUrl });
}

// ── 上传声音，提交音色复刻训练 ──────────────────────────────────
async function uploadVoice(event, { audioFileId }) {
  const { userId: childId } = verifyToken(event);
  if (!audioFileId) return ERRORS.INVALID_PARAMS('缺少 audioFileId');

  const mockVoiceModelId = `voice_${childId}_${Date.now()}`;

  const profiles = whereGet(await db.collection(COLLECTIONS.CHILD_PROFILES)
    .where({ userId: childId }).get());

  if (profiles.length > 0) {
    await db.collection(COLLECTIONS.CHILD_PROFILES).doc(profiles[0]._id)
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
  const profiles = whereGet(await db.collection(COLLECTIONS.CHILD_PROFILES)
    .where({ userId: childId }).get());

  if (!profiles.length || !profiles[0].voiceModelId) {
    return ok({ voiceReady: false, voiceModelId: null });
  }

  return ok({ voiceReady: profiles[0].voiceReady, voiceModelId: profiles[0].voiceModelId });
}

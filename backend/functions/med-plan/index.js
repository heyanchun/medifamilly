/**
 * functions/med-plan/index.js
 * 药品计划 CRUD + 语音解析（调用腾讯云 ASR + DeepSeek 提取结构化信息）
 */
const https = require('https');
const { db, COLLECTIONS, docGet, whereGet } = require('./shared/db');
const { ok, fail, ERRORS } = require('./shared/response');
const { verifyToken } = require('./shared/auth-middleware');
const { recognizeFile } = require('./shared/asr');

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

exports.main = async (event) => {
  const { path, httpMethod, body: rawBody } = event;
  const body = typeof rawBody === 'string' ? JSON.parse(rawBody || '{}') : (rawBody || {});

  try {
    if (path === '/med-plan' && httpMethod === 'POST') return await createPlan(event, body);
    if (path === '/med-plan' && httpMethod === 'GET')  return await listPlans(event, event.queryStringParameters || {});
    if (path.match(/^\/med-plan\/\w+$/) && httpMethod === 'PUT')    return await updatePlan(event, body, path.split('/')[2]);
    if (path.match(/^\/med-plan\/\w+$/) && httpMethod === 'DELETE') return await deletePlan(event, path.split('/')[2]);
    if (path === '/med-plan/parse-voice' && httpMethod === 'POST') return await parseVoice(event, body);
    return fail('接口不存在', 404);
  } catch (e) {
    console.error('[med-plan] error:', e);
    if (e.httpCode === 401) return ERRORS.UNAUTHORIZED;
    return ERRORS.SERVER_ERROR(e.message);
  }
};

// ── 语音解析（ASR + DeepSeek 提取结构化药品信息）────────────────────
async function parseVoice(event, { audioUrl }) {
  verifyToken(event);
  if (!audioUrl) return ERRORS.INVALID_PARAMS('缺少 audioUrl');
  const transcript = await recognizeFile(audioUrl);
  const parsed = await extractMedInfo(transcript);
  return ok({ transcript, parsed });
}

// DeepSeek 提取结构化药品信息
async function extractMedInfo(transcript) {
  const systemPrompt = `你是一个专业的药品信息提取助手。
从用户的语音描述中提取吃药计划信息，以 JSON 格式返回。
JSON 字段：
- medName: 药品名称（字符串）
- frequency: 每日次数（数字）
- timeSlots: 时间点数组，格式 ["HH:MM", ...]
- dosage: 每次用量（字符串，如"2片"）
- mealTiming: 饭前/饭后/空腹/不限（枚举）
- durationDays: 疗程天数（数字，长期用药为 -1）
如果用户描述了多种药品，返回数组。只返回 JSON，不要解释。`;

  const body = JSON.stringify({
    model: 'deepseek-chat',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: transcript },
    ],
    temperature: 0.1,
    response_format: { type: 'json_object' },
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
          const content = resp.choices?.[0]?.message?.content || '{}';
          resolve(JSON.parse(content));
        } catch (e) {
          reject(new Error('DeepSeek 解析失败: ' + e.message));
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// ── 创建吃药计划 ─────────────────────────────────────────────────
async function createPlan(event, { bindingId, plans }) {
  const { userId: childId } = verifyToken(event);
  if (!bindingId || !plans?.length) return ERRORS.INVALID_PARAMS('缺少 bindingId 或 plans');

  const _rawBinding = await db.collection(COLLECTIONS.BINDINGS).doc(bindingId).get();
  const binding = docGet(_rawBinding);
  if (!binding || binding.childId !== childId) return ERRORS.FORBIDDEN;

  const now = new Date();
  const results = [];
  for (const plan of plans) {
    const { medName, frequency, timeSlots, dosage, mealTiming, durationDays, startDate } = plan;
    const start = startDate ? new Date(startDate) : now;
    const endDate = durationDays > 0
      ? new Date(start.getTime() + durationDays * 86400000)
      : null;

    const result = await db.collection(COLLECTIONS.MED_PLANS).add({
      bindingId,
      elderId: binding.elderId,
      childId,
      medName,
      frequency: frequency || timeSlots?.length || 1,
      timeSlots: timeSlots || [],
      dosage: dosage || '',
      mealTiming: mealTiming || '不限',
      durationDays: durationDays ?? -1,
      startDate: start,
      endDate,
      active: true,
      createdAt: now,
    });
    results.push(result.id);
  }

  return ok({ created: results.length, planIds: results });
}

// ── 查询计划列表 ─────────────────────────────────────────────────
async function listPlans(event, { elderId, active }) {
  const { userId: childId } = verifyToken(event);
  const query = { childId };
  if (elderId) query.elderId = elderId;
  if (active !== undefined) query.active = active === 'true';

  const res = await db.collection(COLLECTIONS.MED_PLANS).where(query)
    .orderBy('createdAt', 'desc').get();
  return ok(whereGet(res));
}

// ── 更新计划 ─────────────────────────────────────────────────────
async function updatePlan(event, body, planId) {
  const { userId: childId } = verifyToken(event);
  const plan = docGet(await db.collection(COLLECTIONS.MED_PLANS).doc(planId).get());
  if (!plan || plan.childId !== childId) return ERRORS.FORBIDDEN;

  const allowedFields = ['medName', 'frequency', 'timeSlots', 'dosage', 'mealTiming', 'durationDays', 'active'];
  const update = {};
  for (const field of allowedFields) {
    if (body[field] !== undefined) update[field] = body[field];
  }
  update.updatedAt = new Date();

  await db.collection(COLLECTIONS.MED_PLANS).doc(planId).update(update);
  return ok({ planId, updated: update });
}

// ── 停用计划 ─────────────────────────────────────────────────────
async function deletePlan(event, planId) {
  const { userId: childId } = verifyToken(event);
  const plan = docGet(await db.collection(COLLECTIONS.MED_PLANS).doc(planId).get());
  if (!plan || plan.childId !== childId) return ERRORS.FORBIDDEN;

  await db.collection(COLLECTIONS.MED_PLANS).doc(planId).update({ active: false, updatedAt: new Date() });
  return ok({ planId, status: 'deactivated' });
}

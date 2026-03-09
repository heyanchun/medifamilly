/**
 * functions/auth/index.js
 * 处理注册、登录、绑定邀请与确认、子女画像更新
 */
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { db, COLLECTIONS } = require('../../shared/db');
const { ok, fail, ERRORS } = require('../../shared/response');
const { verifyToken } = require('../../shared/auth-middleware');

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES = '30d';

// 路由分发
exports.main = async (event) => {
  const { path, httpMethod, body: rawBody } = event;
  const body = typeof rawBody === 'string' ? JSON.parse(rawBody || '{}') : (rawBody || {});

  try {
    if (path === '/auth/register' && httpMethod === 'POST') return await register(body);
    if (path === '/auth/login'    && httpMethod === 'POST') return await login(body);
    if (path === '/auth/binding/invite'   && httpMethod === 'POST') return await invite(event, body);
    if (path === '/auth/binding/confirm'  && httpMethod === 'POST') return await confirmBinding(event, body);
    if (path === '/auth/binding/pending'  && httpMethod === 'GET')  return await getPendingBinding(event);
    if (path === '/auth/bindings'         && httpMethod === 'GET')  return await getBindings(event);
    if (path === '/auth/child-profile'    && httpMethod === 'PUT')  return await updateChildProfile(event, body);
    return fail('接口不存在', 404);
  } catch (e) {
    console.error('[auth] error:', e);
    if (e.httpCode === 401) return ERRORS.UNAUTHORIZED;
    return ERRORS.SERVER_ERROR(e.message);
  }
};

// ── 注册 ──────────────────────────────────────────────────────────
async function register({ phone, password, role, name }) {
  if (!phone || !password || !role || !name) return ERRORS.INVALID_PARAMS('缺少必填字段');
  if (!['child', 'elder'].includes(role)) return ERRORS.INVALID_PARAMS('角色无效');

  const existing = await db.collection(COLLECTIONS.USERS).where({ phone }).get();
  if (existing.data.length > 0) return fail('手机号已注册', 409);

  const hash = await bcrypt.hash(password, 10);
  const result = await db.collection(COLLECTIONS.USERS).add({
    phone,
    password: hash,
    role,
    name,
    createdAt: new Date(),
  });

  const userId = result.id;
  const token = jwt.sign({ userId, role, phone }, JWT_SECRET, { expiresIn: JWT_EXPIRES });
  return ok({ userId, token, role, name });
}

// ── 登录 ──────────────────────────────────────────────────────────
async function login({ phone, password }) {
  if (!phone || !password) return ERRORS.INVALID_PARAMS('手机号和密码不能为空');

  const res = await db.collection(COLLECTIONS.USERS).where({ phone }).get();
  if (res.data.length === 0) return fail('手机号未注册', 404);

  const user = res.data[0];
  const match = await bcrypt.compare(password, user.password);
  if (!match) return fail('密码错误', 401);

  const token = jwt.sign(
    { userId: user._id, role: user.role, phone: user.phone },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES }
  );
  return ok({ userId: user._id, token, role: user.role, name: user.name });
}

// ── 子女发送绑定邀请 ──────────────────────────────────────────────
async function invite(event, { elderPhone, elderNickname }) {
  const { userId: childId } = verifyToken(event);
  if (!elderPhone || !elderNickname) return ERRORS.INVALID_PARAMS('缺少长辈手机号或称呼');

  // 查找长辈账号
  const elderRes = await db.collection(COLLECTIONS.USERS)
    .where({ phone: elderPhone, role: 'elder' }).get();
  if (elderRes.data.length === 0) return fail('该手机号未注册长辈账号', 404);
  const elder = elderRes.data[0];

  // 检查是否已被其他子女绑定
  const existBinding = await db.collection(COLLECTIONS.BINDINGS)
    .where({ elderId: elder._id, status: db.command.in(['pending', 'active']) }).get();
  if (existBinding.data.length > 0) return fail('该长辈已被其他账号管理', 409);

  // 检查是否已有待确认邀请
  const dupInvite = await db.collection(COLLECTIONS.BINDINGS)
    .where({ childId, elderId: elder._id, status: 'pending' }).get();
  if (dupInvite.data.length > 0) return fail('已发送过邀请，等待长辈确认', 409);

  const result = await db.collection(COLLECTIONS.BINDINGS).add({
    childId,
    elderId: elder._id,
    elderNickname,
    status: 'pending',
    createdAt: new Date(),
  });

  return ok({ bindingId: result.id, elderName: elder.name });
}

// ── 长辈确认绑定 ──────────────────────────────────────────────────
async function confirmBinding(event, { bindingId }) {
  const { userId: elderId } = verifyToken(event);
  if (!bindingId) return ERRORS.INVALID_PARAMS('缺少 bindingId');

  const bindingRes = await db.collection(COLLECTIONS.BINDINGS).doc(bindingId).get();
  if (!bindingRes.data) return ERRORS.NOT_FOUND;

  const binding = bindingRes.data;
  if (binding.elderId !== elderId) return ERRORS.FORBIDDEN;
  if (binding.status !== 'pending') return fail('邀请状态异常', 400);

  await db.collection(COLLECTIONS.BINDINGS).doc(bindingId).update({ status: 'active' });
  return ok({ bindingId, status: 'active' });
}

// ── 长辈查询待确认绑定 ────────────────────────────────────────────
async function getPendingBinding(event) {
  const { userId: elderId } = verifyToken(event);
  const res = await db.collection(COLLECTIONS.BINDINGS)
    .where({ elderId, status: 'pending' })
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get();
  if (!res.data.length) return ok(null);

  // 附带子女姓名
  const binding = res.data[0];
  const childRes = await db.collection(COLLECTIONS.USERS).doc(binding.childId).get();
  return ok({ ...binding, childName: childRes.data?.name || '您的家人' });
}

// ── 子女查询已绑定长辈列表 ────────────────────────────────────────
async function getBindings(event) {
  const { userId: childId } = verifyToken(event);
  const res = await db.collection(COLLECTIONS.BINDINGS)
    .where({ childId, status: 'active' })
    .get();

  // 附带长辈姓名
  const bindings = await Promise.all(res.data.map(async (b) => {
    const elderRes = await db.collection(COLLECTIONS.USERS).doc(b.elderId).get();
    return { ...b, elderName: elderRes.data?.name || '' };
  }));

  return ok(bindings);
}

// ── 更新子女画像 ──────────────────────────────────────────────────
async function updateChildProfile(event, { city, occupation, chatTopics }) {
  const { userId } = verifyToken(event);

  const existing = await db.collection(COLLECTIONS.CHILD_PROFILES).where({ userId }).get();
  const profileData = {
    userId,
    city: city || '',
    occupation: occupation || '',
    chatTopics: chatTopics || [],
    updatedAt: new Date(),
  };

  if (existing.data.length === 0) {
    await db.collection(COLLECTIONS.CHILD_PROFILES).add({
      ...profileData,
      voiceModelId: null,
      voiceReady: false,
      createdAt: new Date(),
    });
  } else {
    await db.collection(COLLECTIONS.CHILD_PROFILES)
      .doc(existing.data[0]._id).update(profileData);
  }

  return ok(profileData);
}

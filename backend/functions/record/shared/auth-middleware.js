/**
 * shared/auth-middleware.js
 * JWT 验证中间件 — 使用本地 jwt.js，零外部依赖
 */
const { verify } = require('./jwt');

const JWT_SECRET = process.env.JWT_SECRET;

function verifyToken(event) {
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw Object.assign(new Error('未提供 Token'), { httpCode: 401 });
  }
  const token = authHeader.slice(7);
  return verify(token, JWT_SECRET);
}

module.exports = { verifyToken };

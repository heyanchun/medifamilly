/**
 * shared/auth-middleware.js
 * JWT 验证中间件，所有需要登录的接口调用此方法
 */
const jwt = require('jsonwebtoken');
const { ERRORS } = require('./response');

const JWT_SECRET = process.env.JWT_SECRET;

/**
 * 验证请求头中的 Bearer Token
 * @param {object} event CloudBase 函数事件对象
 * @returns {{ userId, role, phone }} 解码后的用户信息
 */
function verifyToken(event) {
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw Object.assign(new Error('未提供 Token'), { httpCode: 401 });
  }
  const token = authHeader.slice(7);
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (e) {
    throw Object.assign(new Error('Token 无效或已过期'), { httpCode: 401 });
  }
}

module.exports = { verifyToken };

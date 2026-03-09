/**
 * shared/response.js
 * 统一 HTTP 响应格式
 */

const ok = (data = null, message = 'success') => ({
  code: 0,
  message,
  data,
});

const fail = (message = 'error', code = -1, data = null) => ({
  code,
  message,
  data,
});

const ERRORS = {
  UNAUTHORIZED: fail('未授权，请重新登录', 401),
  NOT_FOUND: fail('资源不存在', 404),
  INVALID_PARAMS: (msg) => fail(msg || '参数错误', 400),
  SERVER_ERROR: (msg) => fail(msg || '服务器内部错误', 500),
  FORBIDDEN: fail('无权限操作', 403),
};

module.exports = { ok, fail, ERRORS };

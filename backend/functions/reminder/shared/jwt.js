/**
 * shared/jwt.js
 * 用 Node.js 内置 crypto 实现 JWT HS256，替代 jsonwebtoken 包
 */
const crypto = require('crypto');

function base64url(buf) {
  return Buffer.from(buf)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function sign(payload, secret, options = {}) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);

  const claims = {
    iat: now,
    ...payload,
  };

  if (options.expiresIn) {
    const match = String(options.expiresIn).match(/^(\d+)([smhd])$/);
    if (match) {
      const n = parseInt(match[1]);
      const unit = { s: 1, m: 60, h: 3600, d: 86400 }[match[2]];
      claims.exp = now + n * unit;
    }
  }

  const h = base64url(JSON.stringify(header));
  const p = base64url(JSON.stringify(claims));
  const sig = base64url(
    crypto.createHmac('sha256', secret).update(`${h}.${p}`).digest()
  );
  return `${h}.${p}.${sig}`;
}

function verify(token, secret) {
  const parts = token.split('.');
  if (parts.length !== 3) throw Object.assign(new Error('invalid token'), { httpCode: 401 });

  const [h, p, sig] = parts;
  const expected = base64url(
    crypto.createHmac('sha256', secret).update(`${h}.${p}`).digest()
  );
  if (sig !== expected) throw Object.assign(new Error('invalid signature'), { httpCode: 401 });

  const claims = JSON.parse(Buffer.from(p, 'base64').toString());
  const now = Math.floor(Date.now() / 1000);
  if (claims.exp && claims.exp < now) throw Object.assign(new Error('token expired'), { httpCode: 401 });

  return claims;
}

module.exports = { sign, verify };

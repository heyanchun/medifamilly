/**
 * shared/hash.js
 * 用 Node.js 内置 crypto 实现密码哈希，替代 bcryptjs 包
 * 算法：PBKDF2-SHA512，10000 次迭代，64 字节输出
 */
const crypto = require('crypto');

const ITERATIONS = 10000;
const KEYLEN = 64;
const DIGEST = 'sha512';

async function hash(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = await _pbkdf2(password, salt);
  return `${salt}:${derived}`;
}

async function compare(password, stored) {
  const [salt] = stored.split(':');
  const derived = await _pbkdf2(password, salt);
  const expected = `${salt}:${derived}`;
  // 常数时间比较，防止时序攻击
  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(stored));
}

function _pbkdf2(password, salt) {
  return new Promise((resolve, reject) => {
    crypto.pbkdf2(password, salt, ITERATIONS, KEYLEN, DIGEST, (err, key) => {
      if (err) reject(err);
      else resolve(key.toString('hex'));
    });
  });
}

module.exports = { hash, compare };

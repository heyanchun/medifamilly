/**
 * shared/credentials.js
 * 统一凭证获取
 * - 生产（CloudBase 云函数）：优先用内置环境凭证，自动轮换，无需手动配置
 * - 本地开发：回退到 .env / 环境变量中的 TENCENT_SECRET_ID / TENCENT_SECRET_KEY
 *
 * CloudBase 内置凭证文档：
 * https://cloud.tencent.com/document/product/1301/53757
 */

function getCredentials() {
  const secretId  = process.env.TENCENTCLOUD_SECRETID  || process.env.TENCENT_SECRET_ID;
  const secretKey = process.env.TENCENTCLOUD_SECRETKEY || process.env.TENCENT_SECRET_KEY;
  const token     = process.env.TENCENTCLOUD_SESSIONTOKEN; // 内置凭证有 session token，务必传入

  if (!secretId || !secretKey) {
    throw new Error(
      '未找到腾讯云凭证。本地开发请在环境变量中设置 TENCENT_SECRET_ID / TENCENT_SECRET_KEY'
    );
  }

  return { secretId, secretKey, token };
}

module.exports = { getCredentials };

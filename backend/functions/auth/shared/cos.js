/**
 * shared/cos.js
 * 腾讯云 COS 文件上传助手
 * 凭证：优先 CloudBase 内置凭证，本地开发回退到环境变量
 */
const https = require('https');
const crypto = require('crypto');
const { getCredentials } = require('./credentials');

const COS_BUCKET = process.env.COS_BUCKET; // 形如 medifamily-prod-1234567890
const COS_REGION = process.env.COS_REGION || 'ap-guangzhou';

/**
 * 上传 Buffer 到 COS（服务端加密 SSE-COS / AES256）
 */
async function uploadBuffer(key, content, contentType = 'audio/mpeg') {
  const { secretId, secretKey, token } = getCredentials();
  const host = `${COS_BUCKET}.cos.${COS_REGION}.myqcloud.com`;
  const date = new Date().toUTCString();
  const md5  = crypto.createHash('md5').update(content).digest('base64');

  const authorization = _signRequest('PUT', key, host, date, md5, contentType, secretId, secretKey);

  const headers = {
    'Host': host,
    'Date': date,
    'Content-Type': contentType,
    'Content-Length': content.length,
    'Content-MD5': md5,
    'Authorization': authorization,
    'x-cos-server-side-encryption': 'AES256',
  };
  // 临时凭证需额外传 security token
  if (token) headers['x-cos-security-token'] = token;

  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: host,
      path: `/${encodeURIComponent(key).replace(/%2F/g, '/')}`,
      method: 'PUT',
      headers,
    }, (res) => {
      if (res.statusCode === 200) {
        resolve(`cos://${COS_BUCKET}/${key}`);
      } else {
        let body = '';
        res.on('data', (c) => { body += c; });
        res.on('end', () => reject(new Error(`COS 上传失败 ${res.statusCode}: ${body}`)));
      }
    });
    req.on('error', reject);
    req.write(content);
    req.end();
  });
}

/**
 * 生成临时签名 URL（默认 1 小时有效）
 */
function getTempUrl(key, expireSeconds = 3600) {
  const { secretId, secretKey, token } = getCredentials();
  const now     = Math.floor(Date.now() / 1000);
  const keyTime = `${now};${now + expireSeconds}`;
  const signKey = crypto.createHmac('sha1', secretKey).update(keyTime).digest('hex');

  const httpString  = `get\n/${key}\n\nhost=${COS_BUCKET}.cos.${COS_REGION}.myqcloud.com\n`;
  const stringToSign = `sha1\n${keyTime}\n${crypto.createHash('sha1').update(httpString).digest('hex')}\n`;
  const signature   = crypto.createHmac('sha1', signKey).update(stringToSign).digest('hex');

  const params = [
    `q-sign-algorithm=sha1`,
    `q-ak=${secretId}`,
    `q-sign-time=${keyTime}`,
    `q-key-time=${keyTime}`,
    `q-header-list=host`,
    `q-url-param-list=`,
    `q-signature=${signature}`,
    token ? `x-cos-security-token=${token}` : '',
  ].filter(Boolean).join('&');

  return `https://${COS_BUCKET}.cos.${COS_REGION}.myqcloud.com/${key}?${params}`;
}

// 内部：PUT 请求签名
function _signRequest(method, key, host, date, md5, contentType, secretId, secretKey) {
  const stringToSign = [method, md5, contentType, date, `x-cos-server-side-encryption:AES256`, `/${key}`].join('\n');
  const signature    = crypto.createHmac('sha1', secretKey).update(stringToSign).digest('base64');
  return `q-sign-algorithm=sha1&q-ak=${secretId}&q-signature=${signature}`;
}

module.exports = { uploadBuffer, getTempUrl };

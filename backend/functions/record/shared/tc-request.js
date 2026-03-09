/**
 * shared/tc-request.js
 * 腾讯云 API v3 签名 + HTTPS 请求（内置 crypto/https，零外部依赖）
 */
const https  = require('https');
const crypto = require('crypto');
const { getCredentials } = require('./credentials');

function _sign(secretKey, date, service, stringToSign) {
  const kDate    = crypto.createHmac('sha256', `TC3${secretKey}`).update(date).digest();
  const kService = crypto.createHmac('sha256', kDate).update(service).digest();
  const kSigning = crypto.createHmac('sha256', kService).update('tc3_request').digest();
  return crypto.createHmac('sha256', kSigning).update(stringToSign).digest('hex');
}

function _tcRequest(service, action, version, region, payload) {
  const { secretId, secretKey, token } = getCredentials();
  const host = `${service}.tencentcloudapi.com`;
  const body = JSON.stringify(payload);
  const timestamp = Math.floor(Date.now() / 1000);
  const date = new Date(timestamp * 1000).toISOString().slice(0, 10);

  const hashedBody = crypto.createHash('sha256').update(body).digest('hex');
  const canonicalReq = `POST\n/\n\ncontent-type:application/json\nhost:${host}\n\ncontent-type;host\n${hashedBody}`;
  const credScope = `${date}/${service}/tc3_request`;
  const stringToSign = `TC3-HMAC-SHA256\n${timestamp}\n${credScope}\n${crypto.createHash('sha256').update(canonicalReq).digest('hex')}`;
  const signature = _sign(secretKey, date, service, stringToSign);
  const auth = `TC3-HMAC-SHA256 Credential=${secretId}/${credScope}, SignedHeaders=content-type;host, Signature=${signature}`;

  const headers = {
    'Content-Type': 'application/json',
    'Host': host,
    'X-TC-Action': action,
    'X-TC-Version': version,
    'X-TC-Timestamp': String(timestamp),
    'X-TC-Region': region,
    'Authorization': auth,
  };
  if (token) headers['X-TC-Token'] = token;

  return new Promise((resolve, reject) => {
    const req = https.request({ hostname: host, path: '/', method: 'POST', headers }, (res) => {
      let data = '';
      res.on('data', (c) => data += c);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.Response?.Error) reject(new Error(parsed.Response.Error.Message));
          else resolve(parsed.Response);
        } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

module.exports = { _tcRequest };

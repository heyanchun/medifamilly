/**
 * shared/tpns.js
 * 腾讯移动推送 TPNS 封装
 * 文档：https://cloud.tencent.com/document/product/548
 *
 * 应用信息（com.medifamily.app）：
 *   AccessId:  1500045920
 *   AccessKey: ACYWTEAJ0VMC  （Android SDK / local.properties 使用）
 *   SecretKey: 0ecd7235fb98808f5c5ceefb6ba763eb  （后端 REST API 鉴权使用）
 *
 * CloudBase 环境变量配置：
 *   TPNS_ACCESS_ID=1500045920
 *   TPNS_SECRET_KEY=0ecd7235fb98808f5c5ceefb6ba763eb
 */
const https = require('https');

const TPNS_ACCESS_ID = process.env.TPNS_ACCESS_ID  || '1500045920';
const TPNS_SECRET_KEY = process.env.TPNS_SECRET_KEY || '0ecd7235fb98808f5c5ceefb6ba763eb';
const TPNS_HOST = 'api.tpns.tencent.com';

/**
 * 向指定账号（手机号）发送 Push 通知
 * @param {string} account 用户账号（手机号）
 * @param {string} title 通知标题
 * @param {string} content 通知内容
 * @param {object} extra 自定义透传数据
 */
async function pushToAccount(account, title, content, extra = {}) {
  const payload = {
    audience_type: 'account',
    account_list: [account],
    message_type: 'notify',
    message: {
      title,
      content,
      android: {
        action: {
          action_type: 1, // 打开 app
        },
        custom_content: JSON.stringify(extra),
      },
    },
  };

  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const auth = Buffer.from(`${TPNS_ACCESS_ID}:${TPNS_SECRET_KEY}`).toString('base64');
    const options = {
      hostname: TPNS_HOST,
      path: '/v3/push/app',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${auth}`,
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => resolve(JSON.parse(data)));
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

module.exports = { pushToAccount };

/**
 * shared/db.js
 * CloudBase 数据库封装 — 纯 HTTP 实现，零外部依赖
 *
 * 云函数运行时自动注入环境变量：
 *   TENCENTCLOUD_SECRETID / TENCENTCLOUD_SECRETKEY / TENCENTCLOUD_SESSIONTOKEN
 *   TCB_ENV_ID
 *
 * CloudBase 数据库 HTTP API 文档：
 *   https://docs.cloudbase.net/api-reference/server/node-sdk/database/database
 *   实际走的是 tcb.tencentcloudapi.com 的 DatabaseMigrateQueryInfo 等接口，
 *   但更简单的方式是走 CloudBase 的 "数据库HTTP访问服务"：
 *   POST https://{envId}.api.tcloudbasegateway.com/v1/db/... （需要 AccessToken）
 *
 * 这里使用最直接的方式：通过 @cloudbase/node-sdk 的内置路径，
 * 或者回退到 CloudBase 官方提供的 tcb-js-sdk（云函数内置）
 */

const https = require('https');
const crypto = require('crypto');

const ENV_ID     = process.env.TCB_ENV_ID;
const SECRET_ID  = process.env.TENCENTCLOUD_SECRETID;
const SECRET_KEY = process.env.TENCENTCLOUD_SECRETKEY;
const SESSION    = process.env.TENCENTCLOUD_SESSIONTOKEN;
const REGION     = 'ap-guangzhou';

if (!ENV_ID) throw new Error('TCB_ENV_ID not set');

// ── TC3 签名 ─────────────────────────────────────────────────────
function tc3Sign(secretKey, date, service, stringToSign) {
  const kDate    = crypto.createHmac('sha256', `TC3${secretKey}`).update(date).digest();
  const kService = crypto.createHmac('sha256', kDate).update(service).digest();
  const kSigning = crypto.createHmac('sha256', kService).update('tc3_request').digest();
  return crypto.createHmac('sha256', kSigning).update(stringToSign).digest('hex');
}

function tcbRequest(action, payload) {
  const service = 'tcb';
  const host    = `${service}.tencentcloudapi.com`;
  const body    = JSON.stringify(payload);
  const ts      = Math.floor(Date.now() / 1000);
  const date    = new Date(ts * 1000).toISOString().slice(0, 10);
  const hb      = crypto.createHash('sha256').update(body).digest('hex');
  const cr      = `POST\n/\n\ncontent-type:application/json\nhost:${host}\n\ncontent-type;host\n${hb}`;
  const cs      = `${date}/${service}/tc3_request`;
  const s2s     = `TC3-HMAC-SHA256\n${ts}\n${cs}\n${crypto.createHash('sha256').update(cr).digest('hex')}`;
  const sig     = tc3Sign(SECRET_KEY, date, service, s2s);
  const auth    = `TC3-HMAC-SHA256 Credential=${SECRET_ID}/${cs}, SignedHeaders=content-type;host, Signature=${sig}`;

  const headers = {
    'Content-Type': 'application/json',
    'Host': host,
    'X-TC-Action': action,
    'X-TC-Version': '2018-06-08',
    'X-TC-Timestamp': String(ts),
    'X-TC-Region': REGION,
    'Authorization': auth,
  };
  if (SESSION) headers['X-TC-Token'] = SESSION;

  return new Promise((resolve, reject) => {
    const req = https.request({ hostname: host, path: '/', method: 'POST', headers }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try {
          const p = JSON.parse(data);
          if (p.Response && p.Response.Error) {
            reject(new Error(`TCB API Error ${p.Response.Error.Code}: ${p.Response.Error.Message}`));
          } else {
            resolve(p.Response);
          }
        } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// ── 数据库操作封装 ────────────────────────────────────────────────
// CloudBase 数据库 API（RunQuery）支持 MongoDB 风格查询

async function runQuery(query) {
  const res = await tcbRequest('DatabaseMigrateQueryInfo', {
    EnvId: ENV_ID,
    ...query,
  });
  return res;
}

// 简化版：直接用 TCB 的 document CRUD API
// Action: DatabaseGetDocument / DatabaseQueryDocument / DatabaseAddDocument / DatabaseUpdateDocument

async function dbAdd(collection, data) {
  const res = await tcbRequest('DatabaseAddDocument', {
    EnvId: ENV_ID,
    Resource: collection,
    Document: JSON.stringify({ ...data, _createTime: Date.now() }),
  });
  return { id: res.Id };
}

async function dbGet(collection, docId) {
  try {
    const res = await tcbRequest('DatabaseGetDocument', {
      EnvId: ENV_ID,
      Resource: collection,
      Id: docId,
    });
    return res.Document ? JSON.parse(res.Document) : null;
  } catch (e) {
    if (e.message.includes('not found') || e.message.includes('NotFound')) return null;
    throw e;
  }
}

async function dbQuery(collection, filter, options = {}) {
  const payload = {
    EnvId: ENV_ID,
    Resource: collection,
    Filter: filter ? JSON.stringify(filter) : undefined,
    Limit: options.limit || 100,
    Offset: options.offset || 0,
    OrderBy: options.orderBy,
    OrderDirection: options.orderDirection,
  };
  // 移除 undefined 字段
  Object.keys(payload).forEach(k => payload[k] === undefined && delete payload[k]);

  const res = await tcbRequest('DatabaseQueryDocument', payload);
  return (res.DocumentList || []).map(d => JSON.parse(d));
}

async function dbUpdate(collection, docId, data) {
  await tcbRequest('DatabaseUpdateDocument', {
    EnvId: ENV_ID,
    Resource: collection,
    Id: docId,
    Document: JSON.stringify({ ...data, _updateTime: Date.now() }),
    MergeMode: 'Overwrite',
  });
}

// ── docGet / whereGet helpers ─────────────────────────────────────
function docGet(result) {
  if (!result) return null;
  if (Array.isArray(result)) return result[0] || null;
  return result;
}

function whereGet(result) {
  if (!result) return [];
  if (Array.isArray(result)) return result;
  return [result];
}

// ── db 对象（兼容原有 CloudBase SDK 调用风格）────────────────────
// 提供 .collection(name).doc(id).get() / .where(q).get() / .add(data) / .update(data) 接口
class Collection {
  constructor(name) { this.name = name; }

  doc(id) {
    const name = this.name;
    return {
      get: () => dbGet(name, id).then(d => ({ data: d })),
      update: (data) => dbUpdate(name, id, data),
    };
  }

  where(filter) {
    const name = this.name;
    let _limit = 100;
    let _orderBy = null;
    let _orderDir = null;
    const self = {
      orderBy: (field, dir) => { _orderBy = field; _orderDir = dir; return self; },
      limit: (n) => { _limit = n; return self; },
      get: () => dbQuery(name, filter, { limit: _limit, orderBy: _orderBy, orderDirection: _orderDir })
                   .then(docs => ({ data: docs })),
    };
    return self;
  }

  add(data) { return dbAdd(this.name, data); }

  get() { return dbQuery(this.name, {}).then(docs => ({ data: docs })); }
}

const db = {
  collection: (name) => new Collection(name),
  command: {
    in: (arr) => ({ $in: arr }),
    gte: (v)  => ({ $gte: v }),
    lte: (v)  => ({ $lte: v }),
    lt:  (v)  => ({ $lt: v }),
    eq:  (v)  => ({ $eq: v }),
    and: (conditions) => ({ $and: conditions }),
    elemMatch: (cond) => ({ $elemMatch: cond }),
  },
};

// app.callFunction 仍用 TCB API
const app = {
  callFunction: async ({ name, data }) => {
    return tcbRequest('InvokeCloudFunction', {
      EnvId: ENV_ID,
      FunctionName: name,
      RequestData: JSON.stringify(data),
    });
  },
};

const COLLECTIONS = {
  USERS: 'users',
  CHILD_PROFILES: 'child_profiles',
  BINDINGS: 'bindings',
  MED_PLANS: 'med_plans',
  REMINDER_LOGS: 'reminder_logs',
  CALL_RECORDS: 'call_records',
};

module.exports = { db, COLLECTIONS, app, docGet, whereGet };

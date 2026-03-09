/**
 * shared/db.js
 * CloudBase 数据库封装，统一集合名称管理
 * 兼容云函数运行时内置 SDK 路径（不依赖 node_modules）
 */

// 云函数运行时内置 SDK 路径（Node 18）
const BUILTIN_PATHS = [
  '/var/lang/node18/lib/node_modules/@cloudbase/node-sdk',
  '/var/lang/node16/lib/node_modules/@cloudbase/node-sdk',
  '/var/runtime/node_modules/@cloudbase/node-sdk',
  '@cloudbase/node-sdk',
];

let cloudbase;
for (const p of BUILTIN_PATHS) {
  try { cloudbase = require(p); break; } catch(e) { /* try next */ }
}
if (!cloudbase) throw new Error('Cannot find @cloudbase/node-sdk in any known path: ' + BUILTIN_PATHS.join(', '));

const app = cloudbase.init({ env: process.env.TCB_ENV_ID });
const db = app.database();

const COLLECTIONS = {
  USERS: 'users',
  CHILD_PROFILES: 'child_profiles',
  BINDINGS: 'bindings',
  MED_PLANS: 'med_plans',
  REMINDER_LOGS: 'reminder_logs',
  CALL_RECORDS: 'call_records',
};

module.exports = { db, COLLECTIONS, app };

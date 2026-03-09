/**
 * shared/db.js
 * CloudBase 数据库封装，统一集合名称管理
 */
const cloudbase = require('@cloudbase/node-sdk');

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

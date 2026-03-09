/**
 * functions/reminder/index.js
 * 定时触发器（每分钟）：检查到期提醒，执行三级升级链路
 */
const { db, COLLECTIONS, docGet, whereGet } = require('./shared/db');
const { pushToAccount } = require('./shared/tpns');

const ESCALATION_MINUTES = 30;

exports.main = async () => {
  const now = new Date();
  const hhmm = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  console.log(`[reminder] 触发时间: ${now.toISOString()}, 当前时刻: ${hhmm}`);
  await generateReminders(now, hhmm);
  await escalateReminders(now);
};

async function generateReminders(now, hhmm) {
  const plansRes = await db.collection(COLLECTIONS.MED_PLANS)
    .where({ active: true, timeSlots: db.command.elemMatch(db.command.eq(hhmm)) })
    .get();

  for (const plan of whereGet(plansRes)) {
    const today = new Date(now);
    today.setHours(0, 0, 0, 0);
    const existing = whereGet(await db.collection(COLLECTIONS.REMINDER_LOGS)
      .where({ planId: plan._id, scheduledAt: db.command.gte(today) }).get());

    const alreadyCreatedToday = existing.some(
      (log) => new Date(log.scheduledAt).getHours() === now.getHours() &&
               new Date(log.scheduledAt).getMinutes() === now.getMinutes()
    );
    if (alreadyCreatedToday) continue;

    if (plan.endDate && new Date(plan.endDate) < now) {
      await db.collection(COLLECTIONS.MED_PLANS).doc(plan._id).update({ active: false });
      continue;
    }

    const logResult = await db.collection(COLLECTIONS.REMINDER_LOGS).add({
      planId: plan._id,
      elderId: plan.elderId,
      childId: plan.childId,
      medName: plan.medName,
      dosage: plan.dosage,
      mealTiming: plan.mealTiming,
      scheduledAt: now,
      status: 'pending',
      confirmedAt: null,
      callRecordId: null,
      createdAt: now,
    });

    await sendLevel1Push(plan, logResult.id);
    console.log(`[reminder] 创建提醒: ${logResult.id}, 药品: ${plan.medName}, 长辈: ${plan.elderId}`);
  }
}

async function escalateReminders(now) {
  const cutoff = new Date(now.getTime() - ESCALATION_MINUTES * 60 * 1000);
  const pending = whereGet(await db.collection(COLLECTIONS.REMINDER_LOGS)
    .where({ status: db.command.in(['pending', 'call_sent']), scheduledAt: db.command.lte(cutoff) })
    .get());

  for (const log of pending) {
    if (log.status === 'pending') await escalateToCall(log);
    else if (log.status === 'call_sent') await escalateToNotifyChild(log);
  }
}

async function sendLevel1Push(plan, logId) {
  try {
    const elder = docGet(await db.collection(COLLECTIONS.USERS).doc(plan.elderId).get());
    if (!elder) return;
    await pushToAccount(
      elder.phone,
      '💊 该吃药了',
      `${plan.medName}，${plan.dosage}，${plan.mealTiming}服用`,
      { type: 'reminder', logId, action: 'confirm' }
    );
  } catch (e) {
    console.error('[reminder] 一级 Push 失败:', e.message);
  }
}

async function escalateToCall(log) {
  try {
    const { app } = require('./shared/db');
    await app.callFunction({ name: 'call', data: { action: 'initiateCall', logId: log._id } });
    await db.collection(COLLECTIONS.REMINDER_LOGS).doc(log._id).update({
      status: 'call_sent', callEscalatedAt: new Date(),
    });
    console.log(`[reminder] 升级到二级电话: logId=${log._id}`);
  } catch (e) {
    console.error('[reminder] 二级升级失败:', e.message);
  }
}

async function escalateToNotifyChild(log) {
  try {
    const child = docGet(await db.collection(COLLECTIONS.USERS).doc(log.childId).get());
    if (!child) return;
    const scheduledTime = new Date(log.scheduledAt);
    const hhmm = `${String(scheduledTime.getHours()).padStart(2, '0')}:${String(scheduledTime.getMinutes()).padStart(2, '0')}`;
    await pushToAccount(
      child.phone,
      '⚠️ 用药提醒未确认',
      `长辈今天 ${hhmm} 的 ${log.medName} 还未确认服用`,
      { type: 'alert', logId: log._id }
    );
    await db.collection(COLLECTIONS.REMINDER_LOGS).doc(log._id).update({
      status: 'notified_child', childNotifiedAt: new Date(),
    });
    console.log(`[reminder] 升级到三级通知子女: logId=${log._id}`);
  } catch (e) {
    console.error('[reminder] 三级通知失败:', e.message);
  }
}

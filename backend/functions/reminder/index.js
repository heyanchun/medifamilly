/**
 * functions/reminder/index.js
 * 定时触发器（每分钟）：检查到期提醒，执行三级升级链路
 */
const { db, COLLECTIONS } = require('./shared/db');
const { pushToAccount } = require('./shared/tpns');

const ESCALATION_MINUTES = 30; // 每级升级等待时间

exports.main = async () => {
  const now = new Date();
  const hhmm = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

  console.log(`[reminder] 触发时间: ${now.toISOString()}, 当前时刻: ${hhmm}`);

  // ── Step 1: 生成新提醒 ─────────────────────────────────────────
  await generateReminders(now, hhmm);

  // ── Step 2: 检查超时未确认的提醒，执行升级 ──────────────────────
  await escalateReminders(now);
};

// 生成本分钟应触发的提醒
async function generateReminders(now, hhmm) {
  const plansRes = await db.collection(COLLECTIONS.MED_PLANS)
    .where({
      active: true,
      timeSlots: db.command.elemMatch(db.command.eq(hhmm)),
    })
    .get();

  for (const plan of plansRes.data) {
    // 避免同一分钟重复创建
    const today = new Date(now);
    today.setHours(0, 0, 0, 0);
    const existing = await db.collection(COLLECTIONS.REMINDER_LOGS)
      .where({
        planId: plan._id,
        scheduledAt: db.command.gte(today),
      })
      .get();

    const alreadyCreatedToday = existing.data.some(
      (log) => new Date(log.scheduledAt).getHours() === now.getHours() &&
               new Date(log.scheduledAt).getMinutes() === now.getMinutes()
    );
    if (alreadyCreatedToday) continue;

    // 检查疗程是否过期
    if (plan.endDate && new Date(plan.endDate) < now) {
      await db.collection(COLLECTIONS.MED_PLANS).doc(plan._id).update({ active: false });
      continue;
    }

    // 创建提醒记录
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

    // 发送一级 Push 给长辈
    await sendLevel1Push(plan, logResult.id);
    console.log(`[reminder] 创建提醒: ${logResult.id}, 药品: ${plan.medName}, 长辈: ${plan.elderId}`);
  }
}

// 检查超时提醒，执行升级
async function escalateReminders(now) {
  const thresholdMs = ESCALATION_MINUTES * 60 * 1000;
  const cutoff = new Date(now.getTime() - thresholdMs);

  const pendingRes = await db.collection(COLLECTIONS.REMINDER_LOGS)
    .where({
      status: db.command.in(['pending', 'call_sent']),
      scheduledAt: db.command.lte(cutoff),
    })
    .get();

  for (const log of pendingRes.data) {
    if (log.status === 'pending') {
      // 一级超时 → 升级到二级（电话）
      await escalateToCall(log);
    } else if (log.status === 'call_sent') {
      // 二级超时 → 升级到三级（通知子女）
      await escalateToNotifyChild(log);
    }
  }
}

// 一级：Push 通知长辈
async function sendLevel1Push(plan, logId) {
  try {
    // 获取长辈手机号（用于 TPNS 账号标识）
    const elderRes = await db.collection(COLLECTIONS.USERS).doc(plan.elderId).get();
    if (!elderRes.data) return;

    await pushToAccount(
      elderRes.data.phone,
      '💊 该吃药了',
      `${plan.medName}，${plan.dosage}，${plan.mealTiming}服用`,
      { type: 'reminder', logId, action: 'confirm' }
    );
  } catch (e) {
    console.error('[reminder] 一级 Push 失败:', e.message);
  }
}

// 二级：发起 PSTN 电话（调用 call 云函数）
async function escalateToCall(log) {
  try {
    const { app } = require('./shared/db');
    await app.callFunction({
      name: 'call',
      data: { action: 'initiateCall', logId: log._id },
    });
    await db.collection(COLLECTIONS.REMINDER_LOGS).doc(log._id).update({
      status: 'call_sent',
      callEscalatedAt: new Date(),
    });
    console.log(`[reminder] 升级到二级电话: logId=${log._id}`);
  } catch (e) {
    console.error('[reminder] 二级升级失败:', e.message);
  }
}

// 三级：Push 通知子女
async function escalateToNotifyChild(log) {
  try {
    const childRes = await db.collection(COLLECTIONS.USERS).doc(log.childId).get();
    if (!childRes.data) return;

    const scheduledTime = new Date(log.scheduledAt);
    const hhmm = `${String(scheduledTime.getHours()).padStart(2, '0')}:${String(scheduledTime.getMinutes()).padStart(2, '0')}`;

    await pushToAccount(
      childRes.data.phone,
      '⚠️ 用药提醒未确认',
      `长辈今天 ${hhmm} 的 ${log.medName} 还未确认服用`,
      { type: 'alert', logId: log._id }
    );

    await db.collection(COLLECTIONS.REMINDER_LOGS).doc(log._id).update({
      status: 'notified_child',
      childNotifiedAt: new Date(),
    });
    console.log(`[reminder] 升级到三级通知子女: logId=${log._id}`);
  } catch (e) {
    console.error('[reminder] 三级通知失败:', e.message);
  }
}

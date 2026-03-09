/**
 * shared/vms.js
 * 腾讯云语音通知（VMS）— 用内置 https 替代 tencentcloud-sdk-nodejs
 */
const { getCredentials } = require('./credentials');
const { _tcRequest } = require('./tc-request');

const VMS_APPID       = process.env.VMS_APPID;
const VMS_TEMPLATE_ID = process.env.VMS_TEMPLATE_ID;

async function sendVoiceNotification(phone, templateParams) {
  if (process.env.NODE_ENV === 'development') {
    console.log('[VMS mock] 外呼到', phone, '参数:', templateParams);
    return { CallId: `mock_call_${Date.now()}` };
  }
  const res = await _tcRequest('vms', 'SendTtsVoice', '2020-09-02', 'ap-guangzhou', {
    TemplateId: VMS_TEMPLATE_ID,
    TemplateParamSet: templateParams,
    CalledNumber: `+86${phone}`,
    VoiceSdkAppid: VMS_APPID,
    PlayTimes: 2,
    SessionContext: '',
  });
  return { CallId: res.CallId };
}

module.exports = { sendVoiceNotification };

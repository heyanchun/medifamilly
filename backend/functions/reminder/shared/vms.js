/**
 * shared/vms.js
 * 腾讯云语音通知（VMS）外呼封装
 * 凭证：优先 CloudBase 内置凭证，本地开发回退到环境变量
 */
const tencentcloud = require('tencentcloud-sdk-nodejs');
const VmsClient = tencentcloud.vms.v20200902.Client;
const { getCredentials } = require('./credentials');

const VMS_APPID       = process.env.VMS_APPID;
const VMS_TEMPLATE_ID = process.env.VMS_TEMPLATE_ID;

function getClient() {
  const { secretId, secretKey, token } = getCredentials();
  return new VmsClient({
    credential: { secretId, secretKey, token },
    region: 'ap-guangzhou',
  });
}

/**
 * 发起语音通知外呼（TTS 模板模式）
 * @param {string} phone 11 位手机号（不含 +86）
 * @param {string[]} templateParams 模板参数列表
 */
async function sendVoiceNotification(phone, templateParams) {
  if (process.env.NODE_ENV === 'development') {
    console.log('[VMS mock] 外呼到', phone, '参数:', templateParams);
    return { CallId: `mock_call_${Date.now()}` };
  }

  const client = getClient();
  const result = await client.SendTtsVoice({
    TemplateId: VMS_TEMPLATE_ID,
    TemplateParamSet: templateParams,
    CalledNumber: `+86${phone}`,
    VoiceSdkAppid: VMS_APPID,
    PlayTimes: 2,
    SessionContext: '',
  });

  return { CallId: result.CallId };
}

module.exports = { sendVoiceNotification };

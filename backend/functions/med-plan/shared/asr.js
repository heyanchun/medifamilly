/**
 * shared/asr.js
 * 腾讯云语音识别（ASR）封装
 * 凭证：优先 CloudBase 内置凭证，本地开发回退到环境变量
 */
const tencentcloud = require('tencentcloud-sdk-nodejs');
const AsrClient = tencentcloud.asr.v20190614.Client;
const { getCredentials } = require('./credentials');

// 每次请求重新获取凭证（CloudBase 内置凭证会轮换，不可缓存）
function getClient() {
  const { secretId, secretKey, token } = getCredentials();
  return new AsrClient({
    credential: { secretId, secretKey, token },
    region: 'ap-guangzhou',
  });
}

/**
 * 录音文件识别（异步，适合较长录音）
 */
async function recognizeFile(audioUrl, channelNum = 1) {
  if (process.env.NODE_ENV === 'development') {
    return '每天早上8点和晚上8点吃阿莫西林，饭后服用，一次两片，吃7天。';
  }

  const client = getClient();

  const createResult = await client.CreateRecTask({
    EngineModelType: '16k_zh',
    ChannelNum: channelNum,
    ResTextFormat: 0,
    SourceType: 0,
    Url: audioUrl,
  });

  const taskId = createResult.Data.TaskId;

  for (let i = 0; i < 12; i++) {
    await _sleep(5000);
    const statusResult = await client.DescribeTaskStatus({ TaskId: taskId });
    const task = statusResult.Data;
    if (task.Status === 2) return task.Result;
    if (task.Status === 3) throw new Error('ASR 识别失败：' + task.ErrorMsg);
  }

  throw new Error('ASR 识别超时');
}

/**
 * 一句话识别（适合短句，< 60s）
 */
async function recognizeSentence(audioUrl) {
  if (process.env.NODE_ENV === 'development') {
    return '已经吃了，谢谢你打来。';
  }

  const client = getClient();
  const result = await client.SentenceRecognition({
    ProjectId: 0,
    SubServiceType: 2,
    EngSerViceType: '16k_zh',
    SourceType: 0,
    Url: audioUrl,
    UsrAudioKey: `key_${Date.now()}`,
  });

  return result.Result;
}

function _sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

module.exports = { recognizeFile, recognizeSentence };

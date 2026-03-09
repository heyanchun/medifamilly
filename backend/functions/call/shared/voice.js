/**
 * shared/voice.js
 * 腾讯云音色复刻（TTS 自定义音色）封装
 * 凭证：优先 CloudBase 内置凭证，本地开发回退到环境变量
 */
const tencentcloud = require('tencentcloud-sdk-nodejs');
const TtsClient = tencentcloud.tts.v20190823.Client;
const { getCredentials } = require('./credentials');

function getClient() {
  const { secretId, secretKey, token } = getCredentials();
  return new TtsClient({
    credential: { secretId, secretKey, token },
    region: 'ap-guangzhou',
  });
}

/**
 * 提交音色复刻训练
 */
async function createVoiceModel(voiceName, audioUrls) {
  if (process.env.NODE_ENV === 'development') {
    return { modelId: `mock_${Date.now()}`, status: 'training' };
  }

  const client = getClient();
  const result = await client.CreateCustomizationV2({
    ModelName: voiceName,
    TrainTexts: audioUrls.map((url, i) => ({ AudioUrl: url, TextId: `${i + 1}` })),
    TaskType: 0,
  });

  return { modelId: result.ModelId, status: 'training' };
}

/**
 * 查询音色训练状态
 */
async function getVoiceModelStatus(modelId) {
  if (process.env.NODE_ENV === 'development') {
    return { modelId, status: 'success', voiceType: 101001 };
  }

  const client = getClient();
  const result = await client.DescribeCustomizationV2({ ModelId: modelId });
  const statusMap = { 0: 'training', 1: 'success', 2: 'failed' };
  return {
    modelId,
    status: statusMap[result.Status] || 'unknown',
    voiceType: result.VoiceType,
  };
}

/**
 * 文字转语音（使用克隆音色）
 */
async function synthesize(text, voiceType) {
  if (process.env.NODE_ENV === 'development') {
    return Buffer.from('mock_audio');
  }

  const client = getClient();
  const result = await client.TextToVoice({
    Text: text,
    SessionId: `sess_${Date.now()}`,
    VoiceType: voiceType,
    Codec: 'mp3',
    SampleRate: 16000,
    Speed: 0,
    Volume: 0,
    EnableSubtitle: false,
  });

  return Buffer.from(result.Audio, 'base64');
}

module.exports = { createVoiceModel, getVoiceModelStatus, synthesize };

/**
 * shared/voice.js
 * 腾讯云音色复刻（TTS）— 用内置 https 替代 tencentcloud-sdk-nodejs
 */
const { _tcRequest } = require('./tc-request');

async function createVoiceModel(voiceName, audioUrls) {
  if (process.env.NODE_ENV === 'development') return { modelId: `mock_${Date.now()}`, status: 'training' };
  const res = await _tcRequest('tts', 'CreateCustomizationV2', '2019-08-23', 'ap-guangzhou', {
    ModelName: voiceName,
    TrainTexts: audioUrls.map((url, i) => ({ AudioUrl: url, TextId: `${i + 1}` })),
    TaskType: 0,
  });
  return { modelId: res.ModelId, status: 'training' };
}

async function getVoiceModelStatus(modelId) {
  if (process.env.NODE_ENV === 'development') return { modelId, status: 'success', voiceType: 101001 };
  const res = await _tcRequest('tts', 'DescribeCustomizationV2', '2019-08-23', 'ap-guangzhou', { ModelId: modelId });
  const statusMap = { 0: 'training', 1: 'success', 2: 'failed' };
  return { modelId, status: statusMap[res.Status] || 'unknown', voiceType: res.VoiceType };
}

async function synthesize(text, voiceType) {
  if (process.env.NODE_ENV === 'development') return Buffer.from('mock_audio');
  const res = await _tcRequest('tts', 'TextToVoice', '2019-08-23', 'ap-guangzhou', {
    Text: text,
    SessionId: `sess_${Date.now()}`,
    VoiceType: voiceType,
    Codec: 'mp3',
    SampleRate: 16000,
    Speed: 0,
    Volume: 0,
    EnableSubtitle: false,
  });
  return Buffer.from(res.Audio, 'base64');
}

module.exports = { createVoiceModel, getVoiceModelStatus, synthesize };

/**
 * shared/asr.js
 * 腾讯云语音识别（ASR）— 零外部依赖
 */
const { _tcRequest } = require('./tc-request');

async function recognizeFile(audioUrl, channelNum = 1) {
  if (process.env.NODE_ENV === 'development') {
    return '每天早上8点和晚上8点吃阿莫西林，饭后服用，一次两片，吃7天。';
  }
  const res = await _tcRequest('asr', 'CreateRecTask', '2019-06-14', 'ap-guangzhou', {
    EngineModelType: '16k_zh', ChannelNum: channelNum, ResTextFormat: 0, SourceType: 0, Url: audioUrl,
  });
  const taskId = res.Data.TaskId;
  for (let i = 0; i < 12; i++) {
    await _sleep(5000);
    const sr = await _tcRequest('asr', 'DescribeTaskStatus', '2019-06-14', 'ap-guangzhou', { TaskId: taskId });
    if (sr.Data.Status === 2) return sr.Data.Result;
    if (sr.Data.Status === 3) throw new Error('ASR 识别失败：' + sr.Data.ErrorMsg);
  }
  throw new Error('ASR 识别超时');
}

async function recognizeSentence(audioUrl) {
  if (process.env.NODE_ENV === 'development') return '已经吃了，谢谢你打来。';
  const res = await _tcRequest('asr', 'SentenceRecognition', '2019-06-14', 'ap-guangzhou', {
    ProjectId: 0, SubServiceType: 2, EngSerViceType: '16k_zh',
    SourceType: 0, Url: audioUrl, UsrAudioKey: `key_${Date.now()}`,
  });
  return res.Result;
}

function _sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
module.exports = { recognizeFile, recognizeSentence };

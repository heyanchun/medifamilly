# 亲声药铃 (MediFamily)

用您的声音，守护家人健康。

---

## 项目结构

```
medifamily/
├── app/          # Flutter Android 客户端
├── backend/      # 腾讯云 CloudBase 云函数
└── docs/         # 需求与设计文档
```

## 快速开始

### 后端

```bash
cd backend
# 安装腾讯云 CloudBase CLI
npm install -g @cloudbase/cli

# 登录
tcb login

# 部署所有云函数
tcb fn deploy --all
```

### 客户端

```bash
cd app
flutter pub get
flutter run
```

## 环境变量（CloudBase 云函数）

在 CloudBase 控制台配置以下环境变量：

| 变量名 | 说明 |
|--------|------|
| `JWT_SECRET` | JWT 签名密钥（随机生成，至少 32 位）|
| `TENCENT_SECRET_ID` | 腾讯云 SecretId |
| `TENCENT_SECRET_KEY` | 腾讯云 SecretKey |
| `DEEPSEEK_API_KEY` | DeepSeek API Key |
| `TPNS_ACCESS_ID` | 腾讯移动推送 Access ID |
| `TPNS_SECRET_KEY` | 腾讯移动推送 Secret Key |
| `VMS_APPID` | 腾讯云语音通知 AppId |
| `VMS_TEMPLATE_ID` | 腾讯云语音通知模板 ID |
| `COS_BUCKET` | COS 存储桶名称 |
| `COS_REGION` | COS 区域（如 ap-guangzhou）|

## 技术栈

- 客户端：Flutter 3.x（Android 先行）
- 后端：Node.js 18 + 腾讯云 CloudBase
- AI 对话：DeepSeek-V3
- 语音识别：腾讯云 ASR
- 声音克隆：腾讯云音色复刻
- 电话外呼：腾讯云 VMS（PSTN）
- Push 通知：腾讯移动推送 TPNS
- 存储：腾讯云 COS

## 开发进度

- [x] 项目目录结构
- [x] 需求文档 & 架构设计
- [x] 后端云函数骨架（auth / med-plan / reminder / call / record）
- [x] 后端腾讯云 SDK 集成层（asr / cos / vms / voice）
- [x] Flutter 客户端框架（主题、常量、路由）
- [x] Flutter 注册 & 绑定流程（注册、子女画像、邀请长辈、长辈确认绑定）
- [x] 长辈端首页（大字体 + 一键打卡）
- [x] 子女端语音录入页（录音 + AI 解析 + 确认）
- [x] 子女端首页（长辈列表 + 依从率）
- [x] 服药记录 + 通话记录回听页
- [x] Android Push 配置（TPNS + Firebase）
- [x] AndroidManifest 权限声明
- [x] Kotlin MainActivity（TPNS 绑定 + 通知渠道）
- [x] 端到端联调 Checklist
- [ ] 端到端联调验证

# CXY 工作台开源版

[English](README.md) · [简体中文](README.zh-CN.md)

从原行动台升级而来的统一工作台：Mac 与安卓客户端展示 Markdown 工作安排、设备指标和同一份每日信息。

## 下载与安装

[v2.2.0 Release](https://github.com/moxingddyp/action-desk/releases/tag/v2.2.0)提供 Apple Silicon Mac DMG/ZIP、安卓 APK、源码包与 SHA256 校验。Mac 要求 macOS 27，安卓要求 Android 11。Mac 包为临时签名，未经 Apple 公证；本发布版尚未在另一台机器完成首次安装验收。

Mac 开源版保留独立的应用标识、OSS 缓存及 `cxy-actiondesk-oss`、`cxy-devices-oss` 入口，可与私人安装共存。安卓包名为 `com.cxy.workbench`，覆盖安装前阅读[签名与构建说明](android/README.md)。

## 主要功能

- Mac 统一窗口包含行动、设备和四类信息阅读页。
- 从单一 Markdown 清单生成圆环、列表、日历，可跳转用户自己的 Codex 对话。
- Mac、Windows、Linux、手机、网关各有独立桌面卡片。
- 安卓设备总览、主题、事项/日历、信息阅读、小组件和需系统确认的应用更新。
- 可选 Linux 角色鉴权 API；缺测与过期明确显示，不根据在线状态编造硬件或路径指标。

## 配置

按[安装说明](docs/INSTALL.zh-CN.md)复制 `examples/` 到自己的资料目录。在 `~/Library/Application Support/CXY Action Desk OSS/config.json` 填入资料路径和自己的主对话 UUID；示例虚构 UUID 不会打开真实对话。

跨设备功能需自行部署[服务](service/README.md)，在同一 Mac 配置目录创建 `client.json`，并向安卓导入仅手机角色的连接文件。示例只含占位符，令牌须自行生成并私下保存。支持 HTTPS；HTTP 仅用于回环或加密私网 100.64.0.0/10，不要向公网暴露服务。

信息页读取 `/v1/information`。本包不包含私人订阅、账号会话、定时模型代理和历史信息，采集程序由使用者自行接入。

## 构建与验证

Apple Silicon、macOS 27、Xcode 27.1：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer sh native/build.sh
sh tests/run.sh --check-only
```

脚本仅构建，不安装或启动。安卓和服务构建、测试入口分别见各目录说明。

## 从 1.0.1 升级

退出旧开源版后替换 App，保留原 `config.json` 和行动缓存。新名称为 CXY Workbench OSS，设备卡使用独立 OSS 缓存；系统要求时重新选择或添加组件。跨设备功能需新增自己的服务配置。本包不迁移私人安装，不改网络设置。

更多见[更新记录](CHANGELOG.md)、[数据格式](docs/DATA-FORMAT.md)、[验证范围](docs/ACCEPTANCE.md)、[隐私与许可](docs/PRIVACY-AND-LICENSING.md)、[依赖](THIRD-PARTY.md)。

## 许可

原创代码采用 [MIT](LICENSE)，作者 [moxingddyp](https://github.com/moxingddyp)。第三方工具保留各自许可。本项目与 Apple、Google、OpenAI 无官方从属关系。

已有开源版更新可使用 `native/install-workbench.py`：先看 `--help` 和默认校验，再指定备份目录执行 `--apply`，包含定向回收旧组件进程；只针对 OSS 应用。

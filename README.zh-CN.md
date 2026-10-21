# 行动台｜适配Codex的macOS桌面小组件

[English](README.md) · [简体中文](README.zh-CN.md)

![行动台应用图标](native/Assets.xcassets/AppIcon.appiconset/icon-128.png)

把已有的工作安排放到macOS桌面上，并从事项直接进入对应的Codex线程继续工作。

行动台提供圆环、列表和日历视图。它读取你维护的Markdown清单，不建立另一套任务数据库。

## 功能

- 原生WidgetKit桌面小组件。
- 多彩圆环，支持最多两层展示和两位项目编号。
- 点击环段展开事项，再点同一环段收起，点击其他环段切换事项。
- 圆环与列表视图切换。
- 日历展示已安排的活动。
- 点击事项详情进入对应Codex线程；点击圆环中心进入配置的主线程。
- 从同一份清单生成分类、去重总数和日历。

分类包括“优先做”“正在做”“当前可做”和“条件做”。后三类互斥，“优先做”可以叠加。

## 下载安装（普通用户，无需Xcode）

本地已准备1.0.1版DMG和ZIP，正在验收，**尚未上传**；当前GitHub仓库仍只提供源码。验收通过后的安装包将放在[Releases](https://github.com/moxingddyp/action-desk/releases)。

适用Apple Silicon Mac、macOS 27.0或更高版本。下载DMG后将App拖入“应用程序”，或解压ZIP后拖入，再按[中英文安装说明](docs/INSTALL.zh-CN.md)配置已有清单并添加桌面小组件。普通用户不需要Xcode、Python或Homebrew。

当前验收包使用本地临时签名，没有Developer ID签名或Apple公证。互联网下载后可能被系统拦截；具体状态及Apple官方打开方式见安装说明。尚未完成另一台Mac的互联网下载、安装和WidgetKit加载验收。

## 源码构建（开发者）

只有自行编译、修改源码才需要Xcode。构建和离线测试环境：

- Apple Silicon Mac。
- macOS 27.0.1。
- Xcode 27.1。
- 工程最低部署目标：macOS 27.0，arm64。

其他系统、Intel Mac和其他Xcode版本尚未验证。环境由使用者自行准备。

先完成Xcode首次启动和macOS开发组件安装，在仓库根目录执行：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer sh native/build.sh
```

构建产物为`CXY Action Desk OSS.app`。脚本只构建和本机签名，不自动安装或启动应用。

可用`sh native/package.sh APP_PATH OUTPUT_DIRECTORY`将已构建App打包为DMG和ZIP。该脚本不安装、启动、公证或上传应用。图标为本项目原创矢量绘制，已随源码提供多尺寸资源及生成脚本。

## 配置与使用

1. 将`examples/`中的示例清单、项目索引和线程映射复制到自己的资料目录。
2. 在`~/Library/Application Support/CXY Action Desk OSS/config.json`中配置资料目录和Codex主线程ID。
3. 将示例线程ID替换为自己可访问的Codex线程ID。
4. 安装并打开下载或自行构建得到的应用。
5. 在桌面“编辑小组件”中添加“CXY行动台OSS”。

没有配置对应工作线程的事项会回到主线程。示例线程ID不会用于实际导航。

主应用每60秒检查来源，也可通过菜单或以下入口请求刷新：

```sh
open 'cxy-actiondesk-oss://refresh'
```

小组件的实际刷新时机由WidgetKit调度。

## 数据与集成边界

工作进度保存在原Markdown清单中。应用只保存展示缓存和视图偏好，不修改事项状态。

本项目不包含邮件、微信、录音接入、模型调用或后台任务代理，也不自动读取Codex聊天记录。

“正在做”的48小时判断由清单维护方负责；行动台按清单中的分类展示。

当前界面和部分输入格式使用中文。英文文档不代表界面或清单格式已经完成英文适配。

## 测试

```sh
sh tests/run.sh --check-only
```

已完成独立Release构建、签名检查、数据投影、分类、圆环点击区域、视图切换和日历相关离线测试。

发布源码副本尚未在独立新用户环境中完成WidgetKit安装、权限和真实线程跳转的完整验收。示例和预览均为虚构数据。

## 配套说明

- [下载安装](docs/INSTALL.zh-CN.md)
- [数据格式](docs/DATA-FORMAT.zh-CN.md)
- [环境与已验证范围](docs/ACCEPTANCE.zh-CN.md)
- [第三方组成](THIRD-PARTY.zh-CN.md)
- [隐私与许可](docs/PRIVACY-AND-LICENSING.zh-CN.md)

## 许可

自有代码采用[MIT许可证](LICENSE)。

作者：[moxingddyp](https://github.com/moxingddyp)。

第三方系统框架和工具遵循各自许可。行动台为独立项目，不代表OpenAI或Apple官方产品。

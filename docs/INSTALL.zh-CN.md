# 下载安装行动台

[English](INSTALL.md) · [简体中文](INSTALL.zh-CN.md)

## 安装要求

- Apple Silicon Mac，macOS 27.0或更高版本；本机验证环境为macOS 27.0.1。
- 不需要Xcode、Python、Homebrew或命令行开发工具。
- 跳转工作线程需要安装Codex并登录你有权访问对应线程的账号。
- 界面和清单字段目前使用中文。它只展示既有Markdown安排，不自动创建或维护任务。

## 安装App

1. 下载DMG并打开，将`CXY Action Desk OSS.app`拖到`Applications`。也可解压ZIP，再将其中App拖到“应用程序”。不要直接从磁盘映像运行。
2. 打开“应用程序”中的App。它是菜单栏应用，没有常驻主窗口；菜单栏出现四格图标即已启动。
3. 当前验收包只有本地临时签名，没有Developer ID签名或Apple公证。互联网下载后的首次启动可能被macOS拦截；若你确认来源并决定继续，可按Apple官方说明在“系统设置 → 隐私与安全性”中对该App选择“仍要打开”。不需要关闭Gatekeeper或删除隔离属性。
4. 不把出现安全拦截等同于成功安装。当前尚未验证另一台Mac从互联网下载后的完整安装及小组件加载流程。

## 配置已有安排

1. 安装包中的`Example Work Plan`包含虚构清单、项目索引、线程映射及`config.example.json`。先复制到自己的可写资料目录；不要覆盖已有工作安排。
2. 在Finder按Shift–Command–G，打开`~/Library/Application Support/`，创建`CXY Action Desk OSS`文件夹。
3. 将示例中的`config.example.json`复制到该文件夹并改名为`config.json`，使用纯文本编辑器编辑：`sourceDirectory`填已有清单目录的绝对路径，`chiefThread`填自己的Codex主线程UUID。保持有效JSON格式。
4. 资料目录必须有`PROJECT.md`、`PROJECTS.md`和`tools/desktop-action-desk/thread-links.json`；将映射中的演示UUID替换为自己有权访问的工作线程。示例UUID不会真的跳转。
5. 点击菜单栏图标，选择“刷新现有安排”。然后在桌面空白处右键 → 编辑小组件，添加“CXY行动台OSS”。具体字段见仓库的中英文“数据格式”文档。

App每60秒检查一次源文件。小组件的实际刷新时机由WidgetKit调度。与另行安装的非OSS版使用不同App标识、配置目录和URL入口，不会读取它的真实清单。

## 卸载与数据

退出菜单栏App，移除桌面小组件，再将OSS版App移到废纸篓。资料目录不会删除；配置、偏好及显示缓存位于`~/Library/Application Support/CXY Action Desk OSS/`，由你决定是否保留。

来源：[Apple：安全地打开Mac上的App](https://support.apple.com/102445)。

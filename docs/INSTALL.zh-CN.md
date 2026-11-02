# 安装与配置

1. 从 Release 下载对应平台安装包，核对 SHA256SUMS.txt。
2. Mac 将 CXY Workbench OSS.app 放入 Applications。包未经 Apple 公证；若系统阻止，请按 Apple 官方说明通过系统设置批准打开，不关闭系统安全检查。
3. 将仓库 examples 复制到自己的资料目录。修改所有虚构项目和对话映射。
4. 在 `~/Library/Application Support/CXY Action Desk OSS/config.json` 设置 `sourceDirectory` 和 `chiefThread`，示例见 examples/config.example.json。
5. 启动应用，从 macOS 编辑小组件添加需要的卡片。系统决定组件实际刷新时间。
6. 跨设备功能另按 service/README.md 部署服务，在同一配置目录创建 client.json；只向手机分发手机角色连接文件。

更新时退出旧开源 App、替换 App，并保留配置与缓存。新组件初次安装、旧扩展进程回收和跨机器导航尚须实际环境验收，不以构建通过代替。安卓说明见 ../android/README.md。

Apple 官方打开说明：https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac

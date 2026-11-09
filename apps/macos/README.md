# Any Sidebar for Mac

一个留在桌边的阅读小助手。沿用 Any Sidebar 的对话界面，用划词和手动截图辅助阅读本地资料。

目前是 **0.1.0 本机开发版**，适用于 Apple Silicon、macOS 14 或更新系统。尚未完成 Developer ID 签名和公证。

## 怎么用

1. 打开应用，点小助手展开对话，再点一次收起。右键小助手可框选读屏，菜单栏也可恢复入口。
2. 在设置中填写自己的 DeepSeek API Key。Key 保存在 macOS 钥匙串，API 用量由你的 DeepSeek 账户承担。
3. 需要自动划词时，先确认采集说明并开启辅助功能权限。在「预览」中选中文字后，引用进入当前任务草稿。
4. 需要读图时，选择框选区域或窗口。截图先进入草稿；输入问题并发送，模型才收到资料。

阅读任务由你自己新建和切换。同一个任务可以引用多份文档，不会因为切换 PDF 自动换会话。

每次最多新增 9 张截图，单张最多 10 MiB；加上历史后最多 16 个图像块，完整请求体最多 24 MiB。超限会提示，不会悄悄删图或截断历史。Flash 支持图像，Pro 仅支持文字。

## 本机开发

在仓库根目录运行：

```sh
npm ci
npm run typecheck:mac
npm run test:mac:native
npm run test:mac:web
npm run build:mac
npm run audit:mac
npm run package:mac
```

构建包位于 `build/macos/AnySidebarMac.app`。打包结果位于 `release/macos/`，不混入 Chrome 扩展的 ZIP。

原生部分使用 Swift、AppKit、WKWebView、SQLite 和系统钥匙串。React 展示组件与浏览器插件共用，数据和网络层分别实现。没有本地 HTTP 服务、Electron 或第三方 API 中转。

[使用与权限说明](../../docs/macos/user-guide.md) · [阅读质量样例](../../docs/macos/reading-evaluation.md)

仅有截图时可以直接发送，无需输入文字；此时默认解读图片内容。Shift+A 会占用输入大写 A 的组合，可以在设置修改或清除。

## 本机签名

默认构建使用临时签名。开发者明确同意后，可运行 `node scripts/macos/setup-signing.mjs` 创建专用本机身份；私钥保存在用户钥匙串，工程只读取本机保存的证书指纹。后续构建自动沿用该身份，配置存在而签名不可用时会报错，不静默改回临时签名。此操作只配置用户域的代码签名信任，不改变系统软件来源设置，也不等于 Developer ID 签名或公证。

# Any Sidebar for Mac

一个留在桌边的阅读小助手。沿用浏览器版的聊天界面，用划词和手动截图辅助阅读本地资料。

当前版本 **0.1.0**，是本机开发版。目标为 **Apple Silicon、macOS 14+**；尚未完成 Developer ID 签名、公证和最低系统实机验证。

## 从源码安装

需要 Node.js 24.15+（24.x）或 26.x、npm，以及支持 Swift 6 的 Apple 开发工具。可以通过 `xcode-select --install` 安装 Command Line Tools，再用 `swift --version` 确认版本。

在仓库根目录运行：

```sh
npm ci
npx playwright install chromium
npm run build:mac
npm run install:mac
open ~/Applications/AnySidebarMac.app
```

Chromium 用于构建应用图标，不是应用运行时依赖。安装命令将构建结果放到 `~/Applications/AnySidebarMac.app`；更新时替换应用包，保留应用外的数据和钥匙串记录。

## 开始使用

1. 在设置中保存自己的 [DeepSeek API Key](https://platform.deepseek.com/)。API 费用由你的 DeepSeek 账户承担。
2. 需要自动划词时，在设置确认采集说明、开启划词，并允许辅助功能权限。优先适配系统「预览」，其他软件可能无法提供选区。
3. 需要读图时，允许屏幕访问，再框选区域或选择窗口。截图进入草稿后才决定是否发送。
4. 左上角会话抽屉用于新建和切换会话。同一会话可引用多份文档，切换 PDF 不自动换会话。

可以只发送截图，不必额外输入文字。当前配置中 Flash 接收图像，Pro 只接收文字；模型能力以[能力配置](contracts/model-capabilities.json)为准，真实图像理解质量尚未完成端到端验证。

默认快捷键：

| 快捷键 | 作用 |
| --- | --- |
| Shift+A | 开始框选读屏，再按一次取消 |
| Shift+S | 展开或收起对话浮窗 |

两项都可以在设置中修改或清除。它们会占用对应的大写字母输入组合；如果影响打字，建议改成带 Command、Control 或 Option 的组合。

点击小助手或左上角按钮可以收起面板；右键菜单还提供设置、窗口读屏、隐藏小助手和退出。收起面板后继续生成，退出应用则停止请求。

[完整使用与权限说明](../../docs/macos/user-guide.md)

## 本机签名与更新

未配置签名身份时，构建使用临时签名。应用内容变化后，macOS 可能不再认可旧权限，即使系统开关仍显示打开。

如需固定本机开发身份，可主动运行：

```sh
node scripts/macos/setup-signing.mjs
npm run build:mac
npm run install:mac
```

此步骤会创建 Any Sidebar 专用证书，把私钥存入用户钥匙串，并设置仅用于代码签名的信任。系统可能要求你确认。指纹配置保存在 `~/Library/Application Support/com.decous.anysidebar.mac-build/signing.json`，不在工程或安装包里。

后续构建沿用该身份；配置存在但身份不可用时会报错，不静默改回临时签名。不要删除对应证书和私钥。首次更换身份后可能需要重新添加应用权限并重启；固定签名也不代表系统永远不再要求确认。

本机签名不等于 Developer ID 签名或 Apple 公证，不会改变系统允许的软件来源。

## 开发与交付

```sh
npm run typecheck:mac
npm run lint:mac
npm run test:mac:web
npm run test:mac:native
npm run build:mac
npm run package:mac
```

构建结果位于 `build/macos/AnySidebarMac.app`。打包命令先审计资源和签名，再生成 `release/macos/AnySidebarMac-0.1.0-arm64-local.zip`，不会混入 Chrome 扩展包，也不会上传到任何服务。

Swift、AppKit 和 WKWebView 负责原生入口与系统能力，SQLite 保存会话，React 展示组件与 Chrome 共用。没有 Electron、本地 HTTP 服务或第三方 API 中转。

[完整开发说明](../../docs/development.md) · [阅读质量样例](../../docs/macos/reading-evaluation.md) · [返回项目首页](../../README.md)

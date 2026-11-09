# 开发说明

仓库同时维护 Chrome 扩展和 Mac 应用。两端共用聊天展示组件，各自管理数据、权限和请求；修改公共 UI 时需要检查两端。

## 环境准备

- Node.js：24.15+（24.x）或 26.x，具体约束见 `package.json`。
- npm：使用仓库中的 `package-lock.json`，运行 `npm ci` 安装。
- 浏览器测试：运行 `npx playwright install chromium`。
- Mac：Apple Silicon、macOS 14+，支持 Swift 6 的 Command Line Tools 或 Xcode。构建脚本还使用系统的 `iconutil`、`codesign` 和 `ditto`。

无需 Key 即可运行模拟测试。不要把真实 Key 写入源码、测试夹具或环境样例。

## Chrome 扩展

```sh
npm ci
npm run build
```

在 `chrome://extensions` 开启开发者模式，加载 `dist`。修改源码后重新构建，并在扩展管理页重新加载。

```sh
npm run typecheck
npm run lint
npm test
npm run build
npm run audit:package
npm run package
```

打包输出到 `release/`。审计检查版本、资源和权限声明，并排除测试入口及敏感内容。

浏览器集成测试：

```sh
npx playwright install chromium
npm run test:e2e
```

## Mac 应用

先按 [Mac README](../apps/macos/README.md)准备工具链。

```sh
npm run typecheck:mac
npm run lint:mac
npm run test:mac:web
npm run test:mac:native
npm run build:mac
npm run package:mac
```

`build:mac` 会构建 Web 资源、生成图标、编译 arm64 原生程序并签名。`package:mac` 审计当前构建后归档，不代替构建，也不执行安装。

```sh
npm run install:mac
open ~/Applications/AnySidebarMac.app
```

更新前正常退出正在运行的旧版。安装脚本先验证暂存包，再替换安装目录；数据不在应用包内，更新保留会话、图片和 Key。

Mac 界面自动化：

```sh
npx playwright test --config playwright.macos.config.ts
```

它用模拟桥接验证布局和交互，不能替代真实辅助功能、截图、全局快捷键及系统权限测试。原生测试使用 Swift Testing；仓库包装脚本包含当前 Command Line Tools 所需的框架路径。如果本机工具链布局不同，需要按实际安装位置调整，不能把未运行记成通过。

## 代码放在哪里

| 目录 | 职责 |
| --- | --- |
| `src/ui/` | 共用的消息、输入、Markdown、模型菜单等展示组件 |
| `src/sidepanel/` | Chrome 侧栏入口和适配 |
| `src/background/` | Chrome 会话、存储和请求协调 |
| `src/content/` | 网页正文提取和划选采集 |
| `src/shared/` | Chrome 领域类型、上下文、模型和校验 |
| `apps/macos/web/` | Mac React 页面、状态及桥接客户端 |
| `apps/macos/native/Sources/` | 原生窗口、采集、请求和存储 |
| `apps/macos/contracts/` | 桥接命令、模型能力、提示和公开测试夹具 |
| `tests/` | Chrome 单元及浏览器测试，`macos/` 为 Mac Web 测试 |
| `scripts/macos/` | Mac 构建、测试、签名、审计和安装 |

Mac 原生代码按职责分成 `ReadingCore`、`ReadingStorage`、`MacServices`、`DeepSeekTransport` 和应用组装层。Web 页面通过受校验的命令访问原生能力，不取得 Key 明文，也没有任意文件访问接口。

## 请求和数据约定

- 用户发送时冻结问题、引用、图片和历史；重试、重新生成沿用原资料，使用当前模型设置。
- 打开页面、划词和截图不触发模型请求；不自动重试收费调用。
- 不静默裁剪正文、历史或图片。超出预算时给出明确提示。
- Markdown 内容作为资料展示；网页或旧回答中的指令不能改变助手职责。
- Key 不进入会话、请求快照、日志或测试报告；Mac 已保存的 Key 不回传 Web 视图。

Chrome 数据保存在扩展本机存储。Mac 数据目录是 `~/Library/Application Support/com.decous.anysidebar.mac/`，Key 在系统钥匙串；签名配置使用另一个 `mac-build` 目录。两端互不迁移，也不自动同步。

## 怎样记录验证

单元测试和模拟接口验证上下文、状态及失败路径。真实模型回答质量、真实系统权限和最低系统兼容性需要分别验证，不能相互替代。

当前已在开发机器完成 Mac 文字提问及追问，图像理解质量、macOS 14 实机、双屏和完整性能矩阵仍待验证。公开样例见 [Chrome 阅读评测](reading-evaluation.md)及 [Mac 阅读评测](macos/reading-evaluation.md)。真实调用会产生费用，自动化默认不使用真实 Key。

构建产物、用户数据库、私钥、环境文件和本机验收资料不提交。提交前检查 `git status` 和待提交差异；公开文档应使用相对链接与 `~/` 路径，不写个人绝对路径。

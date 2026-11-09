# Any Sidebar

读网页，也读眼前的本地资料。

Any Sidebar 把对话放在阅读旁边：划选不懂的内容，带着引用直接问；遇到代码、公式或图表，可以继续追问。

项目包含两个独立使用的版本，共用一套轻量聊天界面。

| 版本 | 适合什么场景 | 当前状态 |
| --- | --- | --- |
| **Chrome 扩展** | 自动读取网页正文，围绕文章提问 | 0.2.2，可加载使用 |
| **Mac 小助手** | 阅读本地文档，接收划词，手动截取屏幕 | 0.1.0，本机开发版 |

免费使用，自备 [DeepSeek API Key](https://platform.deepseek.com/)。模型调用按你的 DeepSeek 账户计费；项目没有会员、每日次数限制或收费解锁。

## Chrome：边读边问

打开侧栏后，扩展自动读取当前文章。划选一段文字，再问“这段代码为什么这样写”，正文和引用会一起提供给模型。

- 按网页地址保存对话，回到同一页面继续聊。
- 网页引用支持累积或仅保留最新一段，也可以引用 AI 回答。
- 在输入区切换模型和思考强度；支持代码、表格、亮暗主题和字号调整。

![Chrome 侧边栏界面](docs/images/sidebar.png)

需要桌面版 Chrome **142 或更高版本**。目前尚未上架 Chrome 应用商店。

1. 从 [Releases](https://github.com/decous37/Any-Sidebar/releases) 下载 `any-sidebar-*.zip`，解压并保留这个文件夹。
2. 打开 `chrome://extensions`，开启「开发者模式」。
3. 点击「加载已解压的扩展程序」，选择包含 `manifest.json` 的文件夹。
4. 点击工具栏中的 Any Sidebar 图标，在设置中保存 Key。

如果没有现成安装包，可以按[开发说明](docs/development.md)构建后加载 `dist` 目录。

[Chrome 使用指南](docs/user-guide.md)

## Mac：留在桌边的阅读工具

点击桌面小助手展开对话，再点一次收起。它不自动扫描整篇 PDF，而是接收你选中的文字，或在你触发读屏时截取区域、窗口。

- 在「预览」等阅读软件中划词，引用自动进入当前会话，不自动发送。
- 截图先加入草稿，可以配上问题，也可以只发送图片。
- 手动新建、切换会话，同一会话可以讨论多份文档。
- 默认 **Shift+A** 读屏／取消，**Shift+S** 展开／收起，两项均可修改。
- 右键小助手可读屏、打开设置、隐藏入口或退出。

面向 **Apple Silicon、macOS 14+**。当前未完成 Developer ID 签名和 Apple 公证，先提供源码构建方式；不要把它当作已经完成公开分发验证的安装包。

[Mac 安装与开发说明](apps/macos/README.md) · [Mac 使用指南](docs/macos/user-guide.md)

## 资料会发到哪里

网页正文、选文和截图先在本机处理。只有发送、重试或重新生成时，相关资料和会话历史才直接提交到 DeepSeek 官方 API。没有项目方中转服务器、账号系统或使用统计。

Chrome 的 Key 和会话保存在浏览器本机；Mac 的 Key 存入系统钥匙串，对话和截图保存在本机。两个版本不共享 Key 或记录，也不提供云同步。本机对话文件没有额外加密。

Chrome 内部页面、扩展商店和 PDF 不按普通网页读取。Mac 划词兼容性取决于阅读软件；最低系统、双屏和完整图像理解流程仍待进一步验证。AI 可能出错，请核对重要结论。

[Chrome 隐私说明](public/privacy.html) · [Mac 隐私说明](apps/macos/resources/privacy.html)

## 开发与反馈

- [开发说明](docs/development.md)：环境、构建、测试和目录结构。
- [参与贡献](CONTRIBUTING.md)：反馈问题与提交修改。
- [更新记录](CHANGELOG.md)：两个版本分别记录。
- [阅读评测](docs/reading-evaluation.md) · [Mac 评测样例](docs/macos/reading-evaluation.md)：区分模拟检查与真实模型效果。

有问题或建议，欢迎到 [Issues](https://github.com/decous37/Any-Sidebar/issues)。请隐藏 Key、私人文档和其他敏感信息后再附截图或日志。

采用 [MIT 许可证](LICENSE)，允许修改、分发和商用，需保留版权及许可声明。第三方组件见 [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt)。Any Sidebar 是独立项目，与 DeepSeek、Google 和 Apple 没有官方关联。

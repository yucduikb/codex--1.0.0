# Dragon Codex Boot · 连贯启动整合版

Windows x64 的 Codex 启动动画 + 动态壁纸整合包。保留当前修复版的龙娘动画、声音、居中窗口、巨幕衔接和动态壁纸；安装脚本自动识别本机官方 Codex，不需要复制作者电脑的路径或配置。

社区整合版本：`0.2.0-seamless.1`。基于 Dragon Codex Boot 0.2.0 和 Codex Dynamic Skin 1.7.3，非 OpenAI 官方组件。

## 安装

先安装并正常打开一次 Windows 官方 Codex，完成登录。需要 Windows 10/11 x64、.NET Framework 4.8 和 Windows PowerShell 5.1；Windows N 版本还需要媒体功能包。当前只适配经过校验的 `OpenAI.Codex` Store/MSIX 安装。

**普通用户：** 从本仓库 Releases 下载 `DragonCodexBoot-0.2.0-seamless.1-win-x64-offline.zip`，完整解压，双击 `Install.cmd`。随后从桌面或开始菜单的 **Codex** 快捷方式打开。

**让 GPT 部署：** 下载或克隆此仓库，把所在目录交给可操作本机文件和终端的 GPT/Codex，并复制 [DEPLOY_WITH_GPT.md](DEPLOY_WITH_GPT.md) 中的提示词。网页版纯聊天 GPT 只能提供指导，不能直接操作本机。

**手动一条命令：** 在仓库根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

源码版首次安装从 nodejs.org 下载固定版本的官方 Node.js，验证 SHA-256 和发布者签名；离线整包已包含这个运行时，可加 `-Offline` 禁止下载。不需要安装 Python、npm、Git 或 .NET SDK，也不需要另外购买壁纸工具或填写 GPT API Key。

安装位置默认为 `%LOCALAPPDATA%\DragonCodexBoot-Community`，无需管理员权限。安装过程不会自动退出正在工作的 Codex；首次从新快捷方式启动时，如存在未带壁纸参数的 Codex 进程，会先请求正常关闭再重新启动，请先结束正在进行的任务。

## 当前效果

- 1600×900 物理像素居中播放原动画和声音，目标 Codex 客户区匹配播放器；不是全屏铺满桌面。低分辨率屏幕可能裁边，可在安装目录的 `launcher.json` 调整尺寸。
- 动画播放的同时准备真实 Codex、壁纸注入器和视频解码。12.7–13.65 秒执行实时窗口缩略图衔接，结束后立即撤掉覆盖层并交还操作。
- 就绪条件检查真实壁纸视频正在播放且帧计数增长，避免动画结束后才出现背景。已有可验证的壁纸会话和窗口可复用。
- 极慢的首次冷启动有持续动态画面接续、超时和跳过处理。**无法保证所有机器都在 13.65 秒内启动完成，也没有承诺绝对零延迟。**
- 安装会备份并接入当前用户桌面、开始菜单中匹配官方应用的 `.lnk`，建立缺失的默认快捷方式；支持按备份恢复，保留用户后来修改的快捷方式。

已有任务栏/开始屏幕固定项、Store 应用列表、协议链接和直接运行官方 EXE 不会自动转到启动器。任务栏图标需要取消固定，再从新的桌面快捷方式重新固定。不是所有名为 Codex 的入口都能被系统透明替换。

## 恢复与自定义

运行安装目录中的 `Uninstall.cmd`：恢复仍由本程序管理的快捷方式和外观项，停止已验证的壁纸监视进程。保存工作并完全退出 Codex 后重新打开，清除当前窗口中的注入；仅关闭窗口可能仍保留后台进程。安装目录、独立用户资料和备份保留，确认不需要后再手动移除。

更新安装时会保留上一份程序文件到 `backups/payload-*`，并保留已有 `skin/` 状态和资料。不要直接覆盖已有的其他 DragonCodexBoot / CodexDreamSkin 安装；本包使用独立目录。

`themes/dragon/theme.json` 控制壁纸、速度、透明度和配色，`config/launcher.json` 是安装默认动画配置。安装后修改安装目录对应文件；修改源码分发内容后先运行 `scripts/Update-Manifest.ps1`。重新制作视频才需要 `tools/requirements.txt`，安装和日常使用不需要。

只准备独立文件、不修改快捷方式和外观，可使用：

```powershell
.\Install.ps1 -InstallDir 'D:\Apps\DragonCodexBoot' -Portable
```

Portable 只用于文件准备/验证，运行时仍需要官方 Codex，并应手动选择浅色外观。普通安装支持 `-NoShortcuts`、`-NoAppearance`、`-Launch`，详见 [部署与排错](docs/DEPLOYMENT.md)。

## 源码、测试与发布

若系统默认禁止脚本，先用 `powershell.exe -NoProfile -ExecutionPolicy Bypass` 打开仅对当前会话生效的终端，再执行下面命令。

```powershell
.\scripts\Build.ps1
.\scripts\Test-Package.ps1
.\scripts\Build-Release.ps1
```

测试包含配置与几何、回环端口归属、隔离快捷方式备份/恢复、外观冲突恢复和实际视频壁纸负载构建。测试不会重启正在使用的 Codex，也不等于在每种 Codex 版本上完成视觉验收。见本次 [导出验证记录](docs/EXPORT-VALIDATION.md)；发布前应按 [验收说明](docs/TESTING.md) 做首次启动、窗口重开和慢启动的界面检查。

源文件可直接放入 GitHub 仓库；`releases/` 的离线 ZIP 作为 GitHub Release 附件上传，不要把运行目录、账号资料或整个打包临时目录提交到仓库。详见 [发布说明](docs/PUBLISHING.md)。

## 来源与授权

- 启动器：https://github.com/yushua0808-cpu/dragon-codex-boot
- 壁纸引擎：https://github.com/CCDawn/Codex-Dynamic-Skin
- 源码采用 MIT，保留上游版权；Node.js 的许可证另附。
- **视频、角色、美术和声音不自动适用 MIT。当前壁纸的独立再分发授权尚未核实；公开发布前确认授权，或换成你有权分发的素材。**

完整来源、修改和素材说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 与 [变更说明](docs/CHANGES.md)。包内不包含 Codex 本体、个人账号、聊天历史或作者电脑的登录资料。

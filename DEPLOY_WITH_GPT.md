# 复制给 GPT 的部署提示词

先把仓库完整下载/克隆或解压到本机，再将下面提示词交给能访问本机终端的 GPT/Codex。纯网页版聊天不能自行完成本地部署。

```text
请把当前目录的 Dragon Codex Boot 连贯启动整合版安装到这台 Windows 电脑。
先阅读 README.md、AGENTS.md 和 docs/DEPLOYMENT.md。
确认官方 Codex 已安装并正常登录，核验 package-manifest.json 后，运行：
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
如果拿到的是离线整包，可加 -Offline，禁止再次下载依赖。
保留当前动画、声音、1600×900 居中窗口、动态壁纸和 12.7–13.65 秒窗口衔接。
完成后检查安装文件和桌面/开始菜单快捷方式确实指向安装目录的 DragonCodexBoot.exe，
告诉我安装目录和恢复方法，不要自动中断正在进行的 Codex 任务。
不要拷贝其他人的账号、聊天记录、用户配置或机器专用路径，不要通过修改受保护的 Codex 应用包来部署。
```

没有官方 Codex 时，先请用户自行安装官方应用并完成首次登录。该仓库只部署启动动画与皮肤整合，不包含或代替 Codex 主程序。

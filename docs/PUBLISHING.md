# 发布到 GitHub

此目录就是仓库内容。源码、脚本、当前三段视频、许可证和文档都在这里。没有执行上传；请发布到你自己的仓库，保留两个上游的署名。

1. 确认启动视频、声音、角色和动态壁纸的公开分发授权。MIT 代码授权不涵盖这些媒体；无法确认时先换为有权分发的素材。
2. 编辑内容后运行 `scripts/Update-Manifest.ps1`，执行 `scripts/Test-Package.ps1` 和手动界面验收。
3. 运行 `scripts/Build-Release.ps1`。生成源码 ZIP、包含签名 Node 的离线 ZIP 及 SHA256SUMS.txt；发布包由白名单构建，不从个人运行目录整目录复制。
4. 将当前目录中 `.gitignore` 允许的内容提交到 GitHub；`releases/`、`.local/`、`engine/runtime/` 不提交。
5. 创建 tag / GitHub Release，上传 `releases/` 下两个 ZIP 和 SHA256SUMS.txt。普通用户下载 offline ZIP。也可手动触发 Actions 的 Release packages 工作流下载构建产物，再发布 Release。

不要将离线 ZIP 当成普通源码文件提交；Node 放在 Release 附件中，避免仓库长期存放大型运行时文件。源码中最大的单文件是启动视频，约 23 MB，不需要 Git LFS。发布之后，把自己的仓库链接发给别人并让其参考 DEPLOY_WITH_GPT.md。

如果通过浏览器上传源码，包含 `.github/`、`.gitattributes` 和 `.gitignore`；不要把最外层文件夹又套一层提交，也不要上传 `.local/` 中的验证副本。上传前检查 Git staged 列表中没有 `skin`、profile、日志、截图、账号、聊天历史或 config 备份。

代码版本标记是本整合版 `0.2.0-seamless.1`，不是对原作者正式发布版本的冒用。后续改版应同步修改 VERSION，更新清单，重新测试和构建。

`.gitattributes` 禁用换行自动转换，以保持清单哈希在 Windows 克隆、GitHub 源码 ZIP 和 CI 中一致。不要在发布流水线里重新转换换行或保存文件后继续使用旧清单。

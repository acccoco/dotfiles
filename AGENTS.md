# 仓库说明

本仓库使用 Just 和 Nushell，在 Windows/macOS 上同步个人 dotfiles。`dotfiles/` 是配置的唯一权威源，脚本通过 symbolic link 将配置接入用户目录；同步行为必须保持保守，不删除、不移动、不备份，也不覆盖已有文件或目录。

# 敏感信息检查

本仓库会同步到 GitHub public 仓库，因此：

- 每次交付变更前，检查 Git diff、暂存区和新增文件中是否包含敏感信息。
- commit 或 push 前，额外检查全部 tracked 文件和可达 Git 历史。
- 敏感信息包括密码、Token、API Key、私钥、个人邮箱、内部地址，以及客户或公司专有信息。
- 一旦发现敏感信息，停止 commit 或发布；只报告脱敏后的位置和类型，并等待用户处理，不得输出或扩散完整内容。

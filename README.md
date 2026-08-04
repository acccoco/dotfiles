# dotfiles 配置同步工具

这是一个使用 [Just](https://just.systems/) 作为命令入口、基于 [Nushell](https://www.nushell.sh/) 实现的 Windows/macOS 配置同步工具。它以当前目录下的 `dotfiles/` 为唯一权威源，通过 symbolic link 将常用配置接入用户目录。

脚本采用保守策略：只创建缺失的链接，不删除、不移动、不备份，也不覆盖任何已有文件或目录。发现冲突时会报告并跳过，交由用户手动处理。

## 功能

- 检查受管链接是否存在、类型是否正确，以及是否指向预期源文件。
- 为缺失的配置创建 symbolic link，并在创建后再次验证。
- 创建真实链接前，先在系统临时目录测试当前进程的链接创建能力。
- 可扩展检查关键环境变量和外部命令。
- 支持 Windows 和 macOS；其他平台会在执行检查或同步前退出。

## 目录结构

```text
.
├── justfile
├── sync.nu
└── dotfiles
    ├── agents
    │   ├── AGENTS.md
    │   ├── plugins
    │   │   └── marketplace.json
    │   └── rules
    │       └── code-style.md
    ├── home
    │   ├── .clang-format
    │   ├── .ideavimrc
    │   ├── .rustfmt.toml
    │   ├── .vimrc
    │   └── .vsvimrc
    └── nushell
        └── config.nu
```

## 受管配置

脚本根据自身位置、Nushell 的 HOME 和默认配置目录动态计算路径，不依赖固定用户名或 OneDrive 绝对路径。

| 名称 | 权威源 | 链接位置 |
| --- | --- | --- |
| `nushell-config` | `dotfiles/nushell/config.nu` | `$nu.default-config-dir/config.nu` |
| `clang-format` | `dotfiles/home/.clang-format` | `$nu.home-dir/.clang-format` |
| `ideavimrc` | `dotfiles/home/.ideavimrc` | `$nu.home-dir/.ideavimrc` |
| `rustfmt` | `dotfiles/home/.rustfmt.toml` | `$nu.home-dir/.rustfmt.toml` |
| `vimrc` | `dotfiles/home/.vimrc` | `$nu.home-dir/.vimrc` |
| `vsvimrc` | `dotfiles/home/.vsvimrc` | `$nu.home-dir/.vsvimrc` |
| `codex-agents` | `dotfiles/agents/AGENTS.md` | `$nu.home-dir/.codex/AGENTS.md` |
| `agents-plugins` | `dotfiles/agents/plugins` | `$nu.home-dir/.agents/plugins` |
| `agents-rules` | `dotfiles/agents/rules` | `$nu.home-dir/.agents/rules` |

脚本只管理 `~/.codex/AGENTS.md`、`~/.agents/plugins` 和 `~/.agents/rules` 三个具体入口，不会将整个 `~/.agents` 目录替换为链接，因此该目录中的 `skills` 等其他内容可以独立维护。

## 环境要求

- 已安装 Just，并可通过 `just` 命令运行。
- 已安装 Nushell，并可通过 `nu` 命令运行。
- 当前账户能够创建 symbolic link。
  - Windows 可启用“开发人员模式”，或在具备相应权限的终端中运行。
  - macOS 使用系统自带的 `ln -s`。

当前工具已在 Just `1.46.0` 和 Nushell `0.111.0` 上验证。

## 使用方法

不带参数执行 `just`，可以查看全部支持的命令：

```console
just
```

建议先执行只读检查：

```console
just status
```

确认结果后，创建所有缺失的链接：

```console
just sync
```

`justfile` 使用 Nushell 执行 recipe，并将 `status`、`sync` 委托给 `sync.nu`。调用 Nushell 时使用 `-n`，不会加载用户的 `config.nu`，因此也适合配置链接缺失或配置本身有问题的情况。

### 直接运行底层脚本

不经过 Just 时，可以直接调用 `sync.nu`：

```powershell
nu -n .\sync.nu status
nu -n .\sync.nu sync
```

在 macOS 上还可以赋予脚本执行权限后直接运行：

```sh
chmod +x sync.nu
./sync.nu status
./sync.nu sync
```

底层脚本不带子命令或传入 `--help` 可查看自身帮助：

```powershell
nu -n .\sync.nu
nu -n .\sync.nu --help
```

## 命令行为

### `just status`

该 recipe 委托 `sync.nu status`，只读检查全部链接、环境变量和命令，不修改文件系统。输出表格包含：

- `category`：检查类别，如 `link`、`env` 或 `command`。
- `name`：配置项名称。
- `status`：当前状态。
- `action`：执行的动作；`status` 模式下始终为 `none`。
- `detail`：实际路径、冲突原因或探测结果。

只要任一 `required: true` 的项目不为 `ok`，命令就以退出码 `1` 结束；全部必需项正常时退出码为 `0`。

### `just sync`

该 recipe 委托 `sync.nu sync`，处理规则如下：

1. 已正确连接的项目保持不变。
2. 目标不存在时，先进行 symbolic link 权限预检，再创建并验证链接。
3. 目标是普通文件、普通目录、错误链接或断链时，报告冲突并跳过。
4. 权威源缺失、链接创建失败或创建后验证失败时，报告错误。

`sync` 不会自动处理冲突。必需项目仍有异常时，命令以退出码 `1` 结束。

## 常见问题

### 目标位置已有普通文件或目录

脚本会显示 `regular_file` 或 `regular_dir`，并保持该目标不变。请先确认内容，手动迁移或删除冲突项，然后重新执行 `sync`。

### 链接指向了其他位置

脚本会显示 `wrong_link`。它不会替换现有链接，需要手动修正后再运行。

### 链接目标已经不存在

脚本会显示 `broken_link`。为避免误删，它不会自动移除断链。

### 从旧版 agents 整目录链接迁移

旧版脚本曾将整个 `dotfiles/agents` 链接到 `~/.agents`。新版不会自动删除或改写这个旧链接，也不会覆盖已有的 `~/.codex/AGENTS.md`；这些状态会作为冲突报告。请先核对并手动清理对应目标，再重新执行 `sync`，脚本随后只会创建 `~/.codex/AGENTS.md`、`~/.agents/plugins` 和 `~/.agents/rules`。

### Windows 无法创建链接

脚本会先在系统临时目录中分别测试所需的文件链接和目录链接，并输出 `mklink` 的失败信息。可检查 Windows“开发人员模式”、终端权限和本机安全策略。

## 扩展检查项

所有声明式配置都位于 `sync.nu` 顶部区域：

- 在 `link-specs` 中添加新的链接映射。
- 在 `env-checks` 中添加环境变量检查；支持 `non_empty` 和 `path` validator。敏感变量应设置 `secret: true`，避免输出真实值。
- 在 `command-checks` 中添加命令检查；可选的 `probe` 参数会实际执行一次轻量探测，并要求退出码为 `0`。

示例：

```nu
def env-checks [] {
    [
        {
            name: "OPENAI_API_KEY"
            required: false
            validator: "non_empty"
            secret: true
        }
    ]
}

def command-checks [] {
    [
        {
            name: "git"
            required: true
            probe: ["--version"]
        }
    ]
}
```

修改配置后，先运行 `status` 确认检查结果，再执行 `sync`。

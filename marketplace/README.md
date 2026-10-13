# 个人 Skills Marketplace

在 dotfiles 仓库中维护个人 skills，通过本地 Codex marketplace 在不同机器安装。Git 负责同步源码，Codex 负责安装和加载插件；本目录不建立独立 Git 仓库，也不参与 `just sync` 的 symbolic link 管理。

## 目录与维护边界

```text
marketplace/                               ← 注册时选择这一层
├── README.md
├── .agents/plugins/marketplace.json        ← marketplace：插件目录与来源
└── plugins/personal-skills/                ← plugin：安装与版本管理单位
    ├── .codex-plugin/plugin.json           ← 插件名称、版本与技能入口
    └── skills/
        └── pillow-drawing/
            └── SKILL.md                   ← skill：触发条件与工作流
```

marketplace 名称为 `personal-marketplace`，插件为 `personal-skills`，当前版本为 `0.2.1`。当前采用已在本机 Codex CLI 验证的 `.codex-plugin/plugin.json` 格式。

marketplace 的 `source.path` 相对于本目录解析，必须以 `./` 开头并位于本目录内；插件的 `skills` 则相对于插件根目录解析。保持 marketplace 和 plugin 名称稳定，日常更新修改内容及版本即可。

仓库工作副本是源码的唯一编辑入口。Codex 使用安装缓存，不直接把工作副本当作当前会话的技能内容；不要编辑安装缓存，也不要把缓存提交到仓库。插件所需的 CLI、运行时、MCP 和服务认证需要在各机器另行准备。

当前提供 [pillow-drawing](plugins/personal-skills/skills/pillow-drawing/SKILL.md)：仅在明确要求使用 Python Pillow／PIL 绘图或点名技能时使用，交付图片及生成源码。默认采用参考 diagram-design 的浅色编辑式风格，规则独立记录在技能的“绘图风格”章节。运行需要 Python、Pillow 和本机可用字体；中文优先黑体系列，英文和数字优先 Consolas 等等宽字体。具体选择与缺失处理见技能说明，插件不包含字体或依赖安装脚本。

## 首次安装

安装支持 `codex plugin` 命令的 Codex CLI。以下命令从 **dotfiles 仓库根目录**执行，适用于 Windows PowerShell 和 macOS shell：

```sh
codex plugin marketplace add ./marketplace
codex plugin list --marketplace personal-marketplace --available --json
codex plugin add personal-skills@personal-marketplace
```

列表中应出现 `personal-skills@personal-marketplace`，版本为 `0.2.1`。第二条命令只检查发现结果，第三条才执行安装。

若本机已经安装旧版本，CLI 可能仍显示已安装副本的版本，不能仅凭该列表判断源码是否更新；应同时核对源码插件清单，并在更新安装后验证会话加载结果。

桌面端通过本地文件夹添加 marketplace 时，同样选择仓库根目录下的 `marketplace`，不要选择 dotfiles 仓库根目录、`.agents/plugins` 或 `personal-skills` 插件目录。各机器的绝对路径可以不同，内部相对布局应保持一致。

如果已经注册过同名的试验 marketplace，先按下文排障步骤核对来源，再安装。

## 验证安装

安装完成后重新启动客户端，新建会话，在技能选择器中选择 `pillow-drawing`，输入：

```text
使用 Python Pillow 生成一张包含“中文绘图 / Pillow 123”的示意图，中文使用黑体系列，英文使用等宽字体；交付 PNG 和生成源码，并说明实际使用的字体。
```

检查技能能被选择并加载，产物包含 PNG、可复现的 Python 源码及字体说明；打开图片检查中文无缺字、中英文排版无重叠或截断。若缺少 Pillow 或字体，应得到明确的依赖说明，不能将缺字图片视为通过。

不要向验收会话提供源码路径或要求直接读取 `SKILL.md`，否则无法验证插件安装与技能发现。绘图成功本身也不能证明加载了哪个插件版本，应结合技能选择与插件来源、版本检查；不据此推断其他机器已同步。

## 跨机器同步与更新

新机器先克隆本 dotfiles 仓库，进入仓库根目录，再执行上面的首次安装步骤。每台机器都需要独立注册自己的本地目录并安装插件。

日常更新流程：

1. 在仓库工作副本中修改技能，递增插件清单中的 `version`，同步更新本 README 的版本及受影响的验收说明。
2. 完成检查后提交、推送。本仓库为公开仓库，提交前须按根目录 `AGENTS.md` 检查敏感信息。
3. 在其他机器的仓库根目录拉取更新：

   ```sh
   git pull --ff-only
   codex plugin list --marketplace personal-marketplace --available --json
   ```

4. 核对插件来源和版本，重新启动客户端并新建会话，按上面的绘图示例验证技能。若仍加载旧内容，在插件管理界面更新或重新安装 `personal-skills`，然后重新验证。

`git pull --ff-only` 若因本地修改或分支分叉而失败，先处理 Git 提示的冲突，不强制覆盖本地工作。需要回退技能时，在仓库中恢复已知可用内容，以新插件版本提交，再走相同的同步和验证流程。

`codex plugin marketplace upgrade` 刷新的是 **Git 来源 marketplace 的快照**；这里注册的是本地目录，该命令不能替代本仓库的 `git pull`。源码更新、安装缓存更新、会话加载新技能是三个不同状态。本仓库不配置后台自动更新，也不保证已有会话热更新。

## 添加技能与插件

同一插件下新增技能时，创建 `plugins/personal-skills/skills/<skill-name>/SKILL.md`。目录名与 frontmatter 的 `name` 一致，使用小写字母、数字和连字符。例如：

```markdown
---
name: summarize-changes
description: 当用户要求概括当前 Git 改动时，按行为变化总结 diff 和验证状态。
---

# 概括改动

读取工作区与暂存区 diff，按行为变化说明修改目的、影响及已运行的验证。
区分检查结果与推断；没有运行的验证应明确标注。
```

为技能按需添加 `scripts/`、`references/` 或 `assets/`，从技能内部使用相对路径引用。避免固定用户名和机器绝对路径。写清所需外部命令或工具及缺失时的处理方式；包内包含脚本不代表目标机器已安装其运行时。

已有 `skills` 入口会发现同一插件内的新增技能，无需为每个技能新增 marketplace 条目。新增内容后递增插件版本，按更新流程验证。

需要独立安装或有不同依赖的一组技能，可以增加插件：

1. 在 `plugins/<plugin-name>/` 建立独立的 `.codex-plugin/plugin.json` 和 `skills/`，使用唯一名称。
2. 在 `.agents/plugins/marketplace.json` 的 `plugins` 数组中按现有条目增加插件，设置一致的名称、`./plugins/<plugin-name>` 来源路径及 policy、category。
3. 检查发现结果，然后通过 `codex plugin add <plugin-name>@personal-marketplace` 安装。

纳入真实技能前检查内容和依赖。凭据、个人邮箱、内部地址及公司或客户专有信息不得写入公开仓库；机器私有配置留在本机。第三方技能还需核对其许可及后续更新来源。

## 排障与验收

| 现象 | 检查方式与处理 |
| --- | --- |
| marketplace 或插件未找到 | 运行 `codex plugin marketplace list` 检查根路径，确认注册的是仓库根目录下的 `marketplace`；检查清单路径和 JSON 格式。 |
| 移动目录后来源失效，或仍指向旧试验目录 | 用 `codex plugin marketplace list` 核对同名来源。确认不再使用旧来源后，执行 `codex plugin marketplace remove personal-marketplace`，再从仓库根目录执行首次安装步骤，将来源注册为 `./marketplace`；随后核对安装来源与测试结果。源码目录无需删除。 |
| 新文件未出现在 Git 变更中 | 用 `git status --short --untracked-files=all` 和 `git check-ignore -v --no-index <文件路径>` 检查。本仓库已针对 marketplace 添加例外，注意全局 `Plugins/` 规则；命中以 `!` 开头的规则表示放行。 |
| 列表版本已更新，会话仍加载旧技能 | 检查安装来源及缓存刷新状态，更新或重新安装插件，重启客户端并新建会话；不要手工修改缓存。 |
| 运行 `just sync` 后未出现技能 | `just sync` 仅管理原有配置链接，插件需要单独注册和安装。 |

验收时分别记录以下结果，不能以一个环节通过代替全部完成：

- 清单与格式：JSON 可解析，插件与技能路径存在，技能 frontmatter 合法，CLI 可发现插件及版本。
- 绘图行为：用可用的中英文字体生成样图，运行并检查图片；此项不代替插件安装验证。
- 客户端加载：核对插件来源和版本，在新会话通过技能选择器调用并完成绘图示例。
- 第二台机器：拉取更新后，检查来源、版本和本机依赖，并在新会话重复安装验收。

源码的清单解析、技能格式和本机绘图可在交付时检查；客户端加载和第二台机器同步需完成对应安装后实测。

## 参考

- [OpenAI 官方插件打包与 marketplace 文档](https://developers.openai.com/plugins/build/plugins)
- CLI 命令帮助：`codex plugin --help`、`codex plugin marketplace --help`。

#!/usr/bin/env nu

# Windows 和 macOS 配置同步工具
#
# 推荐使用方式：
#   just                    # 显示所有可用命令
#   just status             # 检查软连接、环境变量和命令
#   just sync               # 建立缺失的软连接
#
# 底层脚本也可直接执行：
#   nu -n sync.nu status    # 不加载用户 config.nu
#   nu -n sync.nu sync
#   ./sync.nu status         # macOS：chmod +x sync.nu 后可直接执行
#   ./sync.nu sync
#
# 设计原则：
#   1. dotfiles 是唯一权威源。
#   2. 只创建缺失的软连接；任何冲突都报告并跳过。
#   3. 不删除、不移动、不备份、不覆盖现有文件或目录。


# path self 只能在 Nushell 解析阶段求值，因此在文件顶层保存脚本信息。
const SCRIPT_ROOT = (path self | path dirname)
const SCRIPT_NAME = (path self | path basename)


# 第一版明确支持 Windows 和 macOS；其他平台在任何检查或同步前终止。
def is-supported-platform [platform: string] {
    $platform in ["windows" "macos"]
}


def require-supported-platform [] {
    let platform = $nu.os-info.name
    if not (is-supported-platform $platform) {
        print -e $"不支持的平台：($platform)。当前仅支持 Windows 和 macOS。"
        exit 1
    }

    $platform
}


def path-separator-for [platform: string] {
    if $platform == "windows" { "\\" } else { "/" }
}


def path-separator [] {
    path-separator-for $nu.os-info.name
}


# =============================================================================
# 声明式配置区
# =============================================================================

# 返回需要管理的全部软连接。
#
# 路径在运行时根据脚本位置、HOME 和 Nushell 默认配置目录计算，避免硬编码
# 用户名或 OneDrive 的绝对路径。
def link-specs [] {
    let root = ($SCRIPT_ROOT | path expand --no-symlink)
    let home = $nu.home-dir
    let nu_config_dir = $nu.default-config-dir

    [
        {
            name: "nushell-config"
            source: ([$root "dotfiles" "nushell" "config.nu"] | path join)
            target: ([$nu_config_dir "config.nu"] | path join)
            kind: "file"
            required: true
        }
        {
            name: "clang-format"
            source: ([$root "dotfiles" "home" ".clang-format"] | path join)
            target: ([$home ".clang-format"] | path join)
            kind: "file"
            required: true
        }
        {
            name: "ideavimrc"
            source: ([$root "dotfiles" "home" ".ideavimrc"] | path join)
            target: ([$home ".ideavimrc"] | path join)
            kind: "file"
            required: true
        }
        {
            name: "rustfmt"
            source: ([$root "dotfiles" "home" ".rustfmt.toml"] | path join)
            target: ([$home ".rustfmt.toml"] | path join)
            kind: "file"
            required: true
        }
        {
            name: "vimrc"
            source: ([$root "dotfiles" "home" ".vimrc"] | path join)
            target: ([$home ".vimrc"] | path join)
            kind: "file"
            required: true
        }
        {
            name: "vsvimrc"
            source: ([$root "dotfiles" "home" ".vsvimrc"] | path join)
            target: ([$home ".vsvimrc"] | path join)
            kind: "file"
            required: true
        }
        {
            name: "codex-agents"
            source: ([$root "dotfiles" "agents" "AGENTS.md"] | path join)
            target: ([$home ".codex" "AGENTS.md"] | path join)
            kind: "file"
            required: true
        }
        {
            name: "agents-plugins"
            source: ([$root "dotfiles" "agents" "plugins"] | path join)
            target: ([$home ".agents" "plugins"] | path join)
            kind: "dir"
            required: true
        }
        {
            name: "agents-rules"
            source: ([$root "dotfiles" "agents" "rules"] | path join)
            target: ([$home ".agents" "rules"] | path join)
            kind: "dir"
            required: true
        }
    ]
}


# 关键环境变量检查清单。第一版保持为空；需要时在列表中添加记录。
#
# validator 支持：
#   non_empty - 变量存在且非空
#   path      - 变量存在，并且变量值指向的文件或目录存在
#
# secret 为 true 时，status 只报告“已设置”，绝不输出真实值。
def env-checks [] {
    [
        # {
        #     name: "EDITOR"
        #     required: false
        #     validator: "non_empty"
        #     secret: false
        # }
        # {
        #     name: "OPENAI_API_KEY"
        #     required: false
        #     validator: "non_empty"
        #     secret: true
        # }
    ]
}


# 关键命令检查清单。第一版保持为空；需要时在列表中添加记录。
#
# probe 是可选的轻量探测参数。未提供 probe 时只使用 which 检查命令；
# 提供后还会实际执行命令，并要求退出码为 0。
def command-checks [] {
    [
        # {
        #     name: "git"
        #     required: true
        #     probe: ["--version"]
        # }
        # {
        #     name: "code"
        #     required: false
        #     probe: ["--version"]
        # }
    ]
}


# =============================================================================
# 路径和状态检查
# =============================================================================

# 将路径按当前平台规则标准化，用于比较链接目标。
# Windows 使用反斜杠且不区分大小写；macOS 保留正斜杠和大小写。
def normalize-expanded-path [value: string, platform: string] {
    if $platform == "windows" {
        $value
        | str replace --all "/" "\\"
        | str downcase
    } else {
        $value
    }
}


def normalize-path [value: string] {
    let expanded = ($value | path expand --no-symlink)
    normalize-expanded-path $expanded $nu.os-info.name
}


# 判断路径是否为当前平台的绝对路径。
# path parse 的 prefix 字段只存在于 Windows，因此不能在 macOS 上直接读取。
def is-absolute-path-for [value: string, platform: string] {
    if $platform == "windows" {
        let parsed = ($value | path parse)
        (($parsed.prefix? | default "" | is-not-empty)
            or ($value | str starts-with "\\")
            or ($value | str starts-with "/"))
    } else {
        $value | str starts-with "/"
    }
}


# 将链接记录中的相对目标解析为相对于链接所在目录的绝对路径。
def resolve-link-target [link_path: string, raw_target: string] {
    let is_absolute = (is-absolute-path-for $raw_target $nu.os-info.name)

    if $is_absolute {
        $raw_target | path expand --no-symlink
    } else {
        [($link_path | path dirname) $raw_target]
        | path join
        | path expand --no-symlink
    }
}


def link-result [spec: record, status: string, detail: string] {
    {
        category: "link"
        name: $spec.name
        status: $status
        action: "none"
        detail: $detail
        required: $spec.required
        source: $spec.source
        target: $spec.target
        kind: $spec.kind
    }
}


# 检查一个软连接映射，但不修改任何文件。
def inspect-link [spec: record] {
    if not ($spec.source | path exists) {
        return (link-result $spec "source_missing" $"权威源不存在：($spec.source)")
    }

    let source_type = (try {
        $spec.source | path type
    } catch {
        "unknown"
    })

    if $source_type != $spec.kind {
        return (link-result $spec "source_missing" $"权威源类型错误：期望 ($spec.kind)，实际 ($source_type)")
    }

    # --no-symlink 能在链接目标已经丢失时，仍然识别链接本身的存在。
    if not ($spec.target | path exists --no-symlink) {
        return (link-result $spec "missing" $"目标不存在：($spec.target)")
    }

    let target_type = (try {
        $spec.target | path type
    } catch {
        "unknown"
    })

    match $target_type {
        "file" => {
            link-result $spec "regular_file" $"目标是普通文件：($spec.target)"
        }
        "dir" => {
            link-result $spec "regular_dir" $"目标是普通目录：($spec.target)"
        }
        "symlink" => {
            let row = (try {
                # -D 要求 ls 返回链接条目本身；否则目录链接会被当作目录展开。
                ls -laD $spec.target | first
            } catch {
                null
            })

            if $row == null or ($row.target? | default "" | is-empty) {
                return (link-result $spec "broken_link" "无法读取软连接的实际目标")
            }

            let actual = (resolve-link-target $spec.target $row.target)
            let points_to_expected = (
                (normalize-path $actual) == (normalize-path $spec.source)
            )
            let resolved_exists = ($spec.target | path exists)

            if not $resolved_exists {
                link-result $spec "broken_link" $"软连接目标不存在：($actual)"
            } else if $points_to_expected {
                link-result $spec "ok" $"已连接到：($actual)"
            } else {
                link-result $spec "wrong_link" $"实际指向：($actual)"
            }
        }
        _ => {
            link-result $spec "wrong_link" $"无法识别目标类型：($target_type)"
        }
    }
}


# =============================================================================
# 环境变量和命令检查
# =============================================================================

def inspect-env [spec: record] {
    let exists = ($env | columns | any {|column| $column == $spec.name })

    if not $exists {
        return {
            category: "env"
            name: $spec.name
            status: "missing"
            action: "none"
            detail: "环境变量未设置"
            required: $spec.required
        }
    }

    let value = ($env | get $spec.name)
    let valid = (match $spec.validator {
        "non_empty" => { not ($value | is-empty) }
        "path" => {
            if ($value | is-empty) {
                false
            } else {
                ($value | into string | path exists)
            }
        }
        _ => { false }
    })

    if not $valid {
        {
            category: "env"
            name: $spec.name
            status: "invalid"
            action: "none"
            detail: $"环境变量未通过 ($spec.validator) 检查"
            required: $spec.required
        }
    } else {
        let detail = if $spec.secret {
            "已设置（值已隐藏）"
        } else if $spec.validator == "path" {
            $"路径有效：($value | into string)"
        } else {
            "已设置"
        }

        {
            category: "env"
            name: $spec.name
            status: "ok"
            action: "none"
            detail: $detail
            required: $spec.required
        }
    }
}


# 将 complete 返回的任意输出安全转换为字符串。
# 普通命令的二进制输出编码未知，因此只给出占位说明，避免错误解码或崩溃。
def output-to-string [value: any] {
    match ($value | describe) {
        "nothing" => { "" }
        "string" => { $value }
        "binary" => { "<二进制输出已省略>" }
        _ => {
            try {
                $value | into string
            } catch {
                ""
            }
        }
    }
}


# Windows cmd.exe /u 的管道输出固定为 UTF-16LE，可以安全、确定地解码。
def decode-windows-command-output [value: any] {
    if ($value | describe) == "binary" {
        try {
            $value | decode utf-16le
        } catch {
            "<无法解码的 cmd.exe 二进制输出>"
        }
    } else {
        output-to-string $value
    }
}


def first-output-line [result: record] {
    let stdout = (output-to-string ($result.stdout? | default null) | str trim)
    let stderr = (output-to-string ($result.stderr? | default null) | str trim)
    let text = if ($stdout | is-not-empty) { $stdout } else { $stderr }

    if ($text | is-empty) {
        "命令执行成功"
    } else {
        $text | lines | first
    }
}


def inspect-command [spec: record] {
    let matches = (which $spec.name)

    if ($matches | is-empty) {
        return {
            category: "command"
            name: $spec.name
            status: "missing"
            action: "none"
            detail: "命令未找到"
            required: $spec.required
        }
    }

    let probe = ($spec.probe? | default [])
    if ($probe | is-empty) {
        let command = ($matches | first)
        return {
            category: "command"
            name: $spec.name
            status: "ok"
            action: "none"
            detail: $"已找到：($command.path? | default $command.type)"
            required: $spec.required
        }
    }

    let result = (try {
        run-external $spec.name ...$probe | complete
    } catch {|error|
        {
            stdout: ""
            stderr: $error.msg
            exit_code: 1
        }
    })

    if $result.exit_code == 0 {
        {
            category: "command"
            name: $spec.name
            status: "ok"
            action: "none"
            detail: (first-output-line $result)
            required: $spec.required
        }
    } else {
        {
            category: "command"
            name: $spec.name
            status: "probe_failed"
            action: "none"
            detail: $"探测失败（退出码 ($result.exit_code)）：(first-output-line $result)"
            required: $spec.required
        }
    }
}


# =============================================================================
# 平台软连接创建
# =============================================================================

# Windows 使用 cmd.exe 内置的 mklink；目录链接需要 /D。
def create-link-windows [source: string, target: string, kind: string] {
    let arguments = if $kind == "dir" {
        ["/u" "/d" "/c" "mklink" "/D" $target $source]
    } else {
        ["/u" "/d" "/c" "mklink" $target $source]
    }

    let raw_result = (try {
        ^cmd.exe ...$arguments | complete
    } catch {|error|
        {
            stdout: ""
            stderr: $error.msg
            exit_code: 1
        }
    })
    let result = {
        stdout: (decode-windows-command-output ($raw_result.stdout? | default null))
        stderr: (decode-windows-command-output ($raw_result.stderr? | default null))
        exit_code: ($raw_result.exit_code? | default 1)
    }

    if $result.exit_code == 0 {
        {
            success: true
            detail: (first-output-line $result)
        }
    } else {
        {
            success: false
            detail: $"mklink 失败（退出码 ($result.exit_code)）：(first-output-line $result)"
        }
    }
}


# macOS 使用系统标准 ln。文件和目录软连接使用相同的 -s 参数。
def create-link-macos [source: string, target: string] {
    let raw_result = (try {
        run-external "/bin/ln" "-s" $source $target | complete
    } catch {|error|
        {
            stdout: ""
            stderr: $error.msg
            exit_code: 1
        }
    })
    let result = {
        stdout: (output-to-string ($raw_result.stdout? | default null))
        stderr: (output-to-string ($raw_result.stderr? | default null))
        exit_code: ($raw_result.exit_code? | default 1)
    }

    if $result.exit_code == 0 {
        {
            success: true
            detail: (first-output-line $result)
        }
    } else {
        {
            success: false
            detail: $"ln -s 失败（退出码 ($result.exit_code)）：(first-output-line $result)"
        }
    }
}


# 公共入口负责父目录创建，再分派到当前平台的链接实现。
# 此函数只在目标不存在时由 sync 调用。
def create-link [source: string, target: string, kind: string] {
    let parent = ($target | path dirname)
    if not ($parent | path exists) {
        try {
            mkdir $parent | ignore
        } catch {|error|
            return {
                success: false
                detail: $"无法创建父目录：($error.msg)"
            }
        }
    }

    match $nu.os-info.name {
        "windows" => { create-link-windows $source $target $kind }
        "macos" => { create-link-macos $source $target }
        _ => {
            {
                success: false
                detail: $"不支持的平台：($nu.os-info.name)"
            }
        }
    }
}


def remove-test-path [value: string] {
    let normalized_value = (normalize-path $value)
    let normalized_temp = (normalize-path $nu.temp-dir)
    let separator = (path-separator)
    let temp_prefix = if ($normalized_temp | str ends-with $separator) {
        $normalized_temp
    } else {
        $"($normalized_temp)($separator)"
    }

    # 递归删除只允许发生在系统临时目录下，防止计算路径异常时误删真实配置。
    if not ($normalized_value | str starts-with $temp_prefix) {
        return
    }

    if not ($value | path exists --no-symlink) {
        return
    }

    let item_type = (try { $value | path type } catch { "unknown" })
    try {
        if $item_type == "dir" {
            rm --force --recursive $value
        } else {
            # 对文件和软连接都只删除当前条目，不跟随链接目标。
            rm --force $value
        }
    } catch {
        # 临时测试清理失败不覆盖原始链接创建结果。
    }
}


# 在真实目标发生变化前，先确认当前进程具有创建所需链接类型的能力。
def test-link-capability [kinds: list<string>] {
    let test_root = ([$nu.temp-dir $"sync-nu-link-test-(random uuid)"] | path join)

    let initialized = (try {
        mkdir $test_root | ignore
        true
    } catch {
        false
    })
    if not $initialized {
        return { success: false, detail: $"无法创建临时预检目录：($test_root)" }
    }

    # 整个探测过程都转换为失败记录；无论中途发生什么异常，随后都会清理根目录。
    let probe_failures = (try {
        mut failures = []

        for kind in ($kinds | uniq) {
            let source = if $kind == "dir" {
                let value = ([$test_root "目录源"] | path join)
                mkdir $value | ignore
                $value
            } else {
                let value = ([$test_root "文件源.txt"] | path join)
                touch $value
                $value
            }
            let target = if $kind == "dir" {
                [$test_root "目录链接"] | path join
            } else {
                [$test_root "文件链接.txt"] | path join
            }

            let created = (try {
                create-link $source $target $kind
            } catch {|error|
                { success: false, detail: $"预检异常：($error.msg)" }
            })
            if not $created.success {
                $failures = ($failures | append $"($kind)：($created.detail)")
            } else {
                let target_type = (try { $target | path type } catch { "unknown" })
                if $target_type != "symlink" {
                    $failures = ($failures | append $"($kind)：创建结果不是软连接")
                }
            }

            remove-test-path $target
        }

        $failures
    } catch {|error|
        [$"预检异常：($error.msg)"]
    })

    remove-test-path $test_root
    mut failures = $probe_failures
    if ($test_root | path exists --no-symlink) {
        $failures = ($failures | append $"临时预检目录清理失败：($test_root)")
    }

    if ($failures | is-empty) {
        { success: true, detail: "软连接创建权限检查通过" }
    } else {
        { success: false, detail: ($failures | str join "; ") }
    }
}


# =============================================================================
# 输出和公开命令
# =============================================================================

def print-results [rows: list<record>] {
    print ($rows | select category name status action detail | table -e)

    let normal = ($rows | where status == "ok" and action != "created" | length)
    let created = ($rows | where action == "created" | length)
    let skipped = ($rows | where action == "skipped" | length)
    let errors = ($rows | where status != "ok" and action != "skipped" | length)

    print ""
    print $"汇总：正常=($normal)  新建=($created)  跳过=($skipped)  错误=($errors)"
}


def has-required-failures [rows: list<record>] {
    $rows | any {|row| $row.required and $row.status != "ok" }
}


def run-status [] {
    require-supported-platform | ignore

    let link_rows = (link-specs | each {|spec| inspect-link $spec })
    let env_rows = (env-checks | each {|spec| inspect-env $spec })
    let command_rows = (command-checks | each {|spec| inspect-command $spec })
    let rows = ($link_rows | append $env_rows | append $command_rows)

    print-results $rows

    if (has-required-failures $rows) {
        exit 1
    }
}


def run-sync [] {
    require-supported-platform | ignore

    let initial = (link-specs | each {|spec| inspect-link $spec })
    let pending = ($initial | where status == "missing")

    let capability = if ($pending | is-empty) {
        { success: true, detail: "没有待创建的链接" }
    } else {
        test-link-capability ($pending | get kind)
    }

    let rows = ($initial | each {|row|
        if $row.status == "ok" {
            $row | update action "unchanged"
        } else if $row.status != "missing" {
            $row | update action "skipped"
        } else if not $capability.success {
            $row
            | update action "error"
            | update detail $"未创建：($capability.detail)"
        } else {
            let created = (create-link $row.source $row.target $row.kind)
            if not $created.success {
                $row
                | update action "error"
                | update detail $created.detail
            } else {
                let verified = (inspect-link $row)
                if $verified.status == "ok" {
                    $verified
                    | update action "created"
                    | update detail $"已创建并验证：($verified.target)"
                } else {
                    $verified
                    | update action "error"
                    | update detail $"创建后验证失败：($verified.detail)"
                }
            }
        }
    })

    print-results $rows

    if (has-required-failures $rows) {
        exit 1
    }
}


# 生成和 --help 一致的帮助文本，并把内部命令名 main 替换为脚本文件名。
def help-text [] {
    help main
    | str replace --all "main status" $"($SCRIPT_NAME) status"
    | str replace --all "main sync" $"($SCRIPT_NAME) sync"
    | str replace --all "> main " $"> ($SCRIPT_NAME) "
}


# 不带子命令时显示帮助，不执行任何检查或同步操作。
def main [] {
    print (help-text)
}


# 只读检查软连接、环境变量和命令状态。
def "main status" [] {
    run-status
}


# 建立缺失的软连接；遇到任何冲突时报告并跳过。
def "main sync" [] {
    run-sync
}

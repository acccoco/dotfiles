set shell := ["nu", "-n", "-c"]

_default:
    @just --list

# 检查软连接、环境变量和命令状态
status:
    @nu -n ./sync.nu status

# 创建缺失的软连接并验证结果
sync:
    @nu -n ./sync.nu sync

#!/bin/bash
set -e

# 显示帮助信息
show_help() {
    echo "HummingBot 延迟任务清理脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -a, --all       停止所有待执行的启动任务"
    echo "  -b, --bot <名称> 停止指定机器人的启动任务"
    echo "  -l, --list      列出所有待执行的启动任务"
    echo "  -h, --help      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --list                    # 列出所有待执行任务"
    echo "  $0 --bot bot2                # 停止 bot2 的启动任务"
    echo "  $0 --all                     # 停止所有待执行任务"
}

# 列出所有待执行的启动任务
list_pending_tasks() {
    echo "待执行的启动任务:"
    echo "=================="

    # 使用atq列出所有待执行任务
    if command -v atq >/dev/null 2>&1; then
        atq_output=$(atq 2>/dev/null || echo "")
        if [ -n "$atq_output" ]; then
            echo "$atq_output"
        else
            echo "没有待执行的启动任务"
        fi
    else
        echo "at 命令不可用，无法列出待执行任务"
    fi

    echo ""
    echo "临时启动脚本:"
    echo "============="

    # 查找临时启动脚本
    temp_scripts=$(find /tmp -name "start_*_*.sh" 2>/dev/null || echo "")
    if [ -n "$temp_scripts" ]; then
        echo "$temp_scripts"
    else
        echo "没有找到临时启动脚本"
    fi
}

# 停止指定机器人的启动任务
stop_bot_tasks() {
    local bot_name="$1"

    if [ -z "$bot_name" ]; then
        echo "错误: 请指定机器人名称"
        return 1
    fi

    echo "停止机器人 $bot_name 的启动任务..."

    # 停止at队列中的相关任务
    if command -v atq >/dev/null 2>&1; then
        atq_output=$(atq 2>/dev/null || echo "")
        if [ -n "$atq_output" ]; then
            echo "$atq_output" | while read -r line; do
                job_id=$(echo "$line" | awk '{print $1}')
                # 检查任务描述中是否包含bot名称
                if at -c "$job_id" 2>/dev/null | grep -q "$bot_name"; then
                    echo "停止任务 ID: $job_id (机器人: $bot_name)"
                    atrm "$job_id" 2>/dev/null || echo "无法停止任务 $job_id"
                fi
            done
        fi
    fi

    # 删除相关的临时脚本
    temp_scripts=$(find /tmp -name "start_${bot_name}_*.sh" 2>/dev/null || echo "")
    if [ -n "$temp_scripts" ]; then
        echo "删除临时脚本:"
        echo "$temp_scripts" | while read -r script; do
            if [ -f "$script" ]; then
                echo "  删除: $script"
                rm -f "$script"
            fi
        done
    fi

    echo "机器人 $bot_name 的启动任务已停止"
}

# 停止所有待执行的启动任务
stop_all_tasks() {
    echo "停止所有待执行的启动任务..."

    # 停止at队列中的所有任务
    if command -v atq >/dev/null 2>&1; then
        atq_output=$(atq 2>/dev/null || echo "")
        if [ -n "$atq_output" ]; then
            echo "停止at队列中的任务:"
            echo "$atq_output" | while read -r line; do
                job_id=$(echo "$line" | awk '{print $1}')
                # 检查是否是启动任务
                if at -c "$job_id" 2>/dev/null | grep -q "start_.*\.sh"; then
                    echo "  停止任务 ID: $job_id"
                    atrm "$job_id" 2>/dev/null || echo "    无法停止任务 $job_id"
                fi
            done
        else
            echo "at队列中没有待执行任务"
        fi
    else
        echo "at 命令不可用"
    fi

    # 删除所有临时启动脚本
    echo ""
    echo "删除临时启动脚本:"
    temp_scripts=$(find /tmp -name "start_*_*.sh" 2>/dev/null || echo "")
    if [ -n "$temp_scripts" ]; then
        echo "$temp_scripts" | while read -r script; do
            if [ -f "$script" ]; then
                echo "  删除: $script"
                rm -f "$script"
            fi
        done
    else
        echo "没有找到临时启动脚本"
    fi

    echo "所有待执行的启动任务已停止"
}

# 主函数
main() {
    case "${1:-}" in
        "-l"|"--list")
            list_pending_tasks
            ;;
        "-b"|"--bot")
            if [ -z "$2" ]; then
                echo "错误: --bot 选项需要指定机器人名称"
                echo "用法: $0 --bot <机器人名称>"
                exit 1
            fi
            stop_bot_tasks "$2"
            ;;
        "-a"|"--all")
            stop_all_tasks
            ;;
        "-h"|"--help")
            show_help
            ;;
        "")
            echo "错误: 请指定操作"
            show_help
            exit 1
            ;;
        *)
            echo "错误: 未知选项 '$1'"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

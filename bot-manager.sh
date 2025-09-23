#!/bin/bash
set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# 加载模块
source "$LIB_DIR/common.sh"
source "$LIB_DIR/docker.sh"
source "$LIB_DIR/config.sh"

# 显示帮助信息
show_help() {
    echo "HummingBot 机器人管理工具"
    echo ""
    echo "用法: $0 <命令> [配置文件夹]"
    echo ""
    echo "命令:"
    echo "  start <配置文件夹>    启动指定配置的机器人"
    echo "  stop <配置文件夹>     停止指定配置的机器人"
    echo "  restart <配置文件夹>  重启指定配置的机器人"
    echo "  status <配置文件夹>   查看机器人状态"
    echo "  list                 列出所有配置文件夹"
    echo "  help                 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start ads_31      # 启动 ads_31 配置的机器人"
    echo "  $0 stop ads_31       # 停止 ads_31 配置的机器人"
    echo "  $0 status ads_31     # 查看 ads_31 机器人的状态"
    echo "  $0 list              # 列出所有可用的配置文件夹"
}

# 列出所有配置文件夹
list_config_folders() {
    print_info "可用的配置文件夹:"
    for folder in */; do
        if [ -d "$folder" ] && [ -f "${folder}bots.csv" ]; then
            local bot_count=$(grep -c "^[^,]*," "${folder}bots.csv" 2>/dev/null || echo "0")
            echo "  - $folder (${bot_count} 个机器人)"
        fi
    done
}

# 启动机器人
start_bots() {
    local config_folder="$1"

    if ! validate_config_folder "$config_folder"; then
        return 1
    fi

    if ! check_required_files "$config_folder"; then
        return 1
    fi

    # 运行prepare.py生成配置
    if ! run_prepare_script "$config_folder"; then
        return 1
    fi

    # 读取机器人名称
    local bots_csv="$config_folder/bots.csv"
    local bot_names=()
    if ! read_bot_names "$bots_csv" bot_names; then
        return 1
    fi

    # 获取tmux session
    local session
    session=$(tmux display-message -p '#S' 2>/dev/null || echo "bot")
    check_tmux_session "$session"

    # 启动所有机器人
    for bot_name in "${bot_names[@]}"; do
        start_docker_container "$bot_name" "$session" "$bot_name"
    done

    print_info "所有机器人启动完成"
}

# 停止机器人
stop_bots() {
    local config_folder="$1"

    if ! validate_config_folder "$config_folder"; then
        return 1
    fi

    # 读取机器人名称
    local bots_csv="$config_folder/bots.csv"
    local bot_names=()
    if ! read_bot_names "$bots_csv" bot_names; then
        return 1
    fi

    # 停止所有机器人
    for bot_name in "${bot_names[@]}"; do
        stop_docker_container "$bot_name"
    done

    print_info "所有机器人停止完成"
}

# 重启机器人
restart_bots() {
    local config_folder="$1"

    print_info "重启配置: $config_folder"
    stop_bots "$config_folder"
    sleep 3
    start_bots "$config_folder"
}

# 查看机器人状态
show_status() {
    local config_folder="$1"

    if ! validate_config_folder "$config_folder"; then
        return 1
    fi

    # 读取机器人名称
    local bots_csv="$config_folder/bots.csv"
    local bot_names=()
    if ! read_bot_names "$bots_csv" bot_names; then
        return 1
    fi

    print_info "机器人状态 ($config_folder):"
    echo "----------------------------------------"

    for bot_name in "${bot_names[@]}"; do
        if check_container_status "$bot_name"; then
            echo "  ✅ $bot_name - 运行中"
        else
            echo "  ❌ $bot_name - 未运行"
        fi
    done
}

# 主函数
main() {
    local command="$1"
    local config_folder="$2"

    case "$command" in
        "start")
            if [ -z "$config_folder" ]; then
                print_error "请指定配置文件夹"
                show_help
                exit 1
            fi
            start_bots "$config_folder"
            ;;
        "stop")
            if [ -z "$config_folder" ]; then
                print_error "请指定配置文件夹"
                show_help
                exit 1
            fi
            stop_bots "$config_folder"
            ;;
        "restart")
            if [ -z "$config_folder" ]; then
                print_error "请指定配置文件夹"
                show_help
                exit 1
            fi
            restart_bots "$config_folder"
            ;;
        "status")
            if [ -z "$config_folder" ]; then
                print_error "请指定配置文件夹"
                show_help
                exit 1
            fi
            show_status "$config_folder"
            ;;
        "list")
            list_config_folders
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "")
            print_error "请指定命令"
            show_help
            exit 1
            ;;
        *)
            print_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

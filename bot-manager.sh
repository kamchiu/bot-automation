#!/bin/bash
set -e

# 显示帮助信息
show_help() {
    echo "HummingBot 机器人管理工具"
    echo ""
    echo "用法: $0 <命令> [参数]"
    echo ""
    echo "命令:"
    echo "  start <bot_name>        启动指定的机器人"
    echo "  stop <bot_name>         停止指定的机器人"
    echo "  start-all               启动所有未运行的机器人"
    echo "  stop-all                停止所有运行的机器人"
    echo "  restart <bot_name>      重启指定的机器人"
    echo "  restart-all             重启所有机器人"
    echo "  status                  查看所有机器人状态"
    echo "  status <bot_name>       查看指定机器人状态"
    echo "  cmd <command>           向所有运行中的机器人发送命令"
    echo "  cmd <bot_name> <command> 向指定机器人发送命令"
    echo "  list                    列出所有机器人"
    echo "  help                    显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start bot1            # 启动 bot1"
    echo "  $0 stop bot1             # 停止 bot1"
    echo "  $0 start-all             # 启动所有未运行的机器人"
    echo "  $0 status                # 查看所有机器人状态"
    echo "  $0 cmd stop              # 向所有机器人发送stop命令"
    echo "  $0 cmd bot1 restart      # 向bot1发送restart命令"
    echo "  $0 list                  # 列出所有机器人"
    echo ""
    echo "注意: 确保 ~/ex-bot/docker-compose.override.yml 文件存在"
}

# 检查docker-compose文件是否存在
check_docker_compose_file() {
    if [ ! -f ~/ex-bot/docker-compose.override.yml ]; then
        echo "错误: 找不到 ~/ex-bot/docker-compose.override.yml 文件"
        echo "请确保文件存在并包含 services 配置"
        exit 1
    fi
}

# 从docker-compose.override.yml读取services
read_bot_names() {
    local bot_names=()
    local in_services=false

    cd ~/ex-bot

    while IFS= read -r line; do
        # 检测services段落开始
        if [[ "$line" =~ ^[[:space:]]*services:[[:space:]]*$ ]]; then
            in_services=true
            continue
        fi

        # 如果不在services段落中，跳过
        if [ "$in_services" = false ]; then
            continue
        fi

        # 检测到新的顶级段落，退出services
        if [[ "$line" =~ ^[a-zA-Z] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            in_services=false
            continue
        fi

        # 在services段落中，匹配服务名
        if [[ "$line" =~ ^[[:space:]]+([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
            local service_name="${BASH_REMATCH[1]}"
            # 跳过配置项（如 build, logging, environment, volumes 等）
            if [[ "$service_name" != "build" && "$service_name" != "logging" && "$service_name" != "environment" && "$service_name" != "volumes" && "$service_name" != "options" && "$service_name" != "container_name" ]]; then
                bot_names+=("$service_name")
            fi
        fi
    done < docker-compose.override.yml

    # 返回机器人名称数组
    printf '%s\n' "${bot_names[@]}"
}

# 检查机器人是否存在
bot_exists() {
    local bot_name="$1"
    local bot_names
    bot_names=($(read_bot_names))

    for name in "${bot_names[@]}"; do
        if [ "$name" = "$bot_name" ]; then
            return 0
        fi
    done
    return 1
}

# 检查机器人是否运行中
is_bot_running() {
    local bot_name="$1"
    if docker ps --format "table {{.Names}}" | grep -q "^${bot_name}$"; then
        return 0
    else
        return 1
    fi
}

# 启动指定机器人
start_bot() {
    local bot_name="$1"

    if ! bot_exists "$bot_name"; then
        echo "错误: 机器人 '$bot_name' 不存在"
        return 1
    fi

    if is_bot_running "$bot_name"; then
        echo "机器人 '$bot_name' 已经在运行中"
        return 0
    fi

    echo "启动机器人: $bot_name"
    cd ~/ex-bot
    docker compose up "$bot_name" -d

    if is_bot_running "$bot_name"; then
        echo "✅ 机器人 '$bot_name' 启动成功"
    else
        echo "❌ 机器人 '$bot_name' 启动失败"
        return 1
    fi
}

# 停止指定机器人
stop_bot() {
    local bot_name="$1"

    if ! bot_exists "$bot_name"; then
        echo "错误: 机器人 '$bot_name' 不存在"
        return 1
    fi

    if ! is_bot_running "$bot_name"; then
        echo "机器人 '$bot_name' 未运行"
        return 0
    fi

    echo "停止机器人: $bot_name"
    cd ~/ex-bot
    docker compose stop "$bot_name"

    if ! is_bot_running "$bot_name"; then
        echo "✅ 机器人 '$bot_name' 停止成功"
    else
        echo "❌ 机器人 '$bot_name' 停止失败"
        return 1
    fi
}

# 启动所有未运行的机器人
start_all_stopped() {
    local bot_names
    bot_names=($(read_bot_names))
    local started_count=0

    echo "检查并启动所有未运行的机器人..."

    for bot_name in "${bot_names[@]}"; do
        if ! is_bot_running "$bot_name"; then
            echo "启动机器人: $bot_name"
            cd ~/ex-bot
            docker compose up "$bot_name" -d
            if is_bot_running "$bot_name"; then
                echo "✅ $bot_name 启动成功"
                ((started_count++))
            else
                echo "❌ $bot_name 启动失败"
            fi
        else
            echo "⏭️  $bot_name 已在运行中，跳过"
        fi
    done

    echo "启动完成，共启动了 $started_count 个机器人"
}

# 停止所有运行的机器人
stop_all_running() {
    local bot_names
    bot_names=($(read_bot_names))
    local stopped_count=0

    echo "停止所有运行的机器人..."

    for bot_name in "${bot_names[@]}"; do
        if is_bot_running "$bot_name"; then
            echo "停止机器人: $bot_name"
            cd ~/ex-bot
            docker compose stop "$bot_name"
            if ! is_bot_running "$bot_name"; then
                echo "✅ $bot_name 停止成功"
                ((stopped_count++))
            else
                echo "❌ $bot_name 停止失败"
            fi
        else
            echo "⏭️  $bot_name 未运行，跳过"
        fi
    done

    echo "停止完成，共停止了 $stopped_count 个机器人"
}

# 重启指定机器人
restart_bot() {
    local bot_name="$1"

    if ! bot_exists "$bot_name"; then
        echo "错误: 机器人 '$bot_name' 不存在"
        return 1
    fi

    echo "重启机器人: $bot_name"
    stop_bot "$bot_name"
    sleep 2
    start_bot "$bot_name"
}

# 重启所有机器人
restart_all() {
    local bot_names
    bot_names=($(read_bot_names))

    echo "重启所有机器人..."
    stop_all_running
    sleep 3
    start_all_stopped
}

# 查看机器人状态
show_status() {
    local target_bot="$1"
    local bot_names
    bot_names=($(read_bot_names))

    if [ -n "$target_bot" ]; then
        # 查看指定机器人状态
        if ! bot_exists "$target_bot"; then
            echo "错误: 机器人 '$target_bot' 不存在"
            return 1
        fi

        echo "机器人状态: $target_bot"
        echo "----------------------------------------"
        if is_bot_running "$target_bot"; then
            echo "✅ $target_bot - 运行中"
            # 显示容器详细信息
            echo ""
            echo "容器信息:"
            docker ps --filter "name=$target_bot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            echo "❌ $target_bot - 未运行"
        fi
    else
        # 查看所有机器人状态
        echo "所有机器人状态:"
        echo "========================================"
        local running_count=0
        local total_count=${#bot_names[@]}

        for bot_name in "${bot_names[@]}"; do
            if is_bot_running "$bot_name"; then
                echo "✅ $bot_name - 运行中"
                ((running_count++))
            else
                echo "❌ $bot_name - 未运行"
            fi
        done

        echo "========================================"
        echo "总计: $running_count/$total_count 个机器人运行中"
    fi
}

# 向机器人发送命令
send_command() {
    local target_bot="$1"
    local command="$2"
    local bot_names
    bot_names=($(read_bot_names))

    # 获取当前tmux session
    local session
    session=$(tmux display-message -p '#S' 2>/dev/null || echo "bot")

    if [ -n "$target_bot" ]; then
        # 向指定机器人发送命令
        if ! bot_exists "$target_bot"; then
            echo "错误: 机器人 '$target_bot' 不存在"
            return 1
        fi

        if ! is_bot_running "$target_bot"; then
            echo "错误: 机器人 '$target_bot' 未运行，无法发送命令"
            return 1
        fi

        echo "向机器人 '$target_bot' 发送命令: $command"
        tmux send-keys -t "$session:$target_bot" "$command" C-m
        echo "✅ 命令已发送"
    else
        # 向所有运行中的机器人发送命令
        local sent_count=0
        echo "向所有运行中的机器人发送命令: $command"

        for bot_name in "${bot_names[@]}"; do
            if is_bot_running "$bot_name"; then
                echo "向机器人 '$bot_name' 发送命令: $command"
                tmux send-keys -t "$session:$bot_name" "$command" C-m
                ((sent_count++))
            fi
        done

        echo "✅ 命令已发送给 $sent_count 个运行中的机器人"
    fi
}

# 列出所有机器人
list_bots() {
    local bot_names
    bot_names=($(read_bot_names))

    echo "所有机器人列表:"
    echo "========================================"

    for bot_name in "${bot_names[@]}"; do
        if is_bot_running "$bot_name"; then
            echo "✅ $bot_name - 运行中"
        else
            echo "❌ $bot_name - 未运行"
        fi
    done

    echo "========================================"
    echo "总计: ${#bot_names[@]} 个机器人"
}

# 主函数
main() {
    local command="$1"
    local arg1="$2"
    local arg2="$3"

    # 检查docker-compose文件
    check_docker_compose_file

    case "$command" in
        "start")
            if [ -z "$arg1" ]; then
                echo "错误: 请指定机器人名称"
                echo "用法: $0 start <bot_name>"
                exit 1
            fi
            start_bot "$arg1"
            ;;
        "stop")
            if [ -z "$arg1" ]; then
                echo "错误: 请指定机器人名称"
                echo "用法: $0 stop <bot_name>"
                exit 1
            fi
            stop_bot "$arg1"
            ;;
        "start-all")
            start_all_stopped
            ;;
        "stop-all")
            stop_all_running
            ;;
        "restart")
            if [ -z "$arg1" ]; then
                echo "错误: 请指定机器人名称"
                echo "用法: $0 restart <bot_name>"
                exit 1
            fi
            restart_bot "$arg1"
            ;;
        "restart-all")
            restart_all
            ;;
        "status")
            show_status "$arg1"
            ;;
        "cmd")
            if [ -z "$arg1" ]; then
                echo "错误: 请指定命令"
                echo "用法: $0 cmd <command> 或 $0 cmd <bot_name> <command>"
                exit 1
            fi
            if [ -n "$arg2" ]; then
                # cmd <bot_name> <command>
                send_command "$arg1" "$arg2"
            else
                # cmd <command>
                send_command "" "$arg1"
            fi
            ;;
        "list")
            list_bots
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "")
            echo "错误: 请指定命令"
            show_help
            exit 1
            ;;
        *)
            echo "错误: 未知命令 '$command'"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

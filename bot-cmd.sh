#!/bin/bash
set -e

# 显示帮助信息
show_help() {
    echo "HummingBot 机器人命令执行脚本"
    echo ""
    echo "用法: $0 <命令>"
    echo ""
    echo "功能:"
    echo "  - 读取 ~/ex-bot/docker-compose.override.yml 中的 services"
    echo "  - 向所有机器人的tmux窗口发送指定命令"
    echo ""
    echo "示例:"
    echo "  $0 stop        # 停止所有机器人"
    echo "  $0 restart     # 重启所有机器人"
    echo "  $0 logs        # 查看所有机器人日志"
    echo ""
    echo "注意: 确保 ~/ex-bot/docker-compose.override.yml 文件存在"
}

# 检查是否输入了参数
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# 检查帮助参数
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# 读取输入参数，比如 up / stop / restart 等
CMD="$1"

# 检查是否在正确的目录
if [ ! -f ~/ex-bot/docker-compose.override.yml ]; then
    echo "错误: 找不到 ~/ex-bot/docker-compose.override.yml 文件"
    echo "请确保文件存在并包含 services 配置"
    exit 1
fi

echo "读取 ~/ex-bot/docker-compose.override.yml 中的 services..."

# 切换到ex-bot目录
cd ~/ex-bot

# 从docker-compose.override.yml读取services
BOT_NAMES=()
in_services=false
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
        service_name="${BASH_REMATCH[1]}"
        # 跳过配置项（如 build, logging, environment, volumes 等）
        if [[ "$service_name" != "build" && "$service_name" != "logging" && "$service_name" != "environment" && "$service_name" != "volumes" && "$service_name" != "options" && "$service_name" != "container_name" ]]; then
            BOT_NAMES+=("$service_name")
        fi
    fi
done < docker-compose.override.yml

# 检查是否读取到机器人名称
if [ ${#BOT_NAMES[@]} -eq 0 ]; then
    echo "错误: 没有从 docker-compose.override.yml 中读取到有效的服务名称"
    echo "请检查文件格式，确保有 services 配置"
    exit 1
fi

echo "找到 ${#BOT_NAMES[@]} 个机器人: ${BOT_NAMES[*]}"

# 获取当前tmux session
SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "bot")

# 确保tmux session存在
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "错误: tmux 会话 '$SESSION' 不存在，无法发送命令"
    echo "请先启动机器人或手动创建 tmux 会话"
    exit 1
fi

# 获取现有窗口列表
WINDOW_LIST=$(tmux list-windows -t "$SESSION" -F "#{window_name}")

echo "向所有机器人发送命令: $CMD"
for BOT_NAME in "${BOT_NAMES[@]}"; do
    if echo "$WINDOW_LIST" | grep -Fxq "$BOT_NAME"; then
        echo "向机器人 $BOT_NAME 发送命令: $CMD"
        tmux send-keys -t "$SESSION:$BOT_NAME" "$CMD" C-m
    else
        echo "⚠️  未找到 tmux 窗口 '$BOT_NAME'，跳过发送命令"
    fi
done

echo "命令发送完成！"

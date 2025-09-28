#!/bin/bash
set -e

# 配置变量
START_INTERVAL_MINUTES=3  # 机器人启动间隔（分钟）
RANDOMIZE_ORDER=true      # 是否随机化启动顺序

# 显示帮助信息
show_help() {
    echo "HummingBot 机器人启动脚本"
    echo ""
    echo "用法: $0"
    echo ""
    echo "功能:"
    echo "  - 读取 ~/ex-bot/docker-compose.override.yml 中的 services"
    echo "  - 每隔 $START_INTERVAL_MINUTES 分钟启动一个机器人"
    echo "  - 使用 tmux 管理机器人会话"
    echo "  - 随机化启动顺序 (可通过 RANDOMIZE_ORDER 变量控制)"
    echo ""
    echo "注意: 确保 ~/ex-bot/docker-compose.override.yml 文件存在"
}

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

# 随机化启动顺序
if [ "$RANDOMIZE_ORDER" = true ]; then
    echo "随机化启动顺序..."
    # 使用shuf命令随机打乱数组
    if command -v shuf >/dev/null 2>&1; then
        # 如果有shuf命令，使用它
        BOT_NAMES=($(printf '%s\n' "${BOT_NAMES[@]}" | shuf))
    else
        # 如果没有shuf命令，使用Fisher-Yates洗牌算法
        local i j temp
        for ((i=${#BOT_NAMES[@]}-1; i>0; i--)); do
            j=$((RANDOM % (i+1)))
            temp="${BOT_NAMES[i]}"
            BOT_NAMES[i]="${BOT_NAMES[j]}"
            BOT_NAMES[j]="$temp"
        done
    fi
    echo "随机化后的启动顺序: ${BOT_NAMES[*]}"
else
    echo "使用原始启动顺序: ${BOT_NAMES[*]}"
fi

# 获取当前tmux session
SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "bot")

# 如果tmux session不存在，创建一个新的
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "创建新的tmux session: $SESSION"
    tmux new-session -d -s "$SESSION"
fi

# 启动每个机器人的函数
start_bot() {
    local bot_name="$1"
    local delay_minutes="$2"

    echo "准备启动机器人: $bot_name (延迟 ${delay_minutes} 分钟)"

    # 如果窗口不存在则创建
    if ! tmux list-windows -t "$SESSION" -F "#{window_name}" | grep -Fxq "$bot_name"; then
        tmux new-window -t "$SESSION:" -n "$bot_name"
        echo "创建新窗口: $bot_name"
    else
        echo "窗口已存在: $bot_name"
    fi

    # 在对应窗口里执行启动命令
    tmux send-keys -t "$SESSION:$bot_name" \
        "cd ~/ex-bot && docker compose up $bot_name -d && docker attach $bot_name" C-m

    echo "机器人 $bot_name 启动命令已发送"
}

# 启动第一个机器人（立即启动）
start_bot "${BOT_NAMES[0]}" 0

# 为剩余的机器人设置延迟启动
for i in "${!BOT_NAMES[@]}"; do
    if [ $i -gt 0 ]; then
        bot_name="${BOT_NAMES[$i]}"
        delay_minutes=$((i * START_INTERVAL_MINUTES))

        # 使用at命令在指定时间后启动机器人
        echo "设置 $bot_name 在 $delay_minutes 分钟后启动"

        # 创建临时脚本用于延迟启动
        temp_script="/tmp/start_${bot_name}_$$.sh"
        cat > "$temp_script" << EOF
#!/bin/bash
SESSION=\$(tmux display-message -p '#S' 2>/dev/null || echo "default")
BOT_NAME="$bot_name"
echo "延迟启动机器人: \$BOT_NAME"

# 如果窗口不存在则创建
if ! tmux list-windows -t "\$SESSION" -F "#{window_name}" | grep -Fxq "\$BOT_NAME"; then
    tmux new-window -t "\$SESSION:" -n "\$BOT_NAME"
    echo "创建新窗口: \$BOT_NAME"
else
    echo "窗口已存在: \$BOT_NAME"
fi

# 在对应窗口里执行启动命令
tmux send-keys -t "\$SESSION:\$BOT_NAME" \
    "cd ~/ex-bot && docker compose up \$BOT_NAME -d && docker attach \$BOT_NAME" C-m

echo "机器人 \$BOT_NAME 启动完成"
# 清理临时脚本
rm -f "$temp_script"
EOF

        chmod +x "$temp_script"

        # 使用at命令调度延迟启动
        echo "bash $temp_script" | at now + ${delay_minutes} minutes 2>/dev/null || {
            echo "警告: at命令不可用，使用sleep代替"
            (
                sleep $((delay_minutes * 60))
                bash "$temp_script"
            ) &
        }
    fi
done

echo "="
echo "启动计划:"
echo "机器人数量: ${#BOT_NAMES[@]}"
echo "启动间隔: $START_INTERVAL_MINUTES 分钟"
echo "随机化顺序: $RANDOMIZE_ORDER"
total_time=$(((${#BOT_NAMES[@]} - 1) * START_INTERVAL_MINUTES))
echo "总启动时间: $total_time 分钟"
echo "="
echo "已启动: ${BOT_NAMES[0]} (立即)"
for i in "${!BOT_NAMES[@]}"; do
    if [ $i -gt 0 ]; then
        delay_minutes=$((i * START_INTERVAL_MINUTES))
        echo "计划启动: ${BOT_NAMES[$i]} (${delay_minutes}分钟后)"
    fi
done
echo "="
echo "使用 'tmux attach' 连接到session查看机器人状态"
echo "使用 'tmux list-windows' 查看所有窗口"
echo "使用 'atq' 查看待执行的启动任务"

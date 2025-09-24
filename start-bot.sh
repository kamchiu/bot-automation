#!/bin/bash
set -e

# 配置变量
START_INTERVAL_MINUTES=3  # 机器人启动间隔（分钟）

# 显示帮助信息
show_help() {
    echo "HummingBot 机器人启动脚本"
    echo ""
    echo "用法: $0 <配置文件夹名>"
    echo ""
    echo "参数:"
    echo "  <配置文件夹名>    配置文件夹名称 (如 ads_31)"
    echo ""
    echo "示例:"
    echo "  $0 ads_31                    # 启动 ads_31 配置的机器人"
    echo ""
    echo "功能:"
    echo "  - 读取配置文件夹下的 bots.csv 文件"
    echo "  - 每隔 $START_INTERVAL_MINUTES 分钟启动一个机器人"
    echo "  - 使用 tmux 管理机器人会话"
}

# 检查参数
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

CONFIG_FOLDER="$1"

# 检查配置文件夹是否存在
if [ ! -d "$CONFIG_FOLDER" ]; then
    echo "错误: 配置文件夹不存在: $CONFIG_FOLDER"
    exit 1
fi

# 检查bots.csv文件是否存在
BOTS_CSV="$CONFIG_FOLDER/bots.csv"
if [ ! -f "$BOTS_CSV" ]; then
    echo "错误: 找不到 $BOTS_CSV 文件"
    exit 1
fi

echo "使用配置文件夹: $CONFIG_FOLDER"
echo "机器人配置文件: $BOTS_CSV"

# 从bots.csv读取name字段
echo "从 $BOTS_CSV 读取机器人名称..."
BOT_NAMES=()
while IFS=',' read -r name rest; do
    # 跳过标题行和空行
    if [ "$name" != "name" ] && [ -n "$name" ]; then
        BOT_NAMES+=("$name")
    fi
done < "$BOTS_CSV"

# 检查是否读取到机器人名称
if [ ${#BOT_NAMES[@]} -eq 0 ]; then
    echo "错误: 没有从 $BOTS_CSV 中读取到有效的机器人名称"
    exit 1
fi

echo "找到 ${#BOT_NAMES[@]} 个机器人: ${BOT_NAMES[*]}"

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
    if ! tmux list-windows -t "$SESSION" | grep -q "$bot_name"; then
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
if ! tmux list-windows -t "\$SESSION" | grep -q "\$BOT_NAME"; then
    tmux new-window -t "\$SESSION:" -n "\$BOT_NAME"
    echo "创建新窗口: \$BOT_NAME"
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
local total_time=$(((${#BOT_NAMES[@]} - 1) * START_INTERVAL_MINUTES))
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

#!/bin/bash
set -e

# 检查是否输入了参数
if [ $# -eq 0 ]; then
  echo "用法: $0 <命令>"
  echo "示例: $0 stop"
  exit 1
fi

# 读取输入参数，比如 up / stop / restart 等
CMD="$1"

# 检查bots.csv文件是否存在
BOTS_CSV="bots.csv"
if [ ! -f "$BOTS_CSV" ]; then
    echo "错误: 找不到 $BOTS_CSV 文件"
    exit 1
fi

# 从bots.csv读取name字段作为窗口名称列表
echo "从 $BOTS_CSV 读取机器人名称..."
WINDOWS=()
while IFS=',' read -r name rest; do
    # 跳过标题行和空行
    if [ "$name" != "name" ] && [ -n "$name" ]; then
        WINDOWS+=("$name")
    fi
done < "$BOTS_CSV"

# 检查是否读取到机器人名称
if [ ${#WINDOWS[@]} -eq 0 ]; then
    echo "错误: 没有从 $BOTS_CSV 中读取到有效的机器人名称"
    exit 1
fi

echo "找到 ${#WINDOWS[@]} 个机器人: ${WINDOWS[*]}"

for NAME in "${WINDOWS[@]}"; do
  tmux send-keys -t "$NAME" "$CMD" C-m
done

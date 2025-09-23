#!/bin/bash
set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# 加载模块
source "$LIB_DIR/common.sh"
source "$LIB_DIR/docker.sh"
source "$LIB_DIR/config.sh"

# 主函数
main() {
    # 检查参数
    if [ $# -eq 0 ]; then
        print_error "用法: $0 <配置文件夹名>"
        print_info "示例: $0 ads_31"
        print_info "将从指定文件夹下读取 bots.csv 和 prepare.py"
        exit 1
    fi

    local config_folder="$1"

    # 验证配置文件夹
    if ! validate_config_folder "$config_folder"; then
        exit 1
    fi

    # 检查必要文件
    if ! check_required_files "$config_folder"; then
        exit 1
    fi

    # 显示配置信息
    get_config_info "$config_folder"

    # 读取机器人名称
    local bots_csv="$config_folder/bots.csv"
    local bot_names=()
    if ! read_bot_names "$bots_csv" bot_names; then
        exit 1
    fi

    # 运行prepare.py生成配置
    if ! run_prepare_script "$config_folder"; then
        exit 1
    fi

    # 获取tmux session
    local session
    session=$(tmux display-message -p '#S' 2>/dev/null || echo "bot")

    # 确保tmux session存在
    check_tmux_session "$session"

    # 启动第一个机器人（立即启动）
    start_docker_container "${bot_names[0]}" "$session" "${bot_names[0]}"

    # 为剩余的机器人设置延迟启动
    for i in "${!bot_names[@]}"; do
        if [ $i -gt 0 ]; then
            local bot_name="${bot_names[$i]}"
            local delay_minutes=$((i * 5))

            print_info "设置 $bot_name 在 $delay_minutes 分钟后启动"
            schedule_delayed_start "$bot_name" "$session" "$delay_minutes"
        fi
    done

    # 显示启动计划
    show_startup_plan bot_names
}

# 调度延迟启动
schedule_delayed_start() {
    local bot_name="$1"
    local session="$2"
    local delay_minutes="$3"

    # 创建临时脚本用于延迟启动
    local temp_script="/tmp/start_${bot_name}_$$.sh"
    cat > "$temp_script" << EOF
#!/bin/bash
# 加载模块
source "$LIB_DIR/common.sh"
source "$LIB_DIR/docker.sh"

SESSION=\$(tmux display-message -p '#S' 2>/dev/null || echo "default")
print_info "延迟启动机器人: $bot_name"

# 启动机器人
start_docker_container "$bot_name" "\$SESSION" "$bot_name"

print_info "机器人 $bot_name 启动完成"
# 清理临时脚本
rm -f "$temp_script"
EOF

    chmod +x "$temp_script"

    # 使用at命令调度延迟启动
    echo "bash $temp_script" | at now + ${delay_minutes} minutes 2>/dev/null || {
        print_warn "at命令不可用，使用sleep代替"
        (
            sleep $((delay_minutes * 60))
            bash "$temp_script"
        ) &
    }
}

# 显示启动计划
show_startup_plan() {
    local -n bot_names_ref="$1"

    echo "="
    print_info "启动计划:"
    echo "  机器人数量: ${#bot_names_ref[@]}"
    echo "  启动间隔: 5分钟"
    echo "  总启动时间: $((((${#bot_names_ref[@]} - 1) * 5)) 分钟"
    echo "="
    echo "  已启动: ${bot_names_ref[0]} (立即)"

    for i in "${!bot_names_ref[@]}"; do
        if [ $i -gt 0 ]; then
            local delay_minutes=$((i * 5))
            echo "  计划启动: ${bot_names_ref[$i]} (${delay_minutes}分钟后)"
        fi
    done

    echo "="
    print_info "使用 'tmux attach' 连接到session查看机器人状态"
    print_info "使用 'tmux list-windows' 查看所有窗口"
    print_info "使用 'atq' 查看待执行的启动任务"
}

# 执行主函数
main "$@"

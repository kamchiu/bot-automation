#!/bin/bash
# 通用函数库

# 颜色输出函数
print_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

print_warn() {
    echo -e "\033[33m[WARN]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# 检查文件是否存在
check_file_exists() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        print_error "找不到文件: $file_path"
        return 1
    fi
    return 0
}

# 检查目录是否存在
check_dir_exists() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        print_error "找不到目录: $dir_path"
        return 1
    fi
    return 0
}

# 从CSV文件读取机器人名称
read_bot_names() {
    local csv_file="$1"
    local -n bot_names_ref="$2"  # 使用 nameref 传递数组

    bot_names_ref=()
    while IFS=',' read -r name rest; do
        # 跳过标题行和空行
        if [ "$name" != "name" ] && [ -n "$name" ]; then
            bot_names_ref+=("$name")
        fi
    done < "$csv_file"

    if [ ${#bot_names_ref[@]} -eq 0 ]; then
        print_error "没有从 $csv_file 中读取到有效的机器人名称"
        return 1
    fi

    print_info "找到 ${#bot_names_ref[@]} 个机器人: ${bot_names_ref[*]}"
    return 0
}

# 检查tmux session是否存在
check_tmux_session() {
    local session_name="$1"
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        print_info "创建新的tmux session: $session_name"
        tmux new-session -d -s "$session_name"
        return 0
    fi
    return 1
}

# 创建tmux窗口
create_tmux_window() {
    local session="$1"
    local window_name="$2"

    if ! tmux list-windows -t "$session" | grep -q "$window_name"; then
        tmux new-window -t "$session:" -n "$window_name"
        print_info "创建新窗口: $window_name"
        return 0
    else
        print_info "窗口已存在: $window_name"
        return 1
    fi
}

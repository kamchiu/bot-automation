#!/bin/bash
# Docker 相关函数库

# 启动Docker容器
start_docker_container() {
    local bot_name="$1"
    local session="$2"
    local window_name="$3"

    print_info "准备启动机器人: $bot_name"

    # 创建tmux窗口（如果不存在）
    create_tmux_window "$session" "$window_name"

    # 在对应窗口里执行启动命令
    tmux send-keys -t "$session:$window_name" \
        "cd ~/ex-bot && docker compose up $bot_name -d && docker attach \$(docker ps -qf name=$bot_name)" C-m

    print_info "机器人 $bot_name 启动命令已发送"
}

# 停止Docker容器
stop_docker_container() {
    local bot_name="$1"
    print_info "停止机器人: $bot_name"

    # 停止容器
    docker stop "$bot_name" 2>/dev/null || print_warn "容器 $bot_name 可能已经停止"

    # 删除容器
    docker rm "$bot_name" 2>/dev/null || print_warn "容器 $bot_name 可能已经删除"
}

# 重启Docker容器
restart_docker_container() {
    local bot_name="$1"
    print_info "重启机器人: $bot_name"

    stop_docker_container "$bot_name"
    sleep 2
    start_docker_container "$bot_name"
}

# 检查容器状态
check_container_status() {
    local bot_name="$1"

    if docker ps -qf name="$bot_name" | grep -q "$bot_name"; then
        print_info "容器 $bot_name 正在运行"
        return 0
    else
        print_warn "容器 $bot_name 未运行"
        return 1
    fi
}

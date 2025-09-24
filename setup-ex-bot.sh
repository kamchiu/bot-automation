#!/bin/bash

# 服务器快速搭建ex-bot环境脚本
# 使用方法: ./setup-ex-bot.sh <server_ip> <username>

set -e  # 遇到错误立即退出

# 检查参数
if [ $# -ne 2 ]; then
    echo "使用方法: $0 <server_ip> <username>"
    echo "示例: $0 192.168.1.100 ubuntu"
    exit 1
fi

SERVER_IP=$1
USERNAME=$2

echo "=========================================="
echo "开始搭建ex-bot环境"
echo "服务器IP: $SERVER_IP"
echo "用户名: $USERNAME"
echo "=========================================="

# 1. 复制SSH密钥到服务器
echo "步骤1: 复制SSH密钥到服务器..."
echo "正在复制公钥..."
ssh-copy-id -i ~/.ssh/id_ed25519.pub $USERNAME@$SERVER_IP

echo "正在复制私钥..."
scp ~/.ssh/id_ed25519.pub $USERNAME@$SERVER_IP:/home/$USERNAME/.ssh/
scp ~/.ssh/id_ed25519 $USERNAME@$SERVER_IP:/home/$USERNAME/.ssh/

# 2. 连接服务器并执行安装命令
echo "步骤2: 连接服务器并执行安装..."
ssh $USERNAME@$SERVER_IP << 'EOF'
    echo "正在服务器上执行安装命令..."

    # 拉取ex-bot代码
    echo "拉取ex-bot代码..."
    git clone -b bpx git@github.com:way2freedom/ex-bot.git

    # 安装docker
    echo "安装Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh

    # 将当前用户添加到docker组
    sudo usermod -aG docker $USER
    newgrp docker

    echo "Docker安装完成"

    sudo apt update
    sudo apt install at
    # 启动服务
    sudo systemctl start atd

    # 设置开机自启
    sudo systemctl enable atd

    # 检查服务状态
    sudo systemctl status atd
EOF

echo "=========================================="
echo "ex-bot环境搭建完成！"
echo "=========================================="

#!/bin/bash
set -e

# 检查参数
if [ $# -eq 0 ]; then
    echo "用法: $0 <配置文件夹名>"
    echo "示例: $0 ads_31"
    echo "注意: SSH配置中的主机名必须与配置文件夹名相同"
    exit 1
fi

CONFIG_FOLDER="$1"
SSH_HOST="$1"

echo "部署配置: $CONFIG_FOLDER -> $SSH_HOST"

# 检查本地文件
if [ ! -d "$CONFIG_FOLDER" ]; then
    echo "错误: 配置文件夹不存在: $CONFIG_FOLDER"
    exit 1
fi

if [ ! -d "$CONFIG_FOLDER/conf" ]; then
    echo "错误: conf 目录不存在: $CONFIG_FOLDER/conf"
    echo "请先运行: python prepare.py $CONFIG_FOLDER"
    exit 1
fi

if [ ! -f "$CONFIG_FOLDER/docker-compose.override.yml" ]; then
    echo "错误: docker-compose.override.yml 不存在: $CONFIG_FOLDER/docker-compose.override.yml"
    echo "请先运行: python prepare.py $CONFIG_FOLDER"
    exit 1
fi

echo "本地文件检查通过"

# 测试SSH连接
echo "测试SSH连接..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_HOST" "echo '连接成功'" >/dev/null 2>&1; then
    echo "错误: 无法连接到服务器: $SSH_HOST"
    echo "请检查:"
    echo "1. ~/.ssh/config 中是否配置了 Host $SSH_HOST"
    echo "2. SSH 密钥是否正确"
    echo "3. 网络连接是否正常"
    exit 1
fi

echo "SSH连接正常"

# 创建远程目录
echo "创建远程目录..."
ssh "$SSH_HOST" "mkdir -p ~/ex-bot"

# 上传conf目录
echo "上传 conf 目录..."
rsync -avz "$CONFIG_FOLDER/conf/" "$SSH_HOST:~/ex-bot/conf/"

# 上传docker-compose文件
echo "上传 docker-compose.override.yml..."
scp "$CONFIG_FOLDER/docker-compose.override.yml" "$SSH_HOST:~/ex-bot/docker-compose.override.yml"

echo "部署完成！"
echo "远程文件位置:"
echo "  ~/ex-bot/conf/"
echo "  ~/ex-bot/docker-compose.override.yml"

# HummingBot 任务管理指南

## 🚀 启动机器人

### 基本启动
```bash
# 启动所有配置的机器人（每隔3分钟启动一个）
./start-bot.sh
```

### 启动流程
1. 脚本自动读取 `~/ex-bot/docker-compose.override.yml`
2. 解析出所有服务名称（如 `bot1`, `bot2`）
3. 立即启动第一个机器人
4. 后续机器人每隔3分钟延迟启动

### 启动示例
假设有3个机器人（bot1, bot2, bot3）：
- **bot1**: 立即启动（0分钟）
- **bot2**: 3分钟后启动
- **bot3**: 6分钟后启动

## 🛑 停止待执行任务

### 查看待执行任务
```bash
# 列出所有待执行的启动任务
./stop-pending.sh --list
```

### 停止指定机器人
```bash
# 停止 bot2 的启动任务
./stop-pending.sh --bot bot2
```

### 停止所有待执行任务
```bash
# 停止所有待执行的启动任务
./stop-pending.sh --all
```

## 📋 使用场景

### 场景1：发现问题需要停止后续启动
```bash
# 1. 启动机器人
./start-bot.sh

# 2. 发现 bot1 有问题，想停止后续启动
./stop-pending.sh --list    # 查看待执行任务
./stop-pending.sh --all     # 停止所有待执行任务
```

### 场景2：只停止特定机器人
```bash
# 启动机器人
./start-bot.sh

# 只想停止 bot3 的启动，保留 bot2
./stop-pending.sh --bot bot3
```

### 场景3：检查当前状态
```bash
# 查看当前有哪些任务待执行
./stop-pending.sh --list
```

## 🔧 脚本功能详解

### start-bot.sh
- **功能**: 启动所有配置的机器人
- **特点**:
  - 自动读取 Docker Compose 配置
  - 延迟启动避免资源冲突
  - 使用 tmux 管理会话

### stop-pending.sh
- **功能**: 管理待执行的启动任务
- **特点**:
  - 列出待执行任务
  - 停止指定机器人任务
  - 停止所有待执行任务
  - 清理临时文件

## 📊 任务状态监控

### 查看 tmux 会话
```bash
# 连接到 tmux 会话
tmux attach

# 列出所有窗口
tmux list-windows

# 切换到指定窗口
tmux select-window -t bot1
```

### 查看 Docker 容器
```bash
# 查看运行中的容器
docker ps

# 查看所有容器
docker ps -a

# 查看特定容器日志
docker logs bot1
```

### 查看 at 队列（如果可用）
```bash
# 查看待执行任务
atq

# 查看任务详情
at -c <任务ID>
```

## 🚨 故障排除

### 常见问题

#### 1. at 命令不可用
```bash
# Ubuntu/Debian
sudo apt-get install at

# CentOS/RHEL
sudo yum install at
```

#### 2. 临时脚本残留
```bash
# 手动清理临时脚本
find /tmp -name "start_*_*.sh" -delete
```

#### 3. tmux 会话问题
```bash
# 列出所有 tmux 会话
tmux list-sessions

# 杀死指定会话
tmux kill-session -t <会话名>

# 杀死所有会话
tmux kill-server
```

#### 4. Docker 容器问题
```bash
# 停止所有容器
docker stop $(docker ps -q)

# 删除所有容器
docker rm $(docker ps -aq)

# 重启 Docker 服务
sudo systemctl restart docker
```

## 💡 最佳实践

1. **启动前检查**: 确保 `~/ex-bot/docker-compose.override.yml` 配置正确
2. **监控启动**: 使用 `tmux attach` 监控机器人启动状态
3. **及时停止**: 发现问题时及时使用 `stop-pending.sh` 停止后续启动
4. **定期清理**: 定期清理临时文件和停止的容器
5. **日志记录**: 保存重要的启动和停止操作日志

## 🔄 完整工作流程

```bash
# 1. 启动机器人
./start-bot.sh

# 2. 监控启动状态
tmux attach

# 3. 如果发现问题，停止后续启动
./stop-pending.sh --all

# 4. 修复问题后重新启动
./start-bot.sh
```

这个任务管理系统让您能够灵活地启动和停止 HummingBot 机器人，确保系统的稳定运行！

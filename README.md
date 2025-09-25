# HummingBot 配置生成器

一个用于管理多个 HummingBot 服务器配置的完整工具集。

## 🚀 功能特性

- **多服务器支持**: 为不同的服务器创建独立的配置文件夹
- **自动化配置**: 从 CSV 文件自动生成 HummingBot 配置文件
- **Docker 集成**: 支持 Docker Compose 管理多个机器人容器
- **tmux 管理**: 使用 tmux 管理多个机器人会话
- **延迟启动**: 支持机器人分批启动（默认3分钟间隔），避免资源冲突
- **智能管理**: 提供全面的机器人管理工具，支持启动、停止、状态查看和命令发送

## 📁 项目结构

```
hummingbot-prepare/
├── start-bot.sh                  # 机器人启动脚本（延迟启动）
├── stop-pending.sh               # 延迟任务清理脚本
├── bot-cmd.sh                    # 机器人命令执行脚本
├── bot-manager.sh                # 机器人管理工具
├── setup-ex-bot.sh               # 服务器环境搭建脚本
├── deploy.sh                     # 配置部署脚本
├── prepare.py                    # 配置生成脚本
├── templates/                    # 模板文件夹
├── ads_31/                       # 服务器1配置
│   ├── bots.csv
│   ├── strategy.csv
│   └── strategies-v1.csv
└── ads_32/                       # 服务器2配置
    ├── bots.csv
    ├── strategy.csv
    └── strategies-v1.csv
```

## 🛠️ 安装和使用

### 1. 克隆仓库

```bash
git clone <repository-url>
cd hummingbot-prepare
```

### 2. 设置权限

```bash
chmod +x start-bot.sh
chmod +x stop-pending.sh
chmod +x bot-cmd.sh
chmod +x bot-manager.sh
chmod +x setup-ex-bot.sh
chmod +x deploy.sh
```

### 3. 创建配置文件夹

为每个服务器创建配置文件夹，例如：

```bash
mkdir ads_31
mkdir ads_32
```

### 4. 准备配置文件

在每个配置文件夹中放置以下文件：

- `bots.csv` - 机器人基本信息
- `strategy.csv` - v2 策略配置
- `strategies-v1.csv` - v1 策略配置（可选）

### 5. 准备 Python 环境

#### 方法一：使用 Conda 环境（推荐）

```bash
# 激活 HummingBot conda 环境
conda activate hummingbot

# 安装额外依赖
pip install -r requirements.txt
```

#### 方法二：手动安装依赖

```bash
# 安装 Python 依赖包
pip install PyYAML eth-keyfile eth-account pandas cryptography

# 或者使用 requirements.txt
pip install -r requirements.txt
```

### 6. 运行配置生成

```bash
# 生成 ads_31 的配置
python prepare.py ads_31

# 生成 ads_32 的配置
python prepare.py ads_32
```

**注意**: 确保在运行 `prepare.py` 之前已经激活了正确的 Python 环境并安装了所有依赖包。

### 7. 服务器环境搭建

使用 `setup-ex-bot.sh` 脚本快速搭建服务器环境：

```bash
# 搭建服务器环境（需要服务器IP和用户名）
./setup-ex-bot.sh 192.168.1.31 ubuntu
```

该脚本会自动：
- 复制SSH密钥到服务器
- 拉取ex-bot代码
- 安装Docker和at服务
- 配置用户权限

### 8. 配置 SSH 连接

在 `~/.ssh/config` 文件中配置服务器连接信息：

```bash
# 编辑 SSH 配置
nano ~/.ssh/config

# 添加服务器配置（主机名必须与配置文件夹名相同）
Host ads_31
    HostName 192.168.1.31
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_ed25519

Host ads_32
    HostName 192.168.1.32
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

### 9. 部署配置

```bash
# 部署 ads_31 配置（SSH配置中的主机名必须与配置文件夹名相同）
./deploy.sh ads_31
```

部署脚本会自动：
- 检查本地配置文件夹和必要文件
- 测试SSH连接
- 上传 `conf/` 目录到 `~/ex-bot/conf/`
- 上传 `docker-compose.override.yml` 到 `~/ex-bot/`
- 上传 `start-bot.sh`、`stop-pending.sh`、`bot-cmd.sh` 和 `bot-manager.sh` 到 `~/`

## 🎯 使用方法

### 机器人启动脚本

在服务器上使用 `start-bot.sh` 启动机器人：

```bash
# 在服务器上执行（需要先部署配置）
ssh ads_31
cd ~
./start-bot.sh
```

该脚本会：
- 读取 `~/ex-bot/docker-compose.override.yml` 中的服务列表
- 每隔3分钟启动一个机器人（避免资源冲突）
- 使用tmux管理机器人会话
- 支持延迟启动调度

### 延迟任务管理

使用 `stop-pending.sh` 管理延迟启动任务：

```bash
# 在服务器上执行
ssh ads_31
cd ~

# 列出所有待执行的启动任务
./stop-pending.sh --list

# 停止指定机器人的启动任务
./stop-pending.sh --bot bot2

# 停止所有待执行的启动任务
./stop-pending.sh --all
```

### 机器人管理工具

使用 `bot-manager.sh` 进行全面的机器人管理：

```bash
# 在服务器上执行
ssh ads_31
cd ~

# 启动指定机器人
./bot-manager.sh start bot1

# 停止指定机器人
./bot-manager.sh stop bot1

# 启动所有未运行的机器人
./bot-manager.sh start-all

# 停止所有运行的机器人
./bot-manager.sh stop-all

# 重启指定机器人
./bot-manager.sh restart bot1

# 重启所有机器人
./bot-manager.sh restart-all

# 查看所有机器人状态
./bot-manager.sh status

# 查看指定机器人状态
./bot-manager.sh status bot1

# 向所有运行中的机器人发送命令
./bot-manager.sh cmd stop

# 向指定机器人发送命令
./bot-manager.sh cmd bot1 restart

# 列出所有机器人
./bot-manager.sh list

# 显示帮助信息
./bot-manager.sh help
```

### 机器人命令执行

使用 `bot-cmd.sh` 向机器人发送命令：

```bash
# 在服务器上执行
ssh ads_31
cd ~

# 停止所有机器人
./bot-cmd.sh stop

# 重启所有机器人
./bot-cmd.sh restart

# 查看所有机器人日志
./bot-cmd.sh logs

# 显示帮助信息
./bot-cmd.sh --help
```


## 📋 配置文件格式

### bots.csv

```csv
name,config_file_name,script_config,proxy,connector,api_key,secret_key,password
bot1,v2_with_controllers.py,conf_v2_ads_1_apt.yml,,backpack_perpetual,your_api_key,your_secret_key,your_password
bot2,conf_v1_ads_23_doge.yml,,,backpack_perpetual,your_api_key,your_secret_key,your_password
```

### strategy.csv

```csv
version,market,amount,buy_spreads,sell_spreads,buy_amounts_pct,sell_amounts_pct,executor_refresh_time,cooldown_time,stop_loss,take_profit,activation_price,trailing_delta,candles_connector,candles_trading_pair,interval,macd_fast,macd_slow,macd_signal,natr_length,position_rebalance_threshold_pct
ads_1,APT-USDC,500,"""1.8,2.5,3.4""","""1.8,2.5,3.4""","""0.13,0.27,0.6""","""0.13,0.27,0.6""",600,600,0.004,0.004,0.0032,0.0003,binance_perpetual,APT-USDT,3m,21,42,9,14,0.01
```

**必需列**: `version`, `market` (格式: `TOKEN-USDC`, 如 `APT-USDC`)
**可选列**: `amount`, `buy_spreads`, `sell_spreads`, `buy_amounts_pct`, `sell_amounts_pct`, `executor_refresh_time`, `cooldown_time`, `stop_loss`, `take_profit`, `activation_price`, `trailing_delta`, `candles_connector`, `candles_trading_pair`, `interval`, `macd_fast`, `macd_slow`, `macd_signal`, `natr_length`, `position_rebalance_threshold_pct`

### strategies-v1.csv

```csv
version,market,order_amount,leverage,bid_spread,ask_spread,long_profit_taking_spread,short_profit_taking_spread,stop_loss_spread,time_between_stop_loss_orders,order_levels,order_level_spread,order_levels_amount
ads_20,APT-USDC,60,10,0.08,0.08,0.2,0.2,0.4,15,3,0.001,-10
ads_23,DOGE-USDC,100,10,0.08,0.08,0.2,0.3,0.2,15,1,,
```

**必需列**: `version`, `market` (格式: `TOKEN-USDC`, 如 `APT-USDC`)
**可选列**: `order_amount`, `leverage`, `bid_spread`, `ask_spread`, `long_profit_taking_spread`, `short_profit_taking_spread`, `stop_loss_spread`, `time_between_stop_loss_orders`, `order_levels`, `order_level_spread`, `order_levels_amount`

## 🔄 完整工作流程

### 1. 环境准备
```bash
# 1. 准备 Python 环境
conda activate hummingbot  # 或手动安装依赖
pip install -r requirements.txt

# 2. 搭建服务器环境
./setup-ex-bot.sh 192.168.1.31 ubuntu

# 3. 配置SSH连接
# 编辑 ~/.ssh/config 文件
```

### 2. 配置生成和部署
```bash
# 4. 生成配置文件
python prepare.py ads_31

# 5. 部署到服务器
./deploy.sh ads_31
```

### 3. 机器人管理
```bash
# 6. 连接到服务器
ssh ads_31

# 7. 启动机器人（延迟启动）
./start-bot.sh

# 8. 管理延迟任务（如需要）
./stop-pending.sh --list
./stop-pending.sh --all  # 停止所有延迟任务
```

## 🔧 核心脚本功能

#### start-bot.sh
- 读取docker-compose.override.yml中的服务列表
- 实现延迟启动机制（3分钟间隔）
- 使用tmux管理机器人会话
- 支持at命令调度延迟任务

#### stop-pending.sh
- 管理延迟启动任务
- 支持列出、停止指定机器人或所有任务
- 清理临时脚本文件
- 与at命令集成

#### deploy.sh
- 自动检查本地配置完整性
- 测试SSH连接
- 使用rsync和scp上传文件
- 支持多文件类型部署

#### setup-ex-bot.sh
- 自动化服务器环境搭建
- SSH密钥配置
- Docker和at服务安装
- 用户权限配置

#### bot-manager.sh
- 全面的机器人管理工具
- 支持启动/停止指定机器人或所有机器人
- 实时状态查看和监控
- 集成命令发送功能
- 智能机器人发现和验证

#### bot-cmd.sh
- 向机器人发送命令的专用工具
- 支持向所有或指定机器人发送命令
- 与tmux会话集成
- 简化的命令执行接口

## 🐳 Docker 支持

项目支持 Docker Compose 管理多个机器人容器：

```yaml
services:
  bot1:
    container_name: bot1
    # ... 配置
  bot2:
    container_name: bot2
    # ... 配置
```

## 📝 开发指南

### 开发环境准备

```bash
# 激活 HummingBot conda 环境
conda activate hummingbot

# 安装开发依赖
pip install -r requirements.txt

# 可选：安装开发工具
pip install pytest black  # 测试和代码格式化
```

### 添加新脚本

1. 在项目根目录下创建新的 `.sh` 文件
2. 定义相关函数和功能
3. 添加适当的错误处理和帮助信息
4. 更新文档和使用说明

### 修改现有脚本

1. 在对应的脚本文件中添加新功能
2. 保持向后兼容性
3. 更新帮助信息和文档
4. 测试新功能的正确性

### Python 脚本开发

1. 确保在正确的 Python 环境中开发
2. 使用 `requirements.txt` 管理依赖
3. 遵循 HummingBot 的编码规范
4. 测试加密功能的兼容性

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 🔗 相关链接

- [HummingBot 官方文档](https://docs.hummingbot.org/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [tmux 使用指南](https://tmuxcheatsheet.com/)

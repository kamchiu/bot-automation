# HummingBot 配置生成器

一个用于管理多个 HummingBot 服务器配置的模块化工具集。

## 🚀 功能特性

- **多服务器支持**: 为不同的服务器创建独立的配置文件夹
- **模块化设计**: 使用 bash 模块化架构，代码可复用、易维护
- **自动化配置**: 从 CSV 文件自动生成 HummingBot 配置文件
- **Docker 集成**: 支持 Docker Compose 管理多个机器人容器
- **tmux 管理**: 使用 tmux 管理多个机器人会话
- **延迟启动**: 支持机器人分批启动，避免资源冲突

## 📁 项目结构

```
hummingbot-prepare/
├── lib/                          # 模块库
│   ├── common.sh                 # 通用函数库
│   ├── docker.sh                 # Docker 相关函数
│   └── config.sh                 # 配置管理函数
├── start-bot-modular.sh          # 模块化启动脚本
├── bot-manager.sh                # 通用机器人管理工具
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
chmod +x lib/*.sh
chmod +x start-bot-modular.sh
chmod +x bot-manager.sh
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

### 5. 运行配置生成

```bash
# 生成 ads_31 的配置
python prepare.py ads_31

# 生成 ads_32 的配置
python prepare.py ads_32
```

### 6. 配置 SSH 连接

在 `~/.ssh/config` 文件中配置服务器连接信息：

```bash
# 编辑 SSH 配置
nano ~/.ssh/config

# 添加服务器配置（主机名必须与配置文件夹名相同）
Host ads_31
    HostName 192.168.1.31
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host ads_32
    HostName 192.168.1.32
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa
```

### 7. 部署配置

```bash
# 部署 ads_31 配置（SSH配置中的主机名必须与配置文件夹名相同）
./deploy.sh ads_31
```

## 🎯 使用方法

### 模块化启动脚本

```bash
# 启动 ads_31 配置的机器人
./start-bot-modular.sh ads_31

# 启动 ads_32 配置的机器人
./start-bot-modular.sh ads_32
```

### 通用机器人管理工具

```bash
# 查看帮助
./bot-manager.sh help

# 列出所有配置文件夹
./bot-manager.sh list

# 启动机器人
./bot-manager.sh start ads_31

# 停止机器人
./bot-manager.sh stop ads_31

# 重启机器人
./bot-manager.sh restart ads_31

# 查看机器人状态
./bot-manager.sh status ads_31
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
market,version,amount,buy_spreads
BTC,0.1,2000,"1.6,2.4,3.3"
APT,0.2,1500,"2.0,3.0,4.0"
```

### strategies-v1.csv

```csv
version,market,order_amount,leverage,bid_spread,ask_spread
ads_20,APT,60,10,0.08,0.08
ads_21,DOGE,100,5,0.05,0.05
```

## 🔧 模块化架构

### lib/common.sh
- 彩色输出函数
- 文件/目录检查
- CSV 数据读取
- tmux 会话管理

### lib/docker.sh
- 容器启动/停止/重启
- 容器状态检查
- Docker Compose 集成

### lib/config.sh
- 配置文件夹验证
- 必要文件检查
- 脚本执行管理

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

### 添加新模块

1. 在 `lib/` 目录下创建新的 `.sh` 文件
2. 定义相关函数
3. 在主脚本中使用 `source` 加载

### 添加新功能

1. 在对应模块中添加函数
2. 在主脚本中调用函数
3. 更新文档

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 🔗 相关链接

- [HummingBot 官方文档](https://docs.hummingbot.org/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [tmux 使用指南](https://tmuxcheatsheet.com/)

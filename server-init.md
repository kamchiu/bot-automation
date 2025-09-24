# 服务器快速搭建ex-bot环境

### 1 本机ssh-key复制到服务器

```bash
# 将本地公钥发送到服务器，建立免密连接
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@server_ip

# 公私钥
scp ~/.ssh/id_ed25519.pub ubuntu@server_ip:/home/ubuntu/.ssh
scp ~/.ssh/id_ed25519 ubuntu@server_ip:/home/ubuntu/.ssh
```

### 上传prepare
```bash
scp -r ~/prepare ubuntu@server_ip:/home/ubuntu
```

### 2 连接服务器
```bash
# 连接到服务器
ssh username@server_ip
```

### 进入服务器后

```bash
# 拉取ex-bot代码
git clone -b bpx git@github.com:way2freedom/ex-bot.git

# 安装docker
curl -fsSL https://get.docker.com -o get-docker.sh
# 执行安装脚本
sh get-docker.sh

# 把当前用户加入 docker 用户组
sudo usermod -aG docker $USER
# 刷新组权限
newgrp docker

sudo apt update
sudo apt install at
# 启动服务
sudo systemctl start atd

# 设置开机自启
sudo systemctl enable atd

# 检查服务状态
sudo systemctl status atd

```

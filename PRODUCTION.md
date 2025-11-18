# One Hub 生产环境部署完整指南

## 📦 部署文件清单

本次生成的生产环境部署文件：

```
one-hub/
├── Makefile.prod                  # 生产环境 Make 管理工具 ⭐
├── docker-compose.prod.yml        # 生产环境 Docker Compose 配置 ⭐
├── .env.production.example        # 环境变量配置模板
├── DEPLOY.md                      # 详细部署文档
├── PRODUCTION.md                  # 本文件
├── scripts/
│   ├── backup.sh                 # 数据库备份脚本
│   ├── restore.sh                # 数据库恢复脚本
│   └── quick-start.sh            # 一键部署脚本 ⭐
└── README.md                      # 项目说明
```

## 🚀 三种部署方式

### 方式一：一键部署（推荐新手）

最简单的部署方式，适合快速上手：

```bash
# 运行一键部署脚本
bash scripts/quick-start.sh
```

脚本会自动：
- ✅ 检查并安装 Docker 环境
- ✅ 生成安全密钥
- ✅ 创建配置文件
- ✅ 启动所有服务
- ✅ 进行健康检查

### 方式二：使用 Make 部署（推荐运维）

适合需要精细控制的场景：

```bash
# 1. 初始化环境
make -f Makefile.prod init

# 2. 编辑配置（可选）
vim .env.production

# 3. 启动服务
make -f Makefile.prod start

# 4. 查看状态
make -f Makefile.prod status
```

### 方式三：手动部署（推荐高级用户）

完全手动控制每个步骤：

```bash
# 1. 创建目录
mkdir -p data/{mysql,redis,app} logs backups

# 2. 复制配置模板
cp .env.production.example .env.production

# 3. 生成密钥
SESSION_SECRET=$(openssl rand -base64 32)
USER_TOKEN_SECRET=$(openssl rand -base64 32)
# ... 手动编辑 .env.production

# 4. 启动服务
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d
```

## 📋 Make 命令速查表

### 基础操作

| 命令 | 说明 |
|------|------|
| `make -f Makefile.prod help` | 显示所有可用命令 |
| `make -f Makefile.prod init` | 初始化生产环境 |
| `make -f Makefile.prod start` | 启动所有服务 |
| `make -f Makefile.prod stop` | 停止所有服务 |
| `make -f Makefile.prod restart` | 重启所有服务 |
| `make -f Makefile.prod status` | 查看服务状态 |

### 日志查看

| 命令 | 说明 |
|------|------|
| `make -f Makefile.prod logs` | 查看所有日志 |
| `make -f Makefile.prod logs-app` | 查看应用日志 |
| `make -f Makefile.prod logs-mysql` | 查看 MySQL 日志 |
| `make -f Makefile.prod logs-redis` | 查看 Redis 日志 |

### 数据库管理

| 命令 | 说明 |
|------|------|
| `make -f Makefile.prod db-shell` | 进入 MySQL 命令行 |
| `make -f Makefile.prod db-backup` | 备份数据库 |
| `make -f Makefile.prod db-restore BACKUP=xxx.sql.gz` | 恢复数据库 |
| `make -f Makefile.prod redis-shell` | 进入 Redis 命令行 |

### 更新维护

| 命令 | 说明 |
|------|------|
| `make -f Makefile.prod update` | 更新到最新版本 |
| `make -f Makefile.prod health` | 健康检查 |
| `make -f Makefile.prod clean` | 清理 Docker 资源 |

## ⚙️ 配置说明

### 必要配置（必须修改）

```bash
# .env.production

# 安全密钥（自动生成，无需修改）
SESSION_SECRET=<自动生成>
USER_TOKEN_SECRET=<自动生成>  # ⚠️ 一旦设置不可修改！

# 数据库密码（自动生成，无需修改）
MYSQL_PASSWORD=<自动生成>
```

### 推荐配置（根据实际情况调整）

```bash
# 服务端口
PORT=3000

# 时区
TZ=Asia/Shanghai

# 性能配置
MEMORY_CACHE_ENABLED=true       # 启用内存缓存
BATCH_UPDATE_ENABLED=true       # 启用批量更新

# 限流配置
GLOBAL_API_RATE_LIMIT=180       # API 限流
GLOBAL_WEB_RATE_LIMIT=100       # Web 限流

# 渠道测试频率（分钟）
CHANNEL_TEST_FREQUENCY=60
```

### 高级配置（可选）

```bash
# 禁用 Token 编码器（减少内存）
DISABLE_TOKEN_ENCODERS=false

# Token 缓存目录（离线环境）
TIKTOKEN_CACHE_DIR=

# 可信头部（Cloudflare）
TRUSTED_HEADER=CF-Connecting-IP

# 价格更新模式
AUTO_PRICE_UPDATES_MODE=system
```

## 🔒 安全加固

### 1. 防火墙配置

```bash
# Ubuntu/Debian
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable

# CentOS/RHEL
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

### 2. Nginx 反向代理

```bash
# 安装 Nginx
sudo apt install nginx  # Ubuntu/Debian
sudo yum install nginx  # CentOS/RHEL

# 配置文件位置
sudo vim /etc/nginx/sites-available/one-hub
```

配置内容：

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/one-hub /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 3. SSL 证书（Let's Encrypt）

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo certbot renew --dry-run
```

## 📊 监控与维护

### 定时备份

```bash
# 编辑 crontab
crontab -e

# 添加定时任务（每天凌晨2点备份）
0 2 * * * cd /path/to/one-hub && make -f Makefile.prod db-backup

# 添加定时清理（每周日清理7天前的备份）
0 3 * * 0 find /path/to/one-hub/backups -name "*.sql.gz" -mtime +7 -delete
```

### 日志轮转

Docker 已自动配置日志轮转（见 docker-compose.prod.yml）：

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 资源监控

```bash
# 查看容器资源使用
docker stats one-hub one-hub-mysql one-hub-redis

# 查看磁盘使用
df -h
du -sh data/*

# 查看日志大小
du -sh logs/*
```

## 🔧 常见问题

### Q1: 服务启动失败

```bash
# 查看日志
make -f Makefile.prod logs

# 检查端口占用
sudo lsof -i :3000

# 检查 Docker 状态
docker ps -a
```

### Q2: 数据库连接失败

```bash
# 检查 MySQL 容器
docker ps | grep mysql

# 进入容器检查
docker exec -it one-hub-mysql mysql -u oneapi -p

# 查看 MySQL 日志
make -f Makefile.prod logs-mysql
```

### Q3: 内存占用过高

编辑 `.env.production`：

```bash
# 禁用 Token 编码器
DISABLE_TOKEN_ENCODERS=true

# 减少连接池
SQL_MAX_OPEN_CONNS=500
SQL_MAX_IDLE_CONNS=50
```

### Q4: 如何更新版本

```bash
# 方法一：使用 Make（推荐，会自动备份）
make -f Makefile.prod update

# 方法二：手动更新
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

### Q5: 如何迁移数据

```bash
# 源服务器：备份数据
make -f Makefile.prod db-backup
tar -czf one-hub-data.tar.gz data/ backups/

# 目标服务器：恢复数据
tar -xzf one-hub-data.tar.gz
make -f Makefile.prod start
make -f Makefile.prod db-restore BACKUP=backups/one-api-xxx.sql.gz
```

## 📈 性能调优

### 高并发场景

```bash
# .env.production

# 增加数据库连接池
SQL_MAX_OPEN_CONNS=2000
SQL_MAX_IDLE_CONNS=200

# 启用所有优化
MEMORY_CACHE_ENABLED=true
BATCH_UPDATE_ENABLED=true
REDIS_CONN_STRING=redis://redis:6379
```

### 低延迟场景

```bash
# 缩短同步周期
SYNC_FREQUENCY=60
BATCH_UPDATE_INTERVAL=1

# 增加超时时间
RELAY_TIMEOUT=180
```

## 📞 获取支持

- **详细文档**: 查看 `DEPLOY.md`
- **项目文档**: https://one-hub-doc.vercel.app/
- **GitHub**: https://github.com/MartialBE/one-hub
- **问题反馈**: https://github.com/MartialBE/one-hub/issues

## ✅ 部署检查清单

部署前：
- [ ] 服务器满足最低要求（2核4G内存）
- [ ] Docker 和 Docker Compose 已安装
- [ ] 防火墙已配置
- [ ] 域名已解析（如使用域名）

部署中：
- [ ] 已生成安全密钥
- [ ] 已检查配置文件
- [ ] 服务成功启动
- [ ] 健康检查通过

部署后：
- [ ] 已修改默认密码
- [ ] 已配置 HTTPS（生产环境）
- [ ] 已设置定时备份
- [ ] 已测试基本功能

---

**祝部署顺利！🎉**

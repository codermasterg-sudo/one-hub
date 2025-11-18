# One Hub 生产环境部署指南

## 📋 目录结构

```
one-hub/
├── Makefile.prod              # 生产环境 Makefile
├── docker-compose.prod.yml    # 生产环境 Docker Compose 配置
├── .env.production           # 生产环境变量（自动生成）
├── .env.production.example   # 环境变量模板
├── scripts/
│   ├── backup.sh            # 数据库备份脚本
│   ├── restore.sh           # 数据库恢复脚本
│   └── generate-env.sh      # 环境变量生成脚本
├── data/                    # 数据目录
│   ├── mysql/              # MySQL 数据
│   ├── redis/              # Redis 数据
│   └── app/                # 应用数据
├── logs/                    # 日志目录
└── backups/                 # 备份目录
```

## 🚀 快速开始

### 1. 初始化部署

```bash
# 克隆或进入项目目录
cd one-hub

# 初始化生产环境（会自动生成密钥和配置）
make -f Makefile.prod init
```

**初始化做了什么？**
- 检查 Docker 和 Docker Compose 环境
- 创建必要的目录结构
- 自动生成安全密钥
- 创建配置文件 `.env.production`

### 2. 检查配置

```bash
# 编辑配置文件
vim .env.production

# 或使用你喜欢的编辑器
nano .env.production
```

**必须检查的配置项：**
- `SESSION_SECRET` - 会话密钥（已自动生成）
- `USER_TOKEN_SECRET` - 用户令牌密钥（已自动生成，**不可修改**）
- `MYSQL_PASSWORD` - MySQL 密码（已自动生成）
- 其他配置可保持默认或根据需要调整

### 3. 启动服务

```bash
# 启动所有服务
make -f Makefile.prod start

# 查看服务状态
make -f Makefile.prod status

# 查看日志
make -f Makefile.prod logs
```

### 4. 访问应用

- **管理后台**: http://your-server-ip:3000
- **默认账号**: root
- **默认密码**: 123456

**⚠️ 首次登录后请立即修改密码！**

## 📚 常用命令

### 服务管理

```bash
# 启动服务
make -f Makefile.prod start

# 停止服务
make -f Makefile.prod stop

# 重启所有服务
make -f Makefile.prod restart

# 仅重启应用（不重启数据库）
make -f Makefile.prod restart-app

# 查看服务状态
make -f Makefile.prod status

# 健康检查
make -f Makefile.prod health
```

### 日志查看

```bash
# 查看所有日志
make -f Makefile.prod logs

# 仅查看应用日志
make -f Makefile.prod logs-app

# 查看 MySQL 日志
make -f Makefile.prod logs-mysql

# 查看 Redis 日志
make -f Makefile.prod logs-redis
```

### 数据库管理

```bash
# 进入 MySQL 命令行
make -f Makefile.prod db-shell

# 备份数据库
make -f Makefile.prod db-backup

# 恢复数据库
make -f Makefile.prod db-restore BACKUP=backups/one-api-20240101_120000.sql.gz

# 进入 Redis 命令行
make -f Makefile.prod redis-shell
```

### 更新维护

```bash
# 更新到最新版本（会自动备份）
make -f Makefile.prod update

# 仅拉取最新镜像（不重启）
make -f Makefile.prod pull

# 清理未使用的 Docker 资源
make -f Makefile.prod clean
```

## 🔒 安全建议

### 1. 修改默认端口

编辑 `.env.production`:
```bash
PORT=8080  # 修改为其他端口
```

然后更新 `docker-compose.prod.yml` 中的端口映射:
```yaml
ports:
  - "8080:3000"  # 外部端口:内部端口
```

### 2. 配置反向代理（推荐）

#### Nginx 配置示例

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
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }
}
```

配置后，在 `.env.production` 中设置:
```bash
TRUSTED_HEADER=X-Real-IP
```

### 3. 配置防火墙

```bash
# 仅开放必要端口
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
ufw enable

# 如果不使用反向代理，开放应用端口
ufw allow 3000/tcp
```

### 4. 定期备份

设置 cron 定时任务:
```bash
# 编辑 crontab
crontab -e

# 添加每天凌晨 2 点备份
0 2 * * * cd /path/to/one-hub && make -f Makefile.prod db-backup >> /path/to/one-hub/logs/backup.log 2>&1
```

## 📊 监控和维护

### 健康检查

```bash
# 检查服务健康状态
make -f Makefile.prod health

# 查看资源使用
docker stats one-hub one-hub-mysql one-hub-redis
```

### 日志管理

```bash
# 清理旧日志（保留最近7天）
make -f Makefile.prod logs-clean

# 查看日志文件大小
du -sh logs/*
```

### 数据库优化

```bash
# 进入 MySQL
make -f Makefile.prod db-shell

# 优化所有表
OPTIMIZE TABLE channels, tokens, logs, users;

# 查看表大小
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.TABLES 
WHERE table_schema = 'one-api'
ORDER BY (data_length + index_length) DESC;
```

## 🔧 故障排查

### 服务无法启动

```bash
# 查看服务状态
make -f Makefile.prod status

# 查看详细日志
make -f Makefile.prod logs

# 检查容器健康状态
docker-compose -f docker-compose.prod.yml ps
```

### 数据库连接失败

```bash
# 检查 MySQL 是否运行
docker ps | grep mysql

# 检查 MySQL 日志
make -f Makefile.prod logs-mysql

# 测试数据库连接
docker exec -it one-hub-mysql mysql -u oneapi -p
```

### Redis 连接失败

```bash
# 检查 Redis 是否运行
docker ps | grep redis

# 测试 Redis 连接
docker exec -it one-hub-redis redis-cli ping
```

### 内存占用过高

编辑 `.env.production`:
```bash
# 禁用 Token 编码器（减少约 40MB 内存）
DISABLE_TOKEN_ENCODERS=true

# 减少数据库连接池
SQL_MAX_OPEN_CONNS=500
SQL_MAX_IDLE_CONNS=50
```

### 磁盘空间不足

```bash
# 清理 Docker 资源
make -f Makefile.prod clean
docker system df

# 清理旧备份
find backups/ -name "*.sql.gz" -mtime +7 -delete

# 清理旧日志
make -f Makefile.prod logs-clean
```

## 🔄 升级指南

### 小版本升级

```bash
# 1. 备份数据
make -f Makefile.prod db-backup

# 2. 更新镜像并重启
make -f Makefile.prod update

# 3. 验证服务
make -f Makefile.prod health
```

### 大版本升级

```bash
# 1. 备份所有数据
make -f Makefile.prod db-backup
tar -czf data-backup-$(date +%Y%m%d).tar.gz data/

# 2. 查看发行说明
# 访问: https://github.com/MartialBE/one-hub/releases

# 3. 停止服务
make -f Makefile.prod stop

# 4. 更新配置文件（如果需要）
# 比较 .env.production.example 和 .env.production

# 5. 更新并启动
make -f Makefile.prod update

# 6. 验证
make -f Makefile.prod health
make -f Makefile.prod logs-app
```

## 📝 最佳实践

### 1. 定期备份

- ✅ 每天自动备份数据库
- ✅ 保留至少 7 天的备份
- ✅ 定期测试恢复流程

### 2. 监控告警

- ✅ 配置服务健康检查
- ✅ 监控磁盘空间使用
- ✅ 监控数据库性能

### 3. 安全加固

- ✅ 使用强密码
- ✅ 启用防火墙
- ✅ 配置 HTTPS
- ✅ 定期更新系统

### 4. 性能优化

- ✅ 启用 Redis 缓存
- ✅ 启用批量更新
- ✅ 合理配置连接池

## 📞 获取帮助

- **项目文档**: https://one-hub-doc.vercel.app/
- **GitHub Issues**: https://github.com/MartialBE/one-hub/issues
- **示例网站**: https://one-hub.xiao5.info/

## 📄 许可证

本项目基于 MIT 许可证开源。

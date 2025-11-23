# Makefile 使用指南

本 Makefile 提供了完整的 One-Hub 编译、部署、运维工具集。

## 🚀 快速开始

### 首次部署

```bash
# 完整安装（初始化 + 启动）
make install

# 或分步执行
make init    # 初始化环境
make up      # 启动服务
```

### 日常使用

```bash
# 查看所有可用命令
make help

# 查看服务状态
make ps

# 查看日志
make logs
make logs-clash
make logs-cliproxy
```

---

## 📋 命令分类

### 1. 编译相关

```bash
make build          # 编译完整项目（前端+后端）
make web            # 仅编译前端
make backend        # 仅编译后端
make clean          # 清理编译文件
```

### 2. Docker 部署

```bash
make init           # 初始化环境（首次部署）
make up             # 启动所有服务
make down           # 停止所有服务
make restart        # 重启所有服务
make ps             # 查看服务状态
make logs           # 查看所有日志
```

### 3. 服务管理

```bash
# 启动/停止/重启特定服务
make start-clash
make stop-cliproxy
make restart-onehub

# 查看特定服务日志
make logs-clash
make logs-cliproxy
make logs-onehub
```

### 4. Clash 代理管理

```bash
make clash-setup      # 配置 Clash（订阅模式）
make clash-update     # 更新订阅
make clash-test       # 测试代理连接
make clash-dashboard  # 打开 Clash Dashboard
make clash-proxies    # 查看代理节点
make clash-status     # 查看 Clash 状态
```

### 5. CLIProxy 管理

```bash
make cliproxy-login       # 登录单个 Claude 账号
make cliproxy-login-multi # 登录多个账号（3个）
make cliproxy-status      # 查看账号状态
make cliproxy-refresh     # 刷新令牌
make cliproxy-stats       # 查看负载统计
make cliproxy-test        # 测试 API
```

### 6. 备份恢复

```bash
make backup           # 完整备份（数据库+配置）
make backup-db        # 仅备份数据库
make backup-config    # 仅备份配置
make restore          # 恢复备份
make list-backups     # 列出所有备份
```

### 7. 监控维护

```bash
make health           # 健康检查
make update           # 更新 Docker 镜像
make prune            # 清理 Docker 缓存
make clean-data       # 清理所有数据（危险！）
```

### 8. 快捷操作

```bash
make open-onehub      # 打开 One-Hub 管理后台
make shell-clash      # 进入 Clash 容器
make shell-cliproxy   # 进入 CLIProxy 容器
make dev              # 开发模式（前台运行）
make test-full        # 完整测试流程
```

---

## 💡 使用示例

### 示例 1: 首次部署 One-Hub

```bash
# 1. 初始化环境
make init

# 2. 编辑 Clash 配置（添加订阅链接）
nano clash/config.yaml

# 3. 启动所有服务
make up

# 4. 登录 Claude 账号
make cliproxy-login-multi

# 5. 查看服务状态
make ps

# 6. 打开管理后台
make open-onehub
```

### 示例 2: 日常运维

```bash
# 查看服务状态
make ps

# 查看 Clash 日志（调试代理问题）
make logs-clash

# 更新 Clash 订阅
make clash-update

# 刷新 Claude 令牌
make cliproxy-refresh

# 查看负载统计
make cliproxy-stats

# 健康检查
make health
```

### 示例 3: 备份和恢复

```bash
# 每日备份（建议设置 crontab）
make backup

# 列出所有备份
make list-backups

# 恢复备份
make restore
```

### 示例 4: 更新服务

```bash
# 拉取最新镜像
make update

# 重启服务应用更新
make restart

# 验证更新
make health
```

---

## 🔧 高级用法

### 自定义变量

编辑 Makefile 开头的变量：

```makefile
NAME := one-api
DISTDIR := dist
DOCKER_COMPOSE := docker-compose
```

### 添加自定义命令

在 Makefile 末尾添加：

```makefile
my-command: ## 我的自定义命令
	@echo "执行自定义操作..."
	# 您的命令
```

### 批量操作

```bash
# 重启所有核心服务
make restart-clash restart-cliproxy restart-onehub

# 查看多个服务日志（需要多个终端）
make logs-clash &
make logs-cliproxy &
```

---

## 📊 定时任务

建议添加到 crontab：

```bash
# 编辑 crontab
crontab -e

# 添加以下任务
# 每天凌晨 2 点备份
0 2 * * * cd /path/to/one-hub && make backup >> /var/log/one-hub-backup.log 2>&1

# 每 6 小时刷新 CLIProxy 令牌
0 */6 * * * cd /path/to/one-hub && make cliproxy-refresh >> /var/log/cliproxy-refresh.log 2>&1

# 每天更新 Clash 订阅
0 0 * * * cd /path/to/one-hub && make clash-update >> /var/log/clash-update.log 2>&1
```

---

## ⚠️ 注意事项

### 危险命令

以下命令会删除数据，使用前请确认：

```bash
make clean-data    # 删除所有数据
make restore       # 恢复备份（会覆盖现有数据）
```

### 权限问题

某些操作可能需要 sudo：

```bash
# 如果遇到权限问题
sudo make up
sudo make clean-data
```

### 日志查看

实时日志使用 `Ctrl+C` 退出：

```bash
make logs          # Ctrl+C 退出
make logs-clash    # Ctrl+C 退出
```

---

## 🐛 故障排查

### 问题 1: make 命令不存在

```bash
# Ubuntu/Debian
sudo apt-get install make

# CentOS/RHEL
sudo yum install make

# macOS
xcode-select --install
```

### 问题 2: 权限被拒绝

```bash
# 添加当前用户到 docker 组
sudo usermod -aG docker $USER

# 重新登录或执行
newgrp docker
```

### 问题 3: 服务启动失败

```bash
# 查看详细日志
make logs-<service>

# 检查配置文件
cat clash/config.yaml
cat cliproxy/config.yaml

# 重新初始化
make down
make clean-data  # 警告：会删除数据
make init
make up
```

### 问题 4: 端口冲突

修改 `docker-compose.yml` 中的端口映射：

```yaml
ports:
  - "3001:3000"  # 改用 3001 端口
```

---

## 📚 相关文档

- [DOCKER_SETUP.md](./DOCKER_SETUP.md) - Docker 完整部署指南
- [CLIPROXY_INTEGRATION.md](./CLIPROXY_INTEGRATION.md) - CLIProxy 集成指南
- [clash/README.md](./clash/README.md) - Clash 配置说明
- [cliproxy/README.md](./cliproxy/README.md) - CLIProxy 配置说明

---

## 🤝 贡献

如果您有好的建议或发现问题，欢迎提交 Issue 或 Pull Request。

---

最后更新: 2025-11-23

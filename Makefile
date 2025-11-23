# One-Hub Makefile
# 完整的编译、部署、运维工具集

# ==================== 基础配置 ====================
NAME := one-api
DISTDIR := dist
WEBDIR := web
VERSION := $(shell git describe --tags 2>/dev/null || echo "dev")
GOBUILD := go build -ldflags "-s -w -X 'one-api/common/config.Version=$(VERSION)'"

# Docker 配置
DOCKER_COMPOSE := docker compose
SERVICES := one-hub redis mysql clash cliproxy

# 颜色定义
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: all help

# ==================== 默认目标 ====================
all: help

# ==================== 帮助信息 ====================
help: ## 显示此帮助信息
	@echo "$(BLUE)================================="
	@echo "   One-Hub 运维工具集"
	@echo "=================================$(NC)"
	@echo ""
	@echo "$(GREEN)编译相关:$(NC)"
	@echo "  make build          - 编译完整项目（前端+后端）"
	@echo "  make web            - 仅编译前端"
	@echo "  make backend        - 仅编译后端"
	@echo "  make clean          - 清理编译文件"
	@echo ""
	@echo "$(GREEN)Docker 部署:$(NC)"
	@echo "  make init           - 初始化环境（首次部署）"
	@echo "  make up             - 启动所有服务"
	@echo "  make down           - 停止所有服务"
	@echo "  make restart        - 重启所有服务"
	@echo "  make ps             - 查看服务状态"
	@echo "  make logs           - 查看所有日志"
	@echo "  make logs-<service> - 查看特定服务日志（如 make logs-clash）"
	@echo ""
	@echo "$(GREEN)服务管理:$(NC)"
	@echo "  make start-<service>  - 启动特定服务"
	@echo "  make stop-<service>   - 停止特定服务"
	@echo "  make restart-<service> - 重启特定服务"
	@echo ""
	@echo "$(GREEN)Clash 代理:$(NC)"
	@echo "  make clash-setup      - 配置 Clash（订阅模式）"
	@echo "  make clash-update     - 更新订阅"
	@echo "  make clash-test       - 测试代理连接"
	@echo "  make clash-dashboard  - 打开 Clash Dashboard"
	@echo ""
	@echo "$(GREEN)CLIProxy 管理:$(NC)"
	@echo "  make cliproxy-login    - 登录 Claude 账号"
	@echo "  make cliproxy-login-multi - 登录多个账号"
	@echo "  make cliproxy-status   - 查看账号状态"
	@echo "  make cliproxy-refresh  - 刷新令牌"
	@echo "  make cliproxy-stats    - 查看负载统计"
	@echo ""
	@echo "$(GREEN)备份恢复:$(NC)"
	@echo "  make backup         - 完整备份（数据库+配置）"
	@echo "  make backup-db      - 仅备份数据库"
	@echo "  make restore        - 恢复备份"
	@echo "  make list-backups   - 列出所有备份"
	@echo ""
	@echo "$(GREEN)监控维护:$(NC)"
	@echo "  make health         - 健康检查"
	@echo "  make update         - 更新镜像"
	@echo "  make clean-data     - 清理所有数据（危险！）"
	@echo "  make prune          - 清理 Docker 缓存"
	@echo ""
	@echo "$(GREEN)打包部署:$(NC)"
	@echo "  make package        - 打包生产环境部署文件"
	@echo "  make upload         - 打包并上传到远程服务器"
	@echo ""

# ==================== 编译相关 ====================
build: web backend ## 编译完整项目

web: $(WEBDIR)/build ## 编译前端

$(WEBDIR)/build:
	@echo "$(BLUE)>>> 编译前端...$(NC)"
	cd $(WEBDIR) && yarn install && VITE_APP_VERSION=$(VERSION) yarn run build
	@echo "$(GREEN)✓ 前端编译完成$(NC)"

backend: $(WEBDIR)/build ## 编译后端
	@echo "$(BLUE)>>> 编译后端...$(NC)"
	$(GOBUILD) -o $(DISTDIR)/$(NAME)
	@echo "$(GREEN)✓ 后端编译完成$(NC)"

clean: ## 清理编译文件
	@echo "$(YELLOW)>>> 清理编译文件...$(NC)"
	rm -rf $(DISTDIR) && rm -rf $(WEBDIR)/build
	@echo "$(GREEN)✓ 清理完成$(NC)"

# ==================== 初始化 ====================
init: ## 初始化环境（首次部署）
	@echo "$(BLUE)================================="
	@echo "   开始初始化 One-Hub 环境"
	@echo "=================================$(NC)"
	@$(MAKE) check-requirements
	@$(MAKE) create-dirs
	@$(MAKE) setup-clash
	@echo ""
	@echo "$(GREEN)✓ 初始化完成！$(NC)"
	@echo ""
	@echo "$(YELLOW)下一步：$(NC)"
	@echo "  1. 创建并编辑 .env 文件（参考 docs/快速部署指南.md）"
	@echo "  2. 编辑 clash/config-subscription.yaml 添加订阅链接"
	@echo "  3. 运行: make up（启动服务）"
	@echo "  4. 运行: make cliproxy-login（登录 Claude 账号）"
	@echo ""

check-requirements: ## 检查依赖
	@echo "$(BLUE)>>> 检查环境依赖...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)✗ Docker 未安装$(NC)"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "$(RED)✗ Docker Compose 未安装$(NC)"; exit 1; }
	@echo "$(GREEN)✓ 环境检查通过$(NC)"

create-dirs: ## 创建必要的目录
	@echo "$(BLUE)>>> 创建目录结构...$(NC)"
	@mkdir -p data/{mysql,redis}
	@mkdir -p clash/subscriptions
	@mkdir -p cliproxy/auth
	@mkdir -p backups
	@echo "$(GREEN)✓ 目录创建完成$(NC)"

setup-clash: ## 创建 Clash 配置链接
	@echo "$(BLUE)>>> 设置 Clash 配置...$(NC)"
	@if [ ! -L clash/config.yaml ]; then \
		cd clash && ln -sf config-subscription.yaml config.yaml && \
		echo "$(GREEN)✓ Clash 配置链接已创建 (config.yaml -> config-subscription.yaml)$(NC)"; \
	else \
		echo "$(GREEN)✓ Clash 配置链接已存在$(NC)"; \
	fi

# ==================== Docker 部署 ====================
up: ## 启动所有服务
	@echo "$(BLUE)>>> 启动所有服务...$(NC)"
	$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)✓ 服务启动完成$(NC)"
	@$(MAKE) ps

down: ## 停止所有服务
	@echo "$(YELLOW)>>> 停止所有服务...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ 服务已停止$(NC)"

restart: ## 重启所有服务
	@echo "$(BLUE)>>> 重启所有服务...$(NC)"
	$(DOCKER_COMPOSE) restart
	@echo "$(GREEN)✓ 服务重启完成$(NC)"

ps: ## 查看服务状态
	@echo "$(BLUE)>>> 服务状态:$(NC)"
	@$(DOCKER_COMPOSE) ps

logs: ## 查看所有日志
	$(DOCKER_COMPOSE) logs -f --tail=100

# 特定服务日志
logs-onehub:
	$(DOCKER_COMPOSE) logs -f --tail=100 one-hub

logs-clash:
	$(DOCKER_COMPOSE) logs -f --tail=100 clash

logs-cliproxy:
	$(DOCKER_COMPOSE) logs -f --tail=100 cliproxy

logs-redis:
	$(DOCKER_COMPOSE) logs -f --tail=100 redis

logs-mysql:
	$(DOCKER_COMPOSE) logs -f --tail=100 mysql

# ==================== 服务管理 ====================
start-%: ## 启动特定服务
	@echo "$(BLUE)>>> 启动 $* 服务...$(NC)"
	$(DOCKER_COMPOSE) start $*
	@echo "$(GREEN)✓ $* 已启动$(NC)"

stop-%: ## 停止特定服务
	@echo "$(YELLOW)>>> 停止 $* 服务...$(NC)"
	$(DOCKER_COMPOSE) stop $*
	@echo "$(GREEN)✓ $* 已停止$(NC)"

restart-%: ## 重启特定服务
	@echo "$(BLUE)>>> 重启 $* 服务...$(NC)"
	$(DOCKER_COMPOSE) restart $*
	@echo "$(GREEN)✓ $* 已重启$(NC)"

# ==================== Clash 管理 ====================
clash-setup: setup-clash ## 配置 Clash

clash-update: ## 更新 Clash 订阅
	@echo "$(BLUE)>>> 更新 Clash 订阅...$(NC)"
	@curl -X PUT http://localhost:9090/providers/proxies/my-subscription -H "Content-Type: application/json" 2>/dev/null || \
		{ echo "$(YELLOW)⚠ API 调用失败，重启 Clash...$(NC)"; $(MAKE) restart-clash; }
	@echo "$(GREEN)✓ 订阅更新完成$(NC)"

clash-test: ## 测试 Clash 代理
	@echo "$(BLUE)>>> 测试 Clash 代理...$(NC)"
	@curl -x http://localhost:7890 -I https://www.google.com 2>/dev/null && \
		echo "$(GREEN)✓ 代理连接正常$(NC)" || \
		echo "$(RED)✗ 代理连接失败$(NC)"

clash-dashboard: ## 打开 Clash Dashboard
	@echo "$(BLUE)>>> 打开 Clash Dashboard...$(NC)"
	@echo "访问: $(GREEN)http://localhost:9090/ui$(NC)"
	@command -v xdg-open >/dev/null 2>&1 && xdg-open http://localhost:9090/ui || \
		command -v open >/dev/null 2>&1 && open http://localhost:9090/ui || \
		echo "请手动访问: http://localhost:9090/ui"

clash-proxies: ## 查看代理节点
	@echo "$(BLUE)>>> 代理节点列表:$(NC)"
	@curl -s http://localhost:9090/proxies | jq -r '.proxies | keys[]' 2>/dev/null || \
		echo "$(RED)✗ 无法获取节点列表$(NC)"

clash-status: ## 查看 Clash 状态
	@echo "$(BLUE)>>> Clash 状态:$(NC)"
	@curl -s http://localhost:9090/providers/proxies | jq '.' 2>/dev/null || \
		echo "$(RED)✗ 无法获取状态$(NC)"

# ==================== CLIProxy 管理 ====================
cliproxy-login: ## 登录单个 Claude 账号
	@echo "$(BLUE)>>> 登录 Claude 账号...$(NC)"
	@read -p "账号名称 (account1): " account; \
	account=$${account:-account1}; \
	docker exec -it cliproxy cliproxy auth login --provider claude --account $$account

cliproxy-login-multi: ## 登录多个账号
	@echo "$(BLUE)>>> 登录多个 Claude 账号...$(NC)"
	@for i in 1 2 3; do \
		echo "$(YELLOW)>>> 登录账号 $$i/3...$(NC)"; \
		docker exec -it cliproxy cliproxy auth login --provider claude --account account$$i; \
	done
	@echo "$(GREEN)✓ 多账号登录完成$(NC)"

cliproxy-status: ## 查看 CLIProxy 账号状态
	@echo "$(BLUE)>>> CLIProxy 账号状态:$(NC)"
	@docker exec cliproxy cliproxy auth list 2>/dev/null || \
		echo "$(RED)✗ 无法获取状态（服务未运行？）$(NC)"

cliproxy-refresh: ## 刷新所有令牌
	@echo "$(BLUE)>>> 刷新令牌...$(NC)"
	@docker exec cliproxy cliproxy auth refresh --all
	@echo "$(GREEN)✓ 令牌刷新完成$(NC)"

cliproxy-stats: ## 查看负载统计
	@echo "$(BLUE)>>> 负载统计:$(NC)"
	@docker exec cliproxy cliproxy stats 2>/dev/null || \
		echo "$(RED)✗ 无法获取统计信息$(NC)"

cliproxy-test: ## 测试 CLIProxy API
	@echo "$(BLUE)>>> 测试 CLIProxy API...$(NC)"
	@curl -s http://localhost:8080/health | jq '.' 2>/dev/null && \
		echo "$(GREEN)✓ CLIProxy 运行正常$(NC)" || \
		echo "$(RED)✗ CLIProxy 连接失败$(NC)"

# ==================== 备份恢复 ====================
backup: backup-db backup-config ## 完整备份
	@echo "$(GREEN)✓ 完整备份完成$(NC)"

backup-db: ## 备份数据库
	@echo "$(BLUE)>>> 备份数据库...$(NC)"
	@mkdir -p backups
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	docker exec mysql mysqldump -uoneapi -p123456 one-api > backups/one-api_$$timestamp.sql && \
	echo "$(GREEN)✓ 数据库备份完成: backups/one-api_$$timestamp.sql$(NC)"

backup-config: ## 备份配置文件
	@echo "$(BLUE)>>> 备份配置文件...$(NC)"
	@mkdir -p backups
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	tar -czf backups/config_$$timestamp.tar.gz \
		docker-compose.yml \
		clash/config.yaml \
		cliproxy/config.yaml \
		2>/dev/null && \
	echo "$(GREEN)✓ 配置备份完成: backups/config_$$timestamp.tar.gz$(NC)"

restore: ## 恢复备份
	@echo "$(YELLOW)⚠ 此操作将覆盖现有数据$(NC)"
	@read -p "继续？(y/N): " confirm; \
	if [ "$$confirm" = "y" ]; then \
		ls -1t backups/*.sql | head -1 | xargs -I {} docker exec -i mysql mysql -uoneapi -p123456 one-api < {}; \
		echo "$(GREEN)✓ 恢复完成$(NC)"; \
	else \
		echo "$(YELLOW)已取消$(NC)"; \
	fi

list-backups: ## 列出所有备份
	@echo "$(BLUE)>>> 备份文件列表:$(NC)"
	@ls -lht backups/ 2>/dev/null || echo "$(YELLOW)暂无备份文件$(NC)"

# ==================== 监控维护 ====================
health: ## 健康检查
	@echo "$(BLUE)>>> 健康检查:$(NC)"
	@echo ""
	@echo "$(YELLOW)One-Hub:$(NC)"
	@curl -s http://localhost:3000/api/status | jq '.' 2>/dev/null || echo "$(RED)✗ 不可访问$(NC)"
	@echo ""
	@echo "$(YELLOW)Clash:$(NC)"
	@curl -s http://localhost:9090/ >/dev/null 2>&1 && echo "$(GREEN)✓ 运行正常$(NC)" || echo "$(RED)✗ 不可访问$(NC)"
	@echo ""
	@echo "$(YELLOW)CLIProxy:$(NC)"
	@curl -s http://localhost:8080/health | jq '.' 2>/dev/null || echo "$(RED)✗ 不可访问$(NC)"
	@echo ""
	@echo "$(YELLOW)Docker 容器:$(NC)"
	@$(DOCKER_COMPOSE) ps

update: ## 更新 Docker 镜像
	@echo "$(BLUE)>>> 更新镜像...$(NC)"
	$(DOCKER_COMPOSE) pull
	@echo "$(GREEN)✓ 镜像更新完成$(NC)"
	@echo "$(YELLOW)运行 'make restart' 应用更新$(NC)"

clean-data: ## 清理所有数据（危险！）
	@echo "$(RED)⚠⚠⚠ 警告：这将删除所有数据！⚠⚠⚠$(NC)"
	@read -p "确认删除所有数据？输入 'DELETE' 继续: " confirm; \
	if [ "$$confirm" = "DELETE" ]; then \
		$(MAKE) down; \
		sudo rm -rf data/; \
		sudo rm -rf clash/subscriptions/*; \
		sudo rm -rf cliproxy/auth/*; \
		echo "$(GREEN)✓ 数据清理完成$(NC)"; \
	else \
		echo "$(YELLOW)已取消$(NC)"; \
	fi

prune: ## 清理 Docker 缓存
	@echo "$(BLUE)>>> 清理 Docker 缓存...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✓ 清理完成$(NC)"

# ==================== 快捷操作 ====================
open-onehub: ## 打开 One-Hub 管理后台
	@echo "访问: $(GREEN)http://localhost:3000$(NC)"
	@command -v xdg-open >/dev/null 2>&1 && xdg-open http://localhost:3000 || \
		command -v open >/dev/null 2>&1 && open http://localhost:3000 || \
		echo "请手动访问: http://localhost:3000"

shell-%: ## 进入容器 Shell
	docker exec -it $* sh

install: init up ## 完整安装（init + up）
	@echo "$(GREEN)✓ 安装完成！$(NC)"
	@echo ""
	@echo "$(YELLOW)访问地址:$(NC)"
	@echo "  One-Hub: http://localhost:3000"
	@echo "  Clash Dashboard: http://localhost:9090/ui"
	@echo ""
	@echo "$(YELLOW)默认账号:$(NC)"
	@echo "  用户名: root"
	@echo "  密码: 123456"
	@echo ""
	@echo "$(RED)请立即修改密码！$(NC)"

dev: ## 开发模式（显示所有日志）
	$(DOCKER_COMPOSE) up

# ==================== 版本信息 ====================
version: ## 显示版本信息
	@echo "One-Hub 版本: $(VERSION)"
	@echo "Docker Compose 版本:"
	@$(DOCKER_COMPOSE) version

# ==================== Git 操作 ====================
git-status: ## Git 状态
	@git status

git-commit: ## 提交更改
	@git add -A
	@read -p "提交信息: " message; \
	git commit -m "$$message"

git-push: ## 推送到远程
	@git push -u origin $$(git branch --show-current)

# ==================== 测试 ====================
test-full: ## 完整测试流程
	@echo "$(BLUE)>>> 完整测试流程$(NC)"
	@$(MAKE) health
	@$(MAKE) clash-test
	@$(MAKE) cliproxy-test
	@echo "$(GREEN)✓ 测试完成$(NC)"

# ==================== 打包部署 ====================
package: ## 打包生产环境部署文件
	@echo "$(BLUE)>>> 打包生产环境部署文件...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(RED)✗ .env 文件不存在，请先创建$(NC)"; \
		exit 1; \
	fi; \
	timestamp=$$(date +%Y%m%d_%H%M%S); \
	package_name="one-hub-prod_$$timestamp"; \
	temp_dir="/tmp/$$package_name"; \
	\
	echo "$(YELLOW)>>> 创建临时目录...$(NC)"; \
	rm -rf $$temp_dir; \
	mkdir -p $$temp_dir; \
	\
	echo "$(YELLOW)>>> 复制必要文件...$(NC)"; \
	cp docker-compose.yml $$temp_dir/; \
	cp Dockerfile $$temp_dir/; \
	cp Makefile $$temp_dir/; \
	cp config.example.yaml $$temp_dir/; \
	cp .env $$temp_dir/; \
	cp README.md $$temp_dir/ 2>/dev/null || true; \
	\
	echo "$(YELLOW)>>> 复制配置目录...$(NC)"; \
	mkdir -p $$temp_dir/clash $$temp_dir/cliproxy $$temp_dir/scripts; \
	cp -r clash/*.yaml $$temp_dir/clash/ 2>/dev/null || true; \
	cp -r clash/Dockerfile.* $$temp_dir/clash/ 2>/dev/null || true; \
	cp -r clash/*.sh $$temp_dir/clash/ 2>/dev/null || true; \
	cp -r cliproxy/*.yaml $$temp_dir/cliproxy/ 2>/dev/null || true; \
	cp -r scripts/*.sh $$temp_dir/scripts/ 2>/dev/null || true; \
	\
	echo "$(YELLOW)>>> 创建必要的空目录...$(NC)"; \
	mkdir -p $$temp_dir/data/{mysql,redis}; \
	mkdir -p $$temp_dir/clash/subscriptions; \
	mkdir -p $$temp_dir/cliproxy/auth; \
	mkdir -p $$temp_dir/backups; \
	\
	echo "$(YELLOW)>>> 清理 Mac 系统文件...$(NC)"; \
	find $$temp_dir -name ".DS_Store" -delete; \
	find $$temp_dir -name "._*" -delete; \
	find $$temp_dir -name ".Spotlight-V100" -type d -exec rm -rf {} + 2>/dev/null || true; \
	find $$temp_dir -name ".Trashes" -type d -exec rm -rf {} + 2>/dev/null || true; \
	find $$temp_dir -name ".fseventsd" -type d -exec rm -rf {} + 2>/dev/null || true; \
	find $$temp_dir -name "__MACOSX" -type d -exec rm -rf {} + 2>/dev/null || true; \
	\
	echo "$(YELLOW)>>> 打包文件...$(NC)"; \
	COPYFILE_DISABLE=1 tar --exclude=".git" --exclude="node_modules" --exclude=".idea" \
		--exclude=".vscode" --exclude="*.db" --exclude="*.log" \
		--no-xattrs --no-mac-metadata \
		-czf $$package_name.tar.gz -C /tmp $$package_name/; \
	\
	echo "$(YELLOW)>>> 清理临时文件...$(NC)"; \
	rm -rf $$temp_dir; \
	\
	echo "$(GREEN)✓ 打包完成: $$package_name.tar.gz$(NC)"; \
	echo "$(BLUE)文件大小: $$(du -h $$package_name.tar.gz | cut -f1)$(NC)"; \
	echo "$(YELLOW)⚠ 包含生产环境配置，请妥善保管！$(NC)"

upload: package ## 打包并上传到远程服务器
	@latest_package=$$(ls -t one-hub-prod_*.tar.gz 2>/dev/null | head -1); \
	if [ -z "$$latest_package" ]; then \
		echo "$(RED)✗ 未找到打包文件$(NC)"; \
		exit 1; \
	fi; \
	echo "$(BLUE)>>> 上传到远程服务器...$(NC)"; \
	echo "$(YELLOW)文件: $$latest_package$(NC)"; \
	scp $$latest_package ali:/opt/one_hub/; \
	echo "$(GREEN)✓ 上传完成$(NC)"; \
	echo ""; \
	echo "$(YELLOW)远程服务器部署命令:$(NC)"; \
	echo "  ssh ali"; \
	echo "  cd /opt/one_hub"; \
	echo "  tar -xzf $$latest_package"; \
	echo "  cd one-hub-prod_*"; \
	echo "  make down && make up"

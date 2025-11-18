#!/bin/bash
# One Hub 快速启动脚本（安全版）

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          One Hub 生产环境快速部署工具                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查是否为 root 用户
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}⚠ 检测到 root 用户，建议使用普通用户运行${NC}"
    echo -e "${YELLOW}  继续请按回车，退出请按 Ctrl+C${NC}"
    read
fi

# 检查 Docker
echo -e "${BLUE}>>> 检查 Docker 环境...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ 未找到 Docker，是否安装？(y/n)${NC}"
    read -r install_docker
    if [ "$install_docker" = "y" ]; then
        curl -fsSL https://get.docker.com | bash
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        echo -e "${GREEN}✓ Docker 安装完成${NC}"
        echo -e "${YELLOW}⚠ 请重新登录以使 Docker 权限生效，然后重新运行此脚本${NC}"
        exit 0
    else
        echo -e "${RED}✗ 未安装 Docker，无法继续${NC}"
        exit 1
    fi
fi

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}⚠ 未找到 Docker Compose，正在安装...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✓ Docker Compose 安装完成${NC}"
fi

echo -e "${GREEN}✓ Docker 环境检查通过${NC}"
echo ""

# ============================================
# 🔒 安全检查：检查是否已有配置文件
# ============================================
ENV_FILE=".env.production"

if [ -f "$ENV_FILE" ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                  ⚠️ 安全警告 ⚠️                         ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}检测到已存在配置文件: ${ENV_FILE}${NC}"
    echo ""
    echo -e "${RED}重要提示:${NC}"
    echo -e "  • 覆盖配置将导致所有用户 Token 失效"
    echo -e "  • USER_TOKEN_SECRET 一旦修改无法恢复"
    echo -e "  • 数据库连接信息将被重置"
    echo ""
    echo -e "${BLUE}请选择操作:${NC}"
    echo "  1) 保留现有配置，继续部署（推荐）"
    echo "  2) 备份现有配置后生成新配置"
    echo "  3) 直接覆盖（危险！不推荐）"
    echo "  4) 退出"
    echo ""
    read -p "请选择 (1/2/3/4) [1]: " config_action
    config_action=${config_action:-1}
    
    case $config_action in
        1)
            echo -e "${GREEN}>>> 使用现有配置文件${NC}"
            SKIP_CONFIG_GENERATION=true
            ;;
        2)
            BACKUP_FILE="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$ENV_FILE" "$BACKUP_FILE"
            echo -e "${GREEN}✓ 配置已备份到: ${BACKUP_FILE}${NC}"
            echo -e "${YELLOW}>>> 将生成新的配置文件${NC}"
            SKIP_CONFIG_GENERATION=false
            
            # 尝试从备份中读取旧密钥（如果用户想保留）
            echo ""
            read -p "是否保留原有的安全密钥？(y/n) [y]: " keep_secrets
            keep_secrets=${keep_secrets:-y}
            if [ "$keep_secrets" = "y" ]; then
                echo -e "${BLUE}>>> 从备份中读取密钥...${NC}"
                OLD_SESSION_SECRET=$(grep "^SESSION_SECRET=" "$BACKUP_FILE" | cut -d'=' -f2)
                OLD_USER_TOKEN_SECRET=$(grep "^USER_TOKEN_SECRET=" "$BACKUP_FILE" | cut -d'=' -f2)
                OLD_MYSQL_PASSWORD=$(grep "^MYSQL_PASSWORD=" "$BACKUP_FILE" | cut -d'=' -f2)
                USE_OLD_SECRETS=true
                echo -e "${GREEN}✓ 将使用原有密钥${NC}"
            else
                USE_OLD_SECRETS=false
            fi
            ;;
        3)
            echo -e "${RED}>>> 警告：即将覆盖现有配置！${NC}"
            echo -e "${YELLOW}请输入 'YES' 确认覆盖:${NC}"
            read -r confirm_overwrite
            if [ "$confirm_overwrite" != "YES" ]; then
                echo -e "${YELLOW}操作已取消${NC}"
                exit 0
            fi
            SKIP_CONFIG_GENERATION=false
            USE_OLD_SECRETS=false
            ;;
        4)
            echo -e "${YELLOW}操作已取消${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，使用现有配置${NC}"
            SKIP_CONFIG_GENERATION=true
            ;;
    esac
    echo ""
else
    SKIP_CONFIG_GENERATION=false
    USE_OLD_SECRETS=false
fi

# ============================================
# 配置参数收集（仅在需要生成新配置时）
# ============================================
if [ "$SKIP_CONFIG_GENERATION" = false ]; then
    # 询问部署模式
    echo -e "${BLUE}>>> 选择部署模式:${NC}"
    echo "  1) 完整部署（MySQL + Redis + 应用）"
    echo "  2) 仅应用（使用外部数据库）"
    read -p "请选择 (1/2) [1]: " deploy_mode
    deploy_mode=${deploy_mode:-1}

    # 询问端口
    read -p "请输入服务端口 [3000]: " port
    port=${port:-3000}

    # 询问时区
    read -p "请输入时区 [Asia/Shanghai]: " timezone
    timezone=${timezone:-Asia/Shanghai}

    echo ""
    echo -e "${BLUE}>>> 生成安全密钥...${NC}"

    # 生成密钥或使用旧密钥
    if [ "$USE_OLD_SECRETS" = true ]; then
        SESSION_SECRET="$OLD_SESSION_SECRET"
        USER_TOKEN_SECRET="$OLD_USER_TOKEN_SECRET"
        MYSQL_PASSWORD="$OLD_MYSQL_PASSWORD"
        MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
        echo -e "${GREEN}✓ 使用原有密钥（已从备份恢复）${NC}"
    else
        SESSION_SECRET=$(openssl rand -base64 32)
        USER_TOKEN_SECRET=$(openssl rand -base64 32)
        MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
        MYSQL_PASSWORD=$(openssl rand -base64 32)
        echo -e "${GREEN}✓ 新密钥生成完成${NC}"
    fi
    
    echo ""

    # 创建目录
    echo -e "${BLUE}>>> 创建目录结构...${NC}"
    mkdir -p data/mysql data/redis data/app logs backups scripts

    # 生成配置文件
    echo -e "${BLUE}>>> 生成配置文件...${NC}"

    cat > .env.production << ENV_EOF
# One Hub 生产环境配置
# 生成时间: $(date)
# ⚠️ 警告: USER_TOKEN_SECRET 一旦设置不可修改！

# 基础配置
TZ=${timezone}
GIN_MODE=release
LOG_LEVEL=info
PORT=${port}

# 安全配置（请勿泄露）
SESSION_SECRET=${SESSION_SECRET}
USER_TOKEN_SECRET=${USER_TOKEN_SECRET}

# 数据库配置
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
SQL_DSN=oneapi:${MYSQL_PASSWORD}@tcp(mysql:3306)/one-api

# Redis 配置
REDIS_CONN_STRING=redis://redis:6379
REDIS_DB=0

# 性能优化
MEMORY_CACHE_ENABLED=true
SYNC_FREQUENCY=300
BATCH_UPDATE_ENABLED=true
BATCH_UPDATE_INTERVAL=5

# 限流配置
GLOBAL_API_RATE_LIMIT=180
GLOBAL_WEB_RATE_LIMIT=100
RELAY_TIMEOUT=120

# 渠道管理
CHANNEL_TEST_FREQUENCY=60
POLLING_INTERVAL=2

# 价格管理
AUTO_PRICE_UPDATES=true
AUTO_PRICE_UPDATES_MODE=system
ENV_EOF

    echo -e "${GREEN}✓ 配置文件已生成: .env.production${NC}"
    
    # 显示密钥信息（仅首次生成时）
    if [ "$USE_OLD_SECRETS" != true ]; then
        echo ""
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║           ⚠️ 请妥善保管以下密钥信息 ⚠️                  ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${RED}重要: 以下密钥仅显示一次，请立即备份！${NC}"
        echo ""
        echo -e "${BLUE}SESSION_SECRET:${NC}"
        echo "  ${SESSION_SECRET}"
        echo ""
        echo -e "${BLUE}USER_TOKEN_SECRET (不可修改):${NC}"
        echo "  ${USER_TOKEN_SECRET}"
        echo ""
        echo -e "${BLUE}MYSQL_PASSWORD:${NC}"
        echo "  ${MYSQL_PASSWORD}"
        echo ""
        read -p "$(echo -e ${YELLOW}已记录密钥信息？按回车继续...${NC})"
    fi
    echo ""
else
    # 使用现有配置，从文件中读取端口等信息
    source "$ENV_FILE"
    port=${PORT:-3000}
    timezone=${TZ:-Asia/Shanghai}
    
    # 创建目录（如果不存在）
    echo -e "${BLUE}>>> 检查目录结构...${NC}"
    mkdir -p data/mysql data/redis data/app logs backups scripts
    echo -e "${GREEN}✓ 目录检查完成${NC}"
    echo ""
fi

# 显示配置摘要
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                   配置摘要                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}配置文件:${NC} $([ "$SKIP_CONFIG_GENERATION" = true ] && echo "使用现有" || echo "已生成新")"
echo -e "${YELLOW}服务端口:${NC} ${port}"
echo -e "${YELLOW}时区:${NC} ${timezone}"
echo -e "${YELLOW}数据目录:${NC} $(pwd)/data"
echo -e "${YELLOW}日志目录:${NC} $(pwd)/logs"
echo -e "${YELLOW}备份目录:${NC} $(pwd)/backups"
echo ""

# 确认启动
read -p "$(echo -e ${GREEN}是否开始部署？\(y/n\) [y]: ${NC})" confirm
confirm=${confirm:-y}

if [ "$confirm" != "y" ]; then
    echo -e "${YELLOW}部署已取消${NC}"
    exit 0
fi

# 启动服务
echo ""
echo -e "${GREEN}>>> 启动服务...${NC}"
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d

# 等待服务就绪
echo -e "${YELLOW}>>> 等待服务就绪（约30秒）...${NC}"
sleep 30

# 健康检查
echo -e "${BLUE}>>> 健康检查...${NC}"
max_retries=10
retry=0
while [ $retry -lt $max_retries ]; do
    if curl -sf http://localhost:${port}/api/status >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 服务运行正常！${NC}"
        break
    fi
    retry=$((retry+1))
    if [ $retry -lt $max_retries ]; then
        echo -e "${YELLOW}  等待服务启动... ($retry/$max_retries)${NC}"
        sleep 5
    else
        echo -e "${RED}✗ 服务启动超时，请检查日志${NC}"
        echo -e "${YELLOW}  运行查看日志: make -f Makefile.prod logs${NC}"
    fi
done

# 显示完成信息
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   部署完成！                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}访问地址:${NC} http://$(hostname -I | awk '{print $1}'):${port}"
echo -e "${BLUE}默认账号:${NC} root"
echo -e "${BLUE}默认密码:${NC} 123456"
echo ""
echo -e "${RED}⚠ 重要提示:${NC}"
echo -e "  1. 请立即登录并修改默认密码"
echo -e "  2. 生产环境建议配置 HTTPS 反向代理"
echo -e "  3. 定期备份数据: make -f Makefile.prod db-backup"
if [ "$SKIP_CONFIG_GENERATION" = false ] && [ "$USE_OLD_SECRETS" != true ]; then
    echo -e "  4. ${RED}密钥信息已显示过，请确保已备份${NC}"
fi
echo ""
echo -e "${BLUE}常用命令:${NC}"
echo -e "  查看状态: ${YELLOW}make -f Makefile.prod status${NC}"
echo -e "  查看日志: ${YELLOW}make -f Makefile.prod logs${NC}"
echo -e "  重启服务: ${YELLOW}make -f Makefile.prod restart${NC}"
echo -e "  数据备份: ${YELLOW}make -f Makefile.prod db-backup${NC}"
echo -e "  查看帮助: ${YELLOW}make -f Makefile.prod help${NC}"
echo ""

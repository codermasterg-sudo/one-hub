#!/bin/bash
# One Hub 数据库备份脚本

set -e

# 配置
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/one-api-${DATE}.sql.gz"
RETENTION_DAYS=7

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}>>> 开始备份数据库...${NC}"

# 创建备份目录
mkdir -p ${BACKUP_DIR}

# 读取数据库密码
if [ -f .env.production ]; then
    source .env.production
else
    echo -e "${RED}错误: 未找到配置文件 .env.production${NC}"
    exit 1
fi

# 执行备份
echo -e "${YELLOW}>>> 备份到: ${BACKUP_FILE}${NC}"
docker-compose -f docker-compose.prod.yml exec -T mysql mysqldump \
    -u oneapi \
    -p${MYSQL_PASSWORD} \
    --single-transaction \
    --quick \
    --lock-tables=false \
    one-api | gzip > ${BACKUP_FILE}

# 检查备份是否成功
if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h ${BACKUP_FILE} | cut -f1)
    echo -e "${GREEN}✓ 备份成功！文件大小: ${BACKUP_SIZE}${NC}"
else
    echo -e "${RED}✗ 备份失败！${NC}"
    exit 1
fi

# 清理旧备份
echo -e "${YELLOW}>>> 清理 ${RETENTION_DAYS} 天前的备份...${NC}"
find ${BACKUP_DIR} -name "one-api-*.sql.gz" -mtime +${RETENTION_DAYS} -delete

# 列出当前所有备份
echo -e "${GREEN}>>> 当前备份列表:${NC}"
ls -lh ${BACKUP_DIR}/one-api-*.sql.gz 2>/dev/null || echo "无备份文件"

echo -e "${GREEN}>>> 备份完成！${NC}"

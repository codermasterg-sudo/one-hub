#!/bin/bash
# One Hub 数据库恢复脚本

set -e

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查参数
if [ -z "$1" ]; then
    echo -e "${RED}错误: 请指定备份文件${NC}"
    echo "使用方式: $0 <backup_file>"
    echo "示例: $0 backups/one-api-20240101_120000.sql.gz"
    exit 1
fi

BACKUP_FILE=$1

# 检查备份文件是否存在
if [ ! -f "${BACKUP_FILE}" ]; then
    echo -e "${RED}错误: 备份文件不存在: ${BACKUP_FILE}${NC}"
    exit 1
fi

echo -e "${RED}警告: 此操作将覆盖当前数据库！${NC}"
echo -e "${YELLOW}请输入 'YES' 确认恢复:${NC}"
read -r confirm

if [ "$confirm" != "YES" ]; then
    echo -e "${YELLOW}操作已取消${NC}"
    exit 0
fi

# 读取配置
if [ -f .env.production ]; then
    source .env.production
else
    echo -e "${RED}错误: 未找到配置文件 .env.production${NC}"
    exit 1
fi

echo -e "${GREEN}>>> 开始恢复数据库...${NC}"
echo -e "${YELLOW}>>> 备份文件: ${BACKUP_FILE}${NC}"

# 解压并恢复
zcat ${BACKUP_FILE} | docker-compose -f docker-compose.prod.yml exec -T mysql mysql \
    -u oneapi \
    -p${MYSQL_PASSWORD} \
    one-api

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 数据库恢复成功！${NC}"
    echo -e "${YELLOW}>>> 建议重启应用服务: make -f Makefile.prod restart-app${NC}"
else
    echo -e "${RED}✗ 数据库恢复失败！${NC}"
    exit 1
fi

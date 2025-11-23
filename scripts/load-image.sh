#!/bin/bash
# One Hub Docker 镜像加载脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         One Hub Docker 镜像加载工具                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查 Docker 环境
echo -e "${YELLOW}>>> 检查 Docker 环境...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: 未找到 Docker，请先安装${NC}"
    exit 1
fi

if ! docker ps &> /dev/null; then
    echo -e "${RED}错误: Docker 未运行或无权限访问${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker 环境正常${NC}"
echo ""

# 查找镜像文件
IMAGES_DIR="./images"
IMAGE_FILE=""

if [ ! -d "$IMAGES_DIR" ]; then
    echo -e "${RED}错误: 未找到镜像目录 ${IMAGES_DIR}${NC}"
    echo "请确保在部署包根目录下运行此脚本"
    exit 1
fi

# 查找所有镜像文件
IMAGE_FILES=($(find "$IMAGES_DIR" -name "*.tar.gz" 2>/dev/null))

if [ ${#IMAGE_FILES[@]} -eq 0 ]; then
    echo -e "${RED}错误: 未找到镜像文件 (*.tar.gz)${NC}"
    echo "请确保镜像文件位于 ${IMAGES_DIR} 目录"
    exit 1
fi

# 显示可用镜像
echo -e "${BLUE}>>> 发现以下镜像文件:${NC}"
echo ""
for i in "${!IMAGE_FILES[@]}"; do
    file="${IMAGE_FILES[$i]}"
    size=$(du -h "$file" | cut -f1)
    echo -e "  $((i+1))) $(basename $file) (${size})"

    # 显示镜像信息文件内容（如果存在）
    info_file="${file%.tar.gz}.info"
    if [ -f "$info_file" ]; then
        echo -e "     ${BLUE}$(cat $info_file | head -5 | tail -3)${NC}"
    fi
done
echo ""

# 选择镜像
if [ ${#IMAGE_FILES[@]} -eq 1 ]; then
    IMAGE_FILE="${IMAGE_FILES[0]}"
    echo -e "${GREEN}自动选择: $(basename $IMAGE_FILE)${NC}"
else
    read -p "请选择要加载的镜像 (1-${#IMAGE_FILES[@]}) [1]: " choice
    choice=${choice:-1}

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#IMAGE_FILES[@]} ]; then
        echo -e "${RED}错误: 无效的选择${NC}"
        exit 1
    fi

    IMAGE_FILE="${IMAGE_FILES[$((choice-1))]}"
fi

echo ""

# MD5 校验
MD5_FILE="${IMAGE_FILE}.md5"
if [ -f "$MD5_FILE" ]; then
    echo -e "${YELLOW}>>> 校验镜像文件完整性...${NC}"

    cd "$(dirname $IMAGE_FILE)"

    if md5sum -c "$(basename $MD5_FILE)" 2>/dev/null; then
        echo -e "${GREEN}✓ 文件完整性校验通过${NC}"
    elif md5 -r "$(basename ${IMAGE_FILE})" | sed "s/ / /" | diff - "$(basename $MD5_FILE)" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 文件完整性校验通过${NC}"
    else
        echo -e "${RED}✗ 文件完整性校验失败${NC}"
        read -p "是否继续加载？(y/n) [n]: " continue_load
        if [ "$continue_load" != "y" ]; then
            exit 1
        fi
    fi

    cd - >/dev/null
    echo ""
else
    echo -e "${YELLOW}⚠ 未找到 MD5 校验文件，跳过完整性检查${NC}"
    echo ""
fi

# 确认加载
echo -e "${BLUE}>>> 准备加载镜像${NC}"
echo -e "  文件: ${YELLOW}$(basename $IMAGE_FILE)${NC}"
echo -e "  大小: ${YELLOW}$(du -h $IMAGE_FILE | cut -f1)${NC}"
echo ""

read -p "$(echo -e ${GREEN}是否继续加载镜像？\(y/n\) [y]: ${NC})" confirm
confirm=${confirm:-y}
if [ "$confirm" != "y" ]; then
    echo "加载已取消"
    exit 0
fi

# 加载镜像
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  加载 Docker 镜像                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

LOAD_START=$(date +%s)

echo -e "${YELLOW}>>> 解压并加载镜像...${NC}"
echo ""

# 使用管道直接加载，避免解压到磁盘
if gunzip -c "$IMAGE_FILE" | docker load; then
    LOAD_END=$(date +%s)
    LOAD_TIME=$((LOAD_END - LOAD_START))

    echo ""
    echo -e "${GREEN}✓ 镜像加载完成 (耗时: ${LOAD_TIME}s)${NC}"
else
    echo ""
    echo -e "${RED}✗ 镜像加载失败${NC}"
    exit 1
fi

# 显示已加载的镜像
echo ""
echo -e "${BLUE}>>> 已加载的镜像:${NC}"
docker images one-hub --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   加载完成！                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}下一步:${NC}"
echo -e "  1. 初始化配置: ${YELLOW}make -f Makefile.prod init${NC}"
echo -e "  2. 启动服务: ${YELLOW}make -f Makefile.prod start${NC}"
echo ""
echo -e "  或使用快速开始: ${YELLOW}bash scripts/quick-start.sh${NC}"
echo ""

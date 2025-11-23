#!/bin/bash
# One Hub Docker 镜像构建脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         One Hub Docker 镜像构建工具                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 获取版本信息
if [ -f VERSION ] && [ -s VERSION ]; then
    VERSION=$(cat VERSION | tr -d '[:space:]')
else
    # 尝试从 git 获取版本
    VERSION=$(git describe --tags 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "v1.0.0")
fi

# 确保版本号不为空
if [ -z "$VERSION" ]; then
    VERSION="v1.0.0"
fi

# 默认配置
IMAGE_NAME="one-hub"
IMAGE_TAG="${VERSION}"
IMAGE_FULL="${IMAGE_NAME}:${IMAGE_TAG}"
IMAGE_LATEST="${IMAGE_NAME}:latest"
OUTPUT_DIR="./dist"
IMAGE_FILE="${OUTPUT_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --tag|-t)
            IMAGE_TAG="$2"
            IMAGE_FULL="${IMAGE_NAME}:${IMAGE_TAG}"
            IMAGE_FILE="${OUTPUT_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar"
            shift 2
            ;;
        --name|-n)
            IMAGE_NAME="$2"
            IMAGE_FULL="${IMAGE_NAME}:${IMAGE_TAG}"
            IMAGE_LATEST="${IMAGE_NAME}:latest"
            IMAGE_FILE="${OUTPUT_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar"
            shift 2
            ;;
        --no-export)
            NO_EXPORT=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --help|-h)
            echo "使用方式: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --tag, -t TAG        设置镜像标签 (默认: ${VERSION})"
            echo "  --name, -n NAME      设置镜像名称 (默认: one-hub)"
            echo "  --no-export          不导出镜像为 tar 文件"
            echo "  --no-cache           构建时不使用缓存"
            echo "  --help, -h           显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                   # 使用默认配置构建"
            echo "  $0 --tag v1.0.0      # 指定版本标签"
            echo "  $0 --no-cache        # 强制重新构建"
            echo "  $0 --no-export       # 仅构建不导出"
            exit 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            exit 1
            ;;
    esac
done

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

# 显示构建信息
echo -e "${BLUE}>>> 构建信息${NC}"
echo -e "  镜像名称: ${YELLOW}${IMAGE_FULL}${NC}"
echo -e "  版本标签: ${YELLOW}${IMAGE_TAG}${NC}"
if [ -z "$NO_EXPORT" ]; then
    echo -e "  导出文件: ${YELLOW}${IMAGE_FILE}${NC}"
else
    echo -e "  导出文件: ${YELLOW}不导出${NC}"
fi
echo ""

# 询问确认
read -p "$(echo -e ${GREEN}是否继续构建？\(y/n\) [y]: ${NC})" confirm
confirm=${confirm:-y}
if [ "$confirm" != "y" ]; then
    echo "构建已取消"
    exit 0
fi

# 构建镜像
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  开始构建镜像                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

BUILD_START=$(date +%s)

echo -e "${YELLOW}>>> 执行 Docker 构建...${NC}"
docker build ${NO_CACHE} -t "${IMAGE_FULL}" -f Dockerfile .

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

echo ""
echo -e "${GREEN}✓ 镜像构建完成 (耗时: ${BUILD_TIME}s)${NC}"

# 同时标记为 latest
echo ""
echo -e "${YELLOW}>>> 标记为 latest...${NC}"
docker tag "${IMAGE_FULL}" "${IMAGE_LATEST}"
echo -e "${GREEN}✓ 已标记: ${IMAGE_LATEST}${NC}"

# 显示镜像信息
echo ""
echo -e "${BLUE}>>> 镜像信息${NC}"
docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# 导出镜像
if [ -z "$NO_EXPORT" ]; then
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  导出镜像文件                          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # 创建输出目录
    mkdir -p "${OUTPUT_DIR}"

    # 导出镜像
    echo -e "${YELLOW}>>> 导出镜像到文件...${NC}"
    EXPORT_START=$(date +%s)

    docker save -o "${IMAGE_FILE}" "${IMAGE_FULL}"

    EXPORT_END=$(date +%s)
    EXPORT_TIME=$((EXPORT_END - EXPORT_START))

    echo -e "${GREEN}✓ 镜像导出完成 (耗时: ${EXPORT_TIME}s)${NC}"

    # 压缩镜像文件
    echo ""
    echo -e "${YELLOW}>>> 压缩镜像文件...${NC}"
    COMPRESS_START=$(date +%s)

    gzip -f "${IMAGE_FILE}"
    IMAGE_FILE_GZ="${IMAGE_FILE}.gz"

    COMPRESS_END=$(date +%s)
    COMPRESS_TIME=$((COMPRESS_END - COMPRESS_START))

    echo -e "${GREEN}✓ 压缩完成 (耗时: ${COMPRESS_TIME}s)${NC}"

    # 计算文件信息
    FILE_SIZE=$(du -h "${IMAGE_FILE_GZ}" | cut -f1)
    FILE_MD5=$(md5sum "${IMAGE_FILE_GZ}" 2>/dev/null || md5 "${IMAGE_FILE_GZ}" 2>/dev/null | awk '{print $1}')

    # 生成校验文件
    echo "${FILE_MD5}  $(basename ${IMAGE_FILE_GZ})" > "${IMAGE_FILE_GZ}.md5"

    # 生成镜像信息文件
    cat > "${OUTPUT_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.info" << INFO_EOF
镜像信息
════════════════════════════════════════

镜像名称: ${IMAGE_FULL}
版本标签: ${IMAGE_TAG}
构建时间: $(date '+%Y-%m-%d %H:%M:%S')
构建耗时: ${BUILD_TIME}s
导出耗时: ${EXPORT_TIME}s
压缩耗时: ${COMPRESS_TIME}s

文件信息
────────────────────────────────────────
文件名称: $(basename ${IMAGE_FILE_GZ})
文件大小: ${FILE_SIZE}
MD5 校验: ${FILE_MD5}

加载命令
────────────────────────────────────────
解压: gunzip $(basename ${IMAGE_FILE_GZ})
加载: docker load -i $(basename ${IMAGE_FILE})

或直接: gunzip -c $(basename ${IMAGE_FILE_GZ}) | docker load

INFO_EOF

    # 显示结果
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   构建完成！                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}镜像信息:${NC}"
    echo -e "  名称: ${YELLOW}${IMAGE_FULL}${NC}"
    echo -e "  大小: ${YELLOW}$(docker images ${IMAGE_FULL} --format '{{.Size}}')${NC}"
    echo ""
    echo -e "${BLUE}导出文件:${NC}"
    echo -e "  文件: ${YELLOW}${IMAGE_FILE_GZ}${NC}"
    echo -e "  大小: ${YELLOW}${FILE_SIZE}${NC}"
    echo -e "  MD5: ${YELLOW}${FILE_MD5}${NC}"
    echo ""
    echo -e "${BLUE}总耗时: ${YELLOW}$((BUILD_TIME + EXPORT_TIME + COMPRESS_TIME))s${NC}"
    echo ""
    echo -e "${BLUE}下一步:${NC}"
    echo -e "  1. 使用打包脚本: ${YELLOW}bash scripts/package-prod.sh --with-image${NC}"
    echo -e "  2. 手动加载镜像: ${YELLOW}gunzip -c ${IMAGE_FILE_GZ} | docker load${NC}"
    echo -e "  3. 校验 MD5: ${YELLOW}md5sum -c ${IMAGE_FILE_GZ}.md5${NC}"
    echo ""
else
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   构建完成！                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}镜像信息:${NC}"
    echo -e "  名称: ${YELLOW}${IMAGE_FULL}${NC}"
    echo -e "  大小: ${YELLOW}$(docker images ${IMAGE_FULL} --format '{{.Size}}')${NC}"
    echo ""
    echo -e "${BLUE}构建耗时: ${YELLOW}${BUILD_TIME}s${NC}"
    echo ""
fi

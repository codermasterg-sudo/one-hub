#!/bin/bash
# One Hub 生产环境打包脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          One Hub 生产环境打包工具                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 获取版本信息
if [ -f VERSION ]; then
    VERSION=$(cat VERSION)
else
    VERSION="latest"
fi

# 默认配置
PACKAGE_NAME="one-hub-prod-${VERSION}"
PACKAGE_DIR="./dist/${PACKAGE_NAME}"
PACKAGE_FILE="./dist/${PACKAGE_NAME}.tar.gz"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 询问打包选项
echo -e "${BLUE}>>> 打包配置${NC}"
echo ""

# 是否包含示例配置
read -p "是否包含示例配置文件？(y/n) [y]: " include_example
include_example=${include_example:-y}

# 是否包含文档
read -p "是否包含部署文档？(y/n) [y]: " include_docs
include_docs=${include_docs:-y}

# 打包模式
echo ""
echo -e "${BLUE}选择打包模式:${NC}"
echo "  1) 完整打包（包含所有文件）"
echo "  2) 最小打包（仅核心文件）"
echo "  3) 自定义打包"
read -p "请选择 (1/2/3) [1]: " package_mode
package_mode=${package_mode:-1}

echo ""
echo -e "${BLUE}>>> 开始打包...${NC}"

# 清理旧的打包目录
rm -rf ./dist
mkdir -p "$PACKAGE_DIR"

# ============================================
# 核心文件（必需）
# ============================================
echo -e "${YELLOW}>>> 打包核心文件...${NC}"

core_files=(
    "Makefile.prod"
    "docker-compose.prod.yml"
)

for file in "${core_files[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$PACKAGE_DIR/"
        echo "  ✓ $file"
    else
        echo -e "  ${RED}✗ $file (未找到)${NC}"
    fi
done

# ============================================
# 脚本文件
# ============================================
echo -e "${YELLOW}>>> 打包脚本文件...${NC}"

mkdir -p "$PACKAGE_DIR/scripts"

script_files=(
    "scripts/backup.sh"
    "scripts/restore.sh"
    "scripts/quick-start.sh"
)

for file in "${script_files[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$PACKAGE_DIR/scripts/"
        chmod +x "$PACKAGE_DIR/scripts/$(basename $file)"
        echo "  ✓ $file"
    else
        echo -e "  ${YELLOW}⚠ $file (未找到，跳过)${NC}"
    fi
done

# ============================================
# 配置文件示例
# ============================================
if [ "$include_example" = "y" ]; then
    echo -e "${YELLOW}>>> 打包配置文件示例...${NC}"
    
    config_files=(
        ".env.production.example"
        "config.example.yaml"
    )
    
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$PACKAGE_DIR/"
            echo "  ✓ $file"
        else
            echo -e "  ${YELLOW}⚠ $file (未找到，跳过)${NC}"
        fi
    done
fi

# ============================================
# 文档文件
# ============================================
if [ "$include_docs" = "y" ]; then
    echo -e "${YELLOW}>>> 打包文档文件...${NC}"
    
    doc_files=(
        "README.md"
        "DEPLOY.md"
        "PRODUCTION.md"
        "安全修复说明.md"
    )
    
    for file in "${doc_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$PACKAGE_DIR/"
            echo "  ✓ $file"
        else
            echo -e "  ${YELLOW}⚠ $file (未找到，跳过)${NC}"
        fi
    done
fi

# ============================================
# 完整模式 - 额外文件
# ============================================
if [ "$package_mode" = "1" ]; then
    echo -e "${YELLOW}>>> 打包额外文件（完整模式）...${NC}"
    
    # 创建 bin 目录并复制密钥生成脚本
    if [ -f "bin/generate_random_key.sh" ]; then
        mkdir -p "$PACKAGE_DIR/bin"
        cp "bin/generate_random_key.sh" "$PACKAGE_DIR/bin/"
        chmod +x "$PACKAGE_DIR/bin/generate_random_key.sh"
        echo "  ✓ bin/generate_random_key.sh"
    fi
    
    # Nginx 配置示例
    if [ -f "nginx.conf.example" ]; then
        cp "nginx.conf.example" "$PACKAGE_DIR/"
        echo "  ✓ nginx.conf.example"
    fi
fi

# ============================================
# 创建目录结构
# ============================================
echo -e "${YELLOW}>>> 创建目录结构...${NC}"

directories=(
    "data/mysql"
    "data/redis"
    "data/app"
    "logs"
    "backups"
)

for dir in "${directories[@]}"; do
    mkdir -p "$PACKAGE_DIR/$dir"
    touch "$PACKAGE_DIR/$dir/.gitkeep"
    echo "  ✓ $dir/"
done

# ============================================
# 生成部署清单
# ============================================
echo -e "${YELLOW}>>> 生成部署清单...${NC}"

cat > "$PACKAGE_DIR/MANIFEST.txt" << MANIFEST_EOF
╔════════════════════════════════════════════════════════╗
║          One Hub 生产环境部署包清单                    ║
╚════════════════════════════════════════════════════════╝

版本信息:
  版本: ${VERSION}
  打包时间: ${TIMESTAMP}
  打包模式: $([ "$package_mode" = "1" ] && echo "完整模式" || echo "最小模式")

包含文件:
$(cd "$PACKAGE_DIR" && find . -type f ! -name ".gitkeep" ! -name "MANIFEST.txt" | sort)

目录结构:
$(cd "$PACKAGE_DIR" && tree -L 2 2>/dev/null || find . -type d | sort)

部署步骤:
  1. 解压此压缩包到目标服务器
  2. 进入解压目录
  3. 运行初始化: make -f Makefile.prod init
  4. 启动服务: make -f Makefile.prod start

快速部署:
  bash scripts/quick-start.sh

查看帮助:
  make -f Makefile.prod help

注意事项:
  • 首次部署会自动生成安全密钥
  • 请妥善保管生成的 .env.production 文件
  • USER_TOKEN_SECRET 一旦设置不可修改
  • 建议配置 HTTPS 反向代理

更多信息请查看:
  • DEPLOY.md - 详细部署文档
  • PRODUCTION.md - 生产环境指南
  • README.md - 项目说明

MANIFEST_EOF

echo "  ✓ MANIFEST.txt"

# ============================================
# 生成快速开始文档
# ============================================
echo -e "${YELLOW}>>> 生成快速开始文档...${NC}"

cat > "$PACKAGE_DIR/快速开始.txt" << QUICKSTART_EOF
╔════════════════════════════════════════════════════════╗
║               One Hub 快速部署指南                     ║
╚════════════════════════════════════════════════════════╝

📦 解压完成后，请按以下步骤操作：

方式一：一键部署（推荐新手）
─────────────────────────────
  bash scripts/quick-start.sh

方式二：使用 Make 部署（推荐运维）
─────────────────────────────
  make -f Makefile.prod init
  make -f Makefile.prod start

方式三：手动部署（高级用户）
─────────────────────────────
  cp .env.production.example .env.production
  # 编辑 .env.production，修改必要配置
  docker-compose -f docker-compose.prod.yml --env-file .env.production up -d

常用命令：
  make -f Makefile.prod help      # 查看所有命令
  make -f Makefile.prod status    # 查看服务状态
  make -f Makefile.prod logs      # 查看日志
  make -f Makefile.prod db-backup # 备份数据库

首次登录：
  地址: http://your-server-ip:3000
  账号: root
  密码: 123456
  ⚠️ 请立即修改默认密码！

更多帮助：
  查看 DEPLOY.md 获取详细部署文档
  查看 PRODUCTION.md 获取生产环境最佳实践

QUICKSTART_EOF

echo "  ✓ 快速开始.txt"

# ============================================
# 生成 .gitignore
# ============================================
echo -e "${YELLOW}>>> 生成 .gitignore...${NC}"

cat > "$PACKAGE_DIR/.gitignore" << GITIGNORE_EOF
# 环境配置（包含密钥，不要提交）
.env.production
.env.production.backup.*

# 数据目录
data/*
!data/.gitkeep
!data/mysql/.gitkeep
!data/redis/.gitkeep
!data/app/.gitkeep

# 日志目录
logs/*
!logs/.gitkeep

# 备份目录
backups/*
!backups/.gitkeep

# Docker
docker-compose.override.yml

# 临时文件
*.tmp
*.log
*.pid

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

GITIGNORE_EOF

echo "  ✓ .gitignore"

# ============================================
# 生成 README
# ============================================
echo -e "${YELLOW}>>> 生成部署包 README...${NC}"

cat > "$PACKAGE_DIR/README-DEPLOY.md" << README_EOF
# One Hub 生产环境部署包

## 📦 包内容

本部署包包含 One Hub 生产环境部署所需的所有文件。

- **版本**: ${VERSION}
- **打包时间**: ${TIMESTAMP}

## 🚀 快速开始

### 最简单的方式（一键部署）

\`\`\`bash
bash scripts/quick-start.sh
\`\`\`

### 使用 Make 部署（推荐）

\`\`\`bash
make -f Makefile.prod init
make -f Makefile.prod start
\`\`\`

## 📋 文件说明

| 文件/目录 | 说明 |
|----------|------|
| \`Makefile.prod\` | 生产环境 Make 管理工具 |
| \`docker-compose.prod.yml\` | Docker Compose 配置 |
| \`.env.production.example\` | 环境变量配置模板 |
| \`scripts/\` | 自动化脚本目录 |
| \`DEPLOY.md\` | 详细部署文档 |
| \`PRODUCTION.md\` | 生产环境指南 |
| \`MANIFEST.txt\` | 部署包清单 |
| \`快速开始.txt\` | 快速部署指南 |

## 📖 详细文档

- [DEPLOY.md](./DEPLOY.md) - 详细部署步骤、配置说明、故障排查
- [PRODUCTION.md](./PRODUCTION.md) - 生产环境最佳实践、性能调优
- [快速开始.txt](./快速开始.txt) - 最简化的部署指南

## ⚠️ 重要提示

1. 首次部署会自动生成安全密钥
2. 请妥善保管生成的 \`.env.production\` 文件
3. \`USER_TOKEN_SECRET\` 一旦设置不可修改
4. 首次登录后请立即修改默认密码（root/123456）
5. 生产环境建议配置 HTTPS 反向代理

## 🔒 安全建议

- 定期备份数据库：\`make -f Makefile.prod db-backup\`
- 设置定时备份任务
- 配置防火墙
- 使用 HTTPS
- 定期更新系统

## 📞 获取帮助

- GitHub: https://github.com/MartialBE/one-hub
- 文档: https://one-hub-doc.vercel.app/
- Issues: https://github.com/MartialBE/one-hub/issues

README_EOF

echo "  ✓ README-DEPLOY.md"

# ============================================
# 创建检查脚本
# ============================================
echo -e "${YELLOW}>>> 创建环境检查脚本...${NC}"

cat > "$PACKAGE_DIR/scripts/check-env.sh" << 'CHECK_EOF'
#!/bin/bash
# 环境检查脚本

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "One Hub 环境检查"
echo "═══════════════════════════════════════"
echo ""

# 检查 Docker
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker: $(docker --version)"
else
    echo -e "${RED}✗${NC} Docker: 未安装"
fi

# 检查 Docker Compose
if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker Compose: $(docker-compose --version)"
else
    echo -e "${RED}✗${NC} Docker Compose: 未安装"
fi

# 检查 Make
if command -v make &> /dev/null; then
    echo -e "${GREEN}✓${NC} Make: $(make --version | head -1)"
else
    echo -e "${YELLOW}⚠${NC} Make: 未安装（可选）"
fi

# 检查端口占用
echo ""
echo "端口检查:"
for port in 3000 3306 6379; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        echo -e "${YELLOW}⚠${NC} 端口 $port 已被占用"
    else
        echo -e "${GREEN}✓${NC} 端口 $port 可用"
    fi
done

# 检查磁盘空间
echo ""
echo "磁盘空间:"
df -h . | tail -1 | awk '{print "  可用: " $4 " / " $2}'

# 检查内存
echo ""
echo "内存:"
free -h | grep "Mem:" | awk '{print "  可用: " $7 " / " $2}'

echo ""
echo "═══════════════════════════════════════"
CHECK_EOF

chmod +x "$PACKAGE_DIR/scripts/check-env.sh"
echo "  ✓ scripts/check-env.sh"

# ============================================
# 压缩打包
# ============================================
echo ""
echo -e "${BLUE}>>> 压缩打包...${NC}"

cd ./dist
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"
cd ..

# 计算文件大小和 MD5
PACKAGE_SIZE=$(du -h "$PACKAGE_FILE" | cut -f1)
PACKAGE_MD5=$(md5sum "$PACKAGE_FILE" 2>/dev/null || md5 "$PACKAGE_FILE" 2>/dev/null | awk '{print $1}')

echo -e "${GREEN}✓ 打包完成${NC}"
echo ""

# ============================================
# 生成校验文件
# ============================================
echo -e "${YELLOW}>>> 生成校验文件...${NC}"

cat > "$PACKAGE_FILE.md5" << MD5_EOF
${PACKAGE_MD5}  ${PACKAGE_NAME}.tar.gz
MD5_EOF

echo "  ✓ ${PACKAGE_NAME}.tar.gz.md5"

# ============================================
# 显示打包结果
# ============================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   打包完成！                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}打包信息:${NC}"
echo -e "  文件名: ${YELLOW}${PACKAGE_FILE}${NC}"
echo -e "  大小: ${YELLOW}${PACKAGE_SIZE}${NC}"
echo -e "  MD5: ${YELLOW}${PACKAGE_MD5}${NC}"
echo ""
echo -e "${BLUE}包含内容:${NC}"
cd "$PACKAGE_DIR"
find . -type f ! -name ".gitkeep" | wc -l | xargs echo "  文件数:"
find . -type d | wc -l | xargs echo "  目录数:"
cd - > /dev/null
echo ""
echo -e "${BLUE}使用方法:${NC}"
echo -e "  1. 传输到目标服务器:"
echo -e "     ${YELLOW}scp ${PACKAGE_FILE} user@server:/path/${NC}"
echo ""
echo -e "  2. 在服务器上解压:"
echo -e "     ${YELLOW}tar -xzf ${PACKAGE_NAME}.tar.gz${NC}"
echo -e "     ${YELLOW}cd ${PACKAGE_NAME}${NC}"
echo ""
echo -e "  3. 开始部署:"
echo -e "     ${YELLOW}bash scripts/quick-start.sh${NC}"
echo -e "     或"
echo -e "     ${YELLOW}make -f Makefile.prod init${NC}"
echo ""
echo -e "${BLUE}校验 MD5:${NC}"
echo -e "  ${YELLOW}md5sum -c ${PACKAGE_NAME}.tar.gz.md5${NC}"
echo ""
echo -e "${BLUE}查看清单:${NC}"
echo -e "  ${YELLOW}tar -tzf ${PACKAGE_FILE} | head -20${NC}"
echo ""

# 询问是否查看内容
read -p "$(echo -e ${GREEN}是否查看打包内容？\(y/n\) [n]: ${NC})" show_content
show_content=${show_content:-n}

if [ "$show_content" = "y" ]; then
    echo ""
    echo -e "${BLUE}打包内容:${NC}"
    tar -tzf "$PACKAGE_FILE" | head -50
    echo ""
    if [ $(tar -tzf "$PACKAGE_FILE" | wc -l) -gt 50 ]; then
        echo "... (更多内容请查看 MANIFEST.txt)"
    fi
fi

echo ""
echo -e "${GREEN}打包文件已保存到: ${PACKAGE_FILE}${NC}"
echo ""

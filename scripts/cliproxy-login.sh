#!/bin/bash
# CLIProxyAPI Claude 账号登录辅助脚本

set -e

REMOTE_HOST="ali"
TUNNEL_PORT="54545"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   CLIProxyAPI Claude 账号登录辅助工具          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# 步骤 1: 建立 SSH 隧道
echo -e "${CYAN}步骤 1/4: 建立 SSH 隧道${NC}"
echo -e "${YELLOW}正在检查 SSH 隧道...${NC}"

# 检查端口是否已被占用
if lsof -Pi :$TUNNEL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  端口 $TUNNEL_PORT 已被占用${NC}"
    echo -e "是否要终止占用进程? (y/n)"
    read -r answer
    if [[ "$answer" == "y" ]]; then
        PID=$(lsof -Pi :$TUNNEL_PORT -sTCP:LISTEN -t)
        kill -9 $PID 2>/dev/null || true
        echo -e "${GREEN}✓ 已终止进程${NC}"
    else
        echo -e "${RED}请手动终止占用 $TUNNEL_PORT 的进程${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}正在后台建立 SSH 隧道...${NC}"
ssh -f -N -L $TUNNEL_PORT:127.0.0.1:$TUNNEL_PORT $REMOTE_HOST

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SSH 隧道已建立 (本地:$TUNNEL_PORT -> 服务器:$TUNNEL_PORT)${NC}"
    sleep 2
else
    echo -e "${RED}✗ SSH 隧道建立失败${NC}"
    exit 1
fi
echo ""

# 步骤 2: 启动登录流程
echo -e "${CYAN}步骤 2/4: 启动 Claude OAuth 登录${NC}"
echo -e "${YELLOW}正在连接到 CLIProxyAPI...${NC}"

# 在后台启动登录进程，捕获输出
LOGIN_OUTPUT=$(mktemp)
ssh $REMOTE_HOST "docker exec cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login -no-browser" > "$LOGIN_OUTPUT" 2>&1 &
LOGIN_PID=$!

# 等待 OAuth URL 生成
sleep 3

# 提取 OAuth URL
OAUTH_URL=$(grep -o 'https://claude.ai/oauth/authorize[^[:space:]]*' "$LOGIN_OUTPUT")

if [ -z "$OAUTH_URL" ]; then
    echo -e "${RED}✗ 无法获取 OAuth URL${NC}"
    cat "$LOGIN_OUTPUT"
    kill $LOGIN_PID 2>/dev/null || true
    rm "$LOGIN_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ OAuth URL 已生成${NC}"
echo ""

# 步骤 3: 打开浏览器
echo -e "${CYAN}步骤 3/4: 浏览器授权${NC}"
echo -e "${YELLOW}正在打开浏览器进行授权...${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}OAuth URL:${NC}"
echo -e "${CYAN}$OAUTH_URL${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 根据操作系统打开浏览器
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open "$OAUTH_URL" 2>/dev/null
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    xdg-open "$OAUTH_URL" 2>/dev/null || firefox "$OAUTH_URL" 2>/dev/null || google-chrome "$OAUTH_URL" 2>/dev/null
fi

echo -e "${YELLOW}请在浏览器中：${NC}"
echo -e "  1. 登录你的 Claude 账号"
echo -e "  2. 点击 ${GREEN}'Authorize'${NC} 按钮授权"
echo -e "  3. 授权成功后返回此窗口"
echo ""

# 步骤 4: 等待认证完成
echo -e "${CYAN}步骤 4/4: 等待授权完成${NC}"
echo -e "${YELLOW}等待 Claude 授权回调...${NC}"

# 监控登录进程
TIMEOUT=180  # 3 分钟超时
ELAPSED=0
SUCCESS=false

while [ $ELAPSED -lt $TIMEOUT ]; do
    if ! kill -0 $LOGIN_PID 2>/dev/null; then
        # 进程已结束
        if grep -q "Authentication successful\|successfully" "$LOGIN_OUTPUT"; then
            SUCCESS=true
        fi
        break
    fi

    sleep 2
    ELAPSED=$((ELAPSED + 2))

    # 每 10 秒显示一次进度
    if [ $((ELAPSED % 10)) -eq 0 ]; then
        echo -e "${YELLOW}  等待中... (${ELAPSED}s/${TIMEOUT}s)${NC}"
    fi
done

# 清理
kill $LOGIN_PID 2>/dev/null || true

# 检查结果
echo ""
if [ "$SUCCESS" = true ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ✓ Claude 账号登录成功!                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # 重启 cliproxy 加载新账号
    echo -e "${YELLOW}正在重启 CLIProxyAPI 加载账号...${NC}"
    ssh $REMOTE_HOST "cd /opt/one_hub && docker compose restart cliproxy" > /dev/null 2>&1
    sleep 5

    # 显示账号信息
    echo -e "${CYAN}当前已登录账号:${NC}"
    ACCOUNT_INFO=$(ssh $REMOTE_HOST "docker logs cliproxy 2>&1 | grep 'clients' | tail -1")
    echo -e "  $ACCOUNT_INFO"
    echo ""

    echo -e "${GREEN}下一步操作:${NC}"
    echo -e "  1. 在 One-Hub 中添加渠道"
    echo -e "  2. 渠道地址: ${CYAN}http://cliproxy:8080/v1${NC}"
    echo -e "  3. 渠道类型: ${CYAN}OpenAI${NC}"
    echo -e "  4. 支持模型: ${CYAN}Claude 系列${NC}"

else
    echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║            ✗ 登录失败或超时                     ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}可能的原因:${NC}"
    echo -e "  1. 授权超时 (${TIMEOUT} 秒)"
    echo -e "  2. 未在浏览器中完成授权"
    echo -e "  3. SSH 隧道断开"
    echo ""
    echo -e "${YELLOW}建议:${NC}"
    echo -e "  • 重新运行此脚本"
    echo -e "  • 检查网络连接"
    echo -e "  • 查看完整日志: ${CYAN}cat $LOGIN_OUTPUT${NC}"
fi

# 清理临时文件
rm "$LOGIN_OUTPUT" 2>/dev/null || true

# 关闭 SSH 隧道
echo ""
echo -e "${YELLOW}正在清理 SSH 隧道...${NC}"
TUNNEL_PID=$(lsof -ti:$TUNNEL_PORT)
if [ -n "$TUNNEL_PID" ]; then
    kill $TUNNEL_PID 2>/dev/null || true
    echo -e "${GREEN}✓ SSH 隧道已关闭${NC}"
fi

echo ""

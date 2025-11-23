#!/bin/bash
# Clash 节点管理脚本
# 用途: 查看和切换 Clash 代理节点

set -e

CLASH_API="http://127.0.0.1:9090"
US_PROXY_GROUP="🇺🇸 美国节点"
CLAUDE_PROXY_GROUP="🤖 Claude"
OPENAI_PROXY_GROUP="🌐 OpenAI"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo -e "${BLUE}Clash 节点管理工具${NC}"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  status      查看当前使用的节点"
    echo "  list        列出所有可用的美国节点"
    echo "  switch <编号>  切换到指定编号的美国节点"
    echo "  test        测试当前节点连通性"
    echo "  help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 status          # 查看当前节点"
    echo "  $0 list            # 列出美国节点"
    echo "  $0 switch 2        # 切换到美国2号节点"
    echo ""
}

# URL 编码函数
urlencode() {
    python3 -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))" "$1"
}

# 获取代理组信息
get_proxy_group() {
    local group_name="$1"
    local encoded_name=$(urlencode "$group_name")
    docker exec clash wget -qO- "http://127.0.0.1:9090/proxies/${encoded_name}" 2>/dev/null || echo "{}"
}

# 查看当前节点状态
show_status() {
    echo -e "${BLUE}=== Clash 当前节点状态 ===${NC}"
    echo ""

    # 美国节点组
    local us_info=$(get_proxy_group "$US_PROXY_GROUP")
    local us_current=$(echo "$us_info" | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}🇺🇸 美国节点组:${NC}"
    echo -e "  当前节点: ${YELLOW}${us_current}${NC}"
    echo ""

    # Claude 代理组
    local claude_info=$(get_proxy_group "$CLAUDE_PROXY_GROUP")
    local claude_current=$(echo "$claude_info" | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}🤖 Claude 代理:${NC}"
    echo -e "  当前选择: ${YELLOW}${claude_current}${NC}"
    echo ""

    # OpenAI 代理组
    local openai_info=$(get_proxy_group "$OPENAI_PROXY_GROUP")
    local openai_current=$(echo "$openai_info" | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}🌐 OpenAI 代理:${NC}"
    echo -e "  当前选择: ${YELLOW}${openai_current}${NC}"
    echo ""
}

# 列出所有美国节点
list_us_nodes() {
    echo -e "${BLUE}=== 可用美国节点列表 ===${NC}"
    echo ""

    local us_info=$(get_proxy_group "$US_PROXY_GROUP")
    local nodes=$(echo "$us_info" | grep -o '"all":\[[^]]*\]' | sed 's/"all":\[//;s/\]//' | tr ',' '\n' | sed 's/"//g')

    local index=1
    while IFS= read -r node; do
        if [[ -n "$node" ]]; then
            # 高亮 VIP2 IPLC 节点
            if [[ "$node" =~ "VIP2" ]] && [[ "$node" =~ "IPLC" ]]; then
                echo -e "  ${GREEN}${index}. ${node} ⭐${NC}"
            elif [[ "$node" =~ "VIP2" ]]; then
                echo -e "  ${YELLOW}${index}. ${node}${NC}"
            else
                echo -e "  ${index}. ${node}"
            fi
            ((index++))
        fi
    done <<< "$nodes"
    echo ""
    echo -e "${YELLOW}提示: ⭐ 标记为推荐节点 (VIP2 IPLC 专线)${NC}"
    echo ""
}

# 切换美国节点
switch_node() {
    local node_index=$1

    if [[ ! "$node_index" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: 节点编号必须是数字${NC}"
        exit 1
    fi

    echo -e "${BLUE}正在切换节点...${NC}"

    # 获取节点列表
    local us_info=$(get_proxy_group "$US_PROXY_GROUP")
    local nodes=$(echo "$us_info" | grep -o '"all":\[[^]]*\]' | sed 's/"all":\[//;s/\]//' | tr ',' '\n' | sed 's/"//g')

    # 获取指定编号的节点
    local target_node=$(echo "$nodes" | sed -n "${node_index}p")

    if [[ -z "$target_node" ]]; then
        echo -e "${RED}错误: 节点编号 ${node_index} 不存在${NC}"
        echo -e "${YELLOW}请使用 '$0 list' 查看可用节点${NC}"
        exit 1
    fi

    echo -e "目标节点: ${YELLOW}${target_node}${NC}"

    # 切换节点
    local encoded_group=$(urlencode "$US_PROXY_GROUP")
    local result=$(docker exec clash wget -qO- --method=PUT \
        --body-data="{\"name\":\"${target_node}\"}" \
        --header='Content-Type: application/json' \
        "http://127.0.0.1:9090/proxies/${encoded_group}" 2>&1)

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ 节点切换成功!${NC}"
        echo ""
        show_status
    else
        echo -e "${RED}❌ 节点切换失败${NC}"
        echo "$result"
        exit 1
    fi
}

# 测试节点连通性
test_connectivity() {
    echo -e "${BLUE}=== 测试节点连通性 ===${NC}"
    echo ""

    echo -e "${YELLOW}测试 1: 访问 Google${NC}"
    if docker exec cliproxy curl -s -x http://clash:7890 -I https://www.google.com --max-time 10 | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✅ Google 访问正常${NC}"
    else
        echo -e "${RED}❌ Google 访问失败${NC}"
    fi
    echo ""

    echo -e "${YELLOW}测试 2: 访问 Claude API${NC}"
    if docker exec cliproxy curl -s -x http://clash:7890 -I https://api.anthropic.com --max-time 10 | grep -q "200\|403"; then
        echo -e "${GREEN}✅ Claude API 可达${NC}"
    else
        echo -e "${RED}❌ Claude API 访问失败${NC}"
    fi
    echo ""

    echo -e "${YELLOW}测试 3: 访问 OpenAI API${NC}"
    if docker exec cliproxy curl -s -x http://clash:7890 -I https://api.openai.com --max-time 10 | grep -q "200\|301\|302\|403"; then
        echo -e "${GREEN}✅ OpenAI API 可达${NC}"
    else
        echo -e "${RED}❌ OpenAI API 访问失败${NC}"
    fi
    echo ""
}

# 主函数
main() {
    case "${1:-}" in
        status)
            show_status
            ;;
        list)
            list_us_nodes
            ;;
        switch)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}错误: 请指定节点编号${NC}"
                echo -e "${YELLOW}用法: $0 switch <编号>${NC}"
                echo -e "${YELLOW}使用 '$0 list' 查看可用节点${NC}"
                exit 1
            fi
            switch_node "$2"
            ;;
        test)
            test_connectivity
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"

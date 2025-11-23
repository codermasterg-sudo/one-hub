#!/bin/bash
# 快速查看 Clash 节点状态

echo "=== Clash 当前节点状态 ==="
echo ""

# 获取所有代理信息
PROXIES=$(docker exec clash wget -qO- http://127.0.0.1:9090/proxies 2>/dev/null)

# 提取美国节点当前选择
US_NODE=$(echo "$PROXIES" | grep -o "\"🇺🇸 美国节点\":{[^}]*\"now\":\"[^\"]*\"" | grep -o "\"now\":\"[^\"]*\"" | cut -d"\"" -f4)
echo "🇺🇸 美国节点组: $US_NODE"

# 提取 Claude 代理当前选择
CLAUDE_NODE=$(echo "$PROXIES" | grep -o "\"🤖 Claude\":{[^}]*\"now\":\"[^\"]*\"" | grep -o "\"now\":\"[^\"]*\"" | cut -d"\"" -f4)
echo "🤖 Claude 代理: $CLAUDE_NODE"

# 提取 OpenAI 代理当前选择
OPENAI_NODE=$(echo "$PROXIES" | grep -o "\"🌐 OpenAI\":{[^}]*\"now\":\"[^\"]*\"" | grep -o "\"now\":\"[^\"]*\"" | cut -d"\"" -f4)
echo "🌐 OpenAI 代理: $OPENAI_NODE"

# 提取国际流量当前选择
GLOBAL_NODE=$(echo "$PROXIES" | grep -o "\"🌍 国际流量\":{[^}]*\"now\":\"[^\"]*\"" | grep -o "\"now\":\"[^\"]*\"" | cut -d"\"" -f4)
echo "🌍 国际流量: $GLOBAL_NODE"

echo ""

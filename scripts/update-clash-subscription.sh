#!/bin/bash
# Clash 订阅自动更新脚本
# 用途: 定期更新 Clash 订阅配置(因订阅服务需要特定 User-Agent)

SUBSCRIPTION_URL="http://47.242.55.240/link/oAG8iCTRfICpwtkA?clash=2"
SUBSCRIPTION_FILE="/opt/one_hub/clash/subscriptions/my-subscription.yaml"
USER_AGENT="ClashForWindows/0.20.39"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始更新 Clash 订阅..."

# 下载订阅文件
if curl -s -A "${USER_AGENT}" "${SUBSCRIPTION_URL}" > "${SUBSCRIPTION_FILE}.tmp"; then
    # 检查下载的文件是否为有效 YAML (不是 HTML 错误页)
    if head -n 1 "${SUBSCRIPTION_FILE}.tmp" | grep -q '^#!MANAGED-CONFIG'; then
        mv "${SUBSCRIPTION_FILE}.tmp" "${SUBSCRIPTION_FILE}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 订阅更新成功"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 错误: 订阅返回无效内容"
        rm -f "${SUBSCRIPTION_FILE}.tmp"
        exit 1
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 错误: 订阅下载失败"
    rm -f "${SUBSCRIPTION_FILE}.tmp"
    exit 1
fi

#!/bin/bash
# Clash 订阅自动更新脚本（Docker 容器内运行）

SUBSCRIPTION_URL="http://47.242.55.240/link/oAG8iCTRfICpwtkA?clash=2"
# 容器内路径: /clash-config/subscriptions/my-subscription.yaml
# 检测是否在容器内运行
if [ -d "/clash-config" ]; then
    SUBSCRIPTION_FILE="/clash-config/subscriptions/my-subscription.yaml"
else
    # 宿主机路径
    SUBSCRIPTION_FILE="subscriptions/my-subscription.yaml"
fi
USER_AGENT="ClashForWindows/0.20.39"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始更新 Clash 订阅..."

# 下载订阅文件
if curl -s -A "${USER_AGENT}" "${SUBSCRIPTION_URL}" > "${SUBSCRIPTION_FILE}.tmp"; then
    # 检查下载的文件是否为有效 YAML (不是 HTML 错误页)
    if head -n 1 "${SUBSCRIPTION_FILE}.tmp" | grep -q '^#!MANAGED-CONFIG'; then
        mv "${SUBSCRIPTION_FILE}.tmp" "${SUBSCRIPTION_FILE}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ 订阅更新成功"

        # 触发 Clash 重新加载配置（通过 API）
        # 注意: Clash Premium 会自动检测文件变化，无需手动重载
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Clash 将自动检测并重载配置"
        exit 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ 错误: 订阅返回无效内容"
        rm -f "${SUBSCRIPTION_FILE}.tmp"
        exit 1
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ 错误: 订阅下载失败"
    rm -f "${SUBSCRIPTION_FILE}.tmp"
    exit 1
fi

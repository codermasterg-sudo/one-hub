# Clash 节点优化指南

> 提升 CLIProxy 响应速度的节点选择和测速方案

## 目录

- [问题背景](#问题背景)
- [方案一：自动选择最快节点](#方案一自动选择最快节点推荐)
- [方案二：手动测试和切换节点](#方案二手动测试和切换节点)
- [方案三：使用 Clash Dashboard](#方案三使用-clash-dashboard可视化管理)
- [性能调优建议](#性能调优建议)

---

## 问题背景

CLIProxy 通过 Clash 代理访问 Claude API，节点速度直接影响响应时间：

- **慢速节点**：延迟 300ms+，Claude 响应慢
- **快速节点**：延迟 < 150ms，体验流畅
- **不稳定节点**：丢包、超时，影响服务可用性

---

## 方案一：自动选择最快节点（推荐）

### 1. 修改配置文件

编辑 `/opt/one_hub/clash/config.yaml`，找到美国节点配置部分：

**原配置（手动选择）**：
```yaml
proxy-groups:
  - name: "🇺🇸 美国节点"
    type: select            # 手动选择模式
    use:
      - my-subscription
    filter: "(?i)美国|US|United States|America"
```

**优化配置（自动测速）**：
```yaml
proxy-groups:
  - name: "🇺🇸 美国节点"
    type: url-test          # 自动测速并选择最快节点
    use:
      - my-subscription
    filter: "(?i)美国|US|United States|America"
    url: "http://www.gstatic.com/generate_204"
    interval: 300          # 每5分钟测速一次
    tolerance: 50          # 延迟差异50ms内不切换（避免频繁切换）
```

### 2. 应用配置

```bash
# 远程服务器
ssh ali "cd /opt/one_hub && docker compose restart clash"

# 本地服务器
cd /opt/one_hub
docker compose restart clash
```

### 3. 配置说明

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `type: url-test` | 自动测速模式 | 必填 |
| `interval` | 测速间隔（秒） | 300（5分钟） |
| `tolerance` | 容差（ms） | 50（避免频繁切换） |
| `url` | 测速URL | `http://www.gstatic.com/generate_204` |

### 4. 验证

```bash
# 查看当前使用的节点
docker exec clash wget -q -O- http://localhost:9090/proxies/%F0%9F%87%BA%F0%9F%87%B8%20%E7%BE%8E%E5%9B%BD%E8%8A%82%E7%82%B9 | grep '"now"'

# 查看 Clash 日志
docker logs clash --tail 50
```

---

## 方案二：手动测试和切换节点

### 1. 查看可用节点列表

```bash
ssh ali 'docker exec clash wget -q -O- "http://localhost:9090/proxies" | python3 -m json.tool' | grep -A 5 "美国节点"
```

### 2. 切换到指定节点

```bash
# 切换美国节点组到 AA5美国2
ssh ali 'curl -X PUT http://localhost:9090/proxies/%F0%9F%87%BA%F0%9F%87%B8%20%E7%BE%8E%E5%9B%BD%E8%8A%82%E7%82%B9 \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"🇺🇲 AA5美国2 IPLC  VIP2 网址:nnbin.com\"}"'
```

### 3. 测试当前节点延迟

```bash
# 测试通过 Clash 访问 Claude API 的延迟
ssh ali 'time docker exec cliproxy wget -q -O- -e use_proxy=yes -e http_proxy=http://clash:7890 https://api.anthropic.com 2>&1 | head -1'
```

### 4. 批量测试所有节点（推荐）

在本地创建测试脚本：

```bash
cat > ~/test-clash-nodes.sh << 'EOF'
#!/bin/bash

# 美国节点列表（从你的机场订阅中获取）
nodes=(
  "AA5美国1"
  "AA5美国2"
  "AA5美国3"
  "AA5美国4"
  "AA5美国5"
)

echo "=========================================="
echo "测试美国节点访问 Claude API 延迟"
echo "=========================================="
echo ""

for node in "${nodes[@]}"; do
  echo -n "[$node] ... "

  # 切换节点（这里需要根据实际节点名称调整）
  # 然后测试延迟
  time=$(ssh ali "time docker exec cliproxy wget -q -O- -e use_proxy=yes -e http_proxy=http://clash:7890 https://api.anthropic.com 2>&1" 2>&1 | grep real | awk '{print $2}')

  echo "$time"
  sleep 2
done

echo ""
echo "✓ 选择延迟最低的节点获得最佳性能"
EOF

chmod +x ~/test-clash-nodes.sh
~/test-clash-nodes.sh
```

---

## 方案三：使用 Clash Dashboard（可视化管理）

### 1. 开放 Clash API 端口

修改 `docker-compose.yml`：

```yaml
clash:
  image: dreamacro/clash-premium:latest
  ports:
    - "7890:7890"  # HTTP 代理
    - "9090:9090"  # API 端口（添加这一行）
```

### 2. 重启服务

```bash
cd /opt/one_hub
docker compose up -d clash
```

### 3. 访问 Dashboard

在浏览器中打开：
```
http://39.96.192.116:9090/ui
```

或使用第三方 Dashboard：
- **Yacd**: https://yacd.haishan.me
  - API 地址：`http://39.96.192.116:9090`
  - Secret：留空（如未设置）

- **Clash Dashboard**: http://clash.razord.top
  - API 地址：`http://39.96.192.116:9090`

### 4. Dashboard 功能

- ✅ 可视化查看所有节点
- ✅ 实时测试节点延迟
- ✅ 一键切换节点
- ✅ 查看流量统计
- ✅ 规则管理

---

## 性能调优建议

### 1. 节点选择策略

| 场景 | 推荐节点类型 | 特点 |
|------|-------------|------|
| **Claude API** | 美国 IPLC/IEPL | 延迟低，稳定 |
| **OpenAI API** | 美国/新加坡 | 全球接入点 |
| **一般使用** | 香港/日本 | 低延迟，高带宽 |

### 2. 优化配置参数

```yaml
# 美国节点（Claude 专用）
- name: "🤖 Claude"
  type: url-test
  use:
    - my-subscription
  filter: "(?i)(美国|US).*IPLC"  # 优先选择 IPLC 线路
  url: "https://api.anthropic.com"  # 直接测试 Claude API
  interval: 180        # 3分钟测速一次（更频繁）
  tolerance: 30        # 30ms 容差（更敏感）
```

### 3. 健康检查优化

```yaml
proxy-providers:
  my-subscription:
    type: http
    url: "your-subscription-url"
    interval: 3600
    path: ./subscriptions/my-subscription.yaml
    health-check:
      enable: true
      interval: 180      # 3分钟检查一次（更频繁）
      url: http://www.gstatic.com/generate_204
      lazy: false        # 立即检查，不延迟
```

### 4. 监控和告警

```bash
# 定时检查 Clash 健康状态
*/5 * * * * docker exec clash wget -q -O- http://localhost:9090/ || echo "Clash API 异常" | mail -s "告警" your@email.com
```

---

## 故障排查

### 问题 1：所有节点延迟都很高

**可能原因**：
- 机场服务质量问题
- 本地网络问题
- Clash 配置错误

**解决方案**：
```bash
# 1. 测试宿主机网络
ping -c 5 8.8.8.8

# 2. 检查 Clash 日志
docker logs clash --tail 100

# 3. 手动测试节点
docker exec clash wget -q -O- http://www.gstatic.com/generate_204

# 4. 更新订阅
docker compose restart clash-subscription-updater
```

### 问题 2：节点频繁切换

**原因**：`tolerance` 设置太小

**解决方案**：
```yaml
tolerance: 100  # 增加到 100ms
```

### 问题 3：自动测速不工作

**检查**：
```bash
# 查看代理组类型
docker exec clash wget -q -O- http://localhost:9090/proxies | grep "type"

# 确认是 url-test 类型
# "type": "URLTest" 或 "url-test"
```

---

## 最佳实践总结

1. ✅ **使用 `url-test` 自动选择最快节点**
   - 设置合理的 `interval`（300秒）和 `tolerance`（50ms）

2. ✅ **过滤高质量线路**
   - 优先选择 IPLC/IEPL 专线
   - 使用 `filter` 正则表达式筛选

3. ✅ **定期测试和监控**
   - 每周检查节点质量
   - 关注 Clash 日志中的错误

4. ✅ **备份配置**
   - 修改前备份 `config.yaml`
   - 保存工作良好的配置版本

5. ✅ **使用 Dashboard 可视化管理**
   - 实时查看节点状态
   - 快速切换和测试

---

## 相关文档

- [Clash 配置说明](./clash节点配置说明.md)
- [CLIProxy 账号管理指南](./CLIProxy账号管理指南.md)
- [环境变量配置](./环境变量配置.md)

---

## 更新记录

- **2025-11-24 v1**：初始版本，包含三种节点优化方案

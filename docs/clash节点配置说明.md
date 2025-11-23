# Clash 固定节点配置说明

## 📌 配置目标

- **保持 IP 稳定**: 不自动切换节点，避免 IP 频繁变化
- **优先美国节点**: Claude/OpenAI 等服务固定使用美国节点
- **手动选择模式**: 所有代理组改为手动选择，移除自动测速切换

## ✅ 已完成的配置修改

### 1. 代理组类型修改

**修改前** (自动切换):
```yaml
- name: "🇺🇸 美国节点"
  type: url-test          # 每5分钟测速，自动切换最快节点
  interval: 300
  tolerance: 50
```

**修改后** (固定选择):
```yaml
- name: "🇺🇸 美国节点"
  type: select            # 手动选择，不自动切换
  # 移除 interval 和 tolerance 参数
```

### 2. 代理组配置详情

| 代理组 | 类型 | 默认节点 | 可用节点数 | 说明 |
|--------|------|----------|------------|------|
| 🇺🇸 美国节点 | select | 🇺🇲 AA5美国1 IPLC VIP2 | 10个 | VIP2 IPLC 专线，质量最优 |
| 🇭🇰 香港节点 | select | 🇭🇰 AA香港1 IPLC VIP2 | 12个 | 备用节点组 |
| 🇯🇵 日本节点 | select | 🇯🇵 AA6日本1 IPLC VIP2 | 4个 | 备用节点组 |
| 🚀 手动选择 | select | 🇺🇸 美国节点 | 全部节点 | 可选择任意节点 |

### 3. AI 服务代理组配置

所有 AI 服务默认使用美国节点:

```yaml
🤖 Claude → 🇺🇸 美国节点 (固定)
  └─ 🇺🇲 AA5美国1 IPLC VIP2 网址:nnbin.com

🌐 OpenAI → 🇺🇸 美国节点 (固定)
  └─ 🇺🇲 AA5美国1 IPLC VIP2 网址:nnbin.com

🌍 国际流量 → 🇺🇸 美国节点 (固定)
  └─ 🇺🇲 AA5美国1 IPLC VIP2 网址:nnbin.com
```

### 4. 移除的配置

- ❌ 删除 "⚡ 自动选择" 代理组 (自动测速切换)
- ❌ 删除 "♻️ 故障转移" 代理组 (自动故障切换)
- ❌ 移除所有 `url-test` 类型配置
- ❌ 移除 `interval` (测速间隔) 和 `tolerance` (容差) 参数

## 🔧 手动切换节点 (可选)

如果需要切换节点，可以通过 Clash API 或 Dashboard 手动操作:

### 方法 1: 使用 Clash API

```bash
# 查看当前使用的节点
docker exec clash wget -qO- http://127.0.0.1:9090/proxies/🇺🇸%20美国节点

# 切换到其他美国节点 (例如: 美国2号)
curl -X PUT http://localhost:9090/proxies/🇺🇸%20美国节点 \
  -H "Content-Type: application/json" \
  -d '{"name":"🇺🇲 AA5美国2 IPLC  VIP2 网址:nnbin.com"}'
```

### 方法 2: 使用 Clash Dashboard (推荐)

1. 访问 Clash Dashboard: `http://<服务器IP>:9090/ui`
2. 在 "Proxies" 页面选择代理组
3. 点击 "🇺🇸 美国节点" 代理组
4. 手动选择其他美国节点

## 📊 可用美国节点列表

### VIP2 节点 (推荐，IPLC 专线)

1. 🇺🇲 AA5美国1 IPLC VIP2 ⭐ (当前使用)
2. 🇺🇲 AA5美国2 IPLC VIP2
3. 🇺🇲 AA5美国3 IPLC VIP2
4. 🇺🇲 AA5美国4 IPLC VIP2
5. 🇺🇲 AA5美国5 IPLC VIP2
6. 🇺🇲 AA5美国6 V2ray

### VIP1 节点 (备用)

7. 🇺🇲 c美国1 VIP1
8. 🇺🇲 C美国2 VIP1
9. 🇺🇲 c美国3 VIP1
10. 🇺🇲 c美国4 VIP1

**推荐优先级**: VIP2 IPLC > VIP2 V2ray > VIP1

## 🎯 配置效果

### ✅ 优点

1. **IP 稳定**: 节点不会自动切换，保持固定 IP
2. **质量保证**: 默认使用最优质的 VIP2 IPLC 专线
3. **可控性强**: 可手动切换节点，完全可控
4. **资源节约**: 不进行定期测速，减少带宽消耗

### ⚠️ 注意事项

1. **手动维护**: 如果当前节点失效，需要手动切换到其他节点
2. **监控建议**: 建议定期检查节点连通性
3. **备用方案**: 保留了多个备用节点，可随时切换

## 🔄 订阅更新

订阅更新不会影响已选择的节点，更新后会:
- 保持当前选择的节点
- 更新节点列表 (可能新增或删除节点)
- 如果当前节点被删除，会自动选择列表第一个节点

**自动更新脚本**: `/opt/one_hub/scripts/update-clash-subscription.sh`

手动更新订阅:
```bash
ssh ali /opt/one_hub/scripts/update-clash-subscription.sh
```

## 📂 相关文件

- **配置文件**: `/opt/one_hub/clash/config-subscription.yaml`
- **订阅文件**: `/opt/one_hub/clash/subscriptions/my-subscription.yaml`
- **更新脚本**: `/opt/one_hub/scripts/update-clash-subscription.sh`

## 🆘 故障排查

### 节点无法连接

```bash
# 1. 检查 Clash 服务状态
docker compose ps clash

# 2. 查看 Clash 日志
docker logs clash --tail 50

# 3. 测试节点连通性 (通过 Clash 访问 Google)
docker exec cliproxy curl -x http://clash:7890 https://www.google.com -I
```

### 手动切换到备用节点

如果当前美国节点不可用:

```bash
# 切换到美国2号节点
docker exec clash wget -qO- --method=PUT \
  --body-data='{"name":"🇺🇲 AA5美国2 IPLC  VIP2 网址:nnbin.com"}' \
  --header='Content-Type: application/json' \
  http://127.0.0.1:9090/proxies/🇺🇸%20美国节点
```

### 临时切换到香港节点

```bash
# 修改 Claude 代理组使用香港节点
docker exec clash wget -qO- --method=PUT \
  --body-data='{"name":"🇭🇰 香港节点"}' \
  --header='Content-Type: application/json' \
  http://127.0.0.1:9090/proxies/🤖%20Claude
```

---

**最后更新**: 2025-11-23
**配置版本**: v1.0 (固定节点模式)

# Clash 配置目录

## 📁 文件说明

- `config.yaml` - Clash 主配置文件（符号链接，指向 config-subscription.yaml）
- `config-subscription.yaml` - **订阅模式配置（默认，推荐）**
- `config-manual.yaml` - 手动配置节点模式
- `subscriptions/` - 订阅文件缓存目录（自动生成）
- `ui/` - Clash Dashboard UI 文件（可选）

---

## 🚀 快速开始

### 默认配置（订阅模式）

项目已配置为**订阅模式**，`config.yaml` 链接到 `config-subscription.yaml`。

#### 1. 修改订阅链接

编辑 `clash/config-subscription.yaml`，修改订阅 URL：

```yaml
proxy-providers:
  my-subscription:
    type: http
    url: "https://your-subscription-url.com/link?token=change_this"  # ⚠️ 替换为您的订阅链接
    interval: 3600  # 每小时自动更新
```

或者使用环境变量（推荐）：

```bash
# 在 .env 文件中配置
CLASH_SUBSCRIPTION_URL=https://your-subscription-url.com/link?token=xxxxx
```

**获取订阅链接**：
- 从您的机场/代理服务商获取 Clash 订阅链接
- 通常格式为：`https://xxx.com/api/v1/client/subscribe?token=xxxxx`

#### 2. 启动服务

```bash
# 使用 Makefile（推荐）
make start

# 或使用 docker-compose
docker-compose up -d
```

#### 3. 验证

```bash
# 查看日志（应该显示订阅加载成功）
docker logs clash

# 测试代理
curl -x http://localhost:7890 https://www.google.com

# 访问 Dashboard
open http://localhost:9090/ui
```

### 切换到手动模式

如果您需要手动配置节点：

```bash
# 1. 删除旧的符号链接
rm clash/config.yaml

# 2. 创建新的符号链接指向手动配置
ln -s config-manual.yaml clash/config.yaml

# 3. 编辑手动配置文件
vim clash/config-manual.yaml

# 4. 重启 Clash
make clash-restart
```

### 切换回订阅模式

```bash
# 1. 删除旧的符号链接
rm clash/config.yaml

# 2. 创建新的符号链接指向订阅配置
ln -s config-subscription.yaml clash/config.yaml

# 3. 重启 Clash
make clash-restart
```

---

## 🇺🇸 美国节点自动选择

配置已经设置为**自动选择最快的美国节点**用于 Claude：

```yaml
# Claude 使用美国节点
proxy-groups:
  - name: "🇺🇸 美国节点"
    type: url-test       # 自动测速选择
    filter: "(?i)美国|US|United States|America|Los Angeles|..."
    interval: 300        # 每 5 分钟测速一次

  - name: "🤖 Claude"
    proxies:
      - "🇺🇸 美国节点"  # 优先使用美国节点
```

### 节点过滤规则

配置会自动匹配以下关键词的节点作为美国节点：

- `美国` / `US` / `United States` / `America`
- `Los Angeles` / `San Francisco` / `Silicon Valley`
- `New York` / `Seattle` / `Chicago`

**如果订阅中没有美国节点**，可以修改 `filter` 规则匹配其他地区。

---

## 🔄 订阅自动刷新

### 默认配置

```yaml
proxy-providers:
  my-subscription:
    interval: 3600  # 每小时（3600秒）自动更新订阅
```

### 自定义刷新间隔

```yaml
interval: 1800   # 30 分钟
interval: 7200   # 2 小时
interval: 86400  # 24 小时
```

### 手动刷新订阅

```bash
# 方式 1: 重启 Clash（会重新加载订阅）
docker-compose restart clash

# 方式 2: 使用 Clash API（推荐）
curl -X PUT http://localhost:9090/providers/proxies/my-subscription -H "Content-Type: application/json"

# 方式 3: 删除缓存后重启
rm -f clash/subscriptions/my-subscription.yaml
docker-compose restart clash
```

---

## 📊 查看节点和代理组

### 使用 Clash API

```bash
# 查看所有代理组
curl http://localhost:9090/proxies

# 查看特定代理组
curl http://localhost:9090/proxies/🇺🇸%20美国节点

# 查看订阅源状态
curl http://localhost:9090/providers/proxies
```

### 使用 Dashboard

访问 `http://localhost:9090/ui` 查看：
- 所有可用节点
- 代理组状态
- 延迟测试结果
- 流量统计

---

## 🔧 高级配置

### 1. 添加多个订阅源

```yaml
proxy-providers:
  # 主订阅
  subscription-1:
    type: http
    url: "https://sub1.com/link?token=xxx"
    interval: 3600
    path: ./subscriptions/sub1.yaml

  # 备用订阅
  subscription-2:
    type: http
    url: "https://sub2.com/link?token=xxx"
    interval: 3600
    path: ./subscriptions/sub2.yaml

proxy-groups:
  - name: "🇺🇸 美国节点"
    type: url-test
    use:
      - subscription-1
      - subscription-2  # 使用两个订阅源的节点
```

### 2. 自定义节点过滤

```yaml
# 只使用特定城市的节点
proxy-groups:
  - name: "🇺🇸 洛杉矶"
    type: url-test
    use:
      - my-subscription
    filter: "(?i)Los Angeles|LA"

  - name: "🇺🇸 纽约"
    type: url-test
    use:
      - my-subscription
    filter: "(?i)New York|NY"
```

### 3. 健康检查配置

```yaml
proxy-providers:
  my-subscription:
    health-check:
      enable: true
      interval: 300              # 每 5 分钟检查一次
      lazy: false                # false = 立即检查，true = 延迟检查
      url: http://www.gstatic.com/generate_204
```

### 4. 故障转移配置

```yaml
proxy-groups:
  - name: "♻️ Claude 故障转移"
    type: fallback              # 自动切换到可用节点
    use:
      - my-subscription
    filter: "(?i)美国|US"
    url: 'http://www.gstatic.com/generate_204'
    interval: 300
```

---

## 🐛 故障排查

### 问题 1: 订阅加载失败

**症状**：
```
[ERROR] Failed to update provider my-subscription
```

**解决方案**：
```bash
# 1. 检查订阅链接是否正确
curl -I "https://your-subscription-url.com/link?token=xxxxx"

# 2. 查看详细日志
docker logs clash

# 3. 删除缓存重新加载
rm -rf clash/subscriptions/*
docker-compose restart clash

# 4. 检查网络连接
docker exec clash wget -q -O - http://www.google.com
```

### 问题 2: 找不到美国节点

**症状**：代理组 `🇺🇸 美国节点` 为空

**解决方案**：
```bash
# 1. 查看订阅中的所有节点名称
cat clash/subscriptions/my-subscription.yaml | grep "name:"

# 2. 根据实际节点名称修改 filter 规则
# 例如，如果节点名称是 "美西01"，修改为：
# filter: "美西|美国"

# 3. 或者查看所有节点
curl http://localhost:9090/providers/proxies/my-subscription | jq .
```

### 问题 3: 订阅不自动更新

**症状**：订阅超过设定时间没有更新

**解决方案**：
```bash
# 1. 检查配置中的 interval 设置
grep interval clash/config.yaml

# 2. 手动触发更新
curl -X PUT http://localhost:9090/providers/proxies/my-subscription

# 3. 查看上次更新时间
curl http://localhost:9090/providers/proxies | jq '.providers.my-subscription.updatedAt'

# 4. 重启 Clash
docker-compose restart clash
```

### 问题 4: 节点延迟很高

**症状**：所有节点延迟都很高

**解决方案**：
```bash
# 1. 手动测试节点
curl -x http://localhost:7890 -w "@curl-format.txt" -o /dev/null -s https://www.google.com

# 2. 在 Dashboard 中手动测速
# 访问 http://localhost:9090/ui，点击 "Delay Test"

# 3. 调整测速 URL
# 使用更快的测速地址
url: 'https://cp.cloudflare.com/generate_204'
```

---

## 📝 配置文件对比

### 订阅模式 vs 手动模式

| 特性 | 订阅模式 | 手动模式 |
|------|----------|----------|
| 节点来源 | 从 URL 自动获取 | 手动添加 |
| 更新方式 | 自动定时更新 | 手动修改配置 |
| 节点数量 | 通常几十到上百个 | 较少 |
| 适用场景 | 有机场订阅 | 自建节点 |
| 配置难度 | ⭐ 简单 | ⭐⭐ 中等 |

### 何时使用订阅模式

✅ **推荐使用订阅模式**，如果您：
- 购买了机场服务
- 需要大量节点选择
- 希望节点自动更新
- 不想手动维护节点配置

---

## 🔒 安全建议

1. **保护订阅链接**
   ```bash
   # 不要将包含订阅链接的 config.yaml 提交到 Git
   # 已添加到 .gitignore
   ```

2. **使用环境变量**
   ```yaml
   # 可以使用环境变量存储订阅链接
   url: "${CLASH_SUBSCRIPTION_URL}"
   ```

3. **定期更换订阅链接**
   - 如果链接泄露，在机场后台重置订阅链接

---

## 📚 参考资源

- [Clash Premium 文档](https://github.com/Dreamacro/clash/wiki/premium-core-features)
- [Clash Dashboard](https://github.com/Dreamacro/clash-dashboard)
- [订阅转换工具](https://sub.xeton.dev/)

---

## 🆘 常用命令

```bash
# 启动 Clash
docker-compose up -d clash

# 查看日志
docker logs -f clash

# 重启 Clash
docker-compose restart clash

# 停止 Clash
docker-compose stop clash

# 测试代理
curl -x http://localhost:7890 https://www.google.com

# 查看代理组
curl http://localhost:9090/proxies

# 更新订阅
curl -X PUT http://localhost:9090/providers/proxies/my-subscription

# 切换代理组选择
curl -X PUT http://localhost:9090/proxies/🤖%20Claude -d '{"name":"🇺🇸 美国节点"}'
```

---

最后更新: 2025-11-23

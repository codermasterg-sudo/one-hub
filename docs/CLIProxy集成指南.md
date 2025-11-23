# CLIProxyAPI 集成 One-Hub 完整指南

CLIProxyAPI 是最适合 One-Hub 的 Claude OAuth2 代理方案，支持轻量级部署、多账号负载均衡、认证简便。

---

## 🎯 为什么选择 CLIProxyAPI

### 核心优势

| 特性 | 说明 |
|------|------|
| **轻量级** | Go 实现，内存占用 ~30MB |
| **多账号支持** | ✅ 支持多个 Claude 账号负载均衡 |
| **统一 API** | OpenAI/Anthropic 兼容格式 |
| **认证简单** | OAuth2 一次认证，自动令牌刷新 |
| **成熟稳定** | 1.7k stars，256 个版本 |
| **多 CLI 支持** | Claude + Gemini + Codex + Qwen + iFlow |

### 与其他方案对比

| 方案 | 轻量级 | 多账号 | 认证难度 | One-Hub 集成 |
|------|--------|--------|---------|-------------|
| **CLIProxyAPI** | ✅ 30MB | ✅ 负载均衡 | ⭐⭐ 简单 | ✅ 完美 |
| ccproxy-api | ⚠️ 50MB | ❌ 单账号 | ⭐⭐⭐ 中等 | ✅ 良好 |
| claudine-proxy | ✅ 120KB | ❌ 单账号 | ⭐ 极简 | ✅ 良好 |
| ccproxy | ❌ 100MB | ⚠️ 复杂 | ⭐⭐⭐⭐ 复杂 | ✅ 良好 |

---

## 📦 快速部署

### 方式一：Docker Compose（推荐）

#### 1. 更新 docker-compose.yml

在您的 `docker-compose.yml` 中添加：

```yaml
services:
  # ... 其他服务 (one-hub, redis, mysql, clash)

  cliproxy:
    image: ghcr.io/router-for-me/cliproxy-api:latest
    container_name: cliproxy
    restart: always
    ports:
      - "8080:8080"
    volumes:
      - ./cliproxy/auth:/app/auth          # 认证凭证目录
      - ./cliproxy/config.yaml:/app/config.yaml  # 配置文件
    environment:
      - TZ=Asia/Shanghai
      # 如需通过 Clash 代理访问
      - HTTP_PROXY=http://clash:7890
      - HTTPS_PROXY=http://clash:7890
    depends_on:
      - clash
    networks:
      - one-hub-network
    command: ["--config", "/app/config.yaml", "--port", "8080"]
```

#### 2. 创建配置文件

```bash
# 创建目录
mkdir -p cliproxy

# 创建配置文件
cat > cliproxy/config.yaml << 'EOF'
# CLIProxyAPI 配置文件

# 服务端口
port: 8080

# 认证目录
auth_dir: /app/auth

# 启用的提供商
providers:
  # Claude Code
  - name: claude
    enabled: true
    type: claude_code
    load_balancing: true  # 启用负载均衡

  # 可选：同时支持其他 CLI
  # - name: gemini
  #   enabled: true
  #   type: gemini_cli

  # - name: codex
  #   enabled: true
  #   type: openai_codex

# API 格式兼容性
api_compatibility:
  openai: true      # OpenAI 格式
  anthropic: true   # Anthropic 格式

# 日志级别
log_level: info

# 流式响应
streaming: true

# 函数调用支持
function_calling: true
EOF
```

#### 3. 启动服务

```bash
docker-compose up -d cliproxy
```

---

## 🔐 认证配置

### 单账号认证

```bash
# 进入容器
docker exec -it cliproxy sh

# Claude Code 登录
cliproxy auth login --provider claude

# 按照提示在浏览器中完成 OAuth2 认证
# 认证成功后，凭证会保存到 /app/auth 目录
```

### 多账号配置（负载均衡）

```bash
# 登录第一个账号
docker exec -it cliproxy cliproxy auth login --provider claude --account account1

# 登录第二个账号
docker exec -it cliproxy cliproxy auth login --provider claude --account account2

# 登录第三个账号
docker exec -it cliproxy cliproxy auth login --provider claude --account account3

# 查看所有账号
docker exec -it cliproxy cliproxy auth list
```

输出示例：
```
Provider: claude
Accounts:
  ✓ account1 (email1@example.com) - Active
  ✓ account2 (email2@example.com) - Active
  ✓ account3 (email3@example.com) - Active

Load Balancing: Round Robin
```

### 验证认证状态

```bash
# 验证所有账号
docker exec -it cliproxy cliproxy auth validate

# 查看账号详情
docker exec -it cliproxy cliproxy auth info --provider claude
```

---

## 🔗 One-Hub 渠道配置

### 方式一：使用 Anthropic 格式（推荐）

在 One-Hub 管理后台添加渠道：

| 配置项 | 值 |
|--------|-----|
| **渠道名称** | Claude OAuth2 (CLIProxy) |
| **渠道类型** | Anthropic Claude |
| **Base URL** | `http://cliproxy:8080/v1` |
| **API Key** | `dummy-key`（任意值） |
| **模型列表** | `claude-sonnet-4-20250514,claude-3-5-sonnet-20241022,claude-3-5-haiku-20241022,claude-opus-4-20250514` |
| **代理** | 留空（已通过环境变量配置） |
| **优先级** | 10 |

### 方式二：使用 OpenAI 兼容格式

| 配置项 | 值 |
|--------|-----|
| **渠道名称** | Claude OAuth2 (OpenAI 格式) |
| **渠道类型** | OpenAI |
| **Base URL** | `http://cliproxy:8080` |
| **API Key** | `dummy-key` |
| **模型列表** | `claude-sonnet-4,claude-3-5-sonnet,claude-3-5-haiku` |

### 测试渠道

点击"测试"按钮，发送测试请求：

```json
{
  "model": "claude-sonnet-4-20250514",
  "messages": [
    {
      "role": "user",
      "content": "你好，请用中文回复"
    }
  ],
  "max_tokens": 100
}
```

成功响应表示配置正确！

---

## 🔄 负载均衡机制

### 工作原理

CLIProxyAPI 使用 **轮询（Round Robin）** 策略：

```
请求 1 → account1
请求 2 → account2
请求 3 → account3
请求 4 → account1
...
```

### 查看负载均衡状态

```bash
docker exec -it cliproxy cliproxy stats

# 输出示例：
# Provider: claude
# Total Requests: 1,234
#
# Account Statistics:
#   account1: 412 requests (33.4%)
#   account2: 411 requests (33.3%)
#   account3: 411 requests (33.3%)
```

### 账号故障转移

如果某个账号出现问题（令牌过期、配额耗尽等），CLIProxyAPI 会自动：

1. 检测到错误
2. 标记该账号为不可用
3. 自动切换到其他可用账号
4. 后台尝试恢复问题账号

---

## 📊 API 端点说明

### Anthropic 格式

```bash
# 聊天补全
POST http://cliproxy:8080/v1/messages
Content-Type: application/json
x-api-key: dummy-key
anthropic-version: 2023-06-01

{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 1024,
  "messages": [
    {"role": "user", "content": "Hello"}
  ]
}
```

### OpenAI 兼容格式

```bash
# 聊天补全
POST http://cliproxy:8080/v1/chat/completions
Content-Type: application/json
Authorization: Bearer dummy-key

{
  "model": "claude-sonnet-4",
  "messages": [
    {"role": "user", "content": "Hello"}
  ]
}
```

### 其他端点

```bash
# 模型列表
GET http://cliproxy:8080/v1/models

# 健康检查
GET http://cliproxy:8080/health

# 账号状态
GET http://cliproxy:8080/accounts/status
```

---

## 🔧 高级配置

### 自定义负载均衡策略

编辑 `cliproxy/config.yaml`：

```yaml
providers:
  - name: claude
    enabled: true
    type: claude_code
    load_balancing:
      enabled: true
      strategy: weighted  # 或 round_robin, least_connections
      weights:
        account1: 50  # 50% 流量
        account2: 30  # 30% 流量
        account3: 20  # 20% 流量
```

### 账号配额限制

```yaml
providers:
  - name: claude
    accounts:
      account1:
        daily_limit: 1000    # 每日请求限制
        rate_limit: 10       # 每分钟请求限制
      account2:
        daily_limit: 2000
        rate_limit: 20
```

### 自动令牌刷新

```yaml
auth:
  auto_refresh: true
  refresh_interval: 3600  # 每小时检查一次
  retry_on_failure: true
  retry_attempts: 3
```

### 启用监控

```yaml
monitoring:
  enabled: true
  prometheus:
    enabled: true
    port: 9090
  metrics:
    - request_count
    - response_time
    - account_usage
    - error_rate
```

---

## 🎛️ 管理和维护

### 查看日志

```bash
# 实时日志
docker logs -f cliproxy

# 最近 100 行
docker logs --tail 100 cliproxy
```

### 添加新账号

```bash
# 添加账号（不停机）
docker exec -it cliproxy cliproxy auth add --provider claude --account account4

# 重新加载配置
docker exec -it cliproxy cliproxy reload
```

### 删除账号

```bash
# 删除账号
docker exec -it cliproxy cliproxy auth remove --provider claude --account account2

# 确认删除
docker exec -it cliproxy cliproxy auth list
```

### 刷新令牌

```bash
# 刷新所有账号
docker exec -it cliproxy cliproxy auth refresh --all

# 刷新特定账号
docker exec -it cliproxy cliproxy auth refresh --account account1
```

### 配置热重载

```bash
# 修改配置后重新加载（不停机）
docker exec -it cliproxy cliproxy reload

# 或重启容器
docker-compose restart cliproxy
```

---

## 🚀 性能优化

### 连接池配置

```yaml
performance:
  connection_pool:
    max_connections: 100
    idle_timeout: 300
    max_idle_connections: 10

  request_timeout: 300  # 秒

  cache:
    enabled: true
    ttl: 3600
```

### 并发限制

```yaml
concurrency:
  max_concurrent_requests: 50
  per_account_limit: 20
  queue_size: 100
```

### 资源限制（Docker）

```yaml
cliproxy:
  # ... 其他配置
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 512M
      reservations:
        cpus: '0.25'
        memory: 128M
```

---

## 📈 监控和告警

### Prometheus 集成

```yaml
# docker-compose.yml
prometheus:
  image: prom/prometheus:latest
  ports:
    - "9091:9090"
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
  networks:
    - one-hub-network
```

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'cliproxy'
    static_configs:
      - targets: ['cliproxy:9090']
```

### 关键指标

监控以下指标：

- `cliproxy_requests_total` - 总请求数
- `cliproxy_requests_duration_seconds` - 请求延迟
- `cliproxy_account_requests_total` - 每个账号的请求数
- `cliproxy_errors_total` - 错误数
- `cliproxy_token_refresh_total` - 令牌刷新次数

---

## 🔍 故障排查

### 问题 1: 账号认证失败

**症状**：
```
Error: Authentication failed for account1
```

**解决方案**：
```bash
# 1. 检查账号状态
docker exec -it cliproxy cliproxy auth validate --account account1

# 2. 重新登录
docker exec -it cliproxy cliproxy auth login --provider claude --account account1

# 3. 验证
docker exec -it cliproxy cliproxy auth info --account account1
```

### 问题 2: 负载均衡不均匀

**症状**：某个账号接收了过多请求

**解决方案**：
```bash
# 1. 查看统计
docker exec -it cliproxy cliproxy stats

# 2. 检查配置
cat cliproxy/config.yaml | grep -A 10 load_balancing

# 3. 重置统计
docker exec -it cliproxy cliproxy stats reset
```

### 问题 3: 令牌频繁过期

**症状**：
```
Error: Token expired for account2
```

**解决方案**：

检查 `config.yaml`：
```yaml
auth:
  auto_refresh: true        # 确保启用
  refresh_interval: 3600    # 调整刷新间隔（秒）
  refresh_before_expiry: 600  # 提前 10 分钟刷新
```

### 问题 4: API 返回 429 Too Many Requests

**症状**：请求被限流

**解决方案**：
```yaml
# 添加更多账号分散流量
# 或调整并发限制
concurrency:
  per_account_limit: 10  # 降低单账号并发
  request_interval: 100  # 请求间隔（毫秒）
```

### 问题 5: One-Hub 无法连接 CLIProxy

**症状**：
```
Error: Connection refused to cliproxy:8080
```

**解决方案**：
```bash
# 1. 检查服务状态
docker-compose ps cliproxy

# 2. 检查网络
docker exec -it one-hub ping cliproxy

# 3. 检查端口
docker exec -it cliproxy netstat -tlnp | grep 8080

# 4. 查看日志
docker logs cliproxy
```

---

## 🔐 安全最佳实践

### 1. 凭证保护

```bash
# 设置正确的权限
chmod 700 cliproxy/auth
chmod 600 cliproxy/auth/*

# 添加到 .gitignore
echo "cliproxy/auth/" >> .gitignore
```

### 2. API 密钥管理

虽然 CLIProxy 不需要真实 API Key，但建议：

```yaml
# 配置 API Key 验证
security:
  api_key_validation: true
  allowed_keys:
    - "your-secret-key-1"
    - "your-secret-key-2"
```

在 One-Hub 中使用真实的密钥：
```
API Key: your-secret-key-1
```

### 3. 网络隔离

```yaml
# docker-compose.yml
networks:
  one-hub-network:
    driver: bridge
    internal: false  # 如果不需要外部访问，设为 true
```

### 4. 日志脱敏

```yaml
logging:
  sensitive_fields:
    - email
    - token
    - api_key
  redact: true
```

---

## 📚 完整示例

### 目录结构

```
one-hub/
├── docker-compose.yml
├── cliproxy/
│   ├── config.yaml
│   └── auth/              # 自动生成的认证凭证
│       ├── claude_account1.json
│       ├── claude_account2.json
│       └── claude_account3.json
├── clash/
│   └── config.yaml
└── data/
```

### 完整的 docker-compose.yml

```yaml
version: "3.4"

services:
  one-hub:
    image: martialbe/one-api:latest
    container_name: one-hub
    restart: always
    ports:
      - "3000:3000"
    volumes:
      - ./data:/data
    environment:
      - SQL_DSN=oneapi:123456@tcp(db:3306)/one-api
      - REDIS_CONN_STRING=redis://redis
      - SESSION_SECRET=random_string_change_me
      - USER_TOKEN_SECRET=random_string_32_chars_change_me
      - TZ=Asia/Shanghai
    depends_on:
      - redis
      - db
      - cliproxy
    networks:
      - one-hub-network

  redis:
    image: redis:latest
    container_name: redis
    restart: always
    networks:
      - one-hub-network
    volumes:
      - ./data/redis:/data
    command: redis-server --appendonly yes

  db:
    image: mysql:8.2.0
    restart: always
    container_name: mysql
    volumes:
      - ./data/mysql:/var/lib/mysql
    environment:
      TZ: Asia/Shanghai
      MYSQL_ROOT_PASSWORD: "OneAPI@justsong"
      MYSQL_USER: oneapi
      MYSQL_PASSWORD: "123456"
      MYSQL_DATABASE: one-api
    networks:
      - one-hub-network
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci

  clash:
    image: dreamacro/clash-premium:latest
    container_name: clash
    restart: always
    ports:
      - "7890:7890"
      - "7891:7891"
      - "9090:9090"
    volumes:
      - ./clash/config.yaml:/root/.config/clash/config.yaml:ro
    environment:
      - TZ=Asia/Shanghai
    networks:
      - one-hub-network

  cliproxy:
    image: ghcr.io/router-for-me/cliproxy-api:latest
    container_name: cliproxy
    restart: always
    ports:
      - "8080:8080"
    volumes:
      - ./cliproxy/auth:/app/auth
      - ./cliproxy/config.yaml:/app/config.yaml
    environment:
      - TZ=Asia/Shanghai
      - HTTP_PROXY=http://clash:7890
      - HTTPS_PROXY=http://clash:7890
    depends_on:
      - clash
    networks:
      - one-hub-network
    command: ["--config", "/app/config.yaml", "--port", "8080"]

networks:
  one-hub-network:
    driver: bridge
```

---

## 📖 参考资源

### 官方资源
- [CLIProxyAPI GitHub](https://github.com/router-for-me/CLIProxyAPI)
- [CLIProxyAPI 官方指南](https://help.router-for.me/)
- [增强版 ai-cli-proxy-api](https://github.com/tiendung/ai-cli-proxy-api)

### 社区资源
- [管理多个 Claude Code 账号](https://gist.github.com/KMJ-007/0979814968722051620461ab2aa01bf2)
- [Claude Code 多账号支持请求](https://github.com/anthropics/claude-code/issues/261)

### 相关文档
- [One-Hub 官方文档](https://one-hub-doc.vercel.app/)
- [Claude Code 文档](https://code.claude.com/docs)
- [Anthropic API 文档](https://docs.anthropic.com/)

---

## 🎉 快速开始总结

```bash
# 1. 创建配置目录
mkdir -p cliproxy

# 2. 创建配置文件
cat > cliproxy/config.yaml << 'EOF'
port: 8080
auth_dir: /app/auth
providers:
  - name: claude
    enabled: true
    type: claude_code
    load_balancing: true
api_compatibility:
  openai: true
  anthropic: true
log_level: info
EOF

# 3. 启动服务
docker-compose up -d cliproxy

# 4. 认证账号（多账号）
docker exec -it cliproxy cliproxy auth login --provider claude --account account1
docker exec -it cliproxy cliproxy auth login --provider claude --account account2
docker exec -it cliproxy cliproxy auth login --provider claude --account account3

# 5. 验证
docker exec -it cliproxy cliproxy auth list

# 6. 测试 API
curl http://localhost:8080/health

# 7. 在 One-Hub 中配置渠道
# Base URL: http://cliproxy:8080/v1
# API Key: dummy-key
```

完成！现在您有了一个轻量级、支持多账号负载均衡的 Claude 代理服务！

---

最后更新: 2025-11-23
版本: 1.0

# CLIProxyAPI 配置说明

这是 CLIProxyAPI 的配置目录，用于提供轻量级的多账号 Claude Code 代理服务。

## 目录结构

```
cliproxy/
├── config.yaml        # 主配置文件
├── auth/              # 认证凭证目录（自动生成）
│   ├── claude_account1.json
│   ├── claude_account2.json
│   └── claude_account3.json
└── README.md         # 本文件
```

## 快速开始

### 1. 启动服务

```bash
docker-compose up -d cliproxy
```

### 2. 认证 Claude 账号

#### 单账号认证
```bash
docker exec -it cliproxy cliproxy auth login --provider claude
```

#### 多账号认证（推荐）
```bash
# 账号 1
docker exec -it cliproxy cliproxy auth login --provider claude --account account1

# 账号 2
docker exec -it cliproxy cliproxy auth login --provider claude --account account2

# 账号 3
docker exec -it cliproxy cliproxy auth login --provider claude --account account3
```

每次执行后会打开浏览器，使用不同的 Claude 账号登录即可。

### 3. 验证认证状态

```bash
# 查看所有账号
docker exec -it cliproxy cliproxy auth list

# 验证凭证
docker exec -it cliproxy cliproxy auth validate
```

### 4. 测试 API

```bash
# 健康检查
curl http://localhost:8080/health

# 获取模型列表
curl http://localhost:8080/v1/models

# 测试聊天
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: dummy" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "你好"}]
  }'
```

## 在 One-Hub 中配置

### 方式一：Anthropic 格式（推荐）

- **渠道类型**: Anthropic Claude
- **Base URL**: `http://cliproxy:8080/v1`
- **API Key**: `dummy-key`（任意值）
- **模型列表**:
  ```
  claude-sonnet-4-20250514
  claude-3-5-sonnet-20241022
  claude-3-5-haiku-20241022
  claude-opus-4-20250514
  ```

### 方式二：OpenAI 兼容格式

- **渠道类型**: OpenAI
- **Base URL**: `http://cliproxy:8080`
- **API Key**: `dummy-key`
- **模型列表**:
  ```
  claude-sonnet-4
  claude-3-5-sonnet
  claude-3-5-haiku
  ```

## 负载均衡

当配置了多个账号时，请求会自动在账号间轮询分配：

```
请求 1 → account1
请求 2 → account2
请求 3 → account3
请求 4 → account1
...
```

查看负载均衡统计：
```bash
docker exec -it cliproxy cliproxy stats
```

## 管理命令

```bash
# 添加新账号
docker exec -it cliproxy cliproxy auth add --provider claude --account account4

# 删除账号
docker exec -it cliproxy cliproxy auth remove --provider claude --account account2

# 刷新令牌
docker exec -it cliproxy cliproxy auth refresh --all

# 重新加载配置
docker exec -it cliproxy cliproxy reload

# 查看日志
docker logs -f cliproxy
```

## 配置文件说明

编辑 `config.yaml` 可以调整：

- **负载均衡策略**: `round_robin`, `weighted`, `least_connections`
- **并发限制**: `max_concurrent_requests`
- **超时设置**: `request_timeout`
- **自动刷新**: `auto_refresh`, `refresh_interval`

修改后重新加载：
```bash
docker exec -it cliproxy cliproxy reload
```

## 故障排查

### 问题：认证失败

```bash
# 检查账号状态
docker exec -it cliproxy cliproxy auth validate --account account1

# 重新登录
docker exec -it cliproxy cliproxy auth login --provider claude --account account1
```

### 问题：API 无响应

```bash
# 查看服务状态
docker-compose ps cliproxy

# 查看日志
docker logs cliproxy

# 测试健康检查
curl http://localhost:8080/health
```

### 问题：令牌过期

令牌会自动刷新（如果配置了 `auto_refresh: true`）。

手动刷新：
```bash
docker exec -it cliproxy cliproxy auth refresh --all
```

## 注意事项

1. **凭证安全**: `auth/` 目录包含敏感信息，已添加到 `.gitignore`
2. **多账号**: 建议配置 2-3 个账号实现负载均衡
3. **代理配置**: 已配置通过 Clash 代理访问，确保 Clash 正常运行
4. **令牌刷新**: 每 1 小时自动检查并刷新令牌

## 更多信息

- [完整集成指南](../CLIPROXY_INTEGRATION.md)
- [CLIProxyAPI GitHub](https://github.com/router-for-me/CLIProxyAPI)
- [官方文档](https://help.router-for.me/)

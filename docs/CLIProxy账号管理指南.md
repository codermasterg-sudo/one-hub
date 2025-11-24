# CLIProxy 账号管理指南

> 基于 CLIProxyAPI v6.3+ 版本

本文档说明如何为 CLIProxy 添加和管理 Claude 账号，实现多账号负载均衡。

## 目录

- [前置要求](#前置要求)
- [添加 Claude 账号](#添加-claude-账号)
- [账号管理](#账号管理)
- [验证和测试](#验证和测试)
- [故障排查](#故障排查)

---

## 前置要求

在添加账号前，请确保：

1. ✅ CLIProxy 服务已启动运行
2. ✅ Clash 代理服务正常（CLIProxy 需要通过代理访问 Claude）
3. ✅ 准备好 Claude 账号（可以是多个不同的账号）

### 检查服务状态

```bash
# 本地检查
docker compose ps

# 远程服务器检查
ssh ali "cd /opt/one_hub && docker compose ps"

# 确认 cliproxy 和 clash 状态都是 Up (healthy)
```

---

## 添加 Claude 账号

### 基本命令格式

CLIProxyAPI 使用以下命令添加账号：

```bash
docker exec -it cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login
```

### 在本地服务器添加账号

```bash
# 进入项目目录
cd /path/to/one-hub

# 添加 Claude 账号
docker exec -it cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login
```

### 在远程服务器添加账号

```bash
# 通过 SSH 连接到远程服务器
ssh ali

# 进入项目目录
cd /opt/one_hub

# 添加 Claude 账号
docker exec -it cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login
```

### 登录流程

执行命令后会出现以下流程：

1. **获取授权链接**
   ```
   Please open the following URL in your browser:
   https://claude.ai/oauth/authorize?...
   ```

2. **浏览器授权**
   - 如果是本地服务器，浏览器会自动打开
   - 如果是远程服务器，需要手动复制链接到浏览器
   - 使用 Claude 账号登录
   - 完成授权

3. **确认成功**
   ```
   Successfully logged in to Claude
   Credentials saved to: /root/.cli-proxy-api/claude_XXXXX.json
   ```

### 添加多个账号

要添加多个 Claude 账号（实现负载均衡），需要：

#### 方法一：使用不同的浏览器会话

1. 添加第一个账号（使用默认浏览器）
   ```bash
   docker exec -it cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login
   ```

2. 添加第二个账号（使用隐私模式或不同浏览器）
   ```bash
   docker exec -it cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login
   ```
   在浏览器隐私模式中使用**不同的 Claude 账号**登录

3. 重复步骤 2 添加更多账号

#### 方法二：手动复制链接（推荐远程服务器）

如果无法自动打开浏览器，使用 `-no-browser` 参数：

```bash
docker exec -it cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login -no-browser
```

会输出授权链接：
```
Please open the following URL in your browser:
https://claude.ai/oauth/authorize?client_id=...

Waiting for authorization...
```

手动复制链接到浏览器完成授权。

### 重要提示

- 🔑 每个账号必须是**不同的 Claude 账号**（不同邮箱）
- 🌐 确保可以访问 `claude.ai`（通过 Clash 代理）
- 📱 如果需要双因素认证，请准备好手机
- ⏱️ 认证链接有时效性，请在 10 分钟内完成授权
- 🔄 每次执行登录命令都会添加一个新的凭证文件

---

## 账号管理

### 查看已添加的账号

```bash
# 查看认证文件
docker exec cliproxy ls -la /root/.cli-proxy-api/

# 输出示例：
# claude_abc123.json
# claude_def456.json
# claude_ghi789.json
```

每个 `claude_*.json` 文件代表一个已认证的账号。

### 查看账号凭证详情

```bash
# 查看特定凭证文件（仅查看基本信息，不要泄露完整内容）
docker exec cliproxy cat /root/.cli-proxy-api/claude_abc123.json | head -5
```

### 删除账号

```bash
# 删除特定账号的凭证
docker exec cliproxy rm /root/.cli-proxy-api/claude_abc123.json

# 删除所有账号
docker exec cliproxy rm -rf /root/.cli-proxy-api/claude_*.json
```

**注意**：删除后需要重启服务以重新加载凭证：
```bash
docker compose restart cliproxy
```

### 备份账号凭证

```bash
# 本地备份
docker cp cliproxy:/root/.cli-proxy-api ./cliproxy-auth-backup

# 远程备份
ssh ali "docker cp cliproxy:/root/.cli-proxy-api /tmp/" && \
scp -r ali:/tmp/.cli-proxy-api ./cliproxy-auth-backup
```

### 恢复账号凭证

```bash
# 恢复到容器
docker cp ./cliproxy-auth-backup/. cliproxy:/root/.cli-proxy-api/

# 重启服务
docker compose restart cliproxy
```

---

## 验证和测试

### 1. 检查服务健康状态

```bash
# 本地
curl http://localhost:8080/health

# 远程
ssh ali "curl http://localhost:8080/health"
```

预期输出：
```json
{
  "status": "healthy",
  "version": "v6.3.54"
}
```

### 2. 查看服务日志

```bash
# 实时查看日志
docker logs -f cliproxy

# 查看最近 50 行
docker logs --tail 50 cliproxy

# 查找认证相关日志
docker logs cliproxy 2>&1 | grep -i "claude\|auth\|login"
```

成功加载凭证的日志示例：
```
Loaded Claude credential: claude_abc123.json
Loaded Claude credential: claude_def456.json
Load balancing enabled with 2 accounts
```

### 3. 测试 API 接口

#### 测试模型列表

```bash
curl http://localhost:8080/v1/models
```

#### 测试聊天接口（Anthropic 格式）

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: dummy" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "你好，请简单介绍一下你自己"}]
  }'
```

#### 测试聊天接口（OpenAI 格式）

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer dummy" \
  -d '{
    "model": "claude-sonnet-4",
    "messages": [{"role": "user", "content": "你好"}],
    "max_tokens": 100
  }'
```

成功响应示例：
```json
{
  "id": "msg_xxx",
  "type": "message",
  "role": "assistant",
  "content": [{"type": "text", "text": "你好！我是 Claude..."}],
  "model": "claude-sonnet-4-20250514"
}
```

---

## 故障排查

### 问题 1：登录时无法打开浏览器

**症状**：
```
Error: unable to open browser
```

**解决方案**：
使用 `-no-browser` 参数手动复制链接：
```bash
docker exec -it cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login -no-browser
```

### 问题 2：代理连接失败

**症状**：
```
Error: dial tcp: lookup claude.ai: no such host
Error: connection timeout
```

**检查步骤**：
```bash
# 1. 检查 Clash 状态
docker compose ps clash

# 2. 测试代理连接
docker exec cliproxy curl -I -x http://clash:7890 https://claude.ai

# 3. 检查环境变量
docker exec cliproxy env | grep PROXY

# 4. 重启 Clash
docker compose restart clash

# 5. 重启 CLIProxy
docker compose restart cliproxy
```

### 问题 3：授权后没有保存凭证

**症状**：
完成浏览器授权后，终端显示错误或无反应

**解决方案**：
```bash
# 1. 检查认证目录权限
docker exec cliproxy ls -la /root/.cli-proxy-api/

# 2. 确保目录存在
docker exec cliproxy mkdir -p /root/.cli-proxy-api

# 3. 查看日志中的错误信息
docker logs cliproxy --tail 100

# 4. 重新登录
docker exec -it cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login
```

### 问题 4：API 请求失败

**症状**：
```
{"error": "no available accounts"}
{"error": "authentication failed"}
```

**检查步骤**：
```bash
# 1. 确认有可用的凭证文件
docker exec cliproxy ls /root/.cli-proxy-api/claude_*.json

# 2. 查看服务日志
docker logs cliproxy --tail 50

# 3. 测试凭证有效性（重新登录）
docker exec -it cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login

# 4. 重启服务
docker compose restart cliproxy
```

### 问题 5：多账号负载均衡不工作

**检查配置**：
```bash
# 查看配置文件
docker exec cliproxy cat /CLIProxyAPI/config.yaml | grep -A 10 "load_balancing"
```

确保配置如下：
```yaml
load_balancing:
  enabled: true
  strategy: round_robin
```

**查看账号使用情况**：
```bash
# 多次测试请求，观察日志
for i in {1..5}; do
  curl -s -X POST http://localhost:8080/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: dummy" \
    -H "anthropic-version: 2023-06-01" \
    -d '{"model":"claude-sonnet-4-20250514","max_tokens":10,"messages":[{"role":"user","content":"test"}]}' \
    > /dev/null
done

# 查看日志，应该看到不同账号被使用
docker logs cliproxy --tail 20 | grep -i "using account\|credential"
```

---

## 负载均衡说明

### 工作原理

CLIProxyAPI 会自动检测 `/root/.cli-proxy-api/` 目录中的所有 Claude 凭证文件，并在它们之间进行负载均衡。

**默认策略**：轮询（Round Robin）
```
请求 1 → claude_abc123.json
请求 2 → claude_def456.json
请求 3 → claude_ghi789.json
请求 4 → claude_abc123.json
...
```

### 配置调整

编辑 `cliproxy/config.yaml` 修改负载均衡策略：

```yaml
load_balancing:
  enabled: true
  # 可选策略：
  # - round_robin: 轮询（默认，推荐）
  # - weighted: 加权
  # - least_connections: 最少连接
  # - random: 随机
  strategy: round_robin
```

修改后重启服务：
```bash
docker compose restart cliproxy
```

---

## 在 One-Hub 中配置

添加账号后，在 One-Hub 中配置 CLIProxy 渠道：

### 方式一：Anthropic 格式（推荐）

1. 进入 One-Hub 管理后台
2. 渠道 → 添加渠道
3. 配置如下：
   - **渠道类型**：Anthropic Claude
   - **Base URL**：`http://cliproxy:8080/v1`
   - **API Key**：`dummy-key`（任意值）
   - **模型列表**：
     ```
     claude-sonnet-4-20250514
     claude-3-5-sonnet-20241022
     claude-3-5-haiku-20241022
     claude-opus-4-20250514
     ```
   - **代理**：留空（CLIProxy 已配置代理）

### 方式二：OpenAI 兼容格式

- **渠道类型**：OpenAI
- **Base URL**：`http://cliproxy:8080`
- **API Key**：`dummy-key`
- **模型列表**：
  ```
  claude-sonnet-4
  claude-3-5-sonnet
  claude-3-5-haiku
  ```

---

## 最佳实践

### 1. 账号数量建议

- **个人测试**：1 个账号
- **小团队**：2-3 个账号
- **生产环境**：3-5 个账号

### 2. 定期维护

```bash
# 每周检查凭证文件
docker exec cliproxy ls -la /root/.cli-proxy-api/

# 定期备份凭证
docker cp cliproxy:/root/.cli-proxy-api ./backups/cliproxy-$(date +%Y%m%d)

# 查看服务运行状态
docker compose ps cliproxy
docker logs cliproxy --tail 50
```

### 3. 安全建议

- ⚠️ 不要将 `cliproxy/auth/` 目录提交到 Git
- ⚠️ 定期备份凭证文件到安全位置
- ⚠️ 不要在日志中记录完整的认证信息
- ⚠️ 使用 HTTPS 访问 One-Hub（如果暴露到公网）

---

## 常见问题 FAQ

**Q: CLIProxyAPI 是什么？**
A: CLIProxyAPI 是一个将 Claude Code CLI 转换为 API 接口的代理服务，支持 Anthropic 和 OpenAI 格式。

**Q: 一个 Claude 账号可以添加多次吗？**
A: 可以，但不推荐。每次登录都会生成新的凭证文件，可能导致冲突或速率限制。

**Q: 免费账号和付费账号有区别吗？**
A: CLIProxyAPI 都支持，但付费账号通常有更高的速率限制。

**Q: 凭证文件会过期吗？**
A: 会。CLIProxyAPI 会自动刷新令牌（如果配置了 `auto_refresh: true`）。如果认证失败，需要重新登录。

**Q: 如何知道正在使用哪个账号？**
A: 查看服务日志：`docker logs cliproxy | grep -i "using\|credential"`

**Q: 可以手动指定使用某个账号吗？**
A: 当前版本不支持。CLIProxyAPI 会根据配置的策略自动选择账号。

**Q: 删除凭证文件后需要重启服务吗？**
A: 是的。执行 `docker compose restart cliproxy` 以重新加载凭证。

---

## 相关文档

- [CLIProxy 配置说明](../cliproxy/README.md)
- [CLIProxy 配置文件](../cliproxy/config.yaml)
- [环境变量配置](./环境变量配置.md)
- [CLIProxyAPI GitHub](https://github.com/router-for-me/CLIProxyAPI)

---

## 更新记录

- **2025-11-24 v2**：更新为实际的 CLIProxyAPI v6.3.54 命令格式
- **2025-11-24 v1**：初始版本

# Claude Code OAuth2 登录指南

本指南详细说明如何使用 ccproxy-api 登录 Claude Code 账号。

## 前置要求

- 有效的 Claude Pro 或 Claude Max 订阅
- Docker 和 Docker Compose 已安装
- 浏览器可访问（用于 OAuth2 认证）

---

## 方法一：Docker 容器内登录（推荐）

### 步骤 1: 启用 claude-proxy 服务

编辑 `docker-compose.yml`，取消 `claude-proxy` 服务的注释：

```yaml
claude-proxy:
  image: caddyglow/ccproxy-api:latest
  container_name: claude-proxy
  restart: always
  ports:
    - "8000:8000"
  volumes:
    - ./claude-proxy/credentials:/root/.claude
    - ./claude-proxy/config:/root/.config
  environment:
    - TZ=Asia/Shanghai
    - HTTP_PROXY=http://clash:7890
    - HTTPS_PROXY=http://clash:7890
  depends_on:
    - clash
  networks:
    - one-hub-network
```

### 步骤 2: 创建必要的目录

```bash
mkdir -p claude-proxy/credentials
mkdir -p claude-proxy/config
```

### 步骤 3: 启动服务

```bash
docker-compose up -d claude-proxy
```

### 步骤 4: 进入容器执行登录

```bash
# 进入容器
docker exec -it claude-proxy bash

# 安装 ccproxy-api（如果镜像中未包含）
pip install ccproxy-api

# 执行 Claude OAuth2 登录
ccproxy auth login
```

### 步骤 5: 完成 OAuth2 认证

执行 `ccproxy auth login` 后，会出现以下提示：

```
Opening browser for authentication...
Please visit this URL if browser doesn't open automatically:
https://claude.ai/oauth/authorize?...

Waiting for authentication to complete...
```

**操作步骤**：
1. 浏览器会自动打开 Claude 登录页面
2. 如果没有自动打开，手动复制 URL 到浏览器
3. 使用您的 Claude 账号登录（邮箱或 Google/GitHub 账号）
4. 授权应用访问您的 Claude 账号
5. 看到"Authentication successful"提示后，返回终端

### 步骤 6: 验证登录状态

```bash
# 验证凭证是否有效
ccproxy auth validate

# 查看账号信息
ccproxy auth info

# 查看令牌详情
ccproxy auth status
```

成功输出示例：
```
✓ Authentication valid
User: your-email@example.com
Plan: Claude Pro
Token expires: 2025-12-31 23:59:59
```

### 步骤 7: 退出容器

```bash
exit
```

### 步骤 8: 重启服务使配置生效

```bash
docker-compose restart claude-proxy
```

---

## 方法二：本地登录后挂载凭证文件

如果您的环境无法在容器内进行交互式登录（如无浏览器），可以在本地登录后挂载凭证。

### 步骤 1: 在本地安装 ccproxy-api

```bash
# 使用 pipx（推荐）
pipx install ccproxy-api

# 或使用 uv
uvx ccproxy-api

# 或使用 pip
pip install ccproxy-api
```

### 步骤 2: 在本地执行登录

```bash
ccproxy auth login
```

完成 OAuth2 认证流程（与方法一相同）。

### 步骤 3: 查找凭证文件位置

```bash
# 查看凭证存储位置
ccproxy auth info

# 通常位于：
# Linux/Mac: ~/.claude/.credentials.json
# Windows: %USERPROFILE%\.claude\.credentials.json
```

### 步骤 4: 复制凭证到项目目录

```bash
# Linux/Mac
mkdir -p claude-proxy/credentials
cp -r ~/.claude/* claude-proxy/credentials/

# Windows (PowerShell)
New-Item -ItemType Directory -Force -Path claude-proxy\credentials
Copy-Item -Recurse $env:USERPROFILE\.claude\* claude-proxy\credentials\
```

### 步骤 5: 修改 docker-compose.yml 挂载路径

确保挂载配置正确：

```yaml
volumes:
  - ./claude-proxy/credentials:/root/.claude:ro  # 只读挂载
```

### 步骤 6: 启动服务

```bash
docker-compose up -d claude-proxy
```

---

## 方法三：使用环境变量传递令牌（不推荐）

如果您已经有有效的访问令牌，可以直接通过环境变量传递。

### 步骤 1: 获取访问令牌

从 `~/.claude/.credentials.json` 文件中提取 `access_token`：

```bash
cat ~/.claude/.credentials.json | grep access_token
```

### 步骤 2: 在 docker-compose.yml 中添加环境变量

```yaml
claude-proxy:
  # ... 其他配置
  environment:
    - TZ=Asia/Shanghai
    - CLAUDE_ACCESS_TOKEN=your-access-token-here  # 添加此行
```

**注意**：此方法不推荐，因为：
- 令牌会过期，需要手动刷新
- 环境变量可能被记录在日志中
- 不如 OAuth2 流程安全

---

## 验证 Claude 代理是否工作

### 测试 1: 健康检查

```bash
curl http://localhost:8000/health
```

预期输出：
```json
{"status": "ok", "authenticated": true}
```

### 测试 2: 获取模型列表

```bash
curl http://localhost:8000/api/v1/models
```

### 测试 3: 发送测试请求

```bash
curl -X POST http://localhost:8000/api/v1/messages \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -H "x-api-key: dummy-key" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 1024,
    "messages": [
      {
        "role": "user",
        "content": "你好，请用中文回复"
      }
    ]
  }'
```

---

## 在 One-Hub 中配置 Claude 渠道

登录成功后，在 One-Hub 中添加渠道：

### 配置参数

1. **渠道名称**: Claude OAuth2
2. **渠道类型**: Anthropic Claude
3. **Base URL**: `http://claude-proxy:8000/api/v1`
4. **API Key**: `dummy-key`（任意值即可）
5. **模型列表**:
   - `claude-sonnet-4-20250514`
   - `claude-3-5-sonnet-20241022`
   - `claude-3-5-haiku-20241022`
   - `claude-opus-4-20250514`（需要 Max 订阅）
6. **代理设置**: 留空（已通过环境变量配置）
7. **其他参数**: 保持默认

### 测试渠道

在 One-Hub 管理后台点击"测试"按钮，验证渠道是否正常工作。

---

## 令牌管理

### 查看令牌状态

```bash
docker exec -it claude-proxy ccproxy auth status
```

### 刷新令牌

ccproxy-api 会自动刷新过期的令牌，无需手动操作。

如需手动刷新：

```bash
docker exec -it claude-proxy ccproxy auth refresh
```

### 重新登录

如果令牌失效或需要切换账号：

```bash
# 登出
docker exec -it claude-proxy ccproxy auth logout

# 重新登录
docker exec -it claude-proxy ccproxy auth login
```

---

## 故障排查

### 问题 1: 容器内无法打开浏览器

**错误信息**：
```
Error: Cannot open browser in headless environment
```

**解决方案**：使用方法二，在本地登录后挂载凭证文件。

### 问题 2: OAuth2 认证超时

**错误信息**：
```
Error: Authentication timeout
```

**解决方案**：
1. 检查网络连接
2. 确认 Clash 代理正常工作
3. 手动访问 OAuth URL 完成认证

### 问题 3: 凭证文件权限问题

**错误信息**：
```
Error: Permission denied reading credentials
```

**解决方案**：
```bash
# 修复权限
chmod -R 600 claude-proxy/credentials/*
chown -R 1000:1000 claude-proxy/credentials/  # 根据实际用户 ID 调整
```

### 问题 4: API 请求返回 401 Unauthorized

**原因**：令牌已过期或无效

**解决方案**：
```bash
# 验证令牌
docker exec -it claude-proxy ccproxy auth validate

# 如果无效，重新登录
docker exec -it claude-proxy ccproxy auth login
```

### 问题 5: 模型不可用

**错误信息**：
```
Error: Model not available for your plan
```

**解决方案**：
- `claude-opus-4` 需要 Claude Max 订阅
- 使用 `claude-sonnet-4` 或 `claude-3-5-sonnet` 代替

---

## 凭证文件结构

了解凭证文件结构有助于故障排查：

```json
{
  "access_token": "sk-ant-...",
  "refresh_token": "rt-ant-...",
  "expires_at": "2025-12-31T23:59:59Z",
  "user_id": "user-...",
  "email": "your-email@example.com"
}
```

---

## 安全建议

1. **保护凭证文件**
   - 不要将凭证文件提交到版本控制
   - 使用只读挂载：`:ro`
   - 定期检查文件权限

2. **定期验证令牌**
   ```bash
   # 添加到 crontab
   0 */6 * * * docker exec claude-proxy ccproxy auth validate
   ```

3. **监控异常访问**
   - 查看 Claude 账号的活动日志
   - 设置使用配额警报

4. **使用 HTTPS**
   - 生产环境中，在 One-Hub 前配置 Nginx + SSL

---

## 多账号支持

如果需要配置多个 Claude 账号：

### 方案 1: 多个代理实例

```yaml
claude-proxy-1:
  image: caddyglow/ccproxy-api:latest
  container_name: claude-proxy-1
  ports:
    - "8001:8000"
  volumes:
    - ./claude-proxy-1/credentials:/root/.claude
  # ... 其他配置

claude-proxy-2:
  image: caddyglow/ccproxy-api:latest
  container_name: claude-proxy-2
  ports:
    - "8002:8000"
  volumes:
    - ./claude-proxy-2/credentials:/root/.claude
  # ... 其他配置
```

在 One-Hub 中配置两个渠道，分别指向不同的端口。

---

## 相关命令参考

### ccproxy-api 常用命令

```bash
# 认证相关
ccproxy auth login              # 登录
ccproxy auth logout             # 登出
ccproxy auth validate           # 验证凭证
ccproxy auth info               # 查看账号信息
ccproxy auth status             # 查看令牌状态
ccproxy auth refresh            # 刷新令牌

# 服务相关
ccproxy serve                   # 启动服务器
ccproxy serve --port 8000       # 指定端口
ccproxy serve --host 0.0.0.0    # 监听所有接口

# 配置相关
ccproxy config show             # 显示配置
ccproxy config set KEY VALUE    # 设置配置
```

### Docker 相关命令

```bash
# 查看日志
docker logs claude-proxy
docker logs -f claude-proxy     # 实时日志

# 重启服务
docker-compose restart claude-proxy

# 进入容器
docker exec -it claude-proxy bash

# 查看容器状态
docker-compose ps claude-proxy
```

---

## 参考资源

- [ccproxy-api GitHub](https://github.com/CaddyGlow/ccproxy-api)
- [ccproxy-api 文档](https://caddyglow.github.io/ccproxy-api/)
- [Claude API 文档](https://docs.anthropic.com/)
- [OAuth 2.0 PKCE 规范](https://oauth.net/2/pkce/)

---

## 更新日志

- 2025-11-23: 初始版本
- 支持 ccproxy-api 最新版本
- 支持 Claude Sonnet 4 和 Opus 4 模型

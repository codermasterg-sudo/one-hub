# Claude Code 无浏览器登录方法

适用于服务器环境、Docker容器等无GUI环境的Claude OAuth2认证方案。

---

## 🚀 方法一：使用 claude setup-token（推荐）

这是官方提供的生成长期令牌的方法，**无需浏览器**。

### 步骤 1: 在有浏览器的设备上生成令牌

在您的**本地电脑**（Windows/Mac/Linux）上执行：

```bash
# 安装 Claude Code CLI（如果尚未安装）
npm install -g @anthropic-ai/claude-code

# 生成长期 OAuth 令牌
claude setup-token
```

执行后会：
1. 打开浏览器完成 OAuth 认证
2. 生成一个长期有效的令牌（~6小时有效期）
3. 在终端显示令牌字符串

### 步骤 2: 复制令牌到服务器

将生成的令牌通过以下任一方式传递到服务器：

#### 方法 A: 使用环境变量

在 `docker-compose.yml` 中配置：

```yaml
claude-proxy:
  image: caddyglow/ccproxy-api:latest
  container_name: claude-proxy
  restart: always
  ports:
    - "8000:8000"
  environment:
    - TZ=Asia/Shanghai
    - CLAUDE_CODE_OAUTH_TOKEN=你的令牌字符串  # 添加此行
    - HTTP_PROXY=http://clash:7890
    - HTTPS_PROXY=http://clash:7890
  depends_on:
    - clash
  networks:
    - one-hub-network
```

#### 方法 B: 手动创建凭证文件

```bash
# 创建凭证目录
mkdir -p claude-proxy/credentials

# 创建凭证文件
cat > claude-proxy/credentials/.credentials.json << 'EOF'
{
  "access_token": "你的令牌字符串",
  "token_type": "bearer",
  "expires_at": "2025-12-31T23:59:59Z"
}
EOF

# 启动服务
docker-compose up -d claude-proxy
```

### 步骤 3: 定期刷新令牌

令牌每隔 **~6小时** 会过期，需要定期刷新：

```bash
# 方案1: 在本地重新生成令牌并更新到服务器
claude setup-token

# 方案2: 如果 ccproxy-api 支持，使用 refresh token 自动刷新
docker exec -it claude-proxy ccproxy auth refresh
```

---

## 🔑 方法二：从已登录设备提取凭证

如果您在其他设备（本地电脑、另一台服务器）上已经登录过 Claude Code，可以直接复制凭证文件。

### macOS 用户

Claude Code 在 macOS 上将凭证存储在 **Keychain** 中，需要手动提取：

```bash
# 步骤 1: 打开 Keychain Access 应用
open "/Applications/Utilities/Keychain Access.app"

# 步骤 2: 搜索 "Claude"
# 会找到 "Claude Code-credentials" 条目

# 步骤 3: 双击条目，勾选 "Show password"
# 复制显示的 JSON 字符串

# 步骤 4: 创建凭证文件
mkdir -p claude-proxy/credentials
# 将复制的 JSON 粘贴到以下文件
nano claude-proxy/credentials/.credentials.json
```

### Linux/WSL 用户

```bash
# 步骤 1: 查看本地凭证文件
cat ~/.claude/.credentials.json

# 步骤 2: 复制到项目目录
cp ~/.claude/.credentials.json ./claude-proxy/credentials/

# 步骤 3: 启动服务
docker-compose up -d claude-proxy
```

### Windows 用户

```powershell
# 步骤 1: 查看凭证文件
type $env:USERPROFILE\.claude\.credentials.json

# 步骤 2: 复制到项目目录
Copy-Item $env:USERPROFILE\.claude\.credentials.json .\claude-proxy\credentials\

# 步骤 3: 启动服务
docker-compose up -d claude-proxy
```

---

## 📱 方法三：使用手机浏览器完成认证

如果服务器可以被外部访问，可以用手机浏览器完成 OAuth 认证。

### 步骤 1: 启用端口转发

确保 OAuth 回调端口可以从外部访问：

```bash
# 修改 docker-compose.yml，暴露额外端口
claude-proxy:
  ports:
    - "8000:8000"
    - "3031:3031"  # OAuth 回调端口
```

### 步骤 2: 进入容器执行登录

```bash
docker exec -it claude-proxy bash
ccproxy auth login
```

### 步骤 3: 复制 URL 到手机

终端会显示 OAuth 认证 URL：
```
Please visit: https://claude.ai/oauth/authorize?...
```

用**手机浏览器**打开此 URL，完成登录。

### 步骤 4: 等待认证完成

认证成功后，终端会显示：
```
✓ Authentication successful
```

---

## 🌐 方法四：从 Claude.ai 网站提取 Session Token

> ⚠️ **警告**: 此方法可能违反 Claude 服务条款，仅供学习参考。

### 步骤 1: 登录 Claude.ai

在浏览器中访问 https://claude.ai 并登录。

### 步骤 2: 提取 Session Token

#### Chrome/Edge 操作步骤

1. 按 `F12` 打开开发者工具
2. 切换到 **Application** 标签
3. 左侧菜单选择 **Storage > Cookies > https://claude.ai**
4. 查找名为 `sessionKey` 或 `__cf_bm` 的 Cookie
5. 复制其值

#### Firefox 操作步骤

1. 按 `F12` 打开开发者工具
2. 切换到 **Storage** 标签
3. 左侧菜单选择 **Cookies > https://claude.ai**
4. 查找 `sessionKey` Cookie
5. 复制其值

### 步骤 3: 转换为凭证格式

**注意**：Session Token 格式与 OAuth Token 不同，可能需要额外处理。

建议使用 **方法一或方法二** 获取正确的 OAuth Token。

---

## 🛠️ 方法五：SSH 端口转发（高级）

如果您通过 SSH 连接到远程服务器，可以使用端口转发将 OAuth 回调转发到本地浏览器。

### 步骤 1: 建立 SSH 隧道

在**本地电脑**执行：

```bash
# 转发远程服务器的 3031 端口（OAuth 回调）到本地
ssh -L 3031:localhost:3031 user@your-server.com
```

### 步骤 2: 在远程服务器执行登录

```bash
docker exec -it claude-proxy bash
ccproxy auth login
```

### 步骤 3: 在本地浏览器完成认证

OAuth 回调会通过 SSH 隧道转发到本地浏览器，正常完成认证即可。

---

## 📋 各方法对比

| 方法 | 难度 | 安全性 | 令牌有效期 | 是否需要浏览器 | 推荐度 |
|------|-----|--------|-----------|---------------|--------|
| setup-token | ⭐⭐ | ⭐⭐⭐⭐⭐ | ~6小时 | 首次需要 | ⭐⭐⭐⭐⭐ |
| 提取凭证文件 | ⭐ | ⭐⭐⭐⭐⭐ | 同步自已登录设备 | 否 | ⭐⭐⭐⭐⭐ |
| 手机浏览器 | ⭐⭐ | ⭐⭐⭐⭐ | 长期 | 需要（手机） | ⭐⭐⭐⭐ |
| SSH 端口转发 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 长期 | 需要（本地） | ⭐⭐⭐ |
| Session Token | ⭐⭐⭐⭐⭐ | ⭐⭐ | 不稳定 | 需要 | ⚠️ 不推荐 |

---

## 🔄 自动化令牌刷新方案

为了避免频繁手动刷新令牌，可以设置自动化脚本。

### 方案 A: 使用 Cron 定时刷新

```bash
# 创建刷新脚本
cat > /usr/local/bin/refresh-claude-token.sh << 'EOF'
#!/bin/bash
docker exec claude-proxy ccproxy auth refresh || \
  echo "Token refresh failed, please re-login"
EOF

chmod +x /usr/local/bin/refresh-claude-token.sh

# 添加到 crontab（每 5 小时执行一次）
crontab -e
# 添加以下行：
0 */5 * * * /usr/local/bin/refresh-claude-token.sh
```

### 方案 B: 使用 systemd timer

```bash
# 创建 service 文件
sudo nano /etc/systemd/system/claude-token-refresh.service

[Unit]
Description=Refresh Claude OAuth Token

[Service]
Type=oneshot
ExecStart=/usr/bin/docker exec claude-proxy ccproxy auth refresh

# 创建 timer 文件
sudo nano /etc/systemd/system/claude-token-refresh.timer

[Unit]
Description=Refresh Claude Token every 5 hours

[Timer]
OnBootSec=1h
OnUnitActiveSec=5h

[Install]
WantedBy=timers.target

# 启用 timer
sudo systemctl daemon-reload
sudo systemctl enable --now claude-token-refresh.timer
```

---

## 💡 最佳实践建议

### 推荐工作流

**首次设置**（在有浏览器的设备上）：
```bash
# 1. 安装 Claude Code CLI
npm install -g @anthropic-ai/claude-code

# 2. 登录并生成令牌
claude setup-token

# 3. 复制生成的令牌
```

**在服务器上部署**：
```bash
# 1. 创建凭证文件
mkdir -p claude-proxy/credentials
echo '{"access_token": "你的令牌"}' > claude-proxy/credentials/.credentials.json

# 2. 启动服务
docker-compose up -d claude-proxy

# 3. 验证
curl http://localhost:8000/health
```

**定期维护**：
```bash
# 每 5-6 小时在本地重新生成令牌
claude setup-token

# 更新服务器凭证
scp ~/.claude/.credentials.json server:/path/to/claude-proxy/credentials/

# 重启代理服务
docker-compose restart claude-proxy
```

---

## 🔍 故障排查

### 令牌过期

**症状**：API 返回 401 Unauthorized

**解决**：
```bash
# 检查令牌状态
docker exec -it claude-proxy ccproxy auth validate

# 如果已过期，重新获取令牌
claude setup-token  # 在本地执行
# 然后更新服务器凭证文件
```

### 凭证文件格式错误

**症状**：服务启动失败

**解决**：
```bash
# 验证 JSON 格式
cat claude-proxy/credentials/.credentials.json | jq .

# 正确格式示例：
{
  "access_token": "sk-ant-...",
  "refresh_token": "rt-ant-...",
  "expires_at": "2025-11-23T12:00:00Z",
  "token_type": "bearer"
}
```

### macOS Keychain 无法导出

**症状**：Keychain 中找不到 Claude 凭证

**解决**：
```bash
# 先在 Claude Code 中发送一条消息确保登录
claude /login

# 或使用 setup-token 方法
claude setup-token
```

---

## 📚 参考资源

- [Claude Code IAM 文档](https://code.claude.com/docs/en/iam)
- [claude-code-proxy GitHub](https://github.com/horselock/claude-code-proxy)
- [Developer Toolkit - Authentication](https://developertoolkit.ai/en/claude-code/quick-start/authentication/)
- [Setup Container Authentication](https://claude-did-this.com/claude-hub/getting-started/setup-container-guide)

---

## ⚠️ 重要提示

1. **令牌安全**
   - 不要在公共场合分享令牌
   - 凭证文件权限设置为 600
   - 添加到 .gitignore 避免提交

2. **服务条款**
   - 使用官方提供的 `claude setup-token` 方法
   - 避免使用可能违反 ToS 的 hack 方法
   - 令牌仅用于个人合法用途

3. **令牌有效期**
   - OAuth Token 通常 6 小时过期
   - 需要定期刷新或重新生成
   - 建议设置自动化刷新机制

---

最后更新: 2025-11-23

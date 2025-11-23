# CLIProxyAPI Claude 账号登录指南

## 📋 登录流程说明

CLIProxyAPI 使用 OAuth2 认证方式，需要通过 SSH 隧道完成登录。整个过程分为3步：
1. 在服务器启动登录流程
2. 在本地建立 SSH 隧道
3. 在本地浏览器完成授权

## 🔐 方法一：完整 OAuth 登录流程 (推荐)

### 步骤 1: 在本地终端建立 SSH 隧道

**打开一个新的终端窗口**，运行以下命令建立 SSH 隧道：

```bash
ssh -L 54545:127.0.0.1:54545 ali
```

**重要**:
- 保持这个终端窗口打开，不要关闭
- 隧道建立后会看到服务器的 shell 提示符
- 这个隧道会将本地 54545 端口转发到服务器

### 步骤 2: 在服务器启动登录流程

在 SSH 隧道终端中 (或另一个 SSH 连接中)，运行登录命令：

```bash
docker exec cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login -no-browser
```

会看到类似输出：
```
================================================================================
  Run one of the following commands on your local machine (NOT the server):

  ssh -L 54545:127.0.0.1:54545 root@104.238.222.119 -p 22
================================================================================
Visit the following URL to continue authentication:
https://claude.ai/oauth/authorize?client_id=...&redirect_uri=...

Waiting for Claude authentication callback...
```

### 步骤 3: 在本地浏览器完成授权

1. **复制** 上面输出的完整 OAuth URL
2. **在本地浏览器打开** 这个 URL
3. 登录你的 Claude 账号
4. 点击 **"Authorize"** 授权
5. 授权成功后，浏览器会显示成功消息
6. 返回终端，会看到 "Authentication successful" 消息

### 步骤 4: 验证登录成功

```bash
# 检查认证文件是否生成
ssh ali "ls -la /opt/one_hub/cliproxy/auth/"

# 重启 cliproxy 加载新认证
ssh ali "cd /opt/one_hub && docker compose restart cliproxy"

# 查看日志确认账号加载
ssh ali "docker logs cliproxy --tail 20 | grep 'clients'"
```

应该看到类似：
```
server clients and configuration updated: 1 clients (0 auth files + 1 Claude API keys)
```

## 🔐 方法二：导入已有凭证 (如果你有)

如果你在其他地方已经有 Claude CLI 的认证文件，可以直接复制：

### 从本地 Claude CLI 导入

```bash
# 找到本地 Claude CLI 的凭证文件
# macOS/Linux 路径通常在: ~/.config/claude/
ls -la ~/.config/claude/

# 复制凭证文件到服务器
scp ~/.config/claude/*.json ali:/opt/one_hub/cliproxy/auth/

# 重启服务加载凭证
ssh ali "cd /opt/one_hub && docker compose restart cliproxy"
```

### 从其他服务器导入

```bash
# 从其他服务器复制凭证
scp other-server:/path/to/credentials/*.json ali:/opt/one_hub/cliproxy/auth/

# 重启服务
ssh ali "cd /opt/one_hub && docker compose restart cliproxy"
```

## 👥 添加多个 Claude 账号

CLIProxyAPI 支持多账号负载均衡。要添加多个账号：

### 方法 1: 重复 OAuth 登录流程

每次登录都会在 auth 目录生成新的凭证文件，CLIProxyAPI 会自动加载所有凭证：

```bash
# 第一个账号 (按上述步骤操作)
docker exec cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login -no-browser

# 完成授权后，使用不同的 Claude 账号重复相同步骤
# 第二个账号
docker exec cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login -no-browser

# 第三个账号
docker exec cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login -no-browser
```

### 方法 2: 复制多个凭证文件

```bash
# 将多个账号的凭证文件都复制到 auth 目录
scp account1.json account2.json account3.json ali:/opt/one_hub/cliproxy/auth/

# 重启服务
ssh ali "cd /opt/one_hub && docker compose restart cliproxy"
```

## 📊 查看已登录的账号

```bash
# 查看认证文件
ssh ali "ls -la /opt/one_hub/cliproxy/auth/"

# 查看日志中的账号加载信息
ssh ali "docker logs cliproxy 2>&1 | grep 'clients' | tail -5"
```

输出示例：
```
[2025-11-23 22:00:30] full client load complete - 3 clients (0 auth files + 3 Claude API keys)
```

## ⚠️ 常见问题

### Q1: SSH 隧道连接超时

**问题**: OAuth 回调时提示连接超时或拒绝

**解决**:
1. 确认 SSH 隧道仍在运行
2. 确认端口 54545 没有被占用
3. 尝试重新建立 SSH 隧道

### Q2: 浏览器显示 "Unable to connect"

**问题**: 打开 OAuth URL 后无法连接

**原因**:
- SSH 隧道可能断开
- 本地端口被其他程序占用

**解决**:
```bash
# 检查端口占用
lsof -i :54545

# 如果有占用，kill 该进程或使用其他端口
# 杀掉占用进程
kill -9 <PID>

# 重新建立隧道
ssh -L 54545:127.0.0.1:54545 ali
```

### Q3: 授权成功但容器没有加载账号

**问题**: OAuth 成功但 `docker logs` 仍显示 0 clients

**解决**:
```bash
# 1. 检查认证文件权限
ssh ali "ls -la /opt/one_hub/cliproxy/auth/"

# 2. 检查文件是否在正确位置
ssh ali "docker exec cliproxy ls -la /root/.cli-proxy-api/"

# 3. 重启容器
ssh ali "cd /opt/one_hub && docker compose restart cliproxy"

# 4. 查看详细日志
ssh ali "docker logs cliproxy --tail 50"
```

### Q4: 多账号时如何指定使用哪个

CLIProxyAPI 会根据配置的负载均衡策略自动选择账号：

```yaml
# cliproxy/config.yaml
load_balancing:
  enabled: true
  strategy: round_robin  # 轮询使用所有账号
```

**可用策略**:
- `round_robin`: 轮询 (推荐) - 平均分配
- `weighted`: 加权分配
- `least_connections`: 选择连接数最少的
- `random`: 随机选择

## 🔍 验证账号可用性

登录完成后，测试账号是否可用：

```bash
# 测试 Claude API
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

如果返回 Claude 的响应，说明账号已正常工作！

## 📝 完整操作示例

```bash
# === 终端 1: 建立 SSH 隧道 ===
ssh -L 54545:127.0.0.1:54545 ali
# 保持此终端打开

# === 终端 2: 登录第一个账号 ===
ssh ali
docker exec cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login -no-browser
# 复制 OAuth URL 到浏览器授权
# 等待 "Authentication successful"

# === 验证 ===
docker logs cliproxy | grep clients
# 输出: 1 clients (0 auth files + 1 Claude API keys)

# === (可选) 添加第二个账号 ===
docker exec cliproxy /CLIProxyAPI/CLIProxyAPI -claude-login -no-browser
# 使用不同的 Claude 账号授权
# 验证: 应显示 2 clients

# === 重启加载 ===
cd /opt/one_hub && docker compose restart cliproxy

# === 查看最终状态 ===
docker logs cliproxy --tail 20
```

## 🎯 下一步

账号登录成功后：
1. 在 One-Hub 中添加 CLIProxy 渠道
2. 配置渠道地址: `http://cliproxy:8080/v1`
3. 测试渠道连通性

---

**最后更新**: 2025-11-23

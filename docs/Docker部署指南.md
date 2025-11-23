# One-Hub Docker 完整部署指南

## 目录
- [1. Docker Compose 配置说明](#1-docker-compose-配置说明)
- [2. Clash 代理配置](#2-clash-代理配置)
- [3. Claude OAuth2 集成方案](#3-claude-oauth2-集成方案)
- [4. 快速启动](#4-快速启动)

---

## 1. Docker Compose 配置说明

本项目的 `docker-compose.yml` 包含以下服务：

### 服务列表

1. **one-hub** - 主应用服务（端口: 3000）
2. **redis** - Redis 缓存数据库
3. **mysql** - MySQL 数据库（端口: 3306）
4. **clash** - 代理服务（HTTP: 7890, SOCKS5: 7891, API: 9090）
5. **claude-proxy** - Claude OAuth2 代理（可选，端口: 8000）

### 网络架构

所有服务运行在同一个 Docker 网络 `one-hub-network` 中，可以通过服务名相互访问。

---

## 2. Clash 代理配置

### 配置文件位置

```
clash/config.yaml
```

### 配置步骤

1. **编辑配置文件**

   打开 `clash/config.yaml`，根据您的实际代理节点信息修改 `proxies` 部分：

   ```yaml
   proxies:
     - name: "您的节点名称"
       type: ss  # 或 vmess, trojan 等
       server: your-server.com
       port: 8388
       cipher: aes-256-gcm
       password: "your-password"
   ```

2. **更新代理组**

   在 `proxy-groups` 中添加您的节点：

   ```yaml
   proxy-groups:
     - name: "自动选择"
       type: url-test
       proxies:
         - "您的节点名称"
   ```

3. **验证配置**

   启动后访问 Clash Dashboard:
   ```
   http://localhost:9090/ui
   ```

### 在 One-Hub 中使用 Clash 代理

方法一：通过环境变量（全局代理）

在 `docker-compose.yml` 中的 `one-hub` 服务取消注释：

```yaml
environment:
  - HTTP_PROXY=http://clash:7890
  - HTTPS_PROXY=http://clash:7890
```

方法二：为特定渠道配置代理

在 One-Hub 管理后台的渠道配置中，设置代理字段：
```
http://clash:7890
```
或
```
socks5://clash:7891
```

---

## 3. Claude OAuth2 集成方案

由于您无法使用 Claude API Key，只能通过 Claude Code 账号认证，我研究了多个开源项目，以下是最适合的方案：

### 推荐方案对比

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| **ccproxy-api** (CaddyGlow) | • 完整的 OAuth2 PKCE 支持<br>• 支持 SDK 和 API 模式<br>• 活跃维护<br>• 文档完善 | • 需要 Python 环境 | ⭐⭐⭐⭐⭐ |
| **claude-code-proxy** (horselock) | • 简单易用<br>• 直接使用本地凭证<br>• 轻量级 | • 需要手动登录 Claude Code<br>• 功能相对简单 | ⭐⭐⭐⭐ |
| **starbased-co/ccproxy** | • 支持多个 LLM 提供商<br>• 路由功能强大 | • 较新的项目<br>• 文档较少 | ⭐⭐⭐ |

### 方案一：使用 ccproxy-api（推荐）

**项目地址**: https://github.com/CaddyGlow/ccproxy-api

#### 特性
- ✅ 完整的 OAuth2 PKCE 认证流程
- ✅ 自动令牌刷新
- ✅ 支持 Anthropic 和 OpenAI 兼容 API 格式
- ✅ 支持流式响应
- ✅ 可作为 One-Hub 的上游代理

#### 部署步骤

1. **启用 Claude 代理服务**

   在 `docker-compose.yml` 中取消 `claude-proxy` 服务的注释：

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

2. **进行 OAuth2 认证**

   ```bash
   # 进入容器
   docker exec -it claude-proxy bash

   # 执行登录
   ccproxy auth login

   # 验证凭证
   ccproxy auth validate
   ccproxy auth info
   ```

   这将打开浏览器进行 Claude 账号登录，完成 OAuth2 认证。

3. **在 One-Hub 中配置渠道**

   - 渠道类型: Claude (Anthropic)
   - Base URL: `http://claude-proxy:8000/api/v1`
   - API Key: 填写任意值（如 `dummy-key`）
   - 代理: 留空（已通过环境变量配置）

#### API 端点说明

ccproxy-api 提供两种模式：

**API 模式（推荐用于 One-Hub）**:
```
http://claude-proxy:8000/api/v1/messages          # Anthropic 格式
http://claude-proxy:8000/api/v1/chat/completions  # OpenAI 兼容
```

**SDK 模式（支持本地工具和 MCP）**:
```
http://claude-proxy:8000/sdk/v1/messages
http://claude-proxy:8000/sdk/v1/chat/completions
```

### 方案二：使用 claude-code-proxy

**项目地址**: https://github.com/horselock/claude-code-proxy

#### 特性
- ✅ 轻量级实现
- ✅ 直接读取 Claude Code 本地凭证
- ✅ 自动令牌刷新
- ⚠️ 仅支持 Anthropic 格式 API

#### 部署步骤

1. **创建 Dockerfile**

   ```dockerfile
   FROM node:18-alpine

   WORKDIR /app

   RUN apk add --no-cache git

   RUN git clone https://github.com/horselock/claude-code-proxy.git .

   RUN npm install

   EXPOSE 42069

   CMD ["node", "index.js"]
   ```

2. **修改 docker-compose.yml**

   ```yaml
   claude-proxy:
     build:
       context: ./claude-code-proxy
       dockerfile: Dockerfile
     container_name: claude-code-proxy
     restart: always
     ports:
       - "42069:42069"
     volumes:
       - ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro
     environment:
       - HTTP_PROXY=http://clash:7890
       - HTTPS_PROXY=http://clash:7890
     networks:
       - one-hub-network
   ```

3. **本地登录 Claude Code**

   在主机上安装并登录 Claude Code:
   ```bash
   npm install -g @anthropic-ai/claude-code
   claude /login
   ```

   这将在 `~/.claude/.credentials.json` 生成凭证文件。

4. **在 One-Hub 中配置**

   - Base URL: `http://claude-code-proxy:42069/v1`
   - API Key: 任意值
   - 模型: 使用具体日期版本（如 `claude-sonnet-4-20241022`）

#### 注意事项

- 必须使用具体的模型版本号，不能使用 `claude-3-5-sonnet-latest`
- 系统提示会被强制添加 Claude Code 身份声明
- 仅支持有效的 Claude Pro/Max 订阅

### 方案三：直接集成 OAuth2 到 One-Hub（高级）

如果您熟悉 Go 开发，可以直接修改 One-Hub 的 Claude Provider，添加 OAuth2 支持：

1. 修改 `providers/claude/base.go`
2. 添加 OAuth2 认证逻辑
3. 实现令牌刷新机制

参考实现可查看 ccproxy-api 的源码：
- https://github.com/CaddyGlow/ccproxy-api/blob/main/src/ccproxy_api/auth.py

---

## 4. 快速启动

### 前置要求

- Docker 和 Docker Compose
- 有效的代理节点（用于 Clash）
- Claude Code 账号（如果使用 OAuth2 方案）

### 启动步骤

1. **配置 Clash 代理**

   编辑 `clash/config.yaml`，添加您的代理节点。

2. **（可选）配置环境变量**

   修改 `docker-compose.yml` 中的随机字符串：
   ```yaml
   - SESSION_SECRET=请生成一个随机字符串
   - USER_TOKEN_SECRET=请生成一个32位以上的随机字符串
   ```

3. **启动所有服务**

   ```bash
   docker-compose up -d
   ```

4. **查看日志**

   ```bash
   # 查看所有服务
   docker-compose logs -f

   # 查看特定服务
   docker-compose logs -f one-hub
   docker-compose logs -f clash
   docker-compose logs -f claude-proxy
   ```

5. **访问服务**

   - One-Hub 管理后台: http://localhost:3000
   - Clash Dashboard: http://localhost:9090/ui
   - Claude Proxy (如果启用): http://localhost:8000

6. **首次登录**

   One-Hub 默认管理员账号:
   - 用户名: root
   - 密码: 123456

   **请登录后立即修改密码！**

### 配置 Claude 渠道（使用 OAuth2 代理）

1. 进入 One-Hub 管理后台
2. 导航到 "渠道" -> "添加渠道"
3. 填写以下信息:
   - 名称: Claude OAuth2
   - 类型: Claude (Anthropic)
   - Base URL: `http://claude-proxy:8000/api/v1`
   - API Key: `dummy-key` (任意值)
   - 模型: 选择支持的 Claude 模型
   - 代理: 留空
4. 保存并测试渠道

### 停止服务

```bash
docker-compose down
```

### 完全清理（包括数据）

```bash
docker-compose down -v
rm -rf data/
```

---

## 故障排查

### Clash 无法连接

1. 检查 `clash/config.yaml` 配置是否正确
2. 查看 Clash 日志: `docker-compose logs clash`
3. 访问 Clash API 测试: `curl http://localhost:9090/`

### Claude 代理认证失败

1. 确认已完成 OAuth2 登录
2. 检查凭证文件是否存在并有效
3. 查看代理日志: `docker-compose logs claude-proxy`
4. 重新进行认证:
   ```bash
   docker exec -it claude-proxy ccproxy auth login
   ```

### One-Hub 无法访问外部 API

1. 检查 Clash 是否正常运行
2. 确认代理配置正确（环境变量或渠道代理设置）
3. 测试代理连通性:
   ```bash
   docker exec -it one-hub curl -x http://clash:7890 https://www.google.com
   ```

### 数据库连接失败

1. 检查 MySQL 是否启动: `docker-compose ps mysql`
2. 查看 MySQL 日志: `docker-compose logs mysql`
3. 验证数据库凭证是否匹配

---

## 安全建议

1. **修改默认密码**
   - One-Hub 管理员密码
   - MySQL root 密码
   - SESSION_SECRET 和 USER_TOKEN_SECRET

2. **不要暴露敏感端口**
   - 生产环境中，移除 MySQL 的端口映射
   - 考虑使用反向代理（如 Nginx）保护 One-Hub

3. **定期备份数据**
   ```bash
   # 备份 MySQL 数据
   docker exec mysql mysqldump -uoneapi -p123456 one-api > backup.sql

   # 备份 One-Hub 数据目录
   tar -czf one-hub-backup.tar.gz data/
   ```

4. **保护 Claude 凭证**
   - 不要将 `claude-proxy/credentials` 目录提交到版本控制
   - 定期检查令牌有效性

---

## 参考资源

### 项目文档
- [One-Hub 官方文档](https://one-hub-doc.vercel.app/)
- [Clash 配置指南](https://lancellc.gitbook.io/clash/)

### Claude OAuth2 开源项目
- [ccproxy-api](https://github.com/CaddyGlow/ccproxy-api) - 推荐方案
- [claude-code-proxy](https://github.com/horselock/claude-code-proxy) - 轻量级方案
- [ccproxy](https://github.com/starbased-co/ccproxy) - 多提供商支持

### 相关文章
- [CCProxy API 文档](https://caddyglow.github.io/ccproxy-api/)
- [Claude Code OAuth 认证说明](https://github.com/anthropics/claude-code/issues/11464)

---

## 许可证

本配置文件基于 One-Hub 项目，遵循原项目的 MIT 许可证。

## 贡献

如有问题或改进建议，请提交 Issue 或 Pull Request。

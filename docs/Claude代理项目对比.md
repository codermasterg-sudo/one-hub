# Claude Code 账号代理开源项目全面对比

本文档对比分析了 GitHub 上所有主流的 Claude Code OAuth2 代理项目，帮助您选择最适合的方案。

---

## 📊 项目概览

| 项目名称 | Stars | 技术栈 | 主要特点 | 推荐度 |
|---------|-------|--------|---------|--------|
| [ccproxy-api](https://github.com/CaddyGlow/ccproxy-api) | - | Python | 完整 OAuth2 PKCE，双模式 | ⭐⭐⭐⭐⭐ |
| [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) | 1.7k | Go | 多 CLI 统一，负载均衡 | ⭐⭐⭐⭐⭐ |
| [claudine-proxy](https://github.com/florianilch/claudine-proxy) | - | Rust | 低延迟，跨工具兼容 | ⭐⭐⭐⭐⭐ |
| [claude-code-mux](https://github.com/9j/claude-code-mux) | - | Rust | 高性能路由，故障转移 | ⭐⭐⭐⭐⭐ |
| [ccproxy](https://github.com/starbased-co/ccproxy) | - | Python | LiteLLM 集成，智能路由 | ⭐⭐⭐⭐ |
| [claude-code-proxy (horselock)](https://github.com/horselock/claude-code-proxy) | - | Node.js | 简单直接，读取本地凭证 | ⭐⭐⭐⭐ |
| [ClaudeCodeProxy](https://github.com/AIDotNet/ClaudeCodeProxy) | - | .NET 9 | 企业级，完整管理平台 | ⭐⭐⭐⭐ |
| [claude-code-provider-proxy](https://github.com/ujisati/claude-code-provider-proxy) | - | Python/FastAPI | 提供商路由，格式转换 | ⭐⭐⭐ |
| [anthropic-proxy](https://github.com/maxnowack/anthropic-proxy) | - | Node.js | 转发到 OpenRouter | ⭐⭐⭐ |
| [claude-code-proxy (1rgs)](https://github.com/1rgs/claude-code-proxy) | - | Python | LiteLLM，多模型支持 | ⭐⭐⭐ |

---

## 🏆 详细对比分析

### 1. ccproxy-api (CaddyGlow) ⭐⭐⭐⭐⭐

**项目地址**: https://github.com/CaddyGlow/ccproxy-api

#### 核心特性
- ✅ 完整的 OAuth2 PKCE 认证流程
- ✅ 支持 SDK 和 API 双模式
- ✅ 自动令牌刷新
- ✅ Anthropic + OpenAI 兼容格式
- ✅ 支持流式响应

#### 技术栈
- Python
- 异步 HTTP 客户端

#### 部署方式
```bash
# 使用 pipx
pipx install ccproxy-api

# 使用 uv
uvx ccproxy-api

# Docker
docker run caddyglow/ccproxy-api
```

#### 认证方式
```bash
ccproxy auth login       # OAuth2 登录
ccproxy auth validate    # 验证凭证
ccproxy auth refresh     # 刷新令牌
```

#### API 端点
- SDK 模式：`http://localhost:8000/sdk/v1/messages`
- API 模式：`http://localhost:8000/api/v1/messages`

#### 适用场景
- ✅ **最适合 One-Hub 集成**（推荐）
- ✅ 需要完整 OAuth2 支持
- ✅ 生产环境部署

---

### 2. CLIProxyAPI (router-for-me) ⭐⭐⭐⭐⭐

**项目地址**: https://github.com/router-for-me/CLIProxyAPI
**文档**: https://gist.github.com/chandika/c4b64c5b8f5e29f6112021d46c159fdd

#### 核心特性
- ✅ 统一多个 CLI（Gemini、Claude、Codex、Qwen）
- ✅ 多账户负载均衡
- ✅ 函数调用/工具支持
- ✅ 多模态输入（文本+图像）
- ✅ Go SDK 可嵌入

#### 技术栈
- Go
- 高性能并发

#### 支持的 CLI
| CLI | 模型 |
|-----|------|
| Gemini CLI | Gemini 2.5 Pro/Flash |
| Claude Code | Claude Sonnet 4/Opus 4 |
| OpenAI Codex | GPT-4/GPT-5 |
| Qwen Code | Qwen 系列 |
| iFlow | iFlow 模型 |

#### 部署方式
```bash
# Docker
docker-compose up -d

# 配置文件
cp config.example.yaml config.yaml
```

#### 特点
- 🚀 **1.7k stars**，活跃维护
- 📦 256 个发布版本
- 🔧 14 个贡献者

#### 适用场景
- ✅ 需要整合多个 AI CLI
- ✅ 高并发场景
- ✅ 企业级部署

---

### 3. claudine-proxy (florianilch) ⭐⭐⭐⭐⭐

**项目地址**: https://github.com/florianilch/claudine-proxy

#### 核心特性
- ✅ 轻量级，低延迟（<500μs 首字节延迟）
- ✅ 内存占用极小（~120KB）
- ✅ 跨工具兼容（Jan.ai、Raycast、IDE 等）
- ✅ 自动令牌刷新
- ✅ 隐私优先（不记录凭证和请求）

#### 技术栈
- Rust
- 高性能异步运行时

#### 认证流程
```bash
# 一次性认证
claudine auth login

# 按照提示授权
# 复制粘贴授权码
```

#### 令牌存储方式
1. **操作系统密钥环**（最安全，默认）
2. 文件存储
3. 环境变量

#### API 端点
```bash
# Anthropic 原生格式
curl http://localhost:4000/v1/messages \
  -H "x-api-key: claudine"

# OpenAI 兼容格式
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer claudine"
```

#### 部署方式
```bash
# macOS
brew install florianilch/tap/claudine

# 启动
claudine serve
```

#### 适用场景
- ✅ 需要极致性能
- ✅ 在多个工具中使用同一订阅
- ✅ 注重隐私安全

---

### 4. claude-code-mux (9j) ⭐⭐⭐⭐⭐

**项目地址**: https://github.com/9j/claude-code-mux

#### 核心特性
- ✅ Rust 高性能实现
- ✅ 自动故障转移
- ✅ 基于优先级的路由
- ✅ 支持 18+ AI 提供商
- ✅ 智能任务类型识别

#### 技术栈
- Rust
- 低内存占用（~5MB RAM）
- 路由延迟 <1ms

#### 支持的提供商
| 类型 | 提供商 |
|------|--------|
| 国际 | Anthropic, OpenAI, Google Gemini, Groq, Cohere |
| 国内 | Minimax, Kimi, DeepSeek, 通义千问 |
| 其他 | Cerebras, Mistral, Perplexity 等 |

#### 路由机制
- **任务类型识别**：自动识别网络搜索、推理、后台任务
- **优先级故障转移**：主提供商失败时自动切换备用
- **流式支持**：完整的 SSE 兼容

#### 性能特点
```
内存占用: ~5MB RAM
路由延迟: <1ms
并发能力: 高
```

#### 适用场景
- ✅ 需要高可用性（多提供商备份）
- ✅ 对性能要求极高
- ✅ 复杂的路由规则

---

### 5. ccproxy (starbased-co) ⭐⭐⭐⭐

**项目地址**: https://github.com/starbased-co/ccproxy

#### 核心特性
- ✅ 基于 LiteLLM Proxy Server
- ✅ 智能请求路由
- ✅ 支持多个 LLM 提供商
- ✅ 灵活的路由规则

#### 技术栈
- Python
- LiteLLM
- 动态模型映射

#### 支持的提供商
- Anthropic Claude（所有版本）
- OpenAI
- Google Gemini（2M token 窗口）
- OpenRouter
- 其他 LiteLLM 兼容提供商

#### 路由规则
| 规则类型 | 功能 |
|---------|------|
| MatchModelRule | 基于模型名称路由 |
| ThinkingRule | 识别含"thinking"字段的请求 |
| TokenCountRule | 将高 token 请求转向大窗口模型 |
| MatchToolRule | 基于工具使用路由（如 WebSearch） |

#### 部署方式
```bash
# 安装
ccproxy install

# 启动
ccproxy start --detach

# 配置环境变量
export ANTHROPIC_BASE_URL="http://localhost:4000"
```

#### 适用场景
- ✅ 需要复杂的路由逻辑
- ✅ 多模型混合使用
- ✅ 成本优化（按任务类型选择模型）

---

### 6. claude-code-proxy (horselock) ⭐⭐⭐⭐

**项目地址**: https://github.com/horselock/claude-code-proxy

#### 核心特性
- ✅ 简单直接，轻量级
- ✅ 直接读取本地凭证
- ✅ 自动令牌刷新
- ✅ 无需复杂配置

#### 技术栈
- Node.js
- 简单的 HTTP 代理

#### 认证方式
- 读取 `~/.claude/.credentials.json`
- 自动检查并刷新过期令牌
- 可选：手动提供访问令牌

#### 部署方式
```bash
# 克隆项目
git clone https://github.com/horselock/claude-code-proxy.git

# 启动（Windows）
run.bat

# 启动（Mac/Linux）
./run.sh

# Docker
docker-compose up
```

#### API 端点
- Base URL: `http://localhost:42069/v1`
- 仅支持 Anthropic 格式（非 OpenAI 兼容）

#### 注意事项
- ⚠️ 必须使用具体模型版本（如 `claude-sonnet-4-20241022`）
- ⚠️ 系统提示会被强制添加 Claude Code 身份声明

#### 适用场景
- ✅ 快速测试和开发
- ✅ 本地已有 Claude Code 登录
- ✅ 不需要 OpenAI 兼容格式

---

### 7. ClaudeCodeProxy (AIDotNet) ⭐⭐⭐⭐

**项目地址**: https://github.com/AIDotNet/ClaudeCodeProxy

#### 核心特性
- ✅ 企业级管理平台
- ✅ 完整的仪表板和分析
- ✅ 多平台 AI 服务集成
- ✅ 成本跟踪和财务归属

#### 技术栈
- **后端**: .NET 9.0 + Entity Framework Core
- **前端**: React 19 + TypeScript 5.6
- **数据库**: SQLite
- **UI**: Tailwind CSS + Shadcn/ui

#### 核心组件
- 认证服务
- 代理引擎
- 速率限制器
- 成本计算器
- 请求日志记录器

#### 支持的平台
- Claude/Anthropic
- OpenAI
- Google Gemini

#### 安全特性
- JWT 认证
- 加密存储
- IP 限制
- 审计日志

#### 部署方式
```bash
# Docker
docker-compose up -d

# 本地部署
dotnet publish
dotnet run
```

#### API 文档
- Scalar UI 展示
- REST API 接口
- 完整的 API 规范

#### 适用场景
- ✅ 企业级部署
- ✅ 需要完整的管理界面
- ✅ 多团队/多项目管理
- ✅ 成本控制和监控

---

### 8. claude-code-provider-proxy (ujisati) ⭐⭐⭐

**项目地址**: https://github.com/ujisati/claude-code-provider-proxy

#### 核心特性
- ✅ FastAPI 实现
- ✅ Anthropic ↔ OpenAI 格式转换
- ✅ 流式和非流式支持
- ✅ 详细的请求日志

#### 技术栈
- Python 3.10+
- FastAPI
- 异步请求处理

#### 配置方式
```env
OPENAI_API_KEY=<your_openrouter_api_key>
BIG_MODEL_NAME=google/gemini-2.5-pro-preview
SMALL_MODEL_NAME=google/gemini-2.0-flash-lite-001
LOG_LEVEL=DEBUG
```

#### 模型映射
- **大模型**：Claude Sonnet 4, Gemini 2.5 Pro
- **小模型**：Claude 3.5 Haiku, Gemini 2.5 Flash

#### 启动方式
```bash
ANTHROPIC_BASE_URL=http://localhost:8080 claude
```

#### 测试版本
- Claude Code 1.0.56（截至 2025年7月）

#### 适用场景
- ✅ 需要使用非官方提供商（如 OpenRouter）
- ✅ 成本优化（使用更便宜的模型）
- ✅ 快速原型开发

---

### 9. anthropic-proxy (maxnowack) ⭐⭐⭐

**项目地址**: https://github.com/maxnowack/anthropic-proxy

#### 核心特性
- ✅ 将 Anthropic API 转换为 OpenAI 格式
- ✅ 转发到 OpenRouter.ai
- ✅ 简单配置

#### 技术栈
- Node.js
- Express/类似框架

#### 使用场景
- 使用 Claude Code 通过 OpenRouter
- 不想直接使用 Anthropic API

#### 配置方式
```bash
# 启动
OPENROUTER_API_KEY=your-api-key npx anthropic-proxy

# 环境变量
PORT=3000                          # 服务端口
ANTHROPIC_PROXY_BASE_URL=...       # 自定义基础 URL
REASONING_MODEL=...                # 推理模型（默认 Gemini 2.0）
COMPLETION_MODEL=...               # 补全模型（默认 Gemini 2.0）
```

#### 适用场景
- ✅ 已有 OpenRouter 账号
- ✅ 需要统一使用 OpenRouter
- ✅ 简单的转发需求

---

### 10. claude-code-proxy (1rgs) ⭐⭐⭐

**项目地址**: https://github.com/1rgs/claude-code-proxy

#### 核心特性
- ✅ 基于 LiteLLM
- ✅ 支持多个后端（Gemini、OpenAI、Anthropic）
- ✅ 灵活的模型切换

#### 技术栈
- Python
- LiteLLM

#### 支持的后端
- Anthropic（直连）
- OpenAI
- Google Gemini
- 其他 LiteLLM 支持的提供商

#### 适用场景
- ✅ 需要在多个模型间切换
- ✅ 使用 LiteLLM 生态

---

## 🎯 选择建议

### 根据使用场景选择

#### 1️⃣ **One-Hub 集成（推荐）**
```
首选：ccproxy-api
备选：claudine-proxy
```
- 完整的 OAuth2 支持
- OpenAI 兼容格式
- 易于部署

#### 2️⃣ **高性能生产环境**
```
首选：claude-code-mux
备选：claudine-proxy
```
- Rust 实现，极致性能
- 低资源占用
- 高可用性

#### 3️⃣ **多 CLI 统一管理**
```
首选：CLIProxyAPI
```
- 支持多个 AI CLI
- 负载均衡
- 企业级功能

#### 4️⃣ **企业管理平台**
```
首选：ClaudeCodeProxy (AIDotNet)
```
- 完整的管理界面
- 成本控制
- 多团队支持

#### 5️⃣ **快速测试开发**
```
首选：claude-code-proxy (horselock)
备选：ccproxy
```
- 简单直接
- 快速部署
- 本地开发友好

#### 6️⃣ **智能路由和成本优化**
```
首选：ccproxy (starbased-co)
备选：claude-code-mux
```
- 复杂路由规则
- 多模型混合
- 按任务类型优化

---

## 📋 功能对比矩阵

| 功能 | ccproxy-api | CLIProxyAPI | claudine | mux | ccproxy | horselock | AIDotNet |
|------|------------|-------------|----------|-----|---------|-----------|----------|
| OAuth2 支持 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| OpenAI 兼容 | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| 流式响应 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 自动刷新 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 多提供商 | ❌ | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ |
| 负载均衡 | ❌ | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ |
| 故障转移 | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| 管理界面 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| 成本追踪 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Docker 支持 | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ |

---

## 🚀 快速部署对比

### Docker Compose 配置示例

#### ccproxy-api
```yaml
claude-proxy:
  image: caddyglow/ccproxy-api:latest
  ports:
    - "8000:8000"
  volumes:
    - ./credentials:/root/.claude
  environment:
    - HTTP_PROXY=http://clash:7890
```

#### CLIProxyAPI
```yaml
cliproxy:
  image: router-for-me/cliproxy-api:latest
  ports:
    - "8080:8080"
  volumes:
    - ./config.yaml:/app/config.yaml
```

#### claudine-proxy
```bash
# 使用二进制文件，不推荐 Docker
claudine serve --port 4000
```

#### claude-code-mux
```yaml
mux:
  image: 9j/claude-code-mux:latest
  ports:
    - "8000:8000"
  volumes:
    - ./config.yaml:/etc/mux/config.yaml
```

#### ClaudeCodeProxy
```yaml
claude-proxy:
  image: aidotnet/claude-proxy:latest
  ports:
    - "5000:5000"
  environment:
    - ConnectionStrings__DefaultConnection=...
```

---

## 💰 成本和性能对比

| 项目 | 内存占用 | CPU 占用 | 延迟 | 适用规模 |
|------|---------|---------|------|---------|
| ccproxy-api | ~50MB | 低 | 低 | 小-中 |
| CLIProxyAPI | ~30MB | 低 | 极低 | 中-大 |
| claudine-proxy | ~120KB | 极低 | <0.5ms | 小-大 |
| claude-code-mux | ~5MB | 极低 | <1ms | 小-大 |
| ccproxy | ~100MB | 中 | 低 | 小-中 |
| horselock | ~30MB | 低 | 低 | 小 |
| ClaudeCodeProxy | ~200MB | 中-高 | 中 | 中-大 |

---

## ⚠️ 注意事项

### 服务条款
所有这些代理项目都使用 Claude Pro/Max 订阅，请确保：
- ✅ 仅用于个人合法用途
- ✅ 遵守 Anthropic 服务条款
- ✅ 不要分享账号或滥用服务

### 令牌管理
- OAuth2 令牌通常 6 小时过期
- 需要定期刷新或重新登录
- 建议设置自动刷新机制

### 安全建议
- 🔒 保护凭证文件（权限 600）
- 🔒 不要提交到版本控制
- 🔒 使用环境变量存储敏感信息
- 🔒 生产环境配置 HTTPS

---

## 📚 参考资源

### 官方文档
- [Claude Code 文档](https://code.claude.com/docs)
- [Anthropic API 文档](https://docs.anthropic.com/)
- [LiteLLM 文档](https://docs.litellm.ai/)

### 开源项目
- [ccproxy-api](https://github.com/CaddyGlow/ccproxy-api)
- [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
- [claudine-proxy](https://github.com/florianilch/claudine-proxy)
- [claude-code-mux](https://github.com/9j/claude-code-mux)
- [ccproxy](https://github.com/starbased-co/ccproxy)
- [claude-code-proxy (horselock)](https://github.com/horselock/claude-code-proxy)
- [ClaudeCodeProxy](https://github.com/AIDotNet/ClaudeCodeProxy)
- [claude-code-provider-proxy](https://github.com/ujisati/claude-code-provider-proxy)
- [anthropic-proxy](https://github.com/maxnowack/anthropic-proxy)
- [claude-code-proxy (1rgs)](https://github.com/1rgs/claude-code-proxy)

### 技术文章
- [Factory CLI with Claude Subscription](https://gist.github.com/chandika/c4b64c5b8f5e29f6112021d46c159fdd)
- [Building Claude-Ready Entra ID-Protected MCP Servers](https://developer.microsoft.com/blog/claude-ready-secure-mcp-apim)

---

## 🔄 最后更新

- 文档版本: 1.0
- 更新日期: 2025-11-23
- 涵盖项目: 10 个

如有新的优秀项目，欢迎补充！

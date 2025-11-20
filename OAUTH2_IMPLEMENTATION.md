# OAuth2 框架实现文档

## 📋 概述

本文档描述了 One-Hub 中通用 OAuth2 框架的实现，该框架支持多个 AI Provider 使用 OAuth2 认证方式，实现了配置驱动、高度可扩展的架构。

## 🎯 核心特性

- ✅ **通用框架**：一次开发，支持所有 OAuth2 Provider
- ✅ **配置驱动**：通过配置文件定义不同 Provider 的 OAuth2 参数
- ✅ **自动刷新**：Access Token 自动刷新，无需手动干预
- ✅ **线程安全**：使用双重检查锁定模式，支持高并发
- ✅ **可插拔**：支持自定义 token 格式、请求方式、认证头
- ✅ **向后兼容**：不影响现有的 API key 认证方式

## 📁 文件结构

### 后端（Go）

```
common/oauth2/
├── interfaces.go          # OAuth2 核心接口定义
├── types.go              # 类型和配置定义
├── errors.go             # 错误类型
├── registry.go           # Provider 配置注册表
├── manager.go            # Token 管理器（自动刷新）
├── refresher.go          # Token 刷新器
├── exchanger.go          # 授权码交换器
└── helper.go             # 辅助函数

providers/base/
└── oauth2_provider.go    # OAuth2 Provider Mixin

providers/claude/
├── oauth2_config.go      # Claude OAuth2 配置
└── oauth2_provider.go    # Claude OAuth2 Provider 实现

controller/
└── oauth2.go             # OAuth2 API 接口

router/
└── api-router.go         # OAuth2 路由注册
```

### 前端（React）

```
web/src/components/OAuth2/
├── OAuth2AuthButton.jsx  # 通用 OAuth2 授权按钮组件
└── index.js              # 组件导出

web/src/views/Channel/
├── type/Config.js        # 渠道类型配置（包含 OAuth2 配置）
└── component/EditModal.jsx  # 渠道编辑页面（集成 OAuth2 按钮）
```

## 🔧 实现细节

### 1. OAuth2 配置注册

每个支持 OAuth2 的 Provider 需要注册配置：

```go
// providers/claude/oauth2_config.go
func init() {
    oauth2.MustRegister(&oauth2.OAuth2Config{
        ProviderName:     "claude",
        ClientID:         "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
        Scopes:           []string{"org:create_api_key", "user:profile", "user:inference"},
        UsePKCE:          true,
        TokenRequestType: oauth2.TokenRequestJSON,
        AuthHeaderFormat: oauth2.AuthHeaderBearer,
        DisplayName:      "Claude (OAuth2)",
        // ... 更多配置
    })
}
```

### 2. Provider 实现

```go
// providers/claude/oauth2_provider.go
type ClaudeOAuth2Provider struct {
    base.BaseProvider
    base.OAuth2ProviderMixin  // 组合 OAuth2 能力
}

func (p *ClaudeOAuth2Provider) GetRequestHeaders() map[string]string {
    headers := make(map[string]string)

    // 获取 OAuth2 认证头（自动刷新 token）
    oauth2Headers, _ := p.GetOAuth2Headers(p.Context)
    for k, v := range oauth2Headers {
        headers[k] = v
    }

    return headers
}
```

### 3. Token 自动刷新

Token Manager 使用双重检查锁定模式实现线程安全的自动刷新：

```go
func (m *Manager) GetAccessToken(ctx context.Context) (*oauth2.Token, error) {
    // 第一次检查（读锁）
    m.mutex.RLock()
    if m.accessToken != nil && m.isTokenValid(m.accessToken) {
        token := m.accessToken
        m.mutex.RUnlock()
        return token, nil
    }
    m.mutex.RUnlock()

    // 需要刷新（写锁）
    m.mutex.Lock()
    defer m.mutex.Unlock()

    // 第二次检查（可能其他协程已经刷新了）
    if m.accessToken != nil && m.isTokenValid(m.accessToken) {
        return m.accessToken, nil
    }

    // 执行刷新
    newToken, err := m.refresher.RefreshToken(ctx, m.refreshToken)
    // ...
}
```

### 4. 前端集成

渠道配置中启用 OAuth2：

```javascript
// web/src/views/Channel/type/Config.js
const typeConfig = {
  57: {  // Claude OAuth2
    // ... 其他配置
    oauth2: {
      enabled: true,
      provider: 'claude'
    }
  }
};
```

## 🚀 使用指南

### 用户使用流程

1. **创建渠道**：选择类型 "Claude (OAuth2)"
2. **点击授权**：点击 "OAuth2 授权" 按钮
3. **登录授权**：在弹出的窗口中登录 Claude 账号并授权
4. **复制授权码**：复制授权后显示的授权码（格式：`code#state`）
5. **完成授权**：粘贴授权码并点击"确认授权"
6. **保存渠道**：Refresh Token 自动填入，保存渠道即可使用

### 管理员配置

refresh_token 存储在 `channel.key` 字段中，系统会自动：
- 提前 5 分钟刷新 access_token（避免过期）
- 更新 refresh_token（如果 Provider 返回了新的）
- 处理刷新失败（返回错误给客户端）

## 🎨 新增 Provider 示例

只需 3 步即可添加新的 OAuth2 Provider：

### 步骤 1：注册配置（5 分钟）

```go
// providers/gemini/oauth2_config.go
package gemini

import "one-api/common/oauth2"

func init() {
    oauth2.MustRegister(&oauth2.OAuth2Config{
        ProviderName:     "gemini",
        ClientID:         "your-client-id",
        ClientSecret:     "your-client-secret",
        Scopes:           []string{"your-scopes"},
        UsePKCE:          false,
        TokenRequestType: oauth2.TokenRequestForm,
        DisplayName:      "Google Gemini (OAuth2)",
        // ...
    })
}
```

### 步骤 2：实现 Provider（10 分钟）

```go
// providers/gemini/oauth2_provider.go
type GeminiOAuth2Provider struct {
    base.BaseProvider
    base.OAuth2ProviderMixin
}

func (p *GeminiOAuth2Provider) GetRequestHeaders() map[string]string {
    headers := make(map[string]string)
    oauth2Headers, _ := p.GetOAuth2Headers(p.Context)
    for k, v := range oauth2Headers {
        headers[k] = v
    }
    return headers
}
```

### 步骤 3：前端配置（5 分钟）

```javascript
// web/src/views/Channel/type/Config.js
const typeConfig = {
  XX: {  // 新的渠道类型 ID
    oauth2: {
      enabled: true,
      provider: 'gemini'
    },
    // ... 其他配置
  }
};
```

## 🔒 安全特性

1. **PKCE 支持**：支持 PKCE (Proof Key for Code Exchange) 增强安全性
2. **State 验证**：自动验证 state 参数，防止 CSRF 攻击
3. **Token 过期**：提前 5 分钟刷新，避免请求中过期
4. **线程安全**：并发请求时只刷新一次 token
5. **错误隔离**：刷新失败不影响其他渠道

## 📊 支持的 OAuth2 特性

| 特性 | 支持状态 | 说明 |
|------|---------|------|
| **授权码模式** | ✅ | Authorization Code Flow |
| **PKCE** | ✅ | 支持公开客户端增强安全 |
| **Token 刷新** | ✅ | 自动刷新 access_token |
| **JSON Token 请求** | ✅ | 支持 JSON 格式（如 Anthropic） |
| **Form Token 请求** | ✅ | 支持标准 Form 格式 |
| **Bearer Token** | ✅ | Authorization: Bearer xxx |
| **自定义认证头** | ✅ | 支持自定义格式 |
| **Client Credentials** | ❌ | 暂不支持（未来可扩展） |
| **Implicit Flow** | ❌ | 不推荐，不支持 |

## 🐛 故障排查

### 常见问题

1. **授权失败**
   - 检查 Client ID 是否正确
   - 检查 Redirect URL 是否匹配
   - 检查授权码是否完整（包含 # 符号）

2. **Token 刷新失败**
   - 检查 refresh_token 是否有效
   - 检查网络连接
   - 查看后端日志获取详细错误

3. **请求失败 401**
   - 检查 access_token 是否正确注入
   - 检查认证头格式是否正确
   - 尝试手动刷新 token

### 日志调试

后端日志包含详细的 OAuth2 操作信息：
- Token 刷新时间
- Token 过期时间
- 刷新失败原因
- API 请求错误

## 🔄 扩展性

### 支持的扩展点

1. **自定义 Refresher**：实现 `TokenRefresher` 接口
2. **自定义 Exchanger**：实现 `TokenExchanger` 接口
3. **自定义认证头**：使用 `CustomAuthBuilder` 函数
4. **自定义存储**：实现 `TokenStorage` 接口（未来）

### 未来计划

- [ ] Token 持久化（保存到数据库）
- [ ] 多账号轮询支持
- [ ] OAuth2 健康检查
- [ ] 更多 Provider 支持（Gemini, GitHub Copilot 等）
- [ ] Client Credentials 模式
- [ ] Device Authorization Flow

## 📝 开发者注意事项

1. **Provider 命名**：使用小写，如 "claude", "gemini"
2. **渠道类型 ID**：避免冲突，使用连续 ID
3. **错误处理**：使用 `OAuth2Error` 包装错误
4. **线程安全**：Manager 已处理，无需额外加锁
5. **测试**：添加新 Provider 前先测试 OAuth2 流程

## 📄 API 文档

### GET /api/oauth2/providers
获取所有支持 OAuth2 的 Provider 列表

**响应**：
```json
{
  "success": true,
  "data": {
    "claude": {
      "display_name": "Claude (OAuth2)",
      "help_text": "使用 Claude Pro 或 Claude Max 订阅账号授权",
      "code_format": "code#state"
    }
  }
}
```

### GET /api/oauth2/auth_url?provider=claude
生成 OAuth2 授权 URL

**响应**：
```json
{
  "success": true,
  "data": {
    "auth_url": "https://claude.ai/oauth/authorize?...",
    "state": "verifier_string",
    "use_pkce": true
  }
}
```

### POST /api/oauth2/exchange
交换授权码获取 refresh_token

**请求**：
```json
{
  "provider": "claude",
  "code": "abc123#xyz789",
  "state": "verifier_string"
}
```

**响应**：
```json
{
  "success": true,
  "data": {
    "refresh_token": "rt_xxxxx",
    "access_token": "at_xxxxx",
    "expires_in": 3600
  }
}
```

## 🎉 总结

本 OAuth2 框架提供了：
- 通用、可扩展的架构
- 配置驱动的实现方式
- 完善的错误处理和安全特性
- 友好的用户体验

新增 Provider 只需 20 分钟，大大降低了维护成本！

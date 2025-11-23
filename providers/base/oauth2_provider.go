package base

import (
	"context"
	"fmt"

	"one-api/common/oauth2"
	"one-api/model"
)

// OAuth2ProviderMixin 提供 OAuth2 能力的 Mixin
// 通过组合的方式为 Provider 添加 OAuth2 支持
type OAuth2ProviderMixin struct {
	oauth2Manager *oauth2.Manager
	providerName  string
}

// InitOAuth2 初始化 OAuth2 功能（不使用代理）
// providerName: OAuth2 配置注册时使用的名称（如 "claude", "gemini"）
// refreshToken: refresh_token（通常存储在 channel.Key 中）
func (m *OAuth2ProviderMixin) InitOAuth2(providerName string, refreshToken string) error {
	return m.InitOAuth2WithProxy(providerName, refreshToken, "")
}

// InitOAuth2WithProxy 初始化 OAuth2 功能（手动指定代理）
// providerName: OAuth2 配置注册时使用的名称（如 "claude", "gemini"）
// refreshToken: refresh_token（通常存储在 channel.Key 中）
// proxyAddr: 代理地址（支持 http://, https://, socks5:// 协议）
func (m *OAuth2ProviderMixin) InitOAuth2WithProxy(providerName string, refreshToken string, proxyAddr string) error {
	if refreshToken == "" {
		return fmt.Errorf("refresh_token is required for OAuth2")
	}

	manager, err := oauth2.NewManagerWithProxy(providerName, refreshToken, proxyAddr)
	if err != nil {
		return fmt.Errorf("failed to create oauth2 manager: %w", err)
	}

	m.oauth2Manager = manager
	m.providerName = providerName

	return nil
}

// InitOAuth2FromChannel 初始化 OAuth2 功能（从 Channel 自动获取代理配置）
// providerName: OAuth2 配置注册时使用的名称（如 "claude", "gemini"）
// channel: 渠道配置（将自动读取 channel.Key 作为 refresh_token，channel.Proxy 作为代理地址）
//
// 这是推荐的使用方式，API 和 OAuth2 会自动使用同一个代理配置
func (m *OAuth2ProviderMixin) InitOAuth2FromChannel(providerName string, channel *model.Channel) error {
	if channel == nil {
		return fmt.Errorf("channel cannot be nil")
	}

	// 从 channel 中获取 refresh_token
	refreshToken := channel.Key
	if refreshToken == "" {
		return fmt.Errorf("refresh_token is required for OAuth2")
	}

	// 从 channel 中获取代理配置
	proxyAddr := ""
	if channel.Proxy != nil {
		proxyAddr = *channel.Proxy
	}

	return m.InitOAuth2WithProxy(providerName, refreshToken, proxyAddr)
}

// GetOAuth2Headers 获取 OAuth2 认证头
// 返回一个包含认证头的 map，可以直接合并到请求头中
func (m *OAuth2ProviderMixin) GetOAuth2Headers(ctx context.Context) (map[string]string, error) {
	if m.oauth2Manager == nil {
		return nil, fmt.Errorf("oauth2 not initialized, call InitOAuth2() first")
	}

	key, value, err := m.oauth2Manager.GetAuthHeader(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get auth header: %w", err)
	}

	return map[string]string{
		key: value,
	}, nil
}

// GetOAuth2Manager 获取 OAuth2 Manager（用于高级用法）
func (m *OAuth2ProviderMixin) GetOAuth2Manager() *oauth2.Manager {
	return m.oauth2Manager
}

// IsOAuth2Enabled 检查是否启用了 OAuth2
func (m *OAuth2ProviderMixin) IsOAuth2Enabled() bool {
	return m.oauth2Manager != nil
}

// GetOAuth2ProviderName 获取 OAuth2 Provider 名称
func (m *OAuth2ProviderMixin) GetOAuth2ProviderName() string {
	return m.providerName
}

// RefreshOAuth2Token 手动刷新 OAuth2 Token（通常不需要调用，Manager 会自动刷新）
func (m *OAuth2ProviderMixin) RefreshOAuth2Token(ctx context.Context) error {
	if m.oauth2Manager == nil {
		return fmt.Errorf("oauth2 not initialized")
	}

	// 清除缓存强制刷新
	m.oauth2Manager.ClearCache()

	// 触发刷新
	_, err := m.oauth2Manager.GetAccessToken(ctx)
	return err
}

// AddOAuth2Headers 将 OAuth2 认证头添加到现有 headers 中（通用方法）
// 这是一个便捷方法，会自动处理 Context 为 nil 的情况
func (b *BaseProvider) AddOAuth2Headers(headers map[string]string) {
	if oauth2Provider, ok := interface{}(b).(interface {
		IsOAuth2Enabled() bool
		GetOAuth2Headers(context.Context) (map[string]string, error)
	}); ok && oauth2Provider.IsOAuth2Enabled() {
		// 使用 context.Background() 作为 fallback，OAuth2 token 刷新不依赖请求上下文
		var ctx context.Context
		if b.Context != nil {
			ctx = b.Context
		} else {
			ctx = context.Background()
		}

		oauth2Headers, err := oauth2Provider.GetOAuth2Headers(ctx)
		if err != nil {
			// OAuth2 认证失败时静默返回，让实际请求失败并返回错误
			// 错误会在具体的 API 调用中体现
			return
		}

		// 合并 OAuth2 头
		for k, v := range oauth2Headers {
			headers[k] = v
		}
	}
}

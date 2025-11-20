package oauth2

import (
	"context"
	"fmt"
	"sync"
	"time"

	"golang.org/x/oauth2"
)

// Manager Token 管理器，负责 access_token 的自动刷新
type Manager struct {
	config       *OAuth2Config
	refreshToken string
	accessToken  *oauth2.Token
	mutex        sync.RWMutex
	refresher    TokenRefresher
}

// NewManager 创建 Token Manager
func NewManager(providerName string, refreshToken string) (*Manager, error) {
	if refreshToken == "" {
		return nil, fmt.Errorf("refresh_token is required")
	}

	config, err := GetConfig(providerName)
	if err != nil {
		return nil, err
	}

	return NewManagerWithConfig(config, refreshToken), nil
}

// NewManagerWithConfig 使用自定义配置创建 Manager
func NewManagerWithConfig(config *OAuth2Config, refreshToken string) *Manager {
	return &Manager{
		config:       config,
		refreshToken: refreshToken,
		refresher:    NewDefaultRefresher(config),
	}
}

// SetRefresher 设置自定义 Token 刷新器
func (m *Manager) SetRefresher(refresher TokenRefresher) {
	m.refresher = refresher
}

// GetAccessToken 获取 Access Token（自动刷新）
// 线程安全，使用双重检查锁定模式
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
	if err != nil {
		return nil, err
	}

	// 更新缓存
	m.accessToken = newToken

	// 如果返回了新的 refresh_token，更新它
	if newToken.RefreshToken != "" && newToken.RefreshToken != m.refreshToken {
		m.refreshToken = newToken.RefreshToken
	}

	return newToken, nil
}

// GetAuthHeader 获取认证头（自动生成）
// 返回: header key, header value, error
func (m *Manager) GetAuthHeader(ctx context.Context) (string, string, error) {
	token, err := m.GetAccessToken(ctx)
	if err != nil {
		return "", "", err
	}

	switch m.config.AuthHeaderFormat {
	case AuthHeaderBearer:
		return "Authorization", "Bearer " + token.AccessToken, nil

	case AuthHeaderAPIKey:
		return "x-api-key", token.AccessToken, nil

	case AuthHeaderCustom:
		if m.config.CustomAuthBuilder != nil {
			return "Authorization", m.config.CustomAuthBuilder(token.AccessToken), nil
		}
		// 默认使用 Bearer
		return "Authorization", "Bearer " + token.AccessToken, nil

	default:
		return "Authorization", "Bearer " + token.AccessToken, nil
	}
}

// UpdateRefreshToken 更新 refresh token
// 用于需要持久化新 refresh_token 的场景
func (m *Manager) UpdateRefreshToken(refreshToken string) {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	m.refreshToken = refreshToken
	m.accessToken = nil // 清除缓存的 access token
}

// GetRefreshToken 获取当前的 refresh token
func (m *Manager) GetRefreshToken() string {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	return m.refreshToken
}

// ClearCache 清除缓存的 access token（强制下次重新刷新）
func (m *Manager) ClearCache() {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	m.accessToken = nil
}

// isTokenValid 检查 token 是否有效
// 提前 5 分钟刷新，避免在请求过程中过期
func (m *Manager) isTokenValid(token *oauth2.Token) bool {
	if token == nil {
		return false
	}

	// 检查是否有 access_token
	if token.AccessToken == "" {
		return false
	}

	// 如果没有过期时间，认为是永久有效
	if token.Expiry.IsZero() {
		return true
	}

	// 提前 5 分钟刷新
	return token.Expiry.Add(-5 * time.Minute).After(time.Now())
}

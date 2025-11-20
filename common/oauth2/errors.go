package oauth2

import (
	"fmt"
)

// 定义 OAuth2 相关错误类型
var (
	// ErrProviderNotFound Provider 未注册
	ErrProviderNotFound = fmt.Errorf("oauth2 provider not found")

	// ErrInvalidToken Token 无效
	ErrInvalidToken = fmt.Errorf("invalid oauth2 token")

	// ErrTokenExpired Token 已过期
	ErrTokenExpired = fmt.Errorf("oauth2 token expired")

	// ErrRefreshFailed Token 刷新失败
	ErrRefreshFailed = fmt.Errorf("oauth2 token refresh failed")

	// ErrExchangeFailed 授权码交换失败
	ErrExchangeFailed = fmt.Errorf("oauth2 code exchange failed")

	// ErrInvalidConfig 配置无效
	ErrInvalidConfig = func(msg string) error {
		return fmt.Errorf("invalid oauth2 config: %s", msg)
	}

	// ErrInvalidState State 参数不匹配
	ErrInvalidState = fmt.Errorf("oauth2 state mismatch")
)

// OAuth2Error OAuth2 错误包装
type OAuth2Error struct {
	Provider string
	Op       string // 操作类型：refresh, exchange, auth
	Err      error
}

func (e *OAuth2Error) Error() string {
	return fmt.Sprintf("oauth2 error [%s/%s]: %v", e.Provider, e.Op, e.Err)
}

func (e *OAuth2Error) Unwrap() error {
	return e.Err
}

// NewOAuth2Error 创建 OAuth2 错误
func NewOAuth2Error(provider, op string, err error) *OAuth2Error {
	return &OAuth2Error{
		Provider: provider,
		Op:       op,
		Err:      err,
	}
}

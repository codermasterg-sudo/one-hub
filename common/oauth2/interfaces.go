package oauth2

import (
	"context"

	"golang.org/x/oauth2"
)

// TokenRefresher 定义 Token 刷新接口，支持自定义刷新逻辑
type TokenRefresher interface {
	// RefreshToken 使用 refresh_token 获取新的 access_token
	RefreshToken(ctx context.Context, refreshToken string) (*oauth2.Token, error)
}

// TokenExchanger 定义授权码交换接口
type TokenExchanger interface {
	// Exchange 使用授权码交换 token
	Exchange(ctx context.Context, code string, state string) (*oauth2.Token, error)
}

// TokenStorage 定义 Token 存储接口（可选，用于持久化）
type TokenStorage interface {
	// SaveToken 保存 token
	SaveToken(ctx context.Context, key string, token *oauth2.Token) error

	// LoadToken 加载 token
	LoadToken(ctx context.Context, key string) (*oauth2.Token, error)

	// DeleteToken 删除 token
	DeleteToken(ctx context.Context, key string) error
}

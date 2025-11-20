package oauth2

import (
	"golang.org/x/oauth2"
)

// TokenRequestType 定义 token 请求的格式类型
type TokenRequestType string

const (
	// TokenRequestJSON JSON 格式请求（如 Anthropic）
	TokenRequestJSON TokenRequestType = "json"

	// TokenRequestForm 标准 Form 格式请求（标准 OAuth2）
	TokenRequestForm TokenRequestType = "form"
)

// AuthHeaderFormat 定义认证头的格式类型
type AuthHeaderFormat string

const (
	// AuthHeaderBearer 使用 "Authorization: Bearer xxx" 格式
	AuthHeaderBearer AuthHeaderFormat = "bearer"

	// AuthHeaderAPIKey 使用 "x-api-key: xxx" 格式
	AuthHeaderAPIKey AuthHeaderFormat = "x-api-key"

	// AuthHeaderCustom 自定义格式（需要提供 CustomAuthBuilder）
	AuthHeaderCustom AuthHeaderFormat = "custom"
)

// OAuth2Config 定义 Provider 的 OAuth2 配置
type OAuth2Config struct {
	// === 基础配置 ===

	// ProviderName Provider 唯一标识符（如 "claude", "gemini"）
	ProviderName string `json:"provider_name"`

	// ClientID OAuth2 客户端 ID
	ClientID string `json:"client_id"`

	// ClientSecret OAuth2 客户端密钥（公开客户端可为空）
	ClientSecret string `json:"client_secret,omitempty"`

	// RedirectURL OAuth2 回调地址
	RedirectURL string `json:"redirect_url"`

	// Scopes OAuth2 权限范围
	Scopes []string `json:"scopes"`

	// Endpoint OAuth2 端点配置
	Endpoint oauth2.Endpoint `json:"endpoint"`

	// === 高级配置 ===

	// UsePKCE 是否使用 PKCE (Proof Key for Code Exchange)
	// PKCE 用于公开客户端增强安全性（如移动应用、SPA）
	UsePKCE bool `json:"use_pkce"`

	// TokenRequestType Token 请求格式（JSON 或 Form）
	TokenRequestType TokenRequestType `json:"token_request_type"`

	// AuthHeaderFormat 认证头格式
	AuthHeaderFormat AuthHeaderFormat `json:"auth_header_format"`

	// CustomAuthBuilder 自定义认证头构建器（当 AuthHeaderFormat 为 Custom 时使用）
	// 输入: access_token，输出: 完整的认证头值
	CustomAuthBuilder func(accessToken string) string `json:"-"`

	// === Token 刷新配置 ===

	// RefreshTokenURL Token 刷新端点（默认使用 Endpoint.TokenURL）
	RefreshTokenURL string `json:"refresh_token_url,omitempty"`

	// RefreshExtraParams 刷新 Token 时的额外参数
	RefreshExtraParams map[string]string `json:"refresh_extra_params,omitempty"`

	// === 授权流程配置 ===

	// AuthURLParams 授权 URL 的额外参数
	AuthURLParams map[string]string `json:"auth_url_params,omitempty"`

	// CodeFormat 授权码格式说明（用于前端提示）
	// 例如："code" 或 "code#state"
	CodeFormat string `json:"code_format,omitempty"`

	// === 前端显示配置 ===

	// DisplayName 前端显示名称
	DisplayName string `json:"display_name"`

	// HelpText 帮助文本（前端显示）
	HelpText string `json:"help_text"`

	// IconURL 图标 URL（可选）
	IconURL string `json:"icon_url,omitempty"`
}

// Validate 验证配置的有效性
func (c *OAuth2Config) Validate() error {
	if c.ProviderName == "" {
		return ErrInvalidConfig("provider_name is required")
	}
	if c.ClientID == "" {
		return ErrInvalidConfig("client_id is required")
	}
	if c.RedirectURL == "" {
		return ErrInvalidConfig("redirect_url is required")
	}
	if c.Endpoint.AuthURL == "" {
		return ErrInvalidConfig("endpoint.auth_url is required")
	}
	if c.Endpoint.TokenURL == "" {
		return ErrInvalidConfig("endpoint.token_url is required")
	}
	if c.DisplayName == "" {
		c.DisplayName = c.ProviderName
	}
	return nil
}

// GetRefreshURL 获取 Token 刷新 URL（如果未设置则使用 TokenURL）
func (c *OAuth2Config) GetRefreshURL() string {
	if c.RefreshTokenURL != "" {
		return c.RefreshTokenURL
	}
	return c.Endpoint.TokenURL
}

// GetCodeFormat 获取授权码格式说明（默认为 "code"）
func (c *OAuth2Config) GetCodeFormat() string {
	if c.CodeFormat != "" {
		return c.CodeFormat
	}
	return "code"
}

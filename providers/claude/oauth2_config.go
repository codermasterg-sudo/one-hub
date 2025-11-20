package claude

import (
	"one-api/common/oauth2"

	oauth2Lib "golang.org/x/oauth2"
)

func init() {
	// 注册 Claude 的 OAuth2 配置
	oauth2.MustRegister(&oauth2.OAuth2Config{
		ProviderName: "claude",
		ClientID:     "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
		ClientSecret: "", // 公开客户端，无需 secret
		RedirectURL:  "https://console.anthropic.com/oauth/code/callback",
		Scopes: []string{
			"org:create_api_key",
			"user:profile",
			"user:inference",
		},
		Endpoint: oauth2Lib.Endpoint{
			AuthURL:   "https://claude.ai/oauth/authorize",
			TokenURL:  "https://console.anthropic.com/v1/oauth/token",
			AuthStyle: oauth2Lib.AuthStyleInParams,
		},

		// Claude 特殊配置
		UsePKCE:          true,                         // Claude 使用 PKCE
		TokenRequestType: oauth2.TokenRequestJSON,     // Claude 需要 JSON 格式
		AuthHeaderFormat: oauth2.AuthHeaderBearer,     // 使用 Bearer token
		CodeFormat:       "code#state",                 // Claude 返回格式为 "code#state"

		// 前端显示配置
		DisplayName: "Claude (OAuth2)",
		HelpText:    "使用 Claude Pro 或 Claude Max 订阅账号授权",
		IconURL:     "",
	})
}

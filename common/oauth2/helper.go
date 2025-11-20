package oauth2

import (
	"golang.org/x/oauth2"
)

// GenerateAuthURL 生成授权 URL
func GenerateAuthURL(providerName string, state string) (string, error) {
	config, err := GetConfig(providerName)
	if err != nil {
		return "", err
	}

	oauth2Config := &oauth2.Config{
		ClientID:     config.ClientID,
		ClientSecret: config.ClientSecret,
		RedirectURL:  config.RedirectURL,
		Scopes:       config.Scopes,
		Endpoint:     config.Endpoint,
	}

	var authURL string

	if config.UsePKCE {
		// PKCE 流程
		authURL = oauth2Config.AuthCodeURL(state,
			oauth2.S256ChallengeOption(state),
			oauth2.SetAuthURLParam("code", "true"),
		)
	} else {
		// 标准 OAuth2 流程
		authURL = oauth2Config.AuthCodeURL(state)
	}

	// 添加额外的 URL 参数
	if len(config.AuthURLParams) > 0 {
		separator := "&"
		for key, value := range config.AuthURLParams {
			authURL += separator + key + "=" + value
		}
	}

	return authURL, nil
}

// GenerateState 生成随机 state（用于 CSRF 保护）
// 对于 PKCE，使用 oauth2.GenerateVerifier() 生成
func GenerateState(usePKCE bool) string {
	if usePKCE {
		return oauth2.GenerateVerifier()
	}
	// 简单实现：使用时间戳 + 随机数
	return oauth2.GenerateVerifier() // 复用 verifier 生成器
}

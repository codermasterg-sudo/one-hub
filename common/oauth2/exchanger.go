package oauth2

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"golang.org/x/oauth2"
)

// DefaultExchanger 默认的授权码交换器实现
type DefaultExchanger struct {
	config    *OAuth2Config
	client    *http.Client
	proxyAddr string
}

// NewDefaultExchanger 创建默认交换器
func NewDefaultExchanger(config *OAuth2Config) *DefaultExchanger {
	return NewDefaultExchangerWithProxy(config, "")
}

// NewDefaultExchangerWithProxy 创建支持代理的默认交换器
func NewDefaultExchangerWithProxy(config *OAuth2Config, proxyAddr string) *DefaultExchanger {
	return &DefaultExchanger{
		config:    config,
		client:    CreateHTTPClientWithProxy(proxyAddr),
		proxyAddr: proxyAddr,
	}
}

// Exchange 实现 TokenExchanger 接口
func (e *DefaultExchanger) Exchange(ctx context.Context, code string, state string) (*oauth2.Token, error) {
	if code == "" {
		return nil, NewOAuth2Error(e.config.ProviderName, "exchange", fmt.Errorf("code is empty"))
	}

	// 处理特殊格式的 code（如 "code#state" 格式）
	actualCode, actualState := e.parseCode(code, state)

	// 如果配置使用 PKCE，验证 state
	if e.config.UsePKCE && actualState != state {
		return nil, NewOAuth2Error(e.config.ProviderName, "exchange", ErrInvalidState)
	}

	// 根据配置选择不同的请求格式
	switch e.config.TokenRequestType {
	case TokenRequestJSON:
		return e.exchangeWithJSON(ctx, actualCode, actualState)
	case TokenRequestForm:
		return e.exchangeWithForm(ctx, actualCode, actualState)
	default:
		return e.exchangeWithForm(ctx, actualCode, actualState)
	}
}

// parseCode 解析授权码（支持 "code#state" 格式）
func (e *DefaultExchanger) parseCode(code string, state string) (string, string) {
	// 检查是否包含 # 分隔符（某些 Provider 使用此格式）
	if strings.Contains(code, "#") {
		parts := strings.SplitN(code, "#", 2)
		if len(parts) == 2 {
			return parts[0], parts[1]
		}
	}
	return code, state
}

// exchangeWithJSON 使用 JSON 格式交换 token
func (e *DefaultExchanger) exchangeWithJSON(ctx context.Context, code string, state string) (*oauth2.Token, error) {
	reqBody := map[string]string{
		"grant_type":   "authorization_code",
		"code":         code,
		"client_id":    e.config.ClientID,
		"redirect_uri": e.config.RedirectURL,
	}

	// 添加 client_secret（如果有）
	if e.config.ClientSecret != "" {
		reqBody["client_secret"] = e.config.ClientSecret
	}

	// PKCE: 添加 state 和 code_verifier
	if e.config.UsePKCE && state != "" {
		reqBody["state"] = state
		reqBody["code_verifier"] = state // PKCE 中 verifier 和 state 相同
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, NewOAuth2Error(e.config.ProviderName, "exchange", fmt.Errorf("marshal request: %w", err))
	}

	// 为请求添加代理配置
	ctx = WrapRequestWithProxy(ctx, e.proxyAddr)

	req, err := http.NewRequestWithContext(ctx, "POST", e.config.Endpoint.TokenURL, bytes.NewReader(jsonData))
	if err != nil {
		return nil, NewOAuth2Error(e.config.ProviderName, "exchange", fmt.Errorf("create request: %w", err))
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	return e.doExchange(ctx, req)
}

// exchangeWithForm 使用 Form 格式交换 token
func (e *DefaultExchanger) exchangeWithForm(ctx context.Context, code string, state string) (*oauth2.Token, error) {
	data := url.Values{}
	data.Set("grant_type", "authorization_code")
	data.Set("code", code)
	data.Set("client_id", e.config.ClientID)
	data.Set("redirect_uri", e.config.RedirectURL)

	// 添加 client_secret（如果有）
	if e.config.ClientSecret != "" {
		data.Set("client_secret", e.config.ClientSecret)
	}

	// PKCE: 添加 code_verifier
	if e.config.UsePKCE && state != "" {
		data.Set("code_verifier", state)
	}

	// 为请求添加代理配置
	ctx = WrapRequestWithProxy(ctx, e.proxyAddr)

	req, err := http.NewRequestWithContext(ctx, "POST", e.config.Endpoint.TokenURL, bytes.NewBufferString(data.Encode()))
	if err != nil {
		return nil, NewOAuth2Error(e.config.ProviderName, "exchange", fmt.Errorf("create request: %w", err))
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")

	return e.doExchange(ctx, req)
}

// doExchange 执行交换请求
func (e *DefaultExchanger) doExchange(ctx context.Context, req *http.Request) (*oauth2.Token, error) {
	now := time.Now()

	resp, err := e.client.Do(req)
	if err != nil {
		return nil, NewOAuth2Error(e.config.ProviderName, "exchange", fmt.Errorf("do request: %w", err))
	}
	defer resp.Body.Close()

	// 读取响应体
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, NewOAuth2Error(e.config.ProviderName, "exchange", fmt.Errorf("read response: %w", err))
	}

	// 检查状态码
	if resp.StatusCode != http.StatusOK {
		return nil, NewOAuth2Error(e.config.ProviderName, "exchange", fmt.Errorf("status %d: %s", resp.StatusCode, string(body)))
	}

	// 解析响应
	var token oauth2.Token
	if err := json.Unmarshal(body, &token); err != nil {
		return nil, NewOAuth2Error(e.config.ProviderName, "exchange", fmt.Errorf("parse response: %w", err))
	}

	// 设置过期时间
	if token.Expiry.IsZero() && token.ExpiresIn > 0 {
		token.Expiry = now.Add(time.Duration(token.ExpiresIn) * time.Second)
	}

	return &token, nil
}

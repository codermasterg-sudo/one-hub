package oauth2

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"golang.org/x/oauth2"
)

// DefaultRefresher 默认的 Token 刷新器实现
type DefaultRefresher struct {
	config    *OAuth2Config
	client    *http.Client
	proxyAddr string
}

// NewDefaultRefresher 创建默认刷新器
func NewDefaultRefresher(config *OAuth2Config) *DefaultRefresher {
	return NewDefaultRefresherWithProxy(config, "")
}

// NewDefaultRefresherWithProxy 创建支持代理的默认刷新器
func NewDefaultRefresherWithProxy(config *OAuth2Config, proxyAddr string) *DefaultRefresher {
	return &DefaultRefresher{
		config:    config,
		client:    CreateHTTPClientWithProxy(proxyAddr),
		proxyAddr: proxyAddr,
	}
}

// RefreshToken 实现 TokenRefresher 接口
func (r *DefaultRefresher) RefreshToken(ctx context.Context, refreshToken string) (*oauth2.Token, error) {
	if refreshToken == "" {
		return nil, NewOAuth2Error(r.config.ProviderName, "refresh", fmt.Errorf("refresh_token is empty"))
	}

	// 根据配置选择不同的请求格式
	switch r.config.TokenRequestType {
	case TokenRequestJSON:
		return r.refreshWithJSON(ctx, refreshToken)
	case TokenRequestForm:
		return r.refreshWithForm(ctx, refreshToken)
	default:
		return r.refreshWithForm(ctx, refreshToken)
	}
}

// refreshWithJSON 使用 JSON 格式刷新 token（非标准格式）
func (r *DefaultRefresher) refreshWithJSON(ctx context.Context, refreshToken string) (*oauth2.Token, error) {
	// 构建请求体
	reqBody := map[string]string{
		"grant_type":    "refresh_token",
		"refresh_token": refreshToken,
		"client_id":     r.config.ClientID,
	}

	// 添加 client_secret（如果有）
	if r.config.ClientSecret != "" {
		reqBody["client_secret"] = r.config.ClientSecret
	}

	// 添加额外参数
	for k, v := range r.config.RefreshExtraParams {
		reqBody[k] = v
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, NewOAuth2Error(r.config.ProviderName, "refresh", fmt.Errorf("marshal request: %w", err))
	}

	// 为请求添加代理配置
	ctx = WrapRequestWithProxy(ctx, r.proxyAddr)

	// 创建请求
	req, err := http.NewRequestWithContext(ctx, "POST", r.config.GetRefreshURL(), bytes.NewReader(jsonData))
	if err != nil {
		return nil, NewOAuth2Error(r.config.ProviderName, "refresh", fmt.Errorf("create request: %w", err))
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	return r.doRefresh(ctx, req)
}

// refreshWithForm 使用 Form 格式刷新 token（标准 OAuth2）
func (r *DefaultRefresher) refreshWithForm(ctx context.Context, refreshToken string) (*oauth2.Token, error) {
	// 构建表单数据
	data := url.Values{}
	data.Set("grant_type", "refresh_token")
	data.Set("refresh_token", refreshToken)
	data.Set("client_id", r.config.ClientID)

	// 添加 client_secret（如果有）
	if r.config.ClientSecret != "" {
		data.Set("client_secret", r.config.ClientSecret)
	}

	// 添加额外参数
	for k, v := range r.config.RefreshExtraParams {
		data.Set(k, v)
	}

	// 为请求添加代理配置
	ctx = WrapRequestWithProxy(ctx, r.proxyAddr)

	// 创建请求
	req, err := http.NewRequestWithContext(ctx, "POST", r.config.GetRefreshURL(), bytes.NewBufferString(data.Encode()))
	if err != nil {
		return nil, NewOAuth2Error(r.config.ProviderName, "refresh", fmt.Errorf("create request: %w", err))
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")

	return r.doRefresh(ctx, req)
}

// doRefresh 执行刷新请求
func (r *DefaultRefresher) doRefresh(ctx context.Context, req *http.Request) (*oauth2.Token, error) {
	now := time.Now()

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, NewOAuth2Error(r.config.ProviderName, "refresh", fmt.Errorf("do request: %w", err))
	}
	defer resp.Body.Close()

	// 读取响应体
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, NewOAuth2Error(r.config.ProviderName, "refresh", fmt.Errorf("read response: %w", err))
	}

	// 检查状态码
	if resp.StatusCode != http.StatusOK {
		return nil, NewOAuth2Error(r.config.ProviderName, "refresh", fmt.Errorf("status %d: %s", resp.StatusCode, string(body)))
	}

	// 解析响应
	var token oauth2.Token
	if err := json.Unmarshal(body, &token); err != nil {
		return nil, NewOAuth2Error(r.config.ProviderName, "refresh", fmt.Errorf("parse response: %w", err))
	}

	// 设置过期时间（如果响应中有 expires_in）
	if token.Expiry.IsZero() && token.ExpiresIn > 0 {
		token.Expiry = now.Add(time.Duration(token.ExpiresIn) * time.Second)
	}

	// 如果没有返回新的 refresh_token，使用原来的
	if token.RefreshToken == "" {
		token.RefreshToken = req.FormValue("refresh_token")
	}

	return &token, nil
}

package claude

import (
	"fmt"
	"net/http"
	"strings"

	"one-api/common"
	"one-api/common/config"
	"one-api/common/logger"
	"one-api/common/requester"
	"one-api/model"
	"one-api/providers/base"
	"one-api/types"
)

// ClaudeOAuth2ProviderFactory OAuth2 Provider 工厂
type ClaudeOAuth2ProviderFactory struct{}

// Create 创建 Claude OAuth2 Provider
func (f ClaudeOAuth2ProviderFactory) Create(channel *model.Channel) base.ProviderInterface {
	// 安全地获取代理地址
	proxyAddr := ""
	if channel.Proxy != nil {
		proxyAddr = *channel.Proxy
	}

	provider := &ClaudeOAuth2Provider{
		BaseProvider: base.BaseProvider{
			Config:    getConfig(),
			Channel:   channel,
			Requester: requester.NewHTTPRequester(proxyAddr, RequestErrorHandle),
		},
	}

	// 初始化 OAuth2，自动从 channel 中读取 refresh_token 和代理配置
	// API 请求和 OAuth2 操作将使用同一个代理
	if err := provider.InitOAuth2FromChannel("claude", channel); err != nil {
		// 如果初始化失败，记录错误但不中断创建过程
		// 实际请求时会返回错误
		logger.SysError(fmt.Sprintf("Channel %d OAuth2 initialization failed: %v, proxy=%v, key_length=%d",
			channel.Id, err, channel.Proxy, len(channel.Key)))
	} else {
		proxyInfo := "no proxy"
		if channel.Proxy != nil && *channel.Proxy != "" {
			proxyInfo = *channel.Proxy
		}
		logger.SysLog(fmt.Sprintf("Channel %d OAuth2 initialized successfully with proxy: %s", channel.Id, proxyInfo))
	}

	return provider
}

// ClaudeOAuth2Provider Claude OAuth2 Provider 实现
type ClaudeOAuth2Provider struct {
	base.BaseProvider
	base.OAuth2ProviderMixin // 组合 OAuth2 能力
}

// GetRequestHeaders 覆盖基类方法，使用 OAuth2 认证
func (p *ClaudeOAuth2Provider) GetRequestHeaders() (headers map[string]string) {
	headers = make(map[string]string)
	p.CommonRequestHeaders(headers)

	// 获取 OAuth2 认证头
	p.AddOAuth2Headers(headers)

	// 添加 Anthropic 必需的头
	anthropicVersion := "2023-06-01"
	if p.Context != nil && p.Context.Request != nil {
		if ver := p.Context.Request.Header.Get("anthropic-version"); ver != "" {
			anthropicVersion = ver
		}
	}
	headers["anthropic-version"] = anthropicVersion

	return headers
}

// GetFullRequestURL 获取完整请求URL
func (p *ClaudeOAuth2Provider) GetFullRequestURL(requestURL string) string {
	baseURL := strings.TrimSuffix(p.GetBaseURL(), "/")
	if strings.HasPrefix(baseURL, "https://gateway.ai.cloudflare.com") {
		requestURL = strings.TrimPrefix(requestURL, "/v1")
	}

	return fmt.Sprintf("%s%s", baseURL, requestURL)
}

// 以下方法复用 ClaudeProvider 的实现

// CreateChatCompletion 创建聊天完成（非流式）
func (p *ClaudeOAuth2Provider) CreateChatCompletion(request *types.ChatCompletionRequest) (*types.ChatCompletionResponse, *types.OpenAIErrorWithStatusCode) {
	// 转换请求
	claudeRequest, errWithCode := ConvertFromChatOpenai(request)
	if errWithCode != nil {
		return nil, errWithCode
	}

	req, errWithCode := p.getChatRequest(claudeRequest)
	if errWithCode != nil {
		return nil, errWithCode
	}

	claudeResponse := &ClaudeResponse{}
	_, errWithCode = p.Requester.SendRequest(req, claudeResponse, false)
	if errWithCode != nil {
		return nil, errWithCode
	}

	return ConvertToChatOpenai(p, claudeResponse, request)
}

// CreateChatCompletionStream 创建聊天完成（流式）
func (p *ClaudeOAuth2Provider) CreateChatCompletionStream(request *types.ChatCompletionRequest) (requester.StreamReaderInterface[string], *types.OpenAIErrorWithStatusCode) {
	claudeRequest, errWithCode := ConvertFromChatOpenai(request)
	if errWithCode != nil {
		return nil, errWithCode
	}

	req, errWithCode := p.getChatRequest(claudeRequest)
	if errWithCode != nil {
		return nil, errWithCode
	}

	resp, errWithCode := p.Requester.SendRequestRaw(req)
	if errWithCode != nil {
		return nil, errWithCode
	}

	chatHandler := &ClaudeStreamHandler{
		Usage:   p.Usage,
		Request: request,
		Prefix:  `data: {"type"`,
	}

	return requester.RequestStream(p.Requester, resp, chatHandler.HandlerStream)
}

// getChatRequest 获取聊天请求（内部方法）
func (p *ClaudeOAuth2Provider) getChatRequest(claudeRequest *ClaudeRequest) (*http.Request, *types.OpenAIErrorWithStatusCode) {
	url, errWithCode := p.GetSupportedAPIUri(config.RelayModeChatCompletions)
	if errWithCode != nil {
		return nil, errWithCode
	}

	// 获取请求地址
	fullRequestURL := p.GetFullRequestURL(url)
	if fullRequestURL == "" {
		return nil, common.ErrorWrapperLocal(nil, "invalid_claude_config", http.StatusInternalServerError)
	}

	// 获取请求头（已包含 OAuth2 认证）
	headers := p.GetRequestHeaders()
	if claudeRequest.Stream {
		headers["Accept"] = "text/event-stream"
	}

	if strings.HasPrefix(claudeRequest.Model, "claude-3-5-sonnet") {
		headers["anthropic-beta"] = "max-tokens-3-5-sonnet-2024-07-15"
	}

	if strings.HasPrefix(claudeRequest.Model, "claude-3-7-sonnet") {
		headers["anthropic-beta"] = "output-128k-2025-02-19"
	}

	// 创建请求
	req, err := p.Requester.NewRequest(http.MethodPost, fullRequestURL, p.Requester.WithBody(claudeRequest), p.Requester.WithHeader(headers))
	if err != nil {
		return nil, common.ErrorWrapperLocal(err, "new_request_failed", http.StatusInternalServerError)
	}

	return req, nil
}

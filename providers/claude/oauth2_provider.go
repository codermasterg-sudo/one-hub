package claude

import (
	"net/http"

	"one-api/common/requester"
	"one-api/model"
	"one-api/providers/base"
	"one-api/types"
)

// ClaudeOAuth2ProviderFactory OAuth2 Provider 工厂
type ClaudeOAuth2ProviderFactory struct{}

// Create 创建 Claude OAuth2 Provider
func (f ClaudeOAuth2ProviderFactory) Create(channel *model.Channel) base.ProviderInterface {
	provider := &ClaudeOAuth2Provider{
		BaseProvider: base.BaseProvider{
			Config:    getConfig(),
			Channel:   channel,
			Requester: requester.NewHTTPRequester(*channel.Proxy, RequestErrorHandle),
		},
	}

	// 初始化 OAuth2，自动从 channel 中读取 refresh_token 和代理配置
	// API 请求和 OAuth2 操作将使用同一个代理
	if err := provider.InitOAuth2FromChannel("claude", channel); err != nil {
		// 如果初始化失败，记录错误但不中断创建过程
		// 实际请求时会返回错误
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
	if p.IsOAuth2Enabled() {
		oauth2Headers, err := p.GetOAuth2Headers(p.Context)
		if err != nil {
			// 错误处理：如果获取 OAuth2 头失败，记录错误
			// 实际请求会因为缺少认证而失败
			return headers
		}

		// 合并 OAuth2 头
		for k, v := range oauth2Headers {
			headers[k] = v
		}
	}

	// 添加 Anthropic 必需的头
	anthropicVersion := p.Context.Request.Header.Get("anthropic-version")
	if anthropicVersion == "" {
		anthropicVersion = "2023-06-01"
	}
	headers["anthropic-version"] = anthropicVersion

	return headers
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
	defer req.Body.Close()

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
	defer req.Body.Close()

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
func (p *ClaudeOAuth2Provider) getChatRequest(claudeRequest *ClaudeRequest) (*types.HttpRequest, *types.OpenAIErrorWithStatusCode) {
	url, errWithCode := p.GetSupportedAPIUri(types.RelayModeChatCompletions)
	if errWithCode != nil {
		return nil, errWithCode
	}

	// 获取请求头（已包含 OAuth2 认证）
	headers := p.GetRequestHeaders()

	req := &types.HttpRequest{
		Url:     url,
		Method:  "POST",
		Headers: headers,
	}

	if p.Channel.Plugin != nil {
		newModel, err := getCustomModel(p.Channel.Plugin, claudeRequest.Model)
		if err == nil {
			claudeRequest.Model = newModel
		}
	}

	if err := req.SetBody(claudeRequest); err != nil {
		return nil, types.OpenAIErrorWrapper(err, "marshal_request_body_failed", http.StatusInternalServerError)
	}

	return req, nil
}

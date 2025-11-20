package oauth2

import (
	"context"
	"net/http"
	"time"

	"one-api/common/utils"
)

// CreateHTTPClientWithProxy 创建带代理配置的 HTTP Client
// proxyAddr: 代理地址（支持 http://, https://, socks5:// 协议）
// 如果 proxyAddr 为空，返回不使用代理的 Client
func CreateHTTPClientWithProxy(proxyAddr string) *http.Client {
	// 创建 Transport
	transport := &http.Transport{
		DialContext: utils.Socks5ProxyFunc,
		Proxy:       utils.ProxyFunc,
	}

	client := &http.Client{
		Transport: transport,
		Timeout:   30 * time.Second,
	}

	// 如果配置了代理，设置到 context 中
	// 注意：这里我们不能直接设置 context，需要在请求时设置
	// 所以我们返回 client 和一个辅助函数
	return client
}

// WrapRequestWithProxy 为请求添加代理配置
// 如果 proxyAddr 为空，返回原始 context
func WrapRequestWithProxy(ctx context.Context, proxyAddr string) context.Context {
	if proxyAddr == "" {
		return ctx
	}
	return utils.SetProxy(proxyAddr, ctx)
}

package controller

import (
	"context"
	"fmt"
	"net/http"

	"one-api/common"
	"one-api/common/oauth2"

	"github.com/gin-gonic/gin"
)

// GetOAuth2Providers 获取所有支持 OAuth2 的 Provider 列表
// GET /api/oauth2/providers
func GetOAuth2Providers(c *gin.Context) {
	configs := oauth2.ListConfigs()

	// 构建前端需要的数据结构
	result := make(map[string]interface{})
	for name, config := range configs {
		result[name] = gin.H{
			"display_name": config.DisplayName,
			"help_text":    config.HelpText,
			"icon_url":     config.IconURL,
			"code_format":  config.GetCodeFormat(),
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "",
		"data":    result,
	})
}

// GetOAuth2AuthURL 生成 OAuth2 授权 URL
// GET /api/oauth2/auth_url?provider=claude
func GetOAuth2AuthURL(c *gin.Context) {
	providerName := c.Query("provider")
	if providerName == "" {
		common.APIRespondWithError(c, http.StatusBadRequest, fmt.Errorf("provider parameter is required"))
		return
	}

	// 检查 Provider 是否已注册
	if !oauth2.IsRegistered(providerName) {
		common.APIRespondWithError(c, http.StatusBadRequest, fmt.Errorf("provider '%s' not found", providerName))
		return
	}

	// 获取配置
	config, err := oauth2.GetConfig(providerName)
	if err != nil {
		common.APIRespondWithError(c, http.StatusInternalServerError, err)
		return
	}

	// 生成 state（用于 CSRF 保护和 PKCE）
	state := oauth2.GenerateState(config.UsePKCE)

	// 生成授权 URL
	authURL, err := oauth2.GenerateAuthURL(providerName, state)
	if err != nil {
		common.APIRespondWithError(c, http.StatusInternalServerError, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "",
		"data": gin.H{
			"auth_url":    authURL,
			"state":       state,
			"provider":    providerName,
			"use_pkce":    config.UsePKCE,
			"code_format": config.GetCodeFormat(),
		},
	})
}

// ExchangeOAuth2Code 交换授权码获取 refresh_token
// POST /api/oauth2/exchange
// Body: {"provider": "claude", "code": "xxx", "state": "xxx"}
func ExchangeOAuth2Code(c *gin.Context) {
	var req struct {
		Provider string `json:"provider" binding:"required"`
		Code     string `json:"code" binding:"required"`
		State    string `json:"state" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		common.APIRespondWithError(c, http.StatusBadRequest, err)
		return
	}

	// 检查 Provider 是否已注册
	if !oauth2.IsRegistered(req.Provider) {
		common.APIRespondWithError(c, http.StatusBadRequest, fmt.Errorf("provider '%s' not found", req.Provider))
		return
	}

	// 获取配置
	config, err := oauth2.GetConfig(req.Provider)
	if err != nil {
		common.APIRespondWithError(c, http.StatusInternalServerError, err)
		return
	}

	// 创建 Exchanger
	exchanger := oauth2.NewDefaultExchanger(config)

	// 交换授权码
	ctx := context.Background()
	token, err := exchanger.Exchange(ctx, req.Code, req.State)
	if err != nil {
		common.APIRespondWithError(c, http.StatusOK, fmt.Errorf("token exchange failed: %w", err))
		return
	}

	// 返回结果
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "OAuth2 authorization successful",
		"data": gin.H{
			"refresh_token": token.RefreshToken,
			"access_token":  token.AccessToken,
			"expires_in":    int(token.Expiry.Sub(common.GetTimeNow()).Seconds()),
		},
	})
}

// TestOAuth2Token 测试 OAuth2 Token 是否有效
// POST /api/oauth2/test
// Body: {"provider": "claude", "refresh_token": "xxx"}
func TestOAuth2Token(c *gin.Context) {
	var req struct {
		Provider     string `json:"provider" binding:"required"`
		RefreshToken string `json:"refresh_token" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		common.APIRespondWithError(c, http.StatusBadRequest, err)
		return
	}

	// 创建 Manager 并尝试获取 access_token
	manager, err := oauth2.NewManager(req.Provider, req.RefreshToken)
	if err != nil {
		common.APIRespondWithError(c, http.StatusOK, err)
		return
	}

	ctx := context.Background()
	token, err := manager.GetAccessToken(ctx)
	if err != nil {
		common.APIRespondWithError(c, http.StatusOK, fmt.Errorf("token validation failed: %w", err))
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "OAuth2 token is valid",
		"data": gin.H{
			"valid":      true,
			"expires_in": int(token.Expiry.Sub(common.GetTimeNow()).Seconds()),
		},
	})
}

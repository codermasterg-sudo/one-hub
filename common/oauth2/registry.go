package oauth2

import (
	"fmt"
	"sync"
)

// 全局配置注册表
var (
	registry = make(map[string]*OAuth2Config)
	mu       sync.RWMutex
)

// Register 注册 Provider 的 OAuth2 配置
// 应该在 init() 函数中调用，用于注册各个 Provider 的配置
func Register(config *OAuth2Config) error {
	if config == nil {
		return fmt.Errorf("config cannot be nil")
	}

	// 验证配置
	if err := config.Validate(); err != nil {
		return err
	}

	mu.Lock()
	defer mu.Unlock()

	// 检查是否已注册
	if _, exists := registry[config.ProviderName]; exists {
		return fmt.Errorf("oauth2 provider '%s' already registered", config.ProviderName)
	}

	registry[config.ProviderName] = config
	return nil
}

// MustRegister 注册配置，如果失败则 panic（用于 init 函数）
func MustRegister(config *OAuth2Config) {
	if err := Register(config); err != nil {
		panic(fmt.Sprintf("failed to register oauth2 provider: %v", err))
	}
}

// GetConfig 获取 Provider 的 OAuth2 配置
func GetConfig(providerName string) (*OAuth2Config, error) {
	mu.RLock()
	defer mu.RUnlock()

	config, ok := registry[providerName]
	if !ok {
		return nil, NewOAuth2Error(providerName, "get_config", ErrProviderNotFound)
	}

	return config, nil
}

// IsRegistered 检查 Provider 是否已注册
func IsRegistered(providerName string) bool {
	mu.RLock()
	defer mu.RUnlock()

	_, ok := registry[providerName]
	return ok
}

// ListProviders 列出所有已注册的 Provider
func ListProviders() []string {
	mu.RLock()
	defer mu.RUnlock()

	providers := make([]string, 0, len(registry))
	for name := range registry {
		providers = append(providers, name)
	}
	return providers
}

// ListConfigs 列出所有已注册的配置
func ListConfigs() map[string]*OAuth2Config {
	mu.RLock()
	defer mu.RUnlock()

	configs := make(map[string]*OAuth2Config, len(registry))
	for name, config := range registry {
		configs[name] = config
	}
	return configs
}

// Unregister 注销 Provider 配置（主要用于测试）
func Unregister(providerName string) {
	mu.Lock()
	defer mu.Unlock()

	delete(registry, providerName)
}

// Clear 清空所有注册（主要用于测试）
func Clear() {
	mu.Lock()
	defer mu.Unlock()

	registry = make(map[string]*OAuth2Config)
}

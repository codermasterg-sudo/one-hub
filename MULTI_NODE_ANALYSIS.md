# 多节点部署 Token 管理分析

## 当前实现的架构

### Token 生命周期
```
用户授权 → Refresh Token (存储在 DB)
                ↓
         各节点独立维护 Access Token (内存)
```

## ⚠️ 存在的问题

### 问题 1: Access Token 内存缓存不共享
**现象：**
- 每个节点启动时，Access Token 缓存为空
- 每个节点会独立用 Refresh Token 去换取 Access Token

**影响：**
- 轻微性能损失：多个节点重复刷新
- 通常**不会**造成功能问题，因为 OAuth2 标准允许多次刷新

### 问题 2: Refresh Token 轮换（Token Rotation）
**现象：**
某些 OAuth2 实现（如部分银行 API）会在刷新时返回**新的 Refresh Token**，旧的立即失效。

**代码处理：**
```go
// common/oauth2/manager.go:80-82
if newToken.RefreshToken != "" && newToken.RefreshToken != m.refreshToken {
    m.refreshToken = newToken.RefreshToken
}
```

**❌ 当前问题：**
- 新的 Refresh Token 只保存在内存中
- 没有回写到数据库的 `Channel.Key`
- **多节点竞态条件**：节点 A 刷新后，节点 B 仍使用旧 Token，导致 B 刷新失败

## ✅ Claude OAuth2 的情况

根据 [Anthropic OAuth2 文档](https://docs.anthropic.com/en/api/oauth)：

- ✅ Claude 的 Refresh Token **不会轮换**
- ✅ 同一个 Refresh Token 可以多次使用
- ✅ 多个 Access Token 可以同时有效

**结论：对于 Claude，当前实现是安全的！**

## 🔧 需要改进的场景

如果未来要支持**有 Token 轮换的 Provider**（如 Google OAuth2），需要：

### 方案 1: Refresh Token 回写数据库
```go
// 在 Manager.GetAccessToken() 中
if newToken.RefreshToken != "" && newToken.RefreshToken != m.refreshToken {
    m.refreshToken = newToken.RefreshToken
    // 新增：回写数据库
    if m.onRefreshTokenUpdated != nil {
        m.onRefreshTokenUpdated(newToken.RefreshToken)
    }
}
```

### 方案 2: Access Token 使用 Redis 共享
```go
// 使用 Redis 存储 Access Token
type RedisTokenCache struct {
    client *redis.Client
}

func (c *RedisTokenCache) Get(channelID int) *oauth2.Token
func (c *RedisTokenCache) Set(channelID int, token *oauth2.Token)
```

### 方案 3: 分布式锁
```go
// 刷新时加分布式锁
lock := redisLock.Acquire(fmt.Sprintf("oauth2:refresh:%d", channelID))
defer lock.Release()

// 执行刷新
newToken, err := m.refresher.RefreshToken(ctx, m.refreshToken)
```

## 推荐方案

### 短期（当前 Claude 实现）
✅ **无需修改**，当前实现已满足 Claude OAuth2 要求。

### 长期（支持更多 Provider）
推荐 **方案 1 + 方案 2** 的组合：
1. Refresh Token 更新时回写数据库（方案 1）
2. Access Token 使用 Redis 缓存共享（方案 2）
3. Redis 不可用时降级到内存缓存（优雅降级）

## 配置建议

### 单节点部署
- 无需任何额外配置
- 当前实现完全适用

### 多节点部署（Claude）
- 无需额外配置
- 建议：配置健康检查，监控 Token 刷新失败率

### 多节点部署（其他 Provider）
- 检查该 Provider 的 OAuth2 实现是否支持 Token 轮换
- 如有轮换，建议实现方案 1（Refresh Token 回写）
- 如需高并发，建议实现方案 2（Redis 共享缓存）

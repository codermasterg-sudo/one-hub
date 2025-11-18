# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

One Hub 是基于 one-api 二次开发的 AI 中转服务项目，使用 Go 语言后端和 React 前端架构。该项目提供了多供应商 AI 模型的统一接入接口，支持用户管理、计费、渠道管理等功能。

## 常用开发命令

### 构建和运行
```bash
# 完整构建（包含前端）
make one-api

# 仅构建前端
make web

# 清理构建文件
make clean

# 使用 Docker Compose 运行
docker-compose up -d

# 直接运行 Go 程序（需要先构建前端）
go run main.go
```

### 前端开发
```bash
cd web
yarn install
yarn dev       # 开发模式
yarn build     # 生产构建
yarn lint      # 代码检查
yarn lint:fix  # 自动修复
```

### 数据库迁移
```bash
# 程序启动时会自动进行数据库迁移
# 数据库结构定义在 model/ 目录下
```

## 项目架构

### 后端架构（Go）
- **main.go**: 应用入口点，初始化所有组件
- **common/**: 通用工具和配置
  - `config/`: 配置管理
  - `cache/`: 缓存抽象层
  - `logger/`: 日志系统
  - `requester/`: HTTP 客户端封装
- **controller/**: HTTP 控制器层，处理 API 请求
- **model/**: 数据模型层，包含数据库操作
- **relay/**: 中继层，负责与各 AI 供应商通信
- **middleware/**: 中间件（认证、日志等）
- **router/**: 路由配置
- **cron/**: 定时任务
- **cli/**: 命令行工具

### 前端架构（React）
- **web/src/**: React 应用源码
  - `components/`: 可复用组件
  - `pages/`: 页面组件
  - `store/`: Redux 状态管理
  - `utils/`: 工具函数
  - `themes/`: UI 主题配置

### 核心功能模块
1. **用户管理**: 用户注册、认证、权限控制
2. **渠道管理**: AI 供应商渠道配置和管理
3. **计费系统**: 基于使用量的计费和统计
4. **中继服务**: 统一的 API 接口转发到不同供应商
5. **监控系统**: 日志记录、性能监控、状态检查

## 技术栈

### 后端
- **框架**: Gin (HTTP Web 框架)
- **数据库**: 支持 MySQL/PostgreSQL/SQLite
- **缓存**: Redis + 内存缓存
- **ORM**: GORM
- **认证**: JWT + Session
- **配置**: Viper
- **日志**: Zap + Lumberjack

### 前端
- **框架**: React 18
- **状态管理**: Redux Toolkit
- **UI 库**: Material-UI (MUI)
- **路由**: React Router v6
- **构建工具**: Vite
- **语言**: JavaScript/TypeScript

## 环境配置

### 必需的环境变量
- `SQL_DSN`: 数据库连接字符串
- `REDIS_CONN_STRING`: Redis 连接字符串
- `SESSION_SECRET`: 会话密钥
- `USER_TOKEN_SECRET`: 用户令牌密钥

### 可选配置
- `MEMORY_CACHE_ENABLED`: 启用内存缓存
- `SYNC_FREQUENCY`: 数据同步频率（秒）
- `GIN_MODE`: Gin 运行模式 (debug/release)
- `TZ`: 时区设置

### 配置文件支持
项目支持通过配置文件启动，可以将环境变量配置在 `config.yaml` 文件中。

## 数据库

### 主要数据表
- `users`: 用户信息
- `channels`: AI 供应商渠道配置
- `tokens`: 用户 API 令牌
- `logs`: 请求日志
- `options`: 系统配置选项
- `redemptions`: 兑换码
- `orders`: 订单记录
- `user_groups`: 用户组

### 数据库迁移
使用 gormigrate 进行数据库版本管理和自动迁移。

## API 接口

### 认证相关
- `POST /api/user/register` - 用户注册
- `POST /api/user/login` - 用户登录
- `POST /api/user/logout` - 用户登出

### 管理接口
- `GET /api/channel/` - 获取渠道列表
- `POST /api/channel/` - 创建渠道
- `PUT /api/channel/{id}` - 更新渠道
- `DELETE /api/channel/{id}` - 删除渠道

### 中继接口
- `POST /api/chat/completions` - 聊天完成
- `POST /api/embeddings` - 文本嵌入
- `POST /api/moderations` - 内容审核

## 部署说明

### Docker 部署
```bash
# 构建镜像
docker build -t one-hub .

# 使用 docker-compose
docker-compose up -d
```

### 直接部署
```bash
# 构建前端
cd web && yarn build

# 构建后端
go build -o one-api main.go

# 运行
./one-api
```

## 开发注意事项

1. **前端开发**: 前端代码在 `web/` 目录下，使用 yarn 管理依赖
2. **API 版本**: 所有 API 路径以 `/api/` 开头
3. **错误处理**: 使用统一的错误响应格式
4. **日志记录**: 所有操作都应记录日志
5. **权限控制**: 管理员操作需要权限验证
6. **数据库操作**: 使用 GORM 进行数据库操作
7. **缓存策略**: 合理使用 Redis 和内存缓存
8. **供应商适配**: 新增 AI 供应商需要在 `relay/` 目录下实现适配器

## 故障排查

### 常见问题
1. **数据库连接失败**: 检查 SQL_DSN 配置
2. **Redis 连接失败**: 检查 REDIS_CONN_STRING 配置
3. **前端构建失败**: 确保 Node.js 版本 >= 18
4. **渠道测试失败**: 检查供应商 API 密钥和网络连接

### 日志位置
- 应用日志: 通过 logger 包输出
- 数据库日志: GORM 调试模式
- 访问日志: HTTP 请求中间件记录
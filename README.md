# One-Hub

基于 [one-api](https://github.com/songquanpeng/one-api) 二次开发的 AI 模型接口统一管理平台。

## ✨ 主要特性

- 🎨 全新的 UI 界面
- 📊 用户仪表盘和管理员数据统计
- 🔄 支持多种 AI 模型供应商
- 🌐 **Clash 代理集成**（URL 订阅 + 自动更新）
- 🤖 **Claude OAuth2 代理**（多账号负载均衡）
- 📦 完整的 Docker Compose 部署方案
- 🛠️ 50+ 运维命令（Makefile）

---

## 🚀 快速开始

### 一键部署

```bash
# 克隆项目
git clone https://github.com/your-username/one-hub.git
cd one-hub

# 一键安装
make install
```

### 手动部署

```bash
# 1. 初始化环境
make init

# 2. 配置 Clash（编辑订阅链接）
nano clash/config.yaml

# 3. 启动所有服务
make up

# 4. 登录 Claude 账号
make cliproxy-login-multi

# 5. 打开管理后台
# 访问 http://localhost:3000
# 默认账号: root / 123456
```

---

## 📦 服务组成

| 服务 | 端口 | 说明 |
|------|------|------|
| **one-hub** | 3000 | 主应用服务 |
| **mysql** | 3306 | MySQL 数据库 |
| **redis** | - | Redis 缓存 |
| **clash** | 7890/7891/9090 | 代理服务（订阅模式） |
| **cliproxy** | 8080 | Claude 多账号代理 |

---

## 📚 完整文档

### 核心文档

| 文档 | 说明 |
|------|------|
| [文档索引](./docs/文档索引.md) | 📖 所有文档的导航中心 |
| [Docker部署指南](./docs/Docker部署指南.md) | 🚀 完整的部署指南 |
| [Makefile使用指南](./docs/Makefile使用指南.md) | 🛠️ 运维命令说明 |

### 专题文档

| 文档 | 说明 |
|------|------|
| [clash/README.md](./clash/README.md) | 🌐 Clash 代理配置 |
| [cliproxy/README.md](./cliproxy/README.md) | 🤖 CLIProxy 快速参考 |
| [CLIProxy集成指南](./docs/CLIProxy集成指南.md) | 📘 多账号代理详解 |
| [Claude登录指南](./docs/Claude登录指南.md) | 🔐 OAuth2 认证方法 |
| [Claude无浏览器登录](./docs/Claude无浏览器登录.md) | 💻 无 GUI 环境登录 |
| [Claude代理项目对比](./docs/Claude代理项目对比.md) | 📊 开源项目对比 |

---

## 🛠️ 常用命令

### 服务管理

```bash
make help           # 查看所有命令
make ps             # 查看服务状态
make logs           # 查看所有日志
make logs-clash     # 查看 Clash 日志
make logs-cliproxy  # 查看 CLIProxy 日志
make health         # 健康检查
```

### Clash 代理

```bash
make clash-setup      # 配置 Clash
make clash-update     # 更新订阅
make clash-test       # 测试代理
make clash-dashboard  # 打开控制台
```

### CLIProxy 管理

```bash
make cliproxy-login         # 登录单账号
make cliproxy-login-multi   # 登录多账号
make cliproxy-status        # 查看状态
make cliproxy-refresh       # 刷新令牌
make cliproxy-stats         # 查看统计
```

### 备份恢复

```bash
make backup          # 完整备份
make backup-db       # 备份数据库
make restore         # 恢复备份
make list-backups    # 列出备份
```

---

## 🎯 核心特性

### 1. Clash 订阅模式

- ✅ 从 URL 自动加载节点
- ✅ 定时自动刷新（默认每小时）
- ✅ 自动选择最快的美国节点
- ✅ 健康检查和故障转移

**配置文件**: `clash/config-subscription.yaml`

### 2. Claude 多账号代理

- ✅ 轻量级（Go 实现，30MB 内存）
- ✅ 多账号负载均衡（轮询策略）
- ✅ OAuth2 认证，自动刷新令牌
- ✅ OpenAI/Anthropic 双格式兼容

**技术方案**: CLIProxyAPI (1.7k ⭐)

### 3. 完整的运维工具

- ✅ 50+ Makefile 命令
- ✅ 彩色输出，易于阅读
- ✅ 自动备份和恢复
- ✅ 健康检查和监控

---

## 🏗️ 项目结构

```
one-hub/
├── docker-compose.yml        # Docker 编排文件
├── Makefile                  # 运维脚本
├── docs/                     # 📚 文档中心
│   ├── 文档索引.md
│   ├── Docker部署指南.md
│   ├── Makefile使用指南.md
│   ├── CLIProxy集成指南.md
│   ├── Claude登录指南.md
│   ├── Claude无浏览器登录.md
│   └── Claude代理项目对比.md
├── clash/                    # 🌐 Clash 配置
│   ├── config.yaml          # 主配置（使用时创建）
│   ├── config-subscription.yaml  # 订阅模式配置
│   ├── config-manual.yaml   # 手动模式配置
│   ├── subscriptions/       # 订阅缓存
│   └── README.md
├── cliproxy/                # 🤖 CLIProxy 配置
│   ├── config.yaml          # CLIProxy 配置
│   ├── auth/                # 认证凭证（自动生成）
│   └── README.md
├── data/                    # 💾 数据目录
│   ├── mysql/               # MySQL 数据
│   └── redis/               # Redis 数据
└── backups/                 # 📦 备份目录
```

---

## 🌟 核心优势

### vs 原版 one-api

- ✅ 内置 Clash 代理支持（订阅自动更新）
- ✅ 内置 Claude OAuth2 代理（多账号负载均衡）
- ✅ 完整的 Makefile 运维工具集
- ✅ 详细的中文文档

### vs 手动部署

- ✅ 一键部署（`make install`）
- ✅ 自动化运维（50+ 命令）
- ✅ 开箱即用的代理配置
- ✅ 完整的备份恢复方案

---

## 📖 使用场景

### 场景 1：个人使用

- 使用 Claude Pro 订阅 + CLIProxy
- 通过 One-Hub 统一管理多个 AI 模型
- 自动负载均衡，提高稳定性

### 场景 2：团队协作

- 配置多个 Claude 账号
- 通过 One-Hub 分配 API Key
- 监控使用量和成本

### 场景 3：开发测试

- 快速部署本地环境
- 测试不同 AI 模型
- 使用 Makefile 快速重启和调试

---

## ⚙️ 技术栈

- **后端**: Go + Gin
- **前端**: React 19 + TypeScript
- **数据库**: MySQL 8.2 + Redis
- **代理**: Clash Premium + CLIProxyAPI
- **部署**: Docker Compose
- **运维**: Makefile

---

## 🔒 安全建议

1. **修改默认密码**
   - One-Hub 管理员密码
   - MySQL 密码
   - SESSION_SECRET 和 USER_TOKEN_SECRET

2. **保护敏感文件**
   - `clash/config.yaml` - 包含订阅链接
   - `cliproxy/auth/` - 包含 OAuth 凭证
   - `.env` 文件（如果使用）

3. **定期备份**
   ```bash
   # 建议添加到 crontab
   0 2 * * * cd /path/to/one-hub && make backup
   ```

4. **网络安全**
   - 生产环境使用 HTTPS
   - 配置防火墙规则
   - 定期更新 Docker 镜像

---

## 🤝 贡献

欢迎贡献代码、文档或建议！

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

---

## 📄 许可证

本项目基于 [one-api](https://github.com/songquanpeng/one-api) 二次开发，遵循 MIT 许可证。

---

## 🙏 致谢

本项目使用了以下开源项目：

- [one-api](https://github.com/songquanpeng/one-api) - 基础框架
- [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) - Claude 代理
- [Clash Premium](https://github.com/Dreamacro/clash) - 代理服务
- [Berry Admin Template](https://github.com/codedthemes/berry-free-react-admin-template) - 前端界面

---

## 📞 支持

- 📖 [查看文档](./docs/文档索引.md)
- 🐛 [报告问题](https://github.com/your-username/one-hub/issues)
- 💬 [讨论区](https://github.com/your-username/one-hub/discussions)

---

## ⭐ Star History

如果这个项目对您有帮助，请给一个 Star ⭐

---

**最后更新**: 2025-11-23

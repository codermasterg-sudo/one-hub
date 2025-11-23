# Clash 配置目录

## 文件说明

- `config.yaml` - Clash 主配置文件（需要手动创建并配置）
- `ui/` - Clash Dashboard UI 文件（可选）

## 配置步骤

1. 复制示例配置文件：
   ```bash
   cp config.yaml.example config.yaml
   ```

2. 编辑 `config.yaml`，添加您的代理节点信息

3. 启动服务：
   ```bash
   docker-compose up -d clash
   ```

## config.yaml 示例模板

请创建 `config.yaml` 文件，内容如下：

```yaml
# Clash 配置文件示例
# HTTP(S) 和 SOCKS5 代理端口
port: 7890
socks-port: 7891

# 允许局域网连接
allow-lan: true

# Clash 运行模式: rule / global / direct
mode: rule

# 日志级别: info / warning / error / debug / silent
log-level: info

# RESTful API
external-controller: 0.0.0.0:9090

# 代理节点配置（请根据实际情况修改）
proxies:
  # 示例节点 - 请替换为您的实际节点
  - name: "示例节点-香港"
    type: ss
    server: your-server.com
    port: 8388
    cipher: aes-256-gcm
    password: "your-password"

# 代理组配置
proxy-groups:
  # 自动选择最快节点
  - name: "自动选择"
    type: url-test
    proxies:
      - "示例节点-香港"
    url: 'http://www.gstatic.com/generate_204'
    interval: 300

  # OpenAI 专用
  - name: "OpenAI"
    type: select
    proxies:
      - "自动选择"

  # Claude 专用
  - name: "Claude"
    type: select
    proxies:
      - "自动选择"

  # 国际流量
  - name: "国际流量"
    type: select
    proxies:
      - "自动选择"
      - "DIRECT"

# 规则配置
rules:
  # OpenAI 相关域名
  - DOMAIN-SUFFIX,openai.com,OpenAI
  - DOMAIN-SUFFIX,ai.com,OpenAI
  - DOMAIN-KEYWORD,openai,OpenAI

  # Claude / Anthropic 相关域名
  - DOMAIN-SUFFIX,anthropic.com,Claude
  - DOMAIN-SUFFIX,claude.ai,Claude
  - DOMAIN-KEYWORD,anthropic,Claude
  - DOMAIN-KEYWORD,claude,Claude

  # Google Gemini
  - DOMAIN-SUFFIX,googleapis.com,国际流量
  - DOMAIN-SUFFIX,generativelanguage.googleapis.com,国际流量

  # 局域网地址
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT

  # 中国大陆地址直连
  - GEOIP,CN,DIRECT

  # 其他流量使用国际流量策略
  - MATCH,国际流量
```

## 验证配置

启动后访问 Clash Dashboard:
```
http://localhost:9090/ui
```

## 注意事项

- `config.yaml` 文件包含敏感信息，已被添加到 `.gitignore`
- 请不要将包含真实代理节点信息的配置文件提交到版本控制
- 定期检查和更新代理节点配置

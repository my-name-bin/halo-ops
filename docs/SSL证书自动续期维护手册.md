# SSL 证书自动续期维护手册

> 文档版本: v1.0.0
> 创建日期: 2026-05-31
> 最后更新: 2026-05-31
> 维护者: guobin

---

## 一、证书概述

### 1.1 证书信息

| 项目 | 内容 |
|------|------|
| 证书类型 | Let's Encrypt 通配符证书 |
| 域名 | `*.aace.cc` |
| 验证方式 | DNS-01 (DNSPod) |
| 证书路径 | `/data/halo/ssl/live/aace.cc/` |
| 有效期 | 90 天 |
| 续期时机 | 到期前 30 天内 |

### 1.2 证书文件说明

```
ssl/live/aace.cc/
├── fullchain.pem    # 完整证书链（包含公钥和中间证书）
├── privkey.pem      # 私钥文件（需保密）
├── cert.pem         # 服务器证书
├── chain.pem        # 中间证书
└── README          # Certbot 说明文件
```

### 1.3 Nginx SSL 配置

Nginx 配置路径：
- 配置目录: `/data/halo/config/nginx/sites-available/halo.conf`
- 挂载到容器: `/etc/nginx/ssl/`

---

## 二、自动续期机制

### 2.1 续期流程图

```
┌─────────────────────────────────────┐
│  Crontab 定时触发                   │
│  (每天 02:00)                      │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  renew-cert.sh 主脚本               │
│  /data/halo/scripts/certbot/       │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  certbot renew                      │
│  DNS-01 验证 (DNSPod)              │
└──────────────┬──────────────────────┘
               ↓
        ┌──────┴──────┐
        ↓             ↓
┌───────────┐  ┌───────────────┐
│ dns-auth  │  │ dns-cleanup  │
│ 添加 TXT   │  │ 删除 TXT     │
└───────────┘  └───────────────┘
        ↓
┌─────────────────────────────────────┐
│  deploy-hook.sh                     │
│  复制证书到 Nginx 配置目录          │
│  重载 Nginx                         │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  记录日志                           │
│  /data/halo/logs/halo/             │
│  halo-cert-renew.log                │
└─────────────────────────────────────┘
```

### 2.2 Crontab 配置

**当前配置**：
```bash
# 编辑 crontab
crontab -e

# 添加以下任务
0 2 * * * /data/halo/scripts/certbot/renew-cert.sh >> /data/halo/logs/halo/halo-cert-renew.log 2>&1
```

**配置说明**：
- 执行时间: 每天凌晨 2:00
- 执行用户: root
- 日志输出: 追加到日志文件
- 错误处理: 标准错误输出重定向到标准输出

### 2.3 相关脚本文件

| 脚本 | 路径 | 功能 |
|------|------|------|
| 续期主脚本 | `scripts/certbot/renew-cert.sh` | 执行 certbot renew |
| 部署钩子 | `scripts/certbot/deploy-hook.sh` | 部署证书并重载 Nginx |
| DNS 认证 | `scripts/certbot/hooks/dns-auth.sh` | 添加 DNSPod TXT 记录 |
| DNS 清理 | `scripts/certbot/hooks/dns-cleanup.sh` | 删除 DNSPod TXT 记录 |

---

## 三、手动操作指南

### 3.1 查看证书状态

**方法一：使用 Makefile**
```bash
cd /data/halo
make cert-status
```

**方法二：查看证书详情**
```bash
# 查看证书过期时间
openssl x509 -in /data/halo/ssl/live/aace.cc/fullchain.pem -noout -enddate

# 查看证书完整信息
openssl x509 -in /data/halo/ssl/live/aace.cc/fullchain.pem -noout -text

# 查看证书序列号
openssl x509 -in /data/halo/ssl/live/aace.cc/fullchain.pem -noout -serial

# 查看证书颁发者
openssl x509 -in /data/halo/ssl/live/aace.cc/fullchain.pem -noout -issuer
```

**方法三：在线检查**
- [SSL Labs](https://www.ssllabs.com/ssltest/analyze.html?d=your-domain.com)
- [MySSL](https://myssl.com/)

### 3.2 手动续期证书

**前提条件**：
1. 确保 DNSPod API 凭据配置正确（`.env` 文件）
2. 确保域名 DNS 解析正常
3. 确保 cron 服务运行中

**执行续期**：
```bash
cd /data/halo

# 方法一：使用 Makefile
make cert-renew

# 方法二：直接执行脚本
bash scripts/certbot/renew-cert.sh

# 方法三：查看详细输出
bash -x scripts/certbot/renew-cert.sh
```

### 3.3 测试续期流程

**dry-run 模式**（不实际续期）：
```bash
certbot renew --dry-run \
    --dns-dnspod-auth-hook /data/halo/scripts/certbot/hooks/dns-auth.sh \
    --dns-dnspod-cleanup-hook /data/halo/scripts/certbot/hooks/dns-cleanup.sh \
    --config-dir /data/halo/ssl \
    --work-dir /data/halo/ssl \
    --logs-dir /data/halo/logs
```

### 3.4 查看续期日志

```bash
# 查看完整日志
cat /data/halo/logs/halo/halo-cert-renew.log

# 查看最近 50 行
tail -50 /data/halo/logs/halo/halo-cert-renew.log

# 实时查看日志
tail -f /data/halo/logs/halo/halo-cert-renew.log

# 查看今天的日志
grep "$(date '+%Y-%m-%d')" /data/halo/logs/halo/halo-cert-renew.log
```

---

## 四、备份和恢复

### 4.1 自动备份

**备份脚本**：
```bash
cd /data/halo

# 备份 SSL 证书
make backup-ssl

# 或者直接执行
bash scripts/backup/backup-ssl.sh
```

**备份位置**：
```
/data/halo/ssl/backups/
├── ssl_20260531_020000.tar.gz
├── ssl_20260530_020000.tar.gz
└── ssl_20260529_020000.tar.gz
```

### 4.2 手动备份

```bash
cd /data/halo

# 创建备份目录
mkdir -p ssl/backups

# 备份证书
tar -czf ssl/backups/ssl_$(date +%Y%m%d_%H%M%S).tar.gz \
    -C ssl live

# 备份私钥（单独加密备份）
tar -czf ssl/backups/ssl_keys_$(date +%Y%m%d_%H%M%S).tar.gz \
    -C ssl/live/aace.cc privkey.pem
```

### 4.3 恢复证书

**从备份恢复**：
```bash
cd /data/halo

# 停止 Nginx
docker-compose stop nginx

# 解压备份
tar -xzf ssl/backups/ssl_YYYYMMDD_HHMMSS.tar.gz -C ssl/

# 重新启动 Nginx
docker-compose start nginx

# 或重载配置
docker-compose exec nginx nginx -s reload
```

**手动复制证书**：
```bash
cd /data/halo

# 停止 Nginx
docker-compose stop nginx

# 复制证书文件
cp ssl/backups/fullchain.pem ssl/live/aace.cc/
cp ssl/backups/privkey.pem ssl/live/aace.cc/

# 设置正确权限
chmod 644 ssl/live/aace.cc/fullchain.pem
chmod 600 ssl/live/aace.cc/privkey.pem

# 重新启动 Nginx
docker-compose start nginx
```

### 4.4 备份保留策略

**建议**：
- 保留最近 10 个备份
- 保留最近 3 个月的备份
- 定期将备份复制到异地存储

**自动清理**：
```bash
# 清理超过 30 天的备份
find /data/halo/ssl/backups -name "ssl_*.tar.gz" -mtime +30 -delete

# 保留最近 10 个备份
cd /data/halo/ssl/backups
ls -1t ssl_*.tar.gz | tail -n +11 | xargs rm -f
```

---

## 五、故障排查

### 5.1 常见问题

#### 问题 1：DNSPod API 认证失败

**症状**：
```
Error finding DNS record: Authentication failed
```

**排查步骤**：
1. 检查 `.env` 文件中的 DNSPod API 凭据
```bash
grep DNSPOD /data/halo/.env
```

2. 验证 API 凭据是否正确
```bash
# 测试 DNSPod API
curl -X POST "https://api.dnspod.com/Record.List" \
    -d "login_token=YOUR_API_ID,YOUR_API_TOKEN" \
    -d "domain=aace.cc"
```

3. 检查 API 权限是否足够

**解决方案**：
- 更新 `.env` 中的 `DNSPOD_API_ID` 和 `DNSPOD_API_TOKEN`
- 确保 API 具有添加和删除 TXT 记录的权限

#### 问题 2：DNS 传播延迟

**症状**：
```
DNS check failed: NXDOMAIN
```

**排查步骤**：
1. 检查 DNS TXT 记录是否已添加
```bash
# 使用 dig 查看
dig TXT _acme-challenge.aace.cc

# 使用 nslookup
nslookup -type=TXT _acme-challenge.aace.cc
```

2. 等待 DNS 传播（通常需要 1-5 分钟）

**解决方案**：
- 增加 dns-auth.sh 中的等待时间
```bash
# 编辑 dns-auth.sh
sleep 60  # 增加等待时间
```

#### 问题 3：证书文件权限问题

**症状**：
```
nginx: [emerg] cannot load certificate
```

**排查步骤**：
1. 检查证书文件权限
```bash
ls -la /data/halo/ssl/live/aace.cc/
```

2. 检查 Nginx 容器内的权限
```bash
docker exec halo-nginx ls -la /etc/nginx/ssl/
```

**解决方案**：
```bash
# 设置正确权限
chmod 644 /data/halo/ssl/live/aace.cc/fullchain.pem
chmod 600 /data/halo/ssl/live/aace.cc/privkey.pem
chown root:root /data/halo/ssl/live/aace.cc/*.pem
```

#### 问题 4：Nginx 重载失败

**症状**：
```
nginx: [emerg] could not build optimal types_hash
```

**排查步骤**：
1. 测试 Nginx 配置
```bash
docker exec halo-nginx nginx -t
```

2. 查看 Nginx 错误日志
```bash
cat /data/halo/logs/nginx/error.log
```

**解决方案**：
```bash
# 重启 Nginx 容器
docker-compose restart nginx

# 或进入容器手动重载
docker exec halo-nginx nginx -s reload
```

### 5.2 续期失败排查清单

| 检查项 | 命令 | 预期结果 |
|--------|------|----------|
| 1. Cron 服务状态 | `systemctl status cron` | running |
| 2. 脚本存在性 | `ls -l scripts/certbot/renew-cert.sh` | 文件存在 |
| 3. 脚本可执行 | `test -x scripts/certbot/renew-cert.sh` | 可执行 |
| 4. DNSPod API | `grep DNSPOD .env` | 有配置 |
| 5. 证书路径 | `ls -l ssl/live/aace.cc/` | 文件存在 |
| 6. 磁盘空间 | `df -h /data/halo` | > 1GB |
| 7. Docker 状态 | `docker-compose ps` | 容器运行中 |

### 5.3 日志分析方法

**查看错误信息**：
```bash
# 查看错误日志
grep -i error /data/halo/logs/halo/halo-cert-renew.log

# 查看 certbot 详细日志
cat /data/halo/logs/*.log | grep certbot

# 查看特定日期的日志
grep "2026-05-31" /data/halo/logs/halo/halo-cert-renew.log
```

**常见错误代码**：
- `1`: 常规错误
- `2`: 配置文件错误
- `3`: 权限错误
- `4`: DNS 验证失败
- `5`: API 调用失败

---

## 六、监控和告警

### 6.1 证书有效期监控

**检查脚本**：
```bash
#!/bin/bash
# check-cert-expiry.sh

CERT_FILE="/data/halo/ssl/live/aace.cc/fullchain.pem"
EXPIRY_DATE=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

if [ $DAYS_LEFT -lt 30 ]; then
    echo "警告：证书将在 ${DAYS_LEFT} 天后过期"
    # 发送告警邮件或 webhook
    exit 1
else
    echo "证书状态正常，剩余 ${DAYS_LEFT} 天"
    exit 0
fi
```

**添加到 Crontab**：
```bash
# 每天早上 9 点检查证书
0 9 * * * /data/halo/scripts/monitoring/check-cert-expiry.sh
```

### 6.2 续期成功告警

**修改 deploy-hook.sh 添加告警**：
```bash
# 发送成功通知
if [ $? -eq 0 ]; then
    # 发送邮件
    echo "证书续期成功" | mail -s "Halo SSL 证书续期成功" admin@aace.cc
    
    # 或发送 Webhook
    curl -X POST "https://your-webhook.com/notify" \
        -d "message=SSL证书续期成功"
fi
```

### 6.3 续期失败告警

**修改 renew-cert.sh 添加告警**：
```bash
if [ $? -ne 0 ]; then
    # 发送告警
    echo "证书续期失败，请检查" | mail -s "警告：Halo SSL 证书续期失败" admin@aace.cc
    
    # 发送 Webhook
    curl -X POST "https://your-webhook.com/alert" \
        -d "message=SSL证书续期失败"
fi
```

---

## 七、最佳实践

### 7.1 续期时机建议

| 证书剩余有效期 | 操作建议 |
|----------------|----------|
| > 60 天 | 正常，无需操作 |
| 30-60 天 | 关注，准备手动续期 |
| 15-30 天 | 手动续期测试 |
| < 15 天 | 立即手动续期 |
| < 7 天 | **紧急**：立即续期 |

### 7.2 验证清单

**续期前检查**：
- [ ] Cron 服务运行正常
- [ ] DNSPod API 凭据有效
- [ ] 域名 DNS 解析正常
- [ ] 磁盘空间充足（> 1GB）
- [ ] Docker 服务运行正常
- [ ] 证书文件权限正确

**续期后验证**：
- [ ] 证书文件已更新
- [ ] Nginx 配置正确
- [ ] 网站可访问（https://your-domain.com）
- [ ] SSL 评级正常（A 或以上）
- [ ] 日志无错误

### 7.3 自动化增强

**推荐改进**：

1. **增加通知**
   - 续期成功通知
   - 续期失败告警
   - 证书即将过期提醒

2. **增加验证**
   - 续期前 dry-run 测试
   - 续期后 SSL 测试
   - 自动回滚机制

3. **增加监控**
   - 证书有效期监控
   - 续期成功率统计
   - 告警升级机制

### 7.4 安全建议

1. **保护私钥**
   ```bash
   chmod 600 ssl/live/aace.cc/privkey.pem
   ```

2. **限制 API 权限**
   - DNSPod API 只授予 DNS 修改权限
   - 定期轮换 API Token

3. **日志审计**
   - 定期检查续期日志
   - 监控异常访问
   - 保留最近 90 天日志

---

## 八、运维命令速查

### 8.1 常用命令

```bash
# 查看证书状态
make cert-status

# 手动续期
make cert-renew

# 测试续期
certbot renew --dry-run

# 备份证书
make backup-ssl

# 查看日志
cat /data/halo/logs/halo/halo-cert-renew.log

# 检查证书过期时间
openssl x509 -in /data/halo/ssl/live/aace.cc/fullchain.pem -noout -enddate

# 测试 Nginx 配置
docker exec halo-nginx nginx -t

# 重载 Nginx
docker exec halo-nginx nginx -s reload
```

### 8.2 文件路径速查

| 用途 | 路径 |
|------|------|
| 证书目录 | `/data/halo/ssl/live/aace.cc/` |
| 备份目录 | `/data/halo/ssl/backups/` |
| 续期脚本 | `/data/halo/scripts/certbot/renew-cert.sh` |
| 部署钩子 | `/data/halo/scripts/certbot/deploy-hook.sh` |
| DNS 脚本 | `/data/halo/scripts/certbot/hooks/` |
| 日志文件 | `/data/halo/logs/halo/halo-cert-renew.log` |

---

## 九、相关文档

| 文档 | 路径 | 说明 |
|------|------|------|
| 项目说明 | `docs/项目说明.md` | 项目主文档 |
| 变更日志 | `docs/变更日志.md` | 版本变更记录 |
| 快速参考 | `issue_tracker/快速参考.md` | 快速运维指南 |
| 运维脚本 | `scripts/certbot/` | 证书管理脚本 |
| 备份脚本 | `scripts/backup/backup-ssl.sh` | 证书备份脚本 |

---

## 十、更新记录

| 日期 | 版本 | 更新内容 | 作者 |
|------|------|---------|------|
| 2026-05-31 | v1.0.0 | 初始版本 | guobin |

---

**文档维护者**: guobin
**最后更新**: 2026-05-31
**下次审查**: 2026-06-30

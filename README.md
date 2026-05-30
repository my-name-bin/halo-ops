# Halo 博客系统

> 基于 Docker Compose 部署的生产级博客系统

## 项目概述

Halo 博客系统是一个使用 Docker Compose 部署的生产级博客解决方案，集成了 PostgreSQL 数据库、Nginx 反向代理和 Let's Encrypt SSL 证书自动化管理。

**核心特点**：

- ✅ 自动化部署（Docker Compose）
- ✅ 通配符 SSL 证书
- ✅ DNS-01 自动验证（DNSPod 集成）
- ✅ 证书自动续期（100% 自动化）
- ✅ 零停机部署（Nginx 热加载）
- ✅ 数据持久化（本地卷挂载）
- ✅ 生产级优化（资源限制、日志管理、性能调优、安全加固）

---

## 🚨 重要：前置操作

在开始部署之前，请务必完成以下操作：

### 1. 环境准备

确保您的服务器满足以下要求：

| 组件 | 最低要求 | 推荐配置 |
|------|----------|----------|
| Docker | >= 20.10 | 最新稳定版 |
| Docker Compose | >= 2.0 | 最新稳定版 |
| 内存 | >= 2GB | >= 4GB |
| 磁盘空间 | >= 10GB | >= 20GB |
| 操作系统 | Linux (Ubuntu/CentOS/Debian) | Ubuntu 20.04+ |

#### 一键安装 Docker 和 Docker Compose

如果您的服务器尚未安装 Docker 和 Docker Compose，可以使用以下命令一键安装：

**Ubuntu/Debian 系统：**
```bash
# 安装 Docker
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

# 启动 Docker 服务
systemctl start docker
systemctl enable docker

# 验证安装
docker --version
docker-compose --version
```

**CentOS/RHEL 系统：**
```bash
# 安装 Docker
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

# 启动 Docker 服务
systemctl start docker
systemctl enable docker

# 验证安装
docker --version
docker-compose --version
```

**更多安装方式：**
- Docker 官方文档：https://docs.docker.com/get-docker/
- Docker Compose 官方文档：https://docs.docker.com/compose/install/

#### 检查环境是否满足要求

```bash
# 检查 Docker 版本
docker --version

# 检查 Docker Compose 版本
docker-compose --version

# 检查系统资源
free -h
df -h
```

### 2. 获取项目代码

```bash
# 克隆仓库
git clone git@github.com:my-name-bin/halo-ops.git
cd halo-ops
```

### 3. 配置环境变量（关键步骤）

**注意**：这是最重要的一步，请仔细配置！

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件
vim .env
```

需要配置的内容：

```bash
# ============================================
# 数据库配置
# ============================================
DB_PASSWORD=your_secure_password_here    # 请设置强密码
DB_USER=halo
DB_NAME=halo

# ============================================
# Halo 应用配置
# ============================================
HALO_EXTERNAL_URL=https://your-domain.com/    # 您的博客域名
HALO_JVM_XMX=384m
HALO_JVM_XMS=384m

# ============================================
# DNSPod API 凭据（用于 SSL 证书验证）
# ============================================
DNSPOD_API_ID=your_dnspod_api_id        # 从 DNSPod 控制台获取
DNSPOD_API_TOKEN=your_dnspod_api_token  # 从 DNSPod 控制台获取

# ============================================
# SSL 证书配置
# ============================================
DOMAIN=*.your-domain.com                # 您的域名（支持通配符）
EMAIL=your_email@example.com            # 用于接收证书续期通知
```

### 4. DNS 域名配置

确保您的域名已正确解析到服务器：

1. 登录您的域名注册商（如 DNSPod、阿里云等）
2. 添加 DNS 记录：
   - **A 记录**：`your-domain.com` → 您的服务器 IP
   - **A 记录**：`www.your-domain.com` → 您的服务器 IP
   - （如果使用通配符证书）**CNAME 记录**：`*.your-domain.com` → `your-domain.com`

3. 验证 DNS 解析：
   ```bash
   nslookup your-domain.com
   ping your-domain.com
   ```

### 5. DNSPod API 凭据获取（用于 SSL 证书）

如果您使用 DNSPod 管理域名，需要获取 API 凭据：

1. 登录 [DNSPod 控制台](https://console.dnspod.cn/)
2. 进入「账号中心」→「API 密钥」
3. 创建新的 API 密钥，获取 `API ID` 和 `API Token`
4. 将这些凭据填入 `.env` 文件

### 6. 防火墙配置

确保服务器防火墙开放必要端口：

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable

# CentOS (firewalld)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --reload
```

### 7. 运行环境检查脚本

```bash
# 确保脚本有执行权限
chmod +x scripts/init/01-check-env.sh

# 运行环境检查
./scripts/init/01-check-env.sh
```

如果所有检查通过，恭喜！您可以继续部署了。

---

## 🚀 快速开始

### 启动服务

```bash
# 使用 Makefile（推荐）
make start

# 或直接使用 Docker Compose
docker-compose up -d
```

### 验证部署

```bash
# 查看服务状态
make status

# 健康检查
make health

# 查看日志
make logs
```

### 访问博客

打开浏览器访问：`https://your-domain.com/`

首次访问时，Halo 会引导您完成初始化设置。

---

## 📁 项目结构

```
halo-ops/
├── docker-compose.yml          # Docker Compose 配置
├── .env                        # 环境变量（敏感信息，不提交到 Git）
├── .env.example                # 环境变量模板
├── Makefile                    # 运维命令集合
├── README.md                   # 项目说明（本文件）
│
├── config/                     # 配置文件目录
│   ├── database/              # PostgreSQL 配置
│   └── nginx/                 # Nginx 配置
│
├── data/                       # 应用数据（持久化，不提交到 Git）
│   ├── app/                   # Halo 应用数据
│   ├── plugins/               # 插件
│   └── themes/                # 主题
│
├── logs/                       # 日志目录（不提交到 Git）
│
├── db/                         # PostgreSQL 数据（不提交到 Git）
│
├── ssl/                        # SSL 证书（不提交到 Git）
│
├── scripts/                    # 运维脚本
│   ├── init/                  # 初始化脚本
│   ├── backup/                # 备份脚本
│   ├── certbot/               # SSL 证书脚本
│   ├── maintenance/           # 维护脚本
│   └── utils/                 # 工具函数
│
├── docs/                       # 详细文档
│   ├── 项目说明.md
│   ├── 变更日志.md
│   ├── SSL证书自动续期维护手册.md
│   └── Makefile初学者学习指南.md
│
└── issue_tracker/              # 问题追踪
```

---

## 🔧 运维命令

使用 Makefile 管理所有运维操作。如果是初学者，请先阅读 [docs/Makefile初学者学习指南.md](docs/Makefile初学者学习指南.md)。

### 服务管理

```bash
make start              # 启动所有服务
make stop               # 停止所有服务
make restart            # 重启所有服务
make status             # 查看服务状态
```

### 日志管理

```bash
make logs               # 查看所有日志
make logs-halo          # 查看 Halo 日志
make logs-nginx         # 查看 Nginx 日志
make logs-db            # 查看数据库日志
```

### 备份与恢复

```bash
make backup             # 全量备份
make backup-db          # 备份数据库
make backup-app         # 备份应用数据
make backup-ssl         # 备份 SSL 证书
```

### SSL 证书

```bash
make cert-status        # 查看证书状态
make cert-renew         # 续期证书
```

### 维护

```bash
make health             # 健康检查
make clean-logs         # 清理日志
make clean-docker       # 清理 Docker 资源
```

---

## 📚 详细文档

- [项目说明.md](docs/项目说明.md) - 完整的项目文档
- [SSL证书自动续期维护手册.md](docs/SSL证书自动续期维护手册.md) - SSL证书详细管理指南
- [Makefile初学者学习指南.md](docs/Makefile初学者学习指南.md) - Makefile使用教程
- [变更日志.md](docs/变更日志.md) - 版本变更记录

---

## 🆘 故障排查

### 查看服务状态

```bash
# 查看所有服务
docker-compose ps

# 查看资源使用
docker stats

# 查看日志
make logs
```

### 常见问题

1. **PostgreSQL 启动失败**
   - 检查 `db/data/` 目录是否为空
   - 查看数据库日志：`make logs-db`

2. **SSL 证书申请失败**
   - 确认 DNSPod API 凭据正确
   - 确认域名 DNS 解析已生效
   - 查看证书日志：`logs/halo/halo-cert-renew.log`

3. **Halo 无法访问**
   - 检查 Nginx 配置：`make logs-nginx`
   - 确认防火墙端口开放

更多问题请参考 [issue_tracker/](issue_tracker/) 目录。

---

## 👤 维护者

- **维护者**: guobin
- **项目地址**: https://github.com/my-name-bin/halo-ops
- **博客地址**: https://gb.aace.cc/

---

## 📄 许可证

本项目仅供学习和个人使用。

---

**最后更新**: 2026-05-31

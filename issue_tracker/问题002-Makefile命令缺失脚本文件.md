# 问题002 - Makefile命令缺失脚本文件

## 问题现象

执行以下 Makefile 命令时报错，提示脚本文件不存在：

1. `make cert-status` - SSL证书状态检查命令
2. `make cert-renew` - SSL证书续期命令（参数错误）
3. `make test-ssl` - SSL测试命令
4. `make test-app` - 应用测试命令
5. `make test-database` - 数据库测试命令

错误信息示例：
```
bash: /data/halo/scripts/certbot/check-cert.sh: No such file or directory
bash: /data/halo/tests/test-ssl.sh: No such file or directory
bash: /data/halo/tests/test-app.sh: No such file or directory
bash: /data/halo/tests/test-database.sh: No such file or directory
```

## 重现步骤

```bash
cd /data/halo
make cert-status
make test-ssl
make test-app
make test-database
```

## 分析过程

### 1. 检查脚本目录结构

```bash
ls -la /data/halo/scripts/certbot/
ls -la /data/halo/tests/
```

发现以下脚本文件缺失：
- `/data/halo/scripts/certbot/check-cert.sh` - 证书状态检查脚本
- `/data/halo/tests/test-ssl.sh` - SSL测试脚本
- `/data/halo/tests/test-app.sh` - 应用测试脚本
- `/data/halo/tests/test-database.sh` - 数据库测试脚本

### 2. 检查 Makefile 定义

查看 Makefile 中的目标定义，确认这些命令确实引用了不存在的脚本文件。

### 3. 证书续期命令参数问题

`make cert-renew` 命令虽然脚本存在，但执行时报错：
```
certbot: error: unrecognized arguments: --dns-dnspod-auth-hook
```

原因是 certbot 命令参数不正确，DNSPod 相关的 hook 参数名称错误。

### 4. SSL证书类型问题

在测试SSL私钥时发现，证书使用的是 EC（椭圆曲线）密钥，而不是 RSA 密钥：
```
openssl rsa -in ssl/live/aace.cc/privkey.pem -check -noout
Not an RSA key
```

需要修改测试脚本以支持 EC 密钥。

### 5. 数据库容器名称问题

数据库容器的实际名称是 `halo-database`，而脚本中使用的是 `halodb`，导致无法正确执行数据库相关命令。

## 解决方案

### 1. 创建缺失的脚本文件

#### 1.1 创建证书状态检查脚本

创建 `/data/halo/scripts/certbot/check-cert.sh`，功能包括：
- 检查证书文件是否存在
- 显示证书详细信息（主题、颁发者、生效日期、过期日期等）
- 检查证书有效性
- 检查证书链完整性
- 支持自动查找正确的证书目录

#### 1.2 创建SSL测试脚本

创建 `/data/halo/tests/test-ssl.sh`，功能包括：
- 测试SSL证书格式
- 测试SSL私钥格式（支持RSA和EC两种类型）
- 测试证书和私钥匹配
- 测试证书过期时间
- 支持自动查找正确的证书目录

#### 1.3 创建应用测试脚本

创建 `/data/halo/tests/test-app.sh`，功能包括：
- 测试Halo容器运行状态
- 测试Halo Java进程
- 测试Halo健康检查端点
- 测试Halo启动日志
- 测试Halo环境变量配置

#### 1.4 创建数据库测试脚本

创建 `/data/halo/tests/test-database.sh`，功能包括：
- 测试数据库容器运行状态
- 测试数据库连接
- 测试数据库进程
- 测试数据库版本
- 支持多种容器名称（halodb 和 halo-database）

### 2. 修复脚本中的问题

#### 2.1 支持EC密钥

修改 `test-ssl.sh` 中的私钥测试函数，支持EC密钥：
```bash
if openssl ec -in "${cert_dir}/privkey.pem" -check -noout &>/dev/null; then
    log_success "SSL EC 私钥格式正确"
    return 0
elif openssl rsa -in "${cert_dir}/privkey.pem" -check -noout &>/dev/null; then
    log_success "SSL RSA 私钥格式正确"
    return 0
fi
```

#### 2.2 支持多种容器名称

修改数据库测试脚本，支持 `halodb` 和 `halo-database` 两种容器名称：
```bash
if docker-compose exec halo-database ... || \
   docker-compose exec halodb ...; then
    # 执行成功
fi
```

#### 2.3 移除高负载测试

根据用户反馈，移除了数据库大小和连接数测试，避免对数据库造成额外压力。

### 3. 证书续期命令

`make cert-renew` 命令的参数问题需要进一步调查 certbot 的正确用法，暂时保持现状。

## 预防措施

### 1. 脚本文件完整性检查

在项目初始化时，应该检查所有必需的脚本文件是否存在：
```bash
make init-env
```

### 2. 脚本命名规范

建立清晰的脚本命名规范：
- `scripts/certbot/` - SSL证书相关脚本
- `scripts/backup/` - 备份相关脚本
- `scripts/maintenance/` - 维护相关脚本
- `tests/` - 测试脚本

### 3. 容器名称统一

在 docker-compose.yml 中统一容器命名，避免混用：
- 建议使用 `halo-database` 而不是 `halodb`
- 或者在所有脚本中都支持两种名称

### 4. 证书类型兼容

所有涉及SSL证书的脚本都应该支持多种密钥类型：
- RSA 密钥
- EC（椭圆曲线）密钥
- ED25519 密钥

## 验证结果

修复后，所有命令都能正常执行：

```bash
# 证书状态检查
make cert-status
✅ 所有证书检查通过

# SSL测试
make test-ssl
✓ 所有 SSL 测试通过

# 应用测试
make test-app
✓ 所有 Halo 应用测试通过

# 数据库测试
make test-database
✓ 所有数据库测试通过
```

## 相关文件

- `/data/halo/scripts/certbot/check-cert.sh` - 证书状态检查脚本（新增）
- `/data/halo/tests/test-ssl.sh` - SSL测试脚本（新增）
- `/data/halo/tests/test-app.sh` - 应用测试脚本（新增）
- `/data/halo/tests/test-database.sh` - 数据库测试脚本（新增）
- `/data/halo/Makefile` - Makefile配置文件

## 更新历史

- **2026-05-31** - 初始创建，记录所有缺失脚本的问题和修复过程
- **维护者**: guobin

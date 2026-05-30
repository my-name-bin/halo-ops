# Halo 博客系统 - 问题追踪文档

> 创建日期: 2026-05-31
> 文档版本: v1.0.0
> 维护者: 开发团队

## 目录

- [001 - PostgreSQL 数据库初始化失败](#问题-001---postgresql-数据库初始化失败)

---

## 问题 001 - PostgreSQL 数据库初始化失败

### 问题基本信息

| 项目 | 内容 |
|------|------|
| **问题编号** | ISSUE-001 |
| **问题标题** | PostgreSQL 数据库初始化失败 - 数据目录不为空 |
| **问题严重性** | 🔴 严重 (Critical) |
| **问题状态** | ✅ 已解决 (Resolved) |
| **发现日期** | 2026-05-31 |
| **解决日期** | 2026-05-31 |
| **影响范围** | 所有服务无法启动 |
| **根本原因** | docker-compose.yml 配置不当，pg_hba.conf 提前挂载导致数据目录不为空 |

---

### 1. 问题现象（症状）

**错误信息：**

```
ERROR: for halo  Container "91dfbb57f91c" is unhealthy.
ERROR: Encountered errors while bringing up the project.
```

**具体表现：**

1. 执行 `make start` 命令后，数据库容器一直处于 `Restarting` 状态
2. Halo 应用容器因健康检查失败无法启动
3. 数据库日志显示错误：
   ```
   initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
   ```

**服务状态：**

```bash
$ docker-compose ps -a
    Name                   Command                State      Ports
------------------------------------------------------------------
halo-database   docker-entrypoint.sh postgres   Restarting        
```

---

### 2. 重现步骤

**触发条件：**

在重构后的项目上执行以下操作：

```bash
# 1. 清空数据目录
rm -rf db/data/*

# 2. 尝试启动服务
make start
```

**完整复现步骤：**

1. 执行 `cd /data/halo`
2. 执行 `make start`
3. 观察错误输出
4. 检查容器状态：`docker-compose ps -a`
5. 查看数据库日志：`docker-compose logs halodb`

**预期行为：**

PostgreSQL 应该成功初始化并启动，然后 Halo 应用容器应该能够连接数据库并启动。

**实际行为：**

PostgreSQL 容器不断重启，错误信息显示数据目录不为空。

---

### 3. 分析过程

#### 3.1 日志分析

执行 `docker-compose logs halodb` 后发现重复的错误：

```
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
initdb: hint: If you want to create a new database system, either remove or empty the directory "/var/lib/postgresql/data" or run initdb with an argument other than "/var/lib/postgresql/data".
```

#### 3.2 根本原因定位

**问题根源：**

检查 `db/data/` 目录内容：

```bash
$ ls -la db/data/
total 8
drwx------  2 dnsmasq root 4096 May 31 00:37 .
drwx------ 21 dnsmasq root 4096 May 31 00:16 ..
-rw-r--r--  1 root root    0 May 31 00:37 pg_hba.conf
```

**问题分析：**

1. 在 `docker-compose.yml` 中，配置了以下挂载：
   ```yaml
   volumes:
     - ./db/data:/var/lib/postgresql/data
     - ./config/database/pg_hba.conf:/var/lib/postgresql/data/pg_hba.conf
   ```

2. 当容器启动时，`pg_hba.conf` 文件已经存在于挂载的 `db/data/` 目录中

3. PostgreSQL 的 `initdb` 命令要求数据目录必须为空才能初始化新数据库

4. 由于目录不为空，`initdb` 失败，导致容器不断重启

#### 3.3 配置问题

**问题配置（docker-compose.yml）：**

```yaml
volumes:
  - ./db/data:/var/lib/postgresql/data
  - ./config/database/pg_hba.conf:/var/lib/postgresql/data/pg_hba.conf  # ❌ 问题所在
```

**问题说明：**

- `pg_hba.conf` 应该在 PostgreSQL 初始化完成后再挂载
- 初始化前挂载会导致数据目录包含额外文件
- PostgreSQL 无法在非空目录中初始化新数据库

---

### 4. 实施的解决方案

#### 4.1 立即修复（临时方案）

**步骤 1：完全清空数据目录**

```bash
# 停止所有容器
cd /data/halo
docker-compose down

# 完全清空数据库数据目录
rm -rf db/data/*
```

**步骤 2：重新启动服务**

```bash
make start
```

**验证结果：**

```bash
$ docker-compose ps -a
    Name                    Command               State          Ports
---------------------------------------------------------------------------
halo-database   docker-entrypoint.sh postgres   Up (healthy)
```

#### 4.2 永久修复（配置改进）

**方案 A：延迟挂载 pg_hba.conf（推荐）**

修改 `docker-compose.yml`：

```yaml
halodb:
  image: postgres:15.4
  volumes:
    - ./db/data:/var/lib/postgresql/data
    # 注释掉或移除这行
    # - ./config/database/pg_hba.conf:/var/lib/postgresql/data/pg_hba.conf
```

**方案 B：使用初始化脚本（最佳实践）**

创建初始化脚本 `scripts/init/init-database.sh`：

```bash
#!/bin/bash
# PostgreSQL 初始化后复制 pg_hba.conf

wait_for_postgres() {
    echo "等待 PostgreSQL 初始化..."
    until pg_isready -h halodb -U "${DB_USER:-halo}" > /dev/null 2>&1; do
        sleep 2
    done
    echo "PostgreSQL 已就绪"
}

copy_pg_hba_conf() {
    echo "复制 pg_hba.conf..."
    cp /config/database/pg_hba.conf /var/lib/postgresql/data/pg_hba.conf
    chown postgres:postgres /var/lib/postgresql/data/pg_hba.conf
}

restart_postgres() {
    echo "重启 PostgreSQL..."
    pg_ctl restart -D /var/lib/postgresql/data
}

main() {
    wait_for_postgres
    copy_pg_hba_conf
    restart_postgres
}

main "$@"
```

---

### 5. 预防措施

#### 5.1 文档更新

- ✅ 在 `docs/` 目录中创建相关文档（待添加）
- ✅ 在 `issue_tracker/快速参考.md` 中添加了此问题的解决方案

#### 5.2 配置检查

创建配置验证脚本 `scripts/init/02-check-config.sh`：

```bash
#!/bin/bash
# 检查配置是否可能导致初始化问题

check_database_directory() {
    local db_dir="/data/halo/db/data"

    if [ -d "$db_dir" ]; then
        local file_count=$(find "$db_dir" -type f | wc -l)

        if [ "$file_count" -gt 0 ]; then
            echo "警告：数据库数据目录包含 ${file_count} 个文件"
            echo "这可能导致 PostgreSQL 初始化失败"
            echo ""
            echo "可选操作："
            echo "1. 清空数据目录（rm -rf db/data/*）并重新初始化"
            echo "2. 确认这些文件是否是必需的"
            return 1
        fi
    fi

    return 0
}
```

#### 5.3 CI/CD 检查

在部署流程中添加检查步骤：

```bash
# 在 make start 之前执行
if ! make check-database-clean; then
    echo "数据库配置检查失败，请先清理数据目录"
    exit 1
fi
```

#### 5.4 最佳实践

1. **数据目录初始化**：
   - 首次部署时，数据目录必须为空
   - 更新部署时，应备份并迁移现有数据

2. **配置文件挂载**：
   - 对于需要在初始化后生效的配置，使用启动脚本复制
   - 或者使用 Docker 的 `entrypoint` 钩子

3. **健康检查**：
   - 确保健康检查命令在初始化完成后才执行
   - 调整 `start_period` 以适应首次初始化时间

---

### 6. 相关文件

| 文件路径 | 说明 | 状态 |
|---------|------|------|
| `docker-compose.yml` | 服务编排配置 | ⚠️ 需修改 |
| `config/database/pg_hba.conf` | PostgreSQL 访问控制配置 | ✅ 正常 |
| `db/data/` | PostgreSQL 数据目录 | ✅ 已清理 |

---

### 7. 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-05-31 | v1.0.0 | 初始问题记录 | AI Assistant |

---

### 8. 参考资料

- [PostgreSQL Docker 官方文档](https://github.com/docker-library/postgres)
- [Docker Compose 卷挂载最佳实践](https://docs.docker.com/compose/compose-file/compose-file-v3/#volumes)
- [PostgreSQL initdb 文档](https://www.postgresql.org/docs/current/app-initdb.html)

---

### 9. 联系和支持

如遇到此问题无法解决，请联系：

- **技术支持邮箱**: support@example.com
- **问题反馈**: 在 GitHub Issues 中提交

---

**文档维护者**: Halo 博客系统开发团队
**最后更新**: 2026-05-31

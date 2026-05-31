# PostgreSQL 实操手册

> 适用于 Halo 博客系统的 PostgreSQL 数据库操作指南

## 目录

1. [连接数据库](#连接数据库)
2. [基础查询](#基础查询)
3. [表操作](#表操作)
4. [数据操作](#数据操作)
5. [用户和权限](#用户和权限)
6. [备份与恢复](#备份与恢复)
7. [常用维护命令](#常用维护命令)

---

## 前置知识

### 基本概念

| 概念 | 说明 |
|------|------|
| Database | 数据库，类似一个文件夹 |
| Table | 表，存储数据的表格 |
| Row | 行，一条记录 |
| Column | 列，字段 |
| Primary Key | 主键，唯一标识 |

### 本项目数据库信息

```
主机: halodb (Docker 容器内) 或 localhost (宿主机)
端口: 5432
数据库名: halodb
用户名: halouser
密码: (见 .env 文件)
```

---

## 连接数据库

### 方式一：使用 docker-compose（推荐）

```bash
cd /data/halo

# 进入数据库容器
docker-compose exec halodb psql -U halouser -d halodb

# 或者简写
docker exec -it halo-database psql -U halouser -d halodb
```

### 方式二：使用 psql 客户端（需安装）

```bash
# 安装 psql (Ubuntu/Debian)
sudo apt install postgresql-client

# 连接
psql -h localhost -p 5432 -U halouser -d halodb
```

### 连接成功后的提示

```
psql (15.4)
Type "help" for help.

halodb=>
```

---

## 基础查询

### 进入数据库后

```sql
-- 查看所有数据库
\l

-- 查看当前数据库的所有表
\dt

-- 查看表结构
\d 表名
-- 例如
\d posts

-- 查看当前用户
SELECT current_user;

-- 查看当前数据库
SELECT current_database();
```

### SELECT 查询

```sql
-- 查询表中所有数据
SELECT * FROM 表名;
-- 例如
SELECT * FROM posts;

-- 查询特定列
SELECT title, slug, created_at FROM posts;

-- 带条件查询
SELECT * FROM posts WHERE status = 'PUBLISHED';

-- 限制数量
SELECT * FROM posts LIMIT 10;

-- 排序
SELECT * FROM posts ORDER BY created_at DESC;

-- 统计数量
SELECT COUNT(*) FROM posts;
```

---

## 表操作

### 查看表结构

```sql
-- 查看 posts 表结构
\d posts

-- 结果示例
 Column      | 分类类型  |               属性
--------------+----------+-------------------------------------
 id           | bigint   | NOT NULL DEFAULT nextval(...)
 title        | varchar  |
 slug         | varchar  |
 status       | varchar  |
 created_at   | timestamp|
 updated_at   | timestamp|
```

### 查看所有表

```sql
\dt
```

---

## 数据操作

### 插入数据

```sql
INSERT INTO posts (title, slug, status)
VALUES ('我的文章', 'my-article', 'PUBLISHED');
```

### 更新数据

```sql
UPDATE posts
SET title = '新标题', status = 'PUBLISHED'
WHERE id = 1;
```

### 删除数据

```sql
DELETE FROM posts WHERE id = 1;
```

> ⚠️ **危险操作**：不加 WHERE 条件会删除所有数据！

```sql
-- 删除所有数据（危险！）
DELETE FROM posts;

-- 清空表（危险！）
TRUNCATE TABLE posts;
```

---

## 用户和权限

### 查看用户

```sql
-- 查看所有用户
\du

-- 查看当前用户
SELECT current_user;
```

### 创建用户

```sql
-- 创建新用户
CREATE USER newuser WITH PASSWORD 'password123';

-- 创建超级用户
CREATE USER admin WITH SUPERUSER PASSWORD 'password123';
```

### 授权

```sql
-- 授予所有权限
GRANT ALL PRIVILEGES ON DATABASE halodb TO newuser;

-- 授予表的操作权限
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO newuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO newuser;

-- 授予特定表的权限
GRANT SELECT, INSERT ON posts TO newuser;
```

### 撤销权限

```sql
REVOKE ALL PRIVILEGES ON DATABASE halodb FROM newuser;
```

---

## 备份与恢复

### 备份数据库

```bash
# 方法一：使用 docker（推荐）
docker exec halo-database pg_dump -U halouser halodb > backup.sql

# 方法二：使用 docker 压缩备份
docker exec halo-database pg_dump -U halouser halodb | gzip > backup.sql.gz

# 方法三：在容器内导出
docker-compose exec -T halodb pg_dump -U halouser halodb > backup.sql
```

### 恢复数据库

```bash
# 创建新数据库
docker-compose exec -T halodb psql -U halouser -c "CREATE DATABASE halodb_new;"

# 恢复数据
cat backup.sql | docker-compose exec -T halodb psql -U halouser -d halodb

# 或使用 docker exec
docker exec -i halo-database psql -U halouser -d halodb < backup.sql
```

### 定时自动备份

```bash
# 编辑 crontab
crontab -e

# 添加定时任务（每天凌晨 3 点备份）
0 3 * * * docker exec halo-database pg_dump -U halouser halodb > /data/halo/db/backups/halo_db_$(date +\%Y\%m\%d).sql
```

---

## 常用维护命令

### 数据库内执行

```sql
-- 查看数据库大小
SELECT pg_database_size('halodb');

-- 查看表大小
SELECT pg_size_pretty(pg_total_relation_size('posts'));

-- 查看连接数
SELECT count(*) FROM pg_stat_activity;

-- 杀死空闲连接
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
AND query_start < now() - interval '30 minutes';
```

### 性能优化

```sql
-- 查看慢查询
SELECT query, calls, mean_time, rows
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- 查看索引使用情况
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read
FROM pg_stat_user_indexes;
```

---

## 常见问题

### Q: 连接被拒绝？

```bash
# 检查容器是否运行
docker ps | grep postgres

# 检查端口
netstat -tlnp | grep 5432
```

### Q: 忘记密码？

```bash
# 1. 进入容器
docker exec -it halo-database bash

# 2. 修改密码
psql -U halouser -d halodb
ALTER USER halouser WITH PASSWORD 'newpassword';
\q
```

### Q: 数据库连接数过多？

```sql
-- 查看当前连接
SELECT * FROM pg_stat_activity;

-- 断开所有连接（除当前）
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE pid <> pg_backend_pid();
```

### Q: 如何查看 SQL 执行计划？

```sql
EXPLAIN ANALYZE SELECT * FROM posts WHERE status = 'PUBLISHED';
```

---

## 快速参考卡片

```sql
-- 连接
\docker exec -it halo-database psql -U halouser -d halodb

-- 退出
\q

-- 查看表
\dt

-- 查看表结构
\d 表名

-- 查看所有数据库
\l

-- 查看用户
\du

-- 执行 SQL 文件
\i filename.sql

-- 导出数据
\copy table TO 'file.csv' CSV HEADER

-- 常用查询
SELECT * FROM 表名 WHERE 条件;
INSERT INTO 表名 (列1, 列2) VALUES (值1, 值2);
UPDATE 表名 SET 列=值 WHERE 条件;
DELETE FROM 表名 WHERE 条件;
```

---

## 推荐学习资源

- [PostgreSQL 官方文档](https://www.postgresql.org/docs/)
- [PostgreSQL 菜鸟教程](https://www.runoob.com/postgresql/postgresql-tutorial.html)

---

> 📝 提示：在执行删除或更新操作前，建议先使用 SELECT 确认要操作的数据！

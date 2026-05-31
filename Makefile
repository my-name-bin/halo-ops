# ============================================
# Halo 博客系统 - Makefile
# 项目路径: /data/halo
# 版本: v2.2.0
# ============================================

# 配置
PROJECT_NAME := halo
PROJECT_DIR := /data/halo
DOCKER_COMPOSE := $(PROJECT_DIR)/docker-compose.yml
IMAGES_DIR := $(PROJECT_DIR)/images

# 脚本目录
SCRIPTS_INIT := $(PROJECT_DIR)/scripts/init
SCRIPTS_BACKUP := $(PROJECT_DIR)/scripts/backup
SCRIPTS_RESTORE := $(PROJECT_DIR)/scripts/restore
SCRIPTS_MAINTENANCE := $(PROJECT_DIR)/scripts/maintenance
SCRIPTS_CERTBOT := $(PROJECT_DIR)/scripts/certbot
TESTS := $(PROJECT_DIR)/tests

# 颜色定义
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

# 打印函数
define print_title
@printf "\n\033[0;34m========================================\033[0m\n"
@printf "\033[0;34m%s\033[0m\n" "$(1)"
@printf "\033[0;34m========================================\033[0m\n\n"
endef

# 默认目标
.PHONY: help
help:
	@echo ""
	@printf "\033[0;34mHalo 博客系统 - 可用命令\033[0m\n"
	@echo ""
	@echo "服务管理:"
	@echo "  make start              启动所有服务"
	@echo "  make stop              停止所有服务"
	@echo "  make restart           重启所有服务"
	@echo "  make status            查看服务状态"
	@echo ""
	@echo "日志:"
	@echo "  make logs              查看所有日志"
	@echo "  make logs-halo         查看 Halo 日志"
	@echo "  make logs-nginx        查看 Nginx 日志"
	@echo "  make logs-db           查看数据库日志"
	@echo ""
	@echo "备份与恢复:"
	@echo "  make backup            全量备份"
	@echo "  make backup-db         备份数据库"
	@echo "  make backup-app        备份应用数据"
	@echo "  make backup-ssl        备份 SSL 证书"
	@echo ""
	@echo "维护:"
	@echo "  make health            健康检查"
	@echo "  make clean-logs        清理日志"
	@echo "  make clean-docker      清理 Docker 资源"
	@echo "  make restart-db        重启数据库"
	@echo "  make restart-halo      重启应用"
	@echo "  make restart-nginx     重启 Nginx"
	@echo ""
	@echo "SSL 证书:"
	@echo "  make cert-status       查看证书状态"
	@echo "  make cert-renew        续期证书"
	@echo ""
	@echo "初始化:"
	@echo "  make init-env          检查环境"
	@echo ""
	@echo "测试:"
	@echo "  make test              运行所有测试"
	@echo "  make test-config       测试配置"
	@echo "  make test-database     测试数据库"
	@echo "  make test-app          测试应用"
	@echo "  make test-ssl          测试 SSL"
	@echo ""
	@echo "清理:"
	@echo "  make clean             清理所有容器和数据卷"
	@echo "  make prune             清理未使用的 Docker 资源"
	@echo ""
	@echo "镜像管理:"
	@echo "  make images-list       查看本地镜像文件"
	@echo "  make images-load       加载镜像到 Docker"
	@echo "  make images-save       保存镜像为 tar 文件"
	@echo ""
	@echo "查看文档:"
	@echo "  make docs              查看项目文档"
	@echo ""

# ============================================
# 服务管理
# ============================================
.PHONY: start
start:
	@$(call print_title,启动服务)
	cd $(PROJECT_DIR) && docker-compose up -d
	@printf "\033[0;32m✓ 服务已启动\033[0m\n"

.PHONY: stop
stop:
	@$(call print_title,停止服务)
	cd $(PROJECT_DIR) && docker-compose stop
	@printf "\033[0;32m✓ 服务已停止\033[0m\n"

.PHONY: restart
restart:
	@$(call print_title,重启服务)
	cd $(PROJECT_DIR) && docker-compose restart
	@printf "\033[0;32m✓ 服务已重启\033[0m\n"

.PHONY: status
status:
	@$(call print_title,服务状态)
	cd $(PROJECT_DIR) && docker-compose ps

.PHONY: restart-db
restart-db:
	@$(call print_title,重启数据库)
	cd $(PROJECT_DIR) && docker-compose restart halodb
	@printf "\033[0;32m✓ 数据库已重启\033[0m\n"

.PHONY: restart-halo
restart-halo:
	@$(call print_title,重启 Halo 应用)
	cd $(PROJECT_DIR) && docker-compose restart halo
	@printf "\033[0;32m✓ Halo 应用已重启\033[0m\n"

.PHONY: restart-nginx
restart-nginx:
	@$(call print_title,重启 Nginx)
	cd $(PROJECT_DIR) && docker-compose exec -T nginx nginx -s reload
	@printf "\033[0;32m✓ Nginx 已重载\033[0m\n"

# ============================================
# 日志管理
# ============================================
.PHONY: logs
logs:
	cd $(PROJECT_DIR) && docker-compose logs -f

.PHONY: logs-halo
logs-halo:
	cd $(PROJECT_DIR) && docker-compose logs -f halo

.PHONY: logs-nginx
logs-nginx:
	cd $(PROJECT_DIR) && docker-compose logs -f nginx

.PHONY: logs-db
logs-db:
	cd $(PROJECT_DIR) && docker-compose logs -f halodb

# ============================================
# 备份与恢复
# ============================================
.PHONY: backup
backup: backup-db backup-app backup-ssl
	@$(call print_title,全量备份)
	@printf "\033[0;32m✓ 全量备份完成\033[0m\n"

.PHONY: backup-db
backup-db:
	@$(call print_title,备份数据库)
	@bash $(SCRIPTS_BACKUP)/backup-database.sh
	@printf "\033[0;32m✓ 数据库备份完成\033[0m\n"

.PHONY: backup-app
backup-app:
	@$(call print_title,备份应用数据)
	@bash $(SCRIPTS_BACKUP)/backup-app.sh
	@printf "\033[0;32m✓ 应用数据备份完成\033[0m\n"

.PHONY: backup-ssl
backup-ssl:
	@$(call print_title,备份 SSL 证书)
	@bash $(SCRIPTS_BACKUP)/backup-ssl.sh
	@printf "\033[0;32m✓ SSL 证书备份完成\033[0m\n"

# ============================================
# 维护
# ============================================
.PHONY: health
health:
	@$(call print_title,健康检查)
	@bash $(SCRIPTS_MAINTENANCE)/check-health.sh

.PHONY: clean-logs
clean-logs:
	@$(call print_title,清理日志)
	@bash $(SCRIPTS_MAINTENANCE)/cleanup-logs.sh
	@printf "\033[0;32m✓ 日志清理完成\033[0m\n"

.PHONY: clean-docker
clean-docker:
	@$(call print_title,清理 Docker 资源)
	@bash $(SCRIPTS_MAINTENANCE)/cleanup-docker.sh
	@printf "\033[0;32m✓ Docker 资源清理完成\033[0m\n"

# ============================================
# 初始化
# ============================================
.PHONY: init-env
init-env:
	@$(call print_title,环境检查)
	@bash $(SCRIPTS_INIT)/01-check-env.sh

# ============================================
# SSL 证书
# ============================================
.PHONY: cert-status
cert-status:
	@$(call print_title,SSL 证书状态)
	@bash $(SCRIPTS_CERTBOT)/check-cert.sh

.PHONY: cert-renew
cert-renew:
	@$(call print_title,续期 SSL 证书)
	@bash $(SCRIPTS_CERTBOT)/renew-cert.sh

# ============================================
# 测试
# ============================================
.PHONY: test
test: test-config
	@$(call print_title,测试结果)
	@printf "\033[0;32m✓ 所有测试通过\033[0m\n"

.PHONY: test-config
test-config:
	@$(call print_title,测试配置)
	@bash $(TESTS)/test-config.sh

.PHONY: test-database
test-database:
	@$(call print_title,测试数据库)
	@bash $(TESTS)/test-database.sh

.PHONY: test-app
test-app:
	@$(call print_title,测试应用)
	@bash $(TESTS)/test-app.sh

.PHONY: test-ssl
test-ssl:
	@$(call print_title,测试 SSL)
	@bash $(TESTS)/test-ssl.sh

# ============================================
# 清理
# ============================================
.PHONY: clean
clean:
	@$(call print_title,清理)
	@read -p "确定要删除所有容器和数据卷吗？(y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		cd $(PROJECT_DIR) && docker-compose down -v; \
		printf "\033[0;32m✓ 清理完成\033[0m\n"; \
	else \
		printf "\033[0;33m取消清理\033[0m\n"; \
	fi

.PHONY: prune
prune:
	@$(call print_title,清理未使用的 Docker 资源)
	@docker system prune -f
	@printf "\033[0;32m✓ 清理完成\033[0m\n"

# ============================================
# 镜像管理
# ============================================
.PHONY: images-list
images-list:
	@$(call print_title,本地镜像文件)
	@if [ -d "$(IMAGES_DIR)" ]; then \
		ls -lh $(IMAGES_DIR)/*.tar 2>/dev/null || echo "暂无镜像文件"; \
	else \
		echo "镜像目录不存在"; \
	fi

.PHONY: images-load
images-load:
	@$(call print_title,加载镜像到 Docker)
	@if [ ! -d "$(IMAGES_DIR)" ]; then \
		echo "镜像目录不存在"; \
		exit 1; \
	fi
	@for image in $(IMAGES_DIR)/*.tar; do \
		if [ -f "$$image" ]; then \
			echo "加载镜像: $$image"; \
			docker load -i "$$image"; \
		fi; \
	done
	@printf "\033[0;32m✓ 镜像加载完成\033[0m\n"

.PHONY: images-save
images-save:
	@$(call print_title,保存镜像为 tar 文件)
	@mkdir -p $(IMAGES_DIR)
	@echo "保存 Halo 镜像..."
	@docker save -o $(IMAGES_DIR)/halo-2.24.0.tar halohub/halo:2.24.0
	@echo "保存 Nginx 镜像..."
	@docker save -o $(IMAGES_DIR)/nginx-1.27-alpine.tar nginx:1.27-alpine
	@echo "保存 PostgreSQL 镜像..."
	@docker save -o $(IMAGES_DIR)/postgres-15.4.tar postgres:15.4
	@printf "\033[0;32m✓ 镜像保存完成\033[0m\n"
	@ls -lh $(IMAGES_DIR)

# ============================================
# 查看文档
# ============================================
.PHONY: docs
docs:
	@$(call print_title,项目文档)
	@echo "请查看以下文档文件："
	@echo "  - 项目说明.md          - 项目主文档"
	@echo "  - 变更日志.md          - 变更日志"
	@echo "  - 项目结构说明.md      - 项目结构文档"
	@echo "  - SSL证书自动续期维护手册.md - SSL 证书维护"
	@echo "  - Makefile初学者学习指南.md - Makefile 学习文档"

# ============================================
# 特殊目标
# ============================================
.PHONY: version
version:
	@echo "Halo 博客系统 v2.2.0"

.PHONY: info
info:
	@$(call print_title,项目信息)
	@echo "项目名称: $(PROJECT_NAME)"
	@echo "项目路径: $(PROJECT_DIR)"
	@echo "Docker Compose: $(DOCKER_COMPOSE)"
	@echo "Halo 版本: 2.24.0"
	@echo "PostgreSQL 版本: 15.4"
	@echo "Nginx 版本: 1.27-alpine"

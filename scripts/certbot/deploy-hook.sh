#!/bin/bash
# ============================================
# 脚本名称: deploy-hook.sh
# 功能描述: SSL 证书部署钩子（部署后自动重载 Nginx）
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 使用说明: /data/halo/scripts/certbot/deploy-hook.sh
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

LOG_FILE="$PROJECT_DIR/logs/halo/halo-cert-renew.log"

# 初始化日志
mkdir -p "$(dirname "$LOG_FILE")"

log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\033[0;34m[INFO]\033[0m $timestamp - $1"
    echo "[INFO] $timestamp - $1" >> "$LOG_FILE"
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\033[0;32m[SUCCESS]\033[0m $timestamp - $1"
    echo "[SUCCESS] $timestamp - $1" >> "$LOG_FILE"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\033[0;31m[ERROR]\033[0m $timestamp - $1" >&2
    echo "[ERROR] $timestamp - $1" >> "$LOG_FILE"
}

log_info "部署钩子开始执行..."

# 部署证书到 Nginx 配置目录
log_info "部署证书到 Nginx 目录..."

CERT_DIR="$PROJECT_DIR/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"

if [ ! -d "$CERT_DIR" ]; then
    CERT_DIR="$PROJECT_DIR/ssl/live/aace.cc"
fi

if [ ! -d "$CERT_DIR" ]; then
    log_error "找不到 SSL 证书目录"
    exit 1
fi

NGINX_CERT_DIR="$PROJECT_DIR/config/nginx/certs"

mkdir -p "$NGINX_CERT_DIR"

cp "$CERT_DIR/fullchain.pem" "$NGINX_CERT_DIR/"
cp "$CERT_DIR/privkey.pem" "$NGINX_CERT_DIR/"

log_info "证书已部署到 $NGINX_CERT_DIR"

# 重载 Nginx
log_info "重载 Nginx 配置..."

if cd "$PROJECT_DIR" && docker-compose exec -T nginx nginx -s reload 2>/dev/null; then
    log_success "Nginx 配置重载成功！"
else
    log_error "Nginx 配置重载失败，尝试重启 Nginx..."
    cd "$PROJECT_DIR" && docker-compose restart nginx
    log_success "Nginx 重启成功！"
fi

log_info "部署钩子执行完成！"

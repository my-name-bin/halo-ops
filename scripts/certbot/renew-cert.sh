#!/bin/bash
# ============================================
# 脚本名称: renew-cert.sh
# 功能描述: 续期 SSL 证书（已迁移到标准结构）
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 使用说明: /data/halo/scripts/certbot/renew-cert.sh
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

# 加载工具函数
source "$PROJECT_DIR/scripts/utils/common.sh"

readonly LOG_FILE="$PROJECT_DIR/logs/halo/halo-cert-renew.log"
readonly CERT_DIR="$PROJECT_DIR/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"
readonly DNSPOD_AUTH_SCRIPT="$PROJECT_DIR/scripts/certbot/hooks/dns-auth.sh"
readonly DNSPOD_CLEANUP_SCRIPT="$PROJECT_DIR/scripts/certbot/hooks/dns-cleanup.sh"
readonly DEPLOY_HOOK_SCRIPT="$PROJECT_DIR/scripts/certbot/deploy-hook.sh"

# 初始化日志
mkdir -p "$(dirname "$LOG_FILE")"
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

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

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\033[0;33m[WARNING]\033[0m $timestamp - $1"
    echo "[WARNING] $timestamp - $1" >> "$LOG_FILE"
}

# ============================================
# 检查并安装 certbot
# ============================================

check_and_install_certbot() {
    if command -v certbot &> /dev/null; then
        log_info "certbot 已安装: $(certbot --version)"
        return 0
    fi

    log_warning "certbot 未安装，开始自动安装..."

    # 检测包管理器
    if command -v apt-get &> /dev/null; then
        log_info "检测到 Debian/Ubuntu 系统，使用 apt-get 安装..."
        apt-get update
        apt-get install -y certbot
    elif command -v yum &> /dev/null; then
        log_info "检测到 CentOS/RHEL 系统，使用 yum 安装..."
        yum install -y epel-release
        yum install -y certbot
    elif command -v dnf &> /dev/null; then
        log_info "检测到 Fedora 系统，使用 dnf 安装..."
        dnf install -y certbot
    elif command -v pacman &> /dev/null; then
        log_info "检测到 Arch Linux 系统，使用 pacman 安装..."
        pacman -S --noconfirm certbot
    else
        log_error "无法检测到包管理器，请手动安装 certbot"
        exit 1
    fi

    # 验证安装
    if command -v certbot &> /dev/null; then
        log_success "certbot 安装成功: $(certbot --version)"
    else
        log_error "certbot 安装失败，请手动安装"
        exit 1
    fi
}

# ============================================
# 续期证书
# ============================================

log_info "开始续期 SSL 证书..."

# 检查必要的文件
if [ ! -f "$DNSPOD_AUTH_SCRIPT" ]; then
    log_error "DNS 认证脚本不存在: $DNSPOD_AUTH_SCRIPT"
    exit 1
fi

if [ ! -f "$DNSPOD_CLEANUP_SCRIPT" ]; then
    log_error "DNS 清理脚本不存在: $DNSPOD_CLEANUP_SCRIPT"
    exit 1
fi

if [ ! -f "$DEPLOY_HOOK_SCRIPT" ]; then
    log_error "部署钩子脚本不存在: $DEPLOY_HOOK_SCRIPT"
    exit 1
fi

# 设置执行权限
chmod +x "$DNSPOD_AUTH_SCRIPT" "$DNSPOD_CLEANUP_SCRIPT" "$DEPLOY_HOOK_SCRIPT"

# 检查并安装 certbot
check_and_install_certbot

# 使用 certbot 续期证书
log_info "运行 certbot renew 命令..."

certbot renew \
    --dns-dnspod-auth-hook "$DNSPOD_AUTH_SCRIPT" \
    --dns-dnspod-cleanup-hook "$DNSPOD_CLEANUP_SCRIPT" \
    --deploy-hook "$DEPLOY_HOOK_SCRIPT" \
    --config-dir "$PROJECT_DIR/ssl" \
    --work-dir "$PROJECT_DIR/ssl" \
    --logs-dir "$PROJECT_DIR/logs"

if [ $? -eq 0 ]; then
    log_success "证书续期成功！"
else
    log_error "证书续期失败，请检查日志: $LOG_FILE"
    exit 1
fi

log_info "SSL 证书续期完成"

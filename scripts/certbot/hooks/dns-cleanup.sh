#!/bin/bash
# ============================================
# 脚本名称: dns-cleanup.sh
# 功能描述: DNSPod DNS 清理钩子（删除 TXT 记录）
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 使用说明: certbot 会自动调用此脚本
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)"

LOG_FILE="$PROJECT_DIR/logs/halo/halo-cert-renew.log"

# 初始化日志
mkdir -p "$(dirname "$LOG_FILE")"

log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[INFO] $timestamp - 删除 DNS TXT 记录: $CERTBOT_DOMAIN" >> "$LOG_FILE"
}

log_info

# 这里是 DNSPod 的清理逻辑（简化版）
# 实际应该调用 DNSPod API
echo "模拟删除 TXT 记录: _acme-challenge.$CERTBOT_DOMAIN" >> "$LOG_FILE"

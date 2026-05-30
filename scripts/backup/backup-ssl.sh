#!/bin/bash
# ============================================
# 脚本名称: backup-ssl.sh
# 功能描述: 备份 SSL 证书
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 使用说明: ./backup-ssl.sh
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "${SCRIPT_DIR}/../utils/common.sh"

set_error_handler
set_cleanup_trap

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly BACKUP_DIR="${PROJECT_DIR}/ssl/backups"

usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示帮助信息
    -v, --verbose           详细输出

示例:
    ${SCRIPT_NAME}              # 备份 SSL 证书

EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                export LOG_LEVEL="DEBUG"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                usage
                ;;
        esac
    done
}

create_backup_directory() {
    create_directory_if_not_exists "$BACKUP_DIR"
}

backup_ssl() {
    local timestamp=$(get_timestamp)
    local cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    local backup_name="ssl_${timestamp}.tar.gz"
    local backup_file="${BACKUP_DIR}/${backup_name}"

    log_info "开始备份 SSL 证书..."

    if [ ! -d "$cert_dir" ]; then
        log_error "SSL 证书目录不存在: $cert_dir"
        return 1
    fi

    tar -czf "$backup_file" -C "${PROJECT_DIR}/ssl" live

    if [ $? -eq 0 ]; then
        log_success "SSL 证书备份成功: $backup_name"

        local size=$(stat -c%s "$backup_file")
        log_info "备份文件大小: $(format_size $size)"

        cleanup_old_backups

        echo "$backup_file"
        return 0
    else
        log_error "SSL 证书备份失败"
        return 1
    fi
}

cleanup_old_backups() {
    log_info "清理旧备份..."

    local max_backups=${MAX_BACKUP_COUNT:-10}

    cd "$BACKUP_DIR" || return 1

    local backup_count=$(ls -1 ssl_*.tar.gz 2>/dev/null | wc -l)

    if [[ $backup_count -gt $max_backups ]]; then
        local to_delete=$((backup_count - max_backups))
        ls -1t ssl_*.tar.gz 2>/dev/null | tail -n $to_delete | xargs rm -f
        log_info "已删除 ${to_delete} 个旧备份"
    fi
}

main() {
    parse_arguments "$@"

    print_bold "\n========================================"
    print_bold "Halo 博客系统 - SSL 证书备份"
    print_bold "========================================\n"

    create_backup_directory

    if backup_ssl; then
        print_bg_green "✓ SSL 证书备份完成"
        return 0
    else
        print_bg_red "✗ SSL 证书备份失败"
        return 1
    fi
}

main "$@"

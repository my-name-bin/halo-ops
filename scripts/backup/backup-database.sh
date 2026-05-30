#!/bin/bash
# ============================================
# 脚本名称: backup-database.sh
# 功能描述: 备份 PostgreSQL 数据库
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 使用说明: ./backup-database.sh [--compress]
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "${SCRIPT_DIR}/../utils/common.sh"

set_error_handler
set_cleanup_trap

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly BACKUP_DIR="${PROJECT_DIR}/db/backups"
COMPRESS=${COMPRESS:-true}

usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示帮助信息
    -c, --compress          压缩备份文件
    -v, --verbose           详细输出

示例:
    ${SCRIPT_NAME}              # 备份数据库（默认压缩）
    ${SCRIPT_NAME} -c          # 压缩备份

EOF
    exit 0
}

parse_arguments() {
    COMPRESS=true
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -c|--compress)
                COMPRESS=true
                shift
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

backup_database() {
    local timestamp=$(get_timestamp)
    local backup_file="${BACKUP_DIR}/halo_db_${timestamp}.sql"

    log_info "开始备份数据库..."

    if COMPRESS=true; then
        backup_file="${backup_file}.gz"
    fi

    if docker_compose_exec halodb pg_dump -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" $([ "$COMPRESS" = true ] && echo "-Fc" || echo "") > "$backup_file" 2>/dev/null; then
        log_success "数据库备份成功: $(basename "$backup_file")"

        local size=$(stat -c%s "$backup_file")
        log_info "备份文件大小: $(format_size $size)"

        cleanup_old_backups

        echo "$backup_file"
        return 0
    else
        log_error "数据库备份失败"
        return 1
    fi
}

cleanup_old_backups() {
    log_info "清理旧备份..."

    local max_backups=${MAX_BACKUP_COUNT:-30}

    cd "$BACKUP_DIR" || return 1

    local backup_count=$(ls -1 halo_db_*.sql* 2>/dev/null | wc -l)

    if [[ $backup_count -gt $max_backups ]]; then
        local to_delete=$((backup_count - max_backups))
        ls -1t halo_db_*.sql* 2>/dev/null | tail -n $to_delete | xargs rm -f
        log_info "已删除 ${to_delete} 个旧备份"
    fi
}

main() {
    parse_arguments "$@"

    print_bold "\n========================================"
    print_bold "Halo 博客系统 - 数据库备份"
    print_bold "========================================\n"

    load_env
    create_backup_directory

    if backup_database; then
        print_bg_green "✓ 数据库备份完成"
        return 0
    else
        print_bg_red "✗ 数据库备份失败"
        return 1
    fi
}

main "$@"

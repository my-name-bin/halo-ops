#!/bin/bash
# ============================================
# 脚本名称: backup-app.sh
# 功能描述: 备份 Halo 应用数据
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 使用说明: ./backup-app.sh [--compress]
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "${SCRIPT_DIR}/../utils/common.sh"

set_error_handler
set_cleanup_trap

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly BACKUP_DIR="${PROJECT_DIR}/data/app/backups"
COMPRESS=${COMPRESS:-true}

usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示帮助信息
    -c, --compress          压缩备份文件
    -v, --verbose           详细输出

示例:
    ${SCRIPT_NAME}              # 备份应用数据（默认压缩）
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

backup_app_data() {
    local timestamp=$(get_timestamp)
    local backup_name="halo_app_${timestamp}"
    local backup_dir="${BACKUP_DIR}/${backup_name}"
    local backup_file="${BACKUP_DIR}/${backup_name}.tar.gz"

    log_info "开始备份应用数据..."

    create_directory_if_not_exists "$backup_dir"

    local source_dirs=(
        "attachments"
        "themes"
        "plugins"
    )

    for dir in "${source_dirs[@]}"; do
        local source_path="${PROJECT_DIR}/data/${dir}"
        if [[ -d "$source_path" ]]; then
            cp -a "$source_path" "${backup_dir}/"
            log_debug "已复制: ${dir}"
        fi
    done

    if [[ "$COMPRESS" = true ]]; then
        tar -czf "$backup_file" -C "$BACKUP_DIR" "$(basename "$backup_dir")"
        rm -rf "$backup_dir"

        log_success "应用数据备份成功: $(basename "$backup_file")"

        local size=$(stat -c%s "$backup_file")
        log_info "备份文件大小: $(format_size $size)"

        cleanup_old_backups

        echo "$backup_file"
        return 0
    else
        log_success "应用数据备份成功: ${backup_name}/"
        cleanup_old_backups
        echo "$backup_dir"
        return 0
    fi
}

cleanup_old_backups() {
    log_info "清理旧备份..."

    local max_backups=${MAX_BACKUP_COUNT:-10}

    cd "$BACKUP_DIR" || return 1

    local backup_count=$(ls -1d halo_app_* 2>/dev/null | wc -l)

    if [[ $backup_count -gt $max_backups ]]; then
        local to_delete=$((backup_count - max_backups))
        ls -1td halo_app_* 2>/dev/null | tail -n $to_delete | xargs rm -rf
        log_info "已删除 ${to_delete} 个旧备份"
    fi
}

main() {
    parse_arguments "$@"

    print_bold "\n========================================"
    print_bold "Halo 博客系统 - 应用数据备份"
    print_bold "========================================\n"

    load_env
    create_backup_directory

    if backup_app_data; then
        print_bg_green "✓ 应用数据备份完成"
        return 0
    else
        print_bg_red "✗ 应用数据备份失败"
        return 1
    fi
}

main "$@"

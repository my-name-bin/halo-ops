#!/bin/bash
# ============================================
# 脚本名称: cleanup-logs.sh
# 功能描述: 清理日志文件
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 维护者: guobin
# ============================================

set -euo pipefail

PROJECT_DIR="/data/halo"
SCRIPT_UTILS="${PROJECT_DIR}/scripts/utils"

source "${SCRIPT_UTILS}/common.sh"

SCRIPT_NAME="cleanup-logs.sh"

usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示帮助信息
    -f, --force            强制清理，不询问确认
    -d, --days <天数>       只保留最近 N 天的日志

示例:
    ${SCRIPT_NAME}              # 交互式清理
    ${SCRIPT_NAME} -f           # 强制清理
    ${SCRIPT_NAME} -d 7         # 只保留最近 7 天的日志

EOF
    exit 0
}

cleanup_docker_logs() {
    log_info "清理 Docker 容器日志..."

    local total_size=0
    local cleaned=0

    for container in $(docker ps -a --format '{{.Names}}'); do
        local log_file=$(docker inspect --format='{{.LogPath}}' "$container" 2>/dev/null)

        if [[ -f "$log_file" ]]; then
            local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
            local size_mb=$((size / 1024 / 1024))

            if [[ $size_mb -gt 0 ]]; then
                log_info "清空容器 ${container} 的日志 (${size_mb}MB)"
                truncate -s 0 "$log_file" 2>/dev/null || sudo truncate -s 0 "$log_file" 2>/dev/null
                ((cleaned++))
                ((total_size += size_mb))
            fi
        fi
    done

    if [[ $cleaned -gt 0 ]]; then
        log_success "已清理 ${cleaned} 个容器的日志，共释放 ${total_size}MB 空间"
    else
        log_success "没有需要清理的 Docker 日志"
    fi
}

cleanup_project_logs() {
    log_info "清理项目日志目录..."

    local logs_dir="${PROJECT_DIR}/logs"
    local total_cleaned=0

    if [[ -d "$logs_dir" ]]; then
        local dirs=("halo" "nginx" "database")

        for dir in "${dirs[@]}"; do
            local target_dir="${logs_dir}/${dir}"

            if [[ -d "$target_dir" ]]; then
                local size_before=$(du -sb "$target_dir" 2>/dev/null | cut -f1 || echo 0)
                local size_before_mb=$((size_before / 1024 / 1024))

                if [[ $size_before_mb -gt 0 ]]; then
                    log_info "清理 ${dir} 日志 (${size_before_mb}MB)"
                    rm -rf "${target_dir}"/* 2>/dev/null || true
                    ((total_cleaned += size_before_mb))
                fi
            fi
        done

        if [[ $total_cleaned -gt 0 ]]; then
            log_success "已清理项目日志，释放 ${total_cleaned}MB 空间"
        else
            log_success "项目日志目录为空，无需清理"
        fi
    else
        log_warning "项目日志目录不存在: ${logs_dir}"
    fi
}

cleanup_old_logs() {
    local days=$1

    log_info "清理 ${days} 天前的日志..."

    local logs_dir="${PROJECT_DIR}/logs"

    if [[ -d "$logs_dir" ]]; then
        find "$logs_dir" -type f -name "*.log" -mtime "+${days}" -delete 2>/dev/null || true
        log_success "已清理 ${days} 天前的日志文件"
    fi
}

main() {
    local force=false
    local days=0

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -d|--days)
                days="${2:-7}"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                usage
                ;;
        esac
    done

    if [[ $EUID -ne 0 ]] && ! docker info >/dev/null 2>&1; then
        log_warning "需要 root 权限或 Docker 访问权限来清理日志"
    fi

    cleanup_docker_logs
    cleanup_project_logs

    if [[ $days -gt 0 ]]; then
        cleanup_old_logs "$days"
    fi

    log_success "日志清理完成！"
}

main "$@"

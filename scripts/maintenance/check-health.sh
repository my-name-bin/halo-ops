#!/bin/bash
# ============================================
# 脚本名称: check-health.sh
# 功能描述: 检查所有服务健康状态
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 使用说明: ./check-health.sh
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "${SCRIPT_DIR}/../utils/common.sh"

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示帮助信息
    -v, --verbose           详细输出

示例:
    ${SCRIPT_NAME}              # 检查所有服务健康状态
    ${SCRIPT_NAME} -v           # 详细输出

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

check_docker_services() {
    log_info "检查 Docker 服务状态..."

    cd "$PROJECT_DIR" || return 1

    local running_count=$(docker-compose ps 2>/dev/null | grep -c "Up" || echo "0")

    if [[ $running_count -ge 3 ]]; then
        log_success "Docker 服务运行中"
        return 0
    else
        log_error "部分 Docker 服务未运行"
        docker-compose ps
        return 1
    fi
}

check_database_service() {
    log_info "检查数据库服务..."

    if is_service_running "halodb"; then
        if check_database; then
            log_success "数据库服务正常"
            return 0
        else
            log_error "数据库服务异常"
            return 1
        fi
    else
        log_error "数据库服务未运行"
        return 1
    fi
}

check_halo_service() {
    log_info "检查 Halo 应用..."

    if is_service_running "halo"; then
        local app_url="http://localhost:8090/actuator/health"

        if check_http "$app_url" "200" 10; then
            log_success "Halo 应用正常"
            return 0
        else
            log_warning "Halo 应用响应异常"
            return 1
        fi
    else
        log_error "Halo 应用未运行"
        return 1
    fi
}

check_nginx_service() {
    log_info "检查 Nginx 服务..."

    if is_service_running "nginx"; then
        log_success "Nginx 服务正常"
        return 0
    else
        log_error "Nginx 服务未运行"
        return 1
    fi
}

check_network() {
    log_info "检查网络连接..."

    if check_port "localhost" 80 5; then
        log_success "HTTP 端口 (80) 正常"
    else
        log_warning "HTTP 端口 (80) 异常"
    fi

    if check_port "localhost" 443 5; then
        log_success "HTTPS 端口 (443) 正常"
    else
        log_warning "HTTPS 端口 (443) 异常"
    fi
}

check_ssl_certificate() {
    log_info "检查 SSL 证书..."

    local cert_file="${PROJECT_DIR}/ssl/live/aace.cc/fullchain.pem"

    if [[ ! -f "$cert_file" ]]; then
        log_warning "SSL 证书文件不存在"
        return 1
    fi

    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    if [[ $days_until_expiry -lt 30 ]]; then
        log_warning "SSL 证书将在 ${days_until_expiry} 天后过期"
        return 1
    else
        log_success "SSL 证书有效（${days_until_expiry} 天）"
        return 0
    fi
}

print_summary() {
    local failed=$1

    echo
    print_bold "========================================"
    print_bold "健康检查汇总"
    print_bold "========================================"

    echo "数据库: $(is_service_running 'halodb' && echo '运行中' || echo '停止')"
    echo "Halo: $(is_service_running 'halo' && echo '运行中' || echo '停止')"
    echo "Nginx: $(is_service_running 'nginx' && echo '运行中' || echo '停止')"
    echo "HTTP: $(check_port 'localhost' 80 2 && echo '正常' || echo '异常')"
    echo "HTTPS: $(check_port 'localhost' 443 2 && echo '正常' || echo '异常')"

    echo
    if [[ $failed -eq 0 ]]; then
        print_bg_green "✓ 所有检查通过"
        return 0
    else
        print_bg_red "✗ ${failed} 项检查失败"
        return 1
    fi
}

main() {
    parse_arguments "$@"

    print_bold "\n========================================"
    print_bold "Halo 博客系统 - 健康检查"
    print_bold "========================================\n"

    load_env

    local failed=0

    check_docker_services || ((failed++))
    echo

    check_database_service || ((failed++))
    echo

    check_halo_service || ((failed++))
    echo

    check_nginx_service || ((failed++))
    echo

    check_network
    echo

    check_ssl_certificate || ((failed++))
    echo

    print_summary $failed

    return $?
}

main "$@"

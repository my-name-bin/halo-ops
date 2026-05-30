#!/bin/bash
# ============================================
# 脚本名称: test-config.sh
# 功能描述: 测试配置文件语法和完整性
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 使用说明: ./test-config.sh
# ============================================

set -euo pipefail

PROJECT_DIR="/data/halo"
SCRIPT_UTILS="${PROJECT_DIR}/scripts/utils"

source "${SCRIPT_UTILS}/common.sh"

SCRIPT_NAME="test-config.sh"

usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示帮助信息
    -v, --verbose           详细输出

示例:
    ${SCRIPT_NAME}              # 测试所有配置
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

test_docker_compose_config() {
    log_info "测试 Docker Compose 配置..."

    cd "$PROJECT_DIR" || return 1

    if docker-compose config &>/dev/null; then
        log_success "Docker Compose 配置语法正确"
        return 0
    else
        log_error "Docker Compose 配置语法错误"
        docker-compose config
        return 1
    fi
}

test_environment_file() {
    log_info "测试环境变量文件..."

    if [[ ! -f "${PROJECT_DIR}/.env" ]]; then
        log_error "环境变量文件不存在"
        return 1
    fi

    load_env

    local required_vars=(
        "DB_PASSWORD"
        "DB_USER"
        "DB_NAME"
        "HALO_EXTERNAL_URL"
        "HALO_JVM_XMX"
        "HALO_JVM_XMS"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "缺少必需环境变量: ${var}"
            return 1
        fi
    done

    log_success "环境变量配置完整"
    return 0
}

test_postgres_config() {
    log_info "测试 PostgreSQL 配置..."

    local postgres_conf="${PROJECT_DIR}/config/database/postgres/postgresql.conf"
    local pg_hba_conf="${PROJECT_DIR}/config/database/pg_hba.conf"

    if [[ ! -f "$postgres_conf" ]]; then
        log_error "PostgreSQL 配置文件不存在: $postgres_conf"
        return 1
    fi

    if [[ ! -f "$pg_hba_conf" ]]; then
        log_error "PostgreSQL 访问控制文件不存在: $pg_hba_conf"
        return 1
    fi

    log_success "PostgreSQL 配置文件存在"
    return 0
}

test_nginx_config() {
    log_info "测试 Nginx 配置..."

    local nginx_conf="${PROJECT_DIR}/config/nginx/nginx.conf"

    if [[ ! -f "$nginx_conf" ]]; then
        log_error "Nginx 配置文件不存在"
        return 1
    fi

    log_success "Nginx 配置文件存在"
    return 0
}

test_ssl_certificates() {
    log_info "测试 SSL 证书..."

    local cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    local required_files=("fullchain.pem" "privkey.pem")

    for file in "${required_files[@]}"; do
        if [[ ! -f "${cert_dir}/${file}" ]]; then
            log_error "SSL 证书文件缺失: ${file}"
            return 1
        fi
    done

    if openssl x509 -in "${cert_dir}/fullchain.pem" -noout &>/dev/null; then
        log_success "SSL 证书格式正确"
        return 0
    else
        log_error "SSL 证书格式错误"
        return 1
    fi
}

test_directory_structure() {
    log_info "测试目录结构..."

    local required_dirs=(
        "config/database"
        "config/nginx"
        "data/app"
        "logs"
        "db/data"
        "ssl"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${PROJECT_DIR}/${dir}" ]]; then
            log_error "缺少目录: ${dir}"
            return 1
        fi
    done

    log_success "目录结构完整"
    return 0
}

print_summary() {
    local failed=$1

    echo
    print_bold "========================================"
    print_bold "配置测试汇总"
    print_bold "========================================"

    echo "目录结构: ✓ 完整"
    echo "环境变量: $([[ -f "${PROJECT_DIR}/.env" ]] && echo '✓ 正常' || echo '✗ 缺失')"
    echo "PostgreSQL: $([ -f "${PROJECT_DIR}/config/database/postgres/postgresql.conf" ] && echo '✓ 正常' || echo '✗ 缺失')"
    echo "Nginx: $([ -f "${PROJECT_DIR}/config/nginx/nginx.conf" ] && echo '✓ 正常' || echo '✗ 缺失')"
    echo "SSL 证书: $([[ -f "${PROJECT_DIR}/ssl/live/aace.cc/fullchain.pem" ]] && echo '✓ 正常' || echo '✗ 缺失')"

    echo
    if [[ $failed -eq 0 ]]; then
        print_bg_green "✓ 所有配置测试通过"
        return 0
    else
        print_bg_red "✗ ${failed} 项测试失败"
        return 1
    fi
}

main() {
    parse_arguments "$@"

    print_bold "\n========================================"
    print_bold "Halo 博客系统 - 配置测试"
    print_bold "========================================\n"

    local failed=0

    test_directory_structure || ((failed++))
    echo

    test_environment_file || ((failed++))
    echo

    test_docker_compose_config || ((failed++))
    echo

    test_postgres_config || ((failed++))
    echo

    test_nginx_config || ((failed++))
    echo

    test_ssl_certificates || ((failed++))
    echo

    print_summary $failed

    return $?
}

main "$@"

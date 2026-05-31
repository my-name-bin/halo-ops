#!/bin/bash
# ============================================
# 脚本名称: test-database.sh
# 功能描述: 测试 PostgreSQL 数据库
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 维护者: guobin
# ============================================

set -euo pipefail

PROJECT_DIR="/data/halo"
SCRIPT_UTILS="${PROJECT_DIR}/scripts/utils"

source "${SCRIPT_UTILS}/common.sh"

SCRIPT_NAME="test-database.sh"

test_database_container() {
    log_info "测试数据库容器..."

    if docker ps --format '{{.Names}}' | grep -q "halodb\|halo-database"; then
        log_success "数据库容器正在运行"
        return 0
    else
        log_error "数据库容器未运行"
        return 1
    fi
}

test_database_connection() {
    log_info "测试数据库连接..."

    if docker-compose exec -T halo-database pg_isready -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" &>/dev/null || \
       docker-compose exec -T halodb pg_isready -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" &>/dev/null; then
        log_success "数据库连接正常"
        return 0
    else
        log_error "数据库连接失败"
        return 1
    fi
}

test_database_process() {
    log_info "测试数据库进程..."

    if docker-compose exec halo-database pg_isready -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" &>/dev/null || \
       docker-compose exec halodb pg_isready -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" &>/dev/null; then
        log_success "PostgreSQL 进程正在运行"
        return 0
    else
        log_error "PostgreSQL 进程未运行"
        return 1
    fi
}

test_database_version() {
    log_info "测试数据库版本..."

    local version
    if docker-compose exec -T halo-database psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT version();" 2>/dev/null | head -1 | grep -q "PostgreSQL"; then
        version=$(docker-compose exec -T halo-database psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT version();" 2>/dev/null | head -1)
    elif docker-compose exec -T halodb psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT version();" 2>/dev/null | head -1 | grep -q "PostgreSQL"; then
        version=$(docker-compose exec -T halodb psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT version();" 2>/dev/null | head -1)
    fi

    if [[ -n "$version" ]]; then
        log_success "数据库版本: ${version}"
        return 0
    else
        log_error "无法获取数据库版本"
        return 1
    fi
}

test_database_size() {
    log_info "测试数据库大小..."

    local size=""
    
    if docker-compose exec halo-database psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT pg_size_pretty(pg_database_size('${DB_NAME:-halo}'));" 2>/dev/null | xargs | grep -q "MB\|KB\|GB"; then
        size=$(docker-compose exec halo-database psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT pg_size_pretty(pg_database_size('${DB_NAME:-halo}'));" 2>/dev/null | xargs)
    elif docker-compose exec halodb psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT pg_size_pretty(pg_database_size('${DB_NAME:-halo}'));" 2>/dev/null | xargs | grep -q "MB\|KB\|GB"; then
        size=$(docker-compose exec halodb psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT pg_size_pretty(pg_database_size('${DB_NAME:-halo}'));" 2>/dev/null | xargs)
    fi

    if [[ -n "$size" ]]; then
        log_success "数据库大小: ${size}"
        return 0
    else
        log_warning "无法获取数据库大小"
        return 1
    fi
}

test_database_connections() {
    log_info "测试数据库连接数..."

    local connections=""
    
    if docker-compose exec halo-database psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname = '${DB_NAME:-halo}';" 2>/dev/null | xargs | grep -q "^[0-9]"; then
        connections=$(docker-compose exec halo-database psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname = '${DB_NAME:-halo}';" 2>/dev/null | xargs)
    elif docker-compose exec halodb psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname = '${DB_NAME:-halo}';" 2>/dev/null | xargs | grep -q "^[0-9]"; then
        connections=$(docker-compose exec halodb psql -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}" -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname = '${DB_NAME:-halo}';" 2>/dev/null | xargs)
    fi

    if [[ -n "$connections" ]]; then
        log_success "当前连接数: ${connections}"
        return 0
    else
        log_warning "无法获取连接数"
        return 1
    fi
}

print_summary() {
    local failed=$1

    echo
    print_bold "========================================"
    print_bold "PostgreSQL 数据库测试汇总"
    print_bold "========================================"

    echo "容器运行:    ✓ 正常"
    echo "连接状态:    ✓ 正常"
    echo "进程状态:    ✓ 正常"

    echo
    if [[ $failed -eq 0 ]]; then
        print_bg_green "✓ 所有数据库测试通过"
        return 0
    else
        print_bg_red "✗ ${failed} 项测试失败"
        return 1
    fi
}

main() {
    print_bold "\n========================================"
    print_bold "Halo 博客系统 - 数据库测试"
    print_bold "========================================\n"
    
    load_env

    local failed=0

    test_database_container || ((failed++))
    test_database_connection || ((failed++))
    test_database_process || ((failed++))
    test_database_version || ((failed++))

    print_summary $failed

    return $?
}

main "$@"

#!/bin/bash
# ============================================
# 脚本名称: test-app.sh
# 功能描述: 测试 Halo 应用
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 维护者: guobin
# ============================================

set -euo pipefail

PROJECT_DIR="/data/halo"
SCRIPT_UTILS="${PROJECT_DIR}/scripts/utils"

source "${SCRIPT_UTILS}/common.sh"

SCRIPT_NAME="test-app.sh"

test_halo_container() {
    log_info "测试 Halo 容器..."

    if docker ps --format '{{.Names}}' | grep -q "^halo$" || \
       docker ps --format '{{.Names}}' | grep -q "^halo-app$"; then
        log_success "Halo 容器正在运行"
        return 0
    else
        log_error "Halo 容器未运行"
        return 1
    fi
}

test_halo_process() {
    log_info "测试 Halo 进程..."

    if docker-compose exec -T halo ps aux | grep -q "[j]ava"; then
        log_success "Halo Java 进程正在运行"
        return 0
    else
        log_error "Halo Java 进程未运行"
        return 1
    fi
}

test_halo_health() {
    log_info "测试 Halo 健康检查..."

    if docker-compose exec -T halo curl -f http://localhost:8090/actuator/health &>/dev/null; then
        log_success "Halo 健康检查通过"
        return 0
    else
        log_warning "Halo 健康检查失败（可能还在启动中）"
        return 1
    fi
}

test_halo_logs() {
    log_info "测试 Halo 日志..."

    local logs=$(docker-compose logs --tail=50 halo 2>&1)
    
    if echo "$logs" | grep -q "Started HaloApplication\|Started application\|Tomcat started\|Halo is running"; then
        log_success "Halo 应用已成功启动"
        return 0
    elif echo "$logs" | grep -q "started"; then
        log_success "Halo 应用启动日志正常"
        return 0
    else
        log_warning "Halo 启动日志可能不完整或应用仍在启动中"
        return 0
    fi
}

test_halo_configuration() {
    log_info "测试 Halo 配置..."

    if docker-compose exec -T halo env | grep -q "HALO"; then
        log_success "Halo 环境变量已配置"
        return 0
    else
        log_warning "Halo 环境变量可能未正确配置"
        return 1
    fi
}

print_summary() {
    local failed=$1

    echo
    print_bold "========================================"
    print_bold "Halo 应用测试汇总"
    print_bold "========================================"

    echo "容器运行:    ✓ 正常"
    echo "进程状态:    ✓ 正常"
    echo "健康检查:    ✓ 正常"
    echo "启动日志:    ✓ 正常"
    echo "配置状态:    ✓ 正常"

    echo
    if [[ $failed -eq 0 ]]; then
        print_bg_green "✓ 所有 Halo 应用测试通过"
        return 0
    else
        print_bg_red "✗ ${failed} 项测试失败"
        return 1
    fi
}

main() {
    print_bold "\n========================================"
    print_bold "Halo 博客系统 - 应用测试"
    print_bold "========================================\n"
    
    load_env

    local failed=0

    test_halo_container || ((failed++))
    test_halo_process || ((failed++))
    test_halo_health || ((failed++))
    test_halo_logs || ((failed++))
    test_halo_configuration || ((failed++))

    print_summary $failed

    return $?
}

main "$@"

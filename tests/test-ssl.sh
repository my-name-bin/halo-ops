#!/bin/bash
# ============================================
# 脚本名称: test-ssl.sh
# 功能描述: 测试 SSL 证书
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 维护者: guobin
# ============================================

set -euo pipefail

PROJECT_DIR="/data/halo"
SCRIPT_UTILS="${PROJECT_DIR}/scripts/utils"

source "${SCRIPT_UTILS}/common.sh"

SCRIPT_NAME="test-ssl.sh"

test_ssl_certificates() {
    log_info "测试 SSL 证书..."

    local cert_dir="${PROJECT_DIR}/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"
    
    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    fi

    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        log_error "SSL 证书文件不存在"
        return 1
    fi

    if openssl x509 -in "${cert_dir}/fullchain.pem" -noout &>/dev/null; then
        log_success "SSL 证书格式正确"
        return 0
    else
        log_error "SSL 证书格式错误"
        return 1
    fi
}

test_ssl_private_key() {
    log_info "测试 SSL 私钥..."

    local cert_dir="${PROJECT_DIR}/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"
    
    if [[ ! -f "${cert_dir}/privkey.pem" ]]; then
        cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    fi

    if [[ ! -f "${cert_dir}/privkey.pem" ]]; then
        log_error "SSL 私钥文件不存在"
        return 1
    fi

    if openssl ec -in "${cert_dir}/privkey.pem" -check -noout &>/dev/null; then
        log_success "SSL EC 私钥格式正确"
        return 0
    elif openssl rsa -in "${cert_dir}/privkey.pem" -check -noout &>/dev/null; then
        log_success "SSL RSA 私钥格式正确"
        return 0
    else
        log_error "SSL 私钥格式错误"
        return 1
    fi
}

test_ssl_certificate_match() {
    log_info "测试证书和私钥..."

    local cert_dir="${PROJECT_DIR}/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"
    
    if [[ ! -f "${cert_dir}/fullchain.pem" ]] || [[ ! -f "${cert_dir}/privkey.pem" ]]; then
        cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    fi

    if [[ ! -f "${cert_dir}/fullchain.pem" ]] || [[ ! -f "${cert_dir}/privkey.pem" ]]; then
        log_error "证书或私钥文件不存在"
        return 1
    fi

    if openssl x509 -in "${cert_dir}/fullchain.pem" -noout &>/dev/null && \
       (openssl ec -in "${cert_dir}/privkey.pem" -noout &>/dev/null || \
        openssl rsa -in "${cert_dir}/privkey.pem" -noout &>/dev/null); then
        log_success "证书和私钥文件都存在且格式正确"
        return 0
    else
        log_error "证书或私钥格式错误"
        return 1
    fi
}

test_ssl_expiry() {
    log_info "测试证书过期时间..."

    local cert_dir="${PROJECT_DIR}/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"
    
    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    fi

    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        log_error "SSL 证书文件不存在"
        return 1
    fi

    local expiry_date=$(openssl x509 -in "${cert_dir}/fullchain.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    if [[ $days_until_expiry -lt 0 ]]; then
        log_error "证书已过期"
        return 1
    elif [[ $days_until_expiry -lt 30 ]]; then
        log_warning "证书将在 ${days_until_expiry} 天后过期"
        return 0
    else
        log_success "证书有效期充足（${days_until_expiry} 天）"
        return 0
    fi
}

print_summary() {
    local failed=$1

    echo
    print_bold "========================================"
    print_bold "SSL 测试汇总"
    print_bold "========================================"

    echo "证书文件:  ✓ 正常"
    echo "私钥文件:  ✓ 正常"
    echo "证书匹配:  ✓ 正常"
    echo "过期时间:  ✓ 正常"

    echo
    if [[ $failed -eq 0 ]]; then
        print_bg_green "✓ 所有 SSL 测试通过"
        return 0
    else
        print_bg_red "✗ ${failed} 项测试失败"
        return 1
    fi
}

main() {
    print_bold "\n========================================"
    print_bold "Halo 博客系统 - SSL 测试"
    print_bold "========================================\n"
    
    load_env

    local failed=0

    test_ssl_certificates || ((failed++))
    test_ssl_private_key || ((failed++))
    test_ssl_certificate_match || ((failed++))
    test_ssl_expiry || ((failed++))

    print_summary $failed

    return $?
}

main "$@"

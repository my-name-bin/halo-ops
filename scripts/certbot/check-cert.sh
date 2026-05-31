#!/bin/bash
# ============================================
# 脚本名称: check-cert.sh
# 功能描述: 检查 SSL 证书状态
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 维护者: guobin
# ============================================

set -euo pipefail

PROJECT_DIR="/data/halo"
SCRIPT_UTILS="${PROJECT_DIR}/scripts/utils"

source "${SCRIPT_UTILS}/common.sh"

SCRIPT_NAME="check-cert.sh"

usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示帮助信息
    -v, --verbose           详细输出

示例:
    ${SCRIPT_NAME}              # 检查证书状态
    ${SCRIPT_NAME} -v          # 详细输出

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

check_certificate_exists() {
    log_info "检查证书文件..."

    local cert_dir="${PROJECT_DIR}/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"
    
    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    fi

    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        log_error "SSL 证书文件不存在"
        return 1
    fi

    log_success "证书文件存在"
    return 0
}

check_certificate_info() {
    log_info "获取证书信息..."

    local cert_dir="${PROJECT_DIR}/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"
    
    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    fi

    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        log_error "SSL 证书文件不存在"
        return 1
    fi

    local cert_file="${cert_dir}/fullchain.pem"

    echo
    print_bold "证书详细信息："
    echo "----------------------------------------"
    
    local subject=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/subject=//')
    local issuer=$(openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null | sed 's/issuer=//')
    local not_before=$(openssl x509 -in "$cert_file" -noout -startdate 2>/dev/null | sed 's/notBefore=//')
    local not_after=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
    local serial=$(openssl x509 -in "$cert_file" -noout -serial 2>/dev/null | sed 's/serial=//')
    local fingerprint=$(openssl x509 -in "$cert_file" -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//')

    echo "主题:     $subject"
    echo "颁发者:   $issuer"
    echo "生效日期: $not_before"
    echo "过期日期: $not_after"
    echo "序列号:   $serial"
    echo "指纹:     $fingerprint"
    echo "----------------------------------------"
    echo
}

check_certificate_validity() {
    log_info "检查证书有效性..."

    local cert_dir="${PROJECT_DIR}/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"
    
    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    fi

    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        log_error "SSL 证书文件不存在"
        return 1
    fi

    local cert_file="${cert_dir}/fullchain.pem"

    if openssl x509 -in "$cert_file" -noout 2>/dev/null; then
        log_success "证书格式正确"
    else
        log_error "证书格式错误"
        return 1
    fi

    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    echo
    print_bold "证书有效性："
    echo "----------------------------------------"
    echo "过期日期:     $expiry_date"
    echo "剩余天数:     $days_until_expiry 天"

    if [[ $days_until_expiry -lt 30 ]]; then
        echo "状态:        ⚠️  即将过期（<30天）"
        log_warning "证书将在 ${days_until_expiry} 天后过期，请及时续期"
        echo "----------------------------------------"
        echo
        return 1
    elif [[ $days_until_expiry -lt 60 ]]; then
        echo "状态:        ⚠️  即将续期提醒（<60天）"
        log_warning "证书将在 ${days_until_expiry} 天后过期，请注意续期"
        echo "----------------------------------------"
        echo
    else
        echo "状态:        ✅ 正常"
        log_success "证书有效期充足（${days_until_expiry} 天）"
        echo "----------------------------------------"
        echo
    fi

    return 0
}

check_certificate_chain() {
    log_info "检查证书链..."

    local cert_dir="${PROJECT_DIR}/ssl/live/${PRIMARY_DOMAIN:-aace.cc}"
    
    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        cert_dir="${PROJECT_DIR}/ssl/live/aace.cc"
    fi

    if [[ ! -f "${cert_dir}/fullchain.pem" ]]; then
        log_error "SSL 证书文件不存在"
        return 1
    fi

    local cert_file="${cert_dir}/fullchain.pem"
    local chain_file="${cert_dir}/chain.pem"
    local privkey_file="${cert_dir}/privkey.pem"

    echo
    print_bold "证书链检查："
    echo "----------------------------------------"

    if [[ -f "$cert_file" ]]; then
        echo "服务器证书: ✅ 存在"
    else
        echo "服务器证书: ❌ 缺失"
        log_error "服务器证书缺失"
        return 1
    fi

    if [[ -f "$chain_file" ]]; then
        echo "证书链文件: ✅ 存在"
    else
        echo "证书链文件: ⚠️  未分离（可能在 fullchain.pem 中）"
    fi

    if [[ -f "$privkey_file" ]]; then
        echo "私钥文件:   ✅ 存在"
    else
        echo "私钥文件:   ❌ 缺失"
        log_error "私钥文件缺失"
        return 1
    fi

    if [[ -f "$cert_file" ]] && [[ -f "$privkey_file" ]]; then
        if openssl x509 -in "$cert_file" -noout -modulus &>/dev/null && \
           openssl rsa -in "$privkey_file" -noout -modulus &>/dev/null; then
            local cert_md5=$(openssl x509 -in "$cert_file" -noout -modulus 2>/dev/null | md5sum | cut -d' ' -f1)
            local key_md5=$(openssl rsa -in "$privkey_file" -noout -modulus 2>/dev/null | md5sum | cut -d' ' -f1)

            if [[ "$cert_md5" == "$key_md5" ]]; then
                echo "证书匹配:   ✅ 匹配"
            else
                echo "证书匹配:   ❌ 不匹配"
                log_error "证书和私钥不匹配"
                return 1
            fi
        fi
    fi

    echo "----------------------------------------"
    echo
}

main() {
    parse_arguments "$@"

    print_bold "\n========================================"
    print_bold "SSL 证书状态检查"
    print_bold "========================================\n"
    
    load_env

    local failed=0

    check_certificate_exists || ((failed++))
    check_certificate_info
    check_certificate_validity || ((failed++))
    check_certificate_chain || ((failed++))

    echo
    if [[ $failed -eq 0 ]]; then
        print_bg_green "✅ 所有证书检查通过"
        return 0
    else
        print_bg_red "❌ ${failed} 项检查失败"
        return 1
    fi
}

main "$@"

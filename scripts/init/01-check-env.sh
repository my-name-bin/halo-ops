#!/bin/bash
# ============================================
# 脚本名称: 01-check-env.sh
# 功能描述: 检查环境是否满足部署要求
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 使用说明: ./01-check-env.sh
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "${SCRIPT_DIR}/../utils/common.sh"

set_error_handler
set_cleanup_trap

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示帮助信息
    -v, --verbose           详细输出

示例:
    ${SCRIPT_NAME}              # 检查基本环境
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

check_docker() {
    log_info "检查 Docker..."

    if ! command -v docker &>/dev/null; then
        log_error "Docker 未安装"
        return 1
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker 服务未运行"
        return 1
    fi

    local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
    log_success "Docker 版本: ${docker_version}"
}

check_docker_compose() {
    log_info "检查 Docker Compose..."

    if ! command -v docker-compose &>/dev/null; then
        log_error "Docker Compose 未安装"
        return 1
    fi

    local compose_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
    log_success "Docker Compose 版本: ${compose_version}"
}

check_project_structure() {
    log_info "检查项目结构..."

    local required_dirs=(
        "config"
        "data"
        "logs"
        "db"
        "ssl"
        "scripts"
        "docs"
        "tests"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${PROJECT_DIR}/${dir}" ]]; then
            log_error "缺少必需目录: ${dir}"
            return 1
        fi
        log_debug "目录存在: ${dir}"
    done

    log_success "项目结构完整"
}

check_environment_file() {
    log_info "检查环境配置文件..."

    if [[ ! -f "${PROJECT_DIR}/.env" ]]; then
        log_error "环境配置文件不存在: ${PROJECT_DIR}/.env"
        return 1
    fi

    load_env

    local required_vars=(
        "DB_PASSWORD"
        "DB_USER"
        "DB_NAME"
        "HALO_EXTERNAL_URL"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "缺少必需环境变量: ${var}"
            return 1
        fi
        log_debug "环境变量已设置: ${var}"
    done

    log_success "环境配置文件完整"
}

check_disk_space() {
    log_info "检查磁盘空间..."

    local available_space=$(df -BG "$PROJECT_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')

    if [[ $available_space -lt 5 ]]; then
        log_warning "磁盘空间不足，建议至少 5GB 可用空间"
        log_warning "当前可用空间: ${available_space}GB"
    else
        log_success "磁盘空间充足: ${available_space}GB"
    fi
}

check_system_resources() {
    log_info "检查系统资源..."

    local memory_total=$(free -m | awk 'NR==2 {print $2}')
    local memory_available=$(free -m | awk 'NR==2 {print $7}')

    log_info "总内存: ${memory_total}MB, 可用: ${memory_available}MB"

    if [[ $memory_available -lt 512 ]]; then
        log_warning "可用内存较少，可能影响性能"
    fi

    log_success "系统资源检查完成"
}

check_ports() {
    log_info "检查端口占用..."

    local ports=(80 443 5432 8090)
    local conflicts=()

    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
            log_warning "端口 ${port} 已被占用"
            conflicts+=("$port")
        else
            log_debug "端口 ${port} 可用"
        fi
    done

    if [[ ${#conflicts[@]} -eq 0 ]]; then
        log_success "所有必需端口可用"
    else
        log_warning "部分端口被占用，可能影响服务启动"
    fi
}

print_system_info() {
    print_bold "\n========================================"
    print_bold "系统信息"
    print_bold "========================================"

    echo "操作系统: $(get_os_info)"
    echo "Docker 版本: $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
    echo "Docker Compose 版本: $(docker-compose --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
    echo "CPU 核心数: $(nproc)"
    echo "内存总量: $(get_memory_info)"
    echo "磁盘空间: $(get_disk_info)"
    echo "负载平均值: $(get_load_average)"
    echo "项目路径: ${PROJECT_DIR}"
}

main() {
    parse_arguments "$@"

    print_bold "\n========================================"
    print_bold "Halo 博客系统 - 环境检查"
    print_bold "========================================\n"

    local checks=(
        "check_docker"
        "check_docker_compose"
        "check_project_structure"
        "check_environment_file"
        "check_disk_space"
        "check_system_resources"
        "check_ports"
    )

    local failed=0

    for check in "${checks[@]}"; do
        if ! $check; then
            ((failed++))
        fi
        echo
    done

    print_system_info

    echo
    if [[ $failed -eq 0 ]]; then
        print_bg_green "✓ 所有检查通过，环境满足部署要求"
        return 0
    else
        print_bg_red "✗ ${failed} 项检查失败，请修复后再试"
        return 1
    fi
}

main "$@"

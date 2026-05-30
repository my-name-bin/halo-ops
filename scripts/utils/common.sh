#!/bin/bash
# ============================================
# 脚本名称: common.sh
# 功能描述: 公共函数库
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# ============================================

# 加载工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging.sh"

# ============================================
# 常量定义
# ============================================
readonly PROJECT_DIR="/data/halo"
readonly DOCKER_COMPOSE="${PROJECT_DIR}/docker-compose.yml"

# ============================================
# 环境变量加载
# ============================================
load_env() {
    if [[ -f "${PROJECT_DIR}/.env" ]]; then
        set -a
        source "${PROJECT_DIR}/.env"
        set +a
        log_info "环境变量已加载"
    else
        log_error "环境变量文件不存在: ${PROJECT_DIR}/.env"
        return 1
    fi
}

# ============================================
# 错误处理
# ============================================
error_handler() {
    local line_number=$1
    local error_code=$2

    log_error "脚本执行失败，错误代码: ${error_code}"
    log_error "失败行号: ${line_number}"
    log_error "调用栈: $(caller)"

    cleanup_temp_files

    exit "${error_code}"
}

set_error_handler() {
    trap 'error_handler ${LINENO} $?' ERR
}

# ============================================
# 清理函数
# ============================================
temp_files=()

add_temp_file() {
    temp_files+=("$1")
}

cleanup_temp_files() {
    for temp_file in "${temp_files[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
            log_debug "已清理临时文件: $temp_file"
        fi
    done
    temp_files=()
}

set_cleanup_trap() {
    trap 'cleanup_temp_files' EXIT
    trap 'cleanup_temp_files' SIGINT
}

# ============================================
# Docker Compose 操作
# ============================================
check_docker_compose() {
    if [[ ! -f "$DOCKER_COMPOSE" ]]; then
        log_error "Docker Compose 文件不存在: $DOCKER_COMPOSE"
        return 1
    fi
}

docker_compose_exec() {
    local service=$1
    shift
    cd "$PROJECT_DIR" && docker-compose exec -T "$service" "$@"
}

docker_compose_run() {
    local service=$1
    shift
    cd "$PROJECT_DIR" && docker-compose run --rm "$service" "$@"
}

# ============================================
# 服务检查
# ============================================
is_service_running() {
    local service=$1
    cd "$PROJECT_DIR" && docker-compose ps "$service" | grep -q "Up"
}

wait_for_service() {
    local service=$1
    local max_wait=${2:-60}
    local count=0

    log_info "等待服务启动: $service"

    while ! is_service_running "$service"; do
        sleep 2
        count=$((count + 2))

        if [[ $count -ge $max_wait ]]; then
            log_error "服务启动超时: $service"
            return 1
        fi
    done

    log_success "服务已启动: $service"
    return 0
}

# ============================================
# 数据库操作
# ============================================
check_database() {
    docker_compose_exec halodb pg_isready -U "${DB_USER:-halo}" -d "${DB_NAME:-halo}"
}

wait_for_database() {
    local max_wait=${1:-60}
    local count=0

    log_info "等待数据库就绪..."

    while ! check_database &>/dev/null; do
        sleep 2
        count=$((count + 2))

        if [[ $count -ge $max_wait ]]; then
            log_error "数据库就绪超时"
            return 1
        fi
    done

    log_success "数据库已就绪"
    return 0
}

# ============================================
# 网络检查
# ============================================
check_port() {
    local host=$1
    local port=$2
    local timeout=${3:-5}

    if command -v nc &>/dev/null; then
        nc -z -w "$timeout" "$host" "$port" &>/dev/null
    elif command -v timeout &>/dev/null; then
        timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" &>/dev/null
    else
        curl -s -m "$timeout" "http://${host}:${port}" &>/dev/null
    fi
}

check_http() {
    local url=$1
    local expected_code=${2:-200}
    local timeout=${3:-10}

    local actual_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url")

    [[ "$actual_code" == "$expected_code" ]]
}

# ============================================
# 文件操作
# ============================================
create_directory_if_not_exists() {
    local dir=$1
    local owner=${2:-}
    local mode=${3:-755}

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        chmod "$mode" "$dir"

        if [[ -n "$owner" ]]; then
            chown "$owner" "$dir"
        fi

        log_debug "已创建目录: $dir"
    fi
}

backup_file() {
    local file=$1
    local backup_dir=${2:-"${PROJECT_DIR}/backups"}

    if [[ -f "$file" ]]; then
        create_directory_if_not_exists "$backup_dir"

        local filename=$(basename "$file")
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        local backup_file="${backup_dir}/${filename}.${timestamp}.bak"

        cp "$file" "$backup_file"
        log_info "已备份文件: $file -> $backup_file"

        echo "$backup_file"
    fi
}

# ============================================
# 用户交互
# ============================================
confirm() {
    local prompt=${1:-"确认操作？"}
    local default=${2:-"n"}

    if [[ "$default" == "y" ]]; then
        local options="[Y/n]"
    else
        local options="[y/N]"
    fi

    read -p "$prompt $options " -n 1 -r
    echo

    case $REPLY in
        y|Y) return 0 ;;
        n|N|"") return 1 ;;
        *) return 1 ;;
    esac
}

select_option() {
    local prompt=$1
    shift
    local options=("$@")

    echo "$prompt"
    echo

    for i in "${!options[@]}"; do
        echo "$((i+1))) ${options[$i]}"
    done

    echo

    local valid=false
    while ! $valid; do
        read -p "请选择 (1-${#options[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            selected_index=$((choice-1))
            selected_option="${options[$selected_index]}"
            valid=true
        else
            echo "无效选择，请重新输入"
        fi
    done
}

# ============================================
# 常用工具
# ============================================
get_timestamp() {
    date '+%Y%m%d_%H%M%S'
}

get_date() {
    date '+%Y-%m-%d'
}

get_time() {
    date '+%H:%M:%S'
}

get_epoch() {
    date '+%s'
}

format_size() {
    local size=$1

    if [[ $size -ge 1073741824 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1073741824}")GB"
    elif [[ $size -ge 1048576 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1048576}")MB"
    elif [[ $size -ge 1024 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1024}")KB"
    else
        echo "${size}B"
    fi
}

get_directory_size() {
    local dir=$1
    du -sb "$dir" 2>/dev/null | awk '{print $1}'
}

# ============================================
# 系统信息
# ============================================
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${PRETTY_NAME:-Unknown}"
    else
        echo "Unknown"
    fi
}

get_memory_info() {
    free -h | awk '/^Mem:/ {print $2}'
}

get_disk_info() {
    df -h "$PROJECT_DIR" | awk 'NR==2 {print $2}'
}

get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | sed 's/,//g'
}

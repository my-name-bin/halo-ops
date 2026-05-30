#!/bin/bash
# ============================================
# 脚本名称: logging.sh
# 功能描述: 日志函数库
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# ============================================

# 加载颜色函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/color.sh"

# ============================================
# 日志配置
# ============================================
readonly LOG_DIR="${LOG_DIR:-/data/halo/logs}"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"

# 日志级别
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_SUCCESS=2
readonly LOG_LEVEL_WARNING=3
readonly LOG_LEVEL_ERROR=4

# 获取当前日志级别数值
get_log_level_value() {
    case "$LOG_LEVEL" in
        DEBUG) echo $LOG_LEVEL_DEBUG ;;
        INFO)  echo $LOG_LEVEL_INFO ;;
        SUCCESS) echo $LOG_LEVEL_SUCCESS ;;
        WARNING) echo $LOG_LEVEL_WARNING ;;
        ERROR) echo $LOG_LEVEL_ERROR ;;
        *) echo $LOG_LEVEL_INFO ;;
    esac
}

# ============================================
# 日志输出函数
# ============================================

log_debug() {
    local current_level=$(get_log_level_value)
    if [[ $current_level -le $LOG_LEVEL_DEBUG ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${COLOR_GRAY}[DEBUG]${COLOR_NC} ${timestamp} - $*" >&2
        echo "[DEBUG] ${timestamp} - $*" >> "${LOG_FILE:-/dev/null}"
    fi
}

log_info() {
    local current_level=$(get_log_level_value)
    if [[ $current_level -le $LOG_LEVEL_INFO ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} ${timestamp} - $*"
        echo "[INFO] ${timestamp} - $*" >> "${LOG_FILE:-/dev/null}"
    fi
}

log_success() {
    local current_level=$(get_log_level_value)
    if [[ $current_level -le $LOG_LEVEL_SUCCESS ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} ${timestamp} - $*"
        echo "[SUCCESS] ${timestamp} - $*" >> "${LOG_FILE:-/dev/null}"
    fi
}

log_warning() {
    local current_level=$(get_log_level_value)
    if [[ $current_level -le $LOG_LEVEL_WARNING ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${COLOR_YELLOW}[WARNING]${COLOR_NC} ${timestamp} - $*" >&2
        echo "[WARNING] ${timestamp} - $*" >> "${LOG_FILE:-/dev/null}"
    fi
}

log_error() {
    local current_level=$(get_log_level_value)
    if [[ $current_level -le $LOG_LEVEL_ERROR ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${COLOR_RED}[ERROR]${COLOR_NC} ${timestamp} - $*" >&2
        echo "[ERROR] ${timestamp} - $*" >> "${LOG_FILE:-/dev/null}"
    fi
}

# ============================================
# 日志文件管理
# ============================================

init_log_file() {
    local script_name="${1:-unknown}"
    local log_subdir="${2:-general}"

    mkdir -p "${LOG_DIR}/${log_subdir}"

    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local log_file="${LOG_DIR}/${log_subdir}/${script_name}_${timestamp}.log"

    echo "$log_file"
}

rotate_log() {
    local log_file="$1"
    local max_size="${2:-10485760}"
    local max_files="${3:-10}"

    if [[ -f "$log_file" ]]; then
        local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)

        if [[ $size -gt $max_size ]]; then
            mv "$log_file" "${log_file}.$(date '+%Y%m%d_%H%M%S')"

            find "$(dirname "$log_file")" -name "$(basename "$log_file").*" -type f -mtime +7 -delete
        fi
    fi
}

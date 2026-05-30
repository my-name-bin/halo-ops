#!/bin/bash
# ============================================
# 脚本名称: color.sh
# 功能描述: 彩色输出函数库
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# ============================================

# ============================================
# 颜色定义
# ============================================
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_GRAY='\033[0;90m'
readonly COLOR_NC='\033[0m'

# ============================================
# 样式定义
# ============================================
readonly STYLE_BOLD='\033[1m'
readonly STYLE_DIM='\033[2m'
readonly STYLE_UNDERLINE='\033[4m'
readonly STYLE_BLINK='\033[5m'

# ============================================
# 背景色定义
# ============================================
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_YELLOW='\033[43m'
readonly BG_BLUE='\033[44m'

# ============================================
# 彩色输出函数
# ============================================

print_red() {
    echo -e "${COLOR_RED}$*${COLOR_NC}"
}

print_green() {
    echo -e "${COLOR_GREEN}$*${COLOR_NC}"
}

print_yellow() {
    echo -e "${COLOR_YELLOW}$*${COLOR_NC}"
}

print_blue() {
    echo -e "${COLOR_BLUE}$*${COLOR_NC}"
}

print_purple() {
    echo -e "${COLOR_PURPLE}$*${COLOR_NC}"
}

print_cyan() {
    echo -e "${COLOR_CYAN}$*${COLOR_NC}"
}

print_white() {
    echo -e "${COLOR_WHITE}$*${COLOR_NC}"
}

print_gray() {
    echo -e "${COLOR_GRAY}$*${COLOR_NC}"
}

# ============================================
# 带样式的输出
# ============================================

print_bold() {
    echo -e "${STYLE_BOLD}$*${COLOR_NC}"
}

print_dim() {
    echo -e "${STYLE_DIM}$*${COLOR_NC}"
}

print_underline() {
    echo -e "${STYLE_UNDERLINE}$*${COLOR_NC}"
}

# ============================================
# 带背景色的输出
# ============================================

print_bg_green() {
    echo -e "${BG_GREEN}${COLOR_WHITE}$*${COLOR_NC}"
}

print_bg_red() {
    echo -e "${BG_RED}${COLOR_WHITE}$*${COLOR_NC}"
}

print_bg_blue() {
    echo -e "${BG_BLUE}${COLOR_WHITE}$*${COLOR_NC}"
}

print_bg_yellow() {
    echo -e "${BG_YELLOW}${COLOR_BLACK}$*${COLOR_NC}"
}

# ============================================
# 进度条输出
# ============================================

print_progress() {
    local current=$1
    local total=$2
    local message=${3:-"Processing"}
    local width=50

    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))

    printf "\r${COLOR_BLUE}%s${COLOR_NC} [" "$message"
    printf "${COLOR_GREEN}%${completed}s${COLOR_NC}" | tr ' ' '='
    printf "${COLOR_GRAY}%${remaining}s${COLOR_NC}" | tr ' ' '-'
    printf "] %3d%%" "$percentage"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

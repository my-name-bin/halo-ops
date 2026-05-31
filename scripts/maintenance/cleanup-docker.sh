#!/bin/bash
# ============================================
# 脚本名称: cleanup-docker.sh
# 功能描述: 清理未使用的 Docker 资源
# 创建日期: 2026-05-31
# 版本信息: v1.0.0
# 维护者: guobin
# ============================================

set -euo pipefail

PROJECT_DIR="/data/halo"
SCRIPT_UTILS="${PROJECT_DIR}/scripts/utils"

source "${SCRIPT_UTILS}/common.sh"

SCRIPT_NAME="cleanup-docker.sh"

usage() {
    cat << EOF
使用方法: ${SCRIPT_NAME} [选项]

选项:
    -h, --help              显示帮助信息
    -a, --all              清理所有未使用的资源（包括镜像）
    -v, --volumes          清理未使用的卷
    -n, --network          清理未使用的网络

示例:
    ${SCRIPT_NAME}              # 清理停止的容器和未使用的网络
    ${SCRIPT_NAME} -a          # 清理所有（包括镜像和卷）
    ${SCRIPT_NAME} -v          # 只清理未使用的卷

EOF
    exit 0
}

check_docker_access() {
    if ! docker info >/dev/null 2>&1; then
        log_error "无法访问 Docker，请检查 Docker 服务是否运行"
        exit 1
    fi
}

cleanup_stopped_containers() {
    log_info "清理已停止的容器..."

    local stopped_count=$(docker ps -a -f status=exited -q | wc -l)

    if [[ $stopped_count -gt 0 ]]; then
        docker container prune -f
        log_success "已清理 ${stopped_count} 个已停止的容器"
    else
        log_success "没有已停止的容器需要清理"
    fi
}

cleanup_dangling_images() {
    log_info "清理悬空镜像（无标签的镜像）..."

    local dangling_count=$(docker images -f dangling=true -q | wc -l)

    if [[ $dangling_count -gt 0 ]]; then
        docker image prune -f
        log_success "已清理 ${dangling_count} 个悬空镜像"
    else
        log_success "没有悬空镜像需要清理"
    fi
}

cleanup_unused_networks() {
    log_info "清理未使用的网络..."

    local network_count=$(docker network ls -f dangling=true -q | wc -l)

    if [[ $network_count -gt 0 ]]; then
        docker network prune -f
        log_success "已清理 ${network_count} 个未使用的网络"
    else
        log_success "没有未使用的网络需要清理"
    fi
}

cleanup_unused_volumes() {
    log_info "清理未使用的卷..."

    local volume_count=$(docker volume ls -f dangling=true -q | wc -l)

    if [[ $volume_count -gt 0 ]]; then
        docker volume prune -f
        log_success "已清理 ${volume_count} 个未使用的卷"
    else
        log_success "没有未使用的卷需要清理"
    fi
}

cleanup_unused_images() {
    log_info "清理未使用的镜像..."

    local image_count=$(docker images -q | wc -l)

    if [[ $image_count -gt 0 ]]; then
        docker image prune -a -f
        log_success "已清理未使用的镜像"
    else
        log_success "没有未使用的镜像需要清理"
    fi
}

cleanup_build_cache() {
    log_info "清理构建缓存..."

    local cache_size=$(docker system df --format '{{.Size}}' | head -1)

    if [[ -n "$cache_size" ]]; then
        docker builder prune -f
        log_success "已清理构建缓存"
    else
        log_success "没有构建缓存需要清理"
    fi
}

print_summary() {
    log_info "清理前磁盘使用情况:"
    docker system df

    echo
    log_success "Docker 资源清理完成！"
}

main() {
    local cleanup_all=false
    local cleanup_volumes=false
    local cleanup_network=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -a|--all)
                cleanup_all=true
                shift
                ;;
            -v|--volumes)
                cleanup_volumes=true
                shift
                ;;
            -n|--network)
                cleanup_network=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                usage
                ;;
        esac
    done

    check_docker_access

    log_info "开始清理 Docker 资源..."

    cleanup_stopped_containers
    cleanup_dangling_images

    if [[ "$cleanup_network" == true ]]; then
        cleanup_unused_networks
    fi

    if [[ "$cleanup_volumes" == true ]] || [[ "$cleanup_all" == true ]]; then
        cleanup_unused_volumes
    fi

    if [[ "$cleanup_all" == true ]]; then
        cleanup_unused_images
        cleanup_build_cache
    fi

    print_summary
}

main "$@"

#!/bin/sh
#
# OpenList FreeBSD 自动更新安装脚本 v2 (优化版)
#

set -euo pipefail  # 开启严格模式：未定义变量报错、命令失败终止、管道错误传递

APP_NAME="openlist"
INSTALL_DIR="/usr/home/s13xianan/openlist"
BACKUP_DIR="/usr/home/s13xianan/openlist_backup"
LOG_FILE="/usr/home/s13xianan/var/openlist_update.log"
GITHUB_REPO="OpenListTeam/OpenList"
TAR_NAME="openlist-freebsd-amd64.tar.gz"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${TAR_NAME}"
TMP_TAR="/usr/home/s13xianan/tmp/${TAR_NAME}"

# 确保必要目录存在
mkdir -p "$INSTALL_DIR" "$BACKUP_DIR" "$(dirname "$LOG_FILE")" "$(dirname "$TMP_TAR")"

# 日志函数：同时输出到控制台和日志文件
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 获取当前安装版本
get_current_version() {
    if [ -f "$INSTALL_DIR/version.txt" ]; then
        cat "$INSTALL_DIR/version.txt"
    else
        echo "unknown"
    fi
}

# 获取GitHub最新版本号
get_latest_version() {
    # 增加超时控制（10秒），避免无限等待
    latest_json=$(fetch -T 10 -qo - "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null)
    latest_ver=$(echo "$latest_json" | grep -E '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    if [ -z "$latest_ver" ]; then
        latest_ver="unknown"
    fi
    echo "$latest_ver"
}

# 回滚函数
rollback() {
    log "开始执行回滚..."
    if [ -d "$BACKUP_DIR/latest_backup" ]; then
        # 先删除现有目录（确保干净），再恢复备份
        rm -rf "$INSTALL_DIR" && cp -r "$BACKUP_DIR/latest_backup" "$INSTALL_DIR"
        log "✅ 回滚完成。"
    else
        log "❌ 未找到可用备份，无法回滚。"
    fi
    exit 0
}

# 处理回滚参数
if [ "$#" -ge 1 ] && [ "$1" = "--rollback" ]; then
    rollback
fi

# 主流程开始
log "===== OpenList 更新脚本启动 ====="
CURRENT_VER=$(get_current_version)
LATEST_VER=$(get_latest_version)

log "当前版本: $CURRENT_VER"
log "最新版本: $LATEST_VER"

# 版本检查逻辑
if [ "$LATEST_VER" = "unknown" ]; then
    log "⚠️ 无法获取 GitHub 版本号，可能是 API 被限制或网络问题。"
    exit 1
fi

if [ "$LATEST_VER" = "$CURRENT_VER" ]; then
    log "已是最新版本，无需更新。"
    exit 0
fi

# 下载最新版本
log "开始下载最新版本包..."
if ! fetch -T 30 -o "$TMP_TAR" "$DOWNLOAD_URL"; then  # 下载超时30秒
    log "❌ 下载失败，请检查网络或 GitHub 可用性。"
    exit 1
fi

# 校验下载文件（简单检查文件大小）
if [ ! -s "$TMP_TAR" ]; then
    log "❌ 下载的文件为空，可能下载不完整。"
    rm -f "$TMP_TAR"
    exit 1
fi

# 备份旧版本（安全备份逻辑）
log "备份旧版本..."
BACKUP_TMP="$BACKUP_DIR/latest_backup.tmp"
rm -rf "$BACKUP_TMP"  # 清理可能残留的临时备份
if [ -d "$INSTALL_DIR" ]; then
    if ! cp -r "$INSTALL_DIR" "$BACKUP_TMP"; then
        log "❌ 备份失败，终止更新。"
        rm -f "$TMP_TAR"
        exit 1
    fi
    # 备份成功后再替换正式备份
    rm -rf "$BACKUP_DIR/latest_backup"
    mv "$BACKUP_TMP" "$BACKUP_DIR/latest_backup"
fi

# 解压更新
log "开始更新文件..."
mkdir -p "$INSTALL_DIR"  # 确保目标目录存在
if ! tar -xzf "$TMP_TAR" -C "$INSTALL_DIR" --strip-components=1 2>>"$LOG_FILE"; then
    log "❌ 解压缩失败，启动自动回滚..."
    rollback
    exit 1
fi

# 写入版本号
echo "$LATEST_VER" > "$INSTALL_DIR/version.txt"

# 清理临时文件
rm -f "$TMP_TAR"

log "✅ 更新完成，当前版本：$LATEST_VER"
log "===== 更新结束 ====="
exit 0

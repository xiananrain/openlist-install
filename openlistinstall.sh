#!/bin/sh
#
# OpenList FreeBSD 自动更新安装脚本 v2
#

APP_NAME="openlist"
INSTALL_DIR="/usr/home/s13xianan/openlist"
BACKUP_DIR="/usr/home/s13xianan/openlist_backup"
LOG_FILE="/usr/home/s13xianan/var/openlist_update.log"
GITHUB_REPO="OpenListTeam/OpenList"
TAR_NAME="openlist-freebsd-amd64.tar.gz"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${TAR_NAME}"

mkdir -p "$INSTALL_DIR" "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_current_version() {
    if [ -f "$INSTALL_DIR/version.txt" ]; then
        cat "$INSTALL_DIR/version.txt"
    else
        echo "unknown"
    fi
}

# 解析 GitHub 最新版本号（tag_name）
get_latest_version() {
    latest_json=$(fetch -qo - "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null)
    latest_ver=$(echo "$latest_json" | grep -E '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    if [ -z "$latest_ver" ]; then
        latest_ver="unknown"
    fi
    echo "$latest_ver"
}

rollback() {
    log "开始执行回滚..."
    if [ -d "$BACKUP_DIR/latest_backup" ]; then
        rm -rf "$INSTALL_DIR"
        cp -r "$BACKUP_DIR/latest_backup" "$INSTALL_DIR"
        log "✅ 回滚完成。"
    else
        log "❌ 未找到可用备份，无法回滚。"
    fi
    exit 0
}

if [ "$1" = "--rollback" ]; then
    rollback
fi

log "===== OpenList 更新脚本启动 ====="
CURRENT_VER=$(get_current_version)
LATEST_VER=$(get_latest_version)

log "当前版本: $CURRENT_VER"
log "最新版本: $LATEST_VER"

if [ "$LATEST_VER" = "unknown" ]; then
    log "⚠️ 无法获取 GitHub 版本号，可能是 API 被限制。"
fi

if [ "$LATEST_VER" = "$CURRENT_VER" ] && [ "$LATEST_VER" != "unknown" ]; then
    log "已是最新版本，无需更新。"
    exit 0
fi

log "开始下载最新版本包..."
TMP_TAR="/usr/home/s13xianan/tmp/${TAR_NAME}"

if fetch -o "$TMP_TAR" "$DOWNLOAD_URL"; then
    log "下载完成：$TMP_TAR"
else
    log "❌ 下载失败，请检查网络或 GitHub 可用性。"
    exit 1
fi

log "备份旧版本..."
rm -rf "$BACKUP_DIR/latest_backup"
if [ -d "$INSTALL_DIR" ]; then
    cp -r "$INSTALL_DIR" "$BACKUP_DIR/latest_backup"
fi

log "开始更新文件..."
mkdir -p "$INSTALL_DIR"
tar -xzf "$TMP_TAR" -C "$INSTALL_DIR" --strip-components=1 2>>"$LOG_FILE"
echo "$LATEST_VER" > "$INSTALL_DIR/version.txt"

log "✅ 更新完成，当前版本：$LATEST_VER"
log "===== 更新结束 ====="
exit 0

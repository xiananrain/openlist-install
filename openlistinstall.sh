#!/bin/sh
#
# OpenList FreeBSD 自动更新安装脚本
# 功能：自动下载最新版本、检测版本号、备份旧版本、支持回滚 (--rollback)
#

APP_NAME="openlist"
INSTALL_DIR="/usr/local/openlist"
BACKUP_DIR="/usr/local/openlist_backup"
LOG_FILE="/var/log/openlist_update.log"
GITHUB_REPO="OpenListTeam/OpenList"
TAR_NAME="openlist-freebsd-amd64.tar.gz"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${TAR_NAME}"

# 创建目录
mkdir -p "$INSTALL_DIR" "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 获取当前版本号
get_current_version() {
    if [ -f "$INSTALL_DIR/version.txt" ]; then
        cat "$INSTALL_DIR/version.txt"
    else
        echo "unknown"
    fi
}

# 获取远程最新版本号
get_latest_version() {
    latest_ver=$(fetch -qo - "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
        | grep -m1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "$latest_ver"
}

# 回滚功能
rollback() {
    log "开始执行回滚..."
    if [ -d "$BACKUP_DIR/latest_backup" ]; then
        rm -rf "$INSTALL_DIR"
        cp -r "$BACKUP_DIR/latest_backup" "$INSTALL_DIR"
        log "✅ 回滚完成。"
    else
        log "❌ 未找到可用的备份，无法回滚。"
    fi
    exit 0
}

# 检测参数
if [ "$1" = "--rollback" ]; then
    rollback
fi

# 主流程
log "===== OpenList 更新脚本启动 ====="
CURRENT_VER=$(get_current_version)
LATEST_VER=$(get_latest_version)

log "当前版本: $CURRENT_VER"
log "最新版本: $LATEST_VER"

if [ "$LATEST_VER" = "$CURRENT_VER" ]; then
    log "已是最新版本，无需更新。"
    exit 0
fi

log "开始下载最新版本包..."
TMP_TAR="/tmp/${TAR_NAME}"

# 使用 fetch 下载并跟随重定向
if fetch -o "$TMP_TAR" "$DOWNLOAD_URL"; then
    log "下载完成：$TMP_TAR"
else
    log "❌ 下载失败，请检查网络或 GitHub 可用性。"
    exit 1
fi

# 备份旧版本
log "备份旧版本..."
rm -rf "$BACKUP_DIR/latest_backup"
cp -r "$INSTALL_DIR" "$BACKUP_DIR/latest_backup"

# 安装更新
log "开始更新文件..."
tar -xzf "$TMP_TAR" -C "$INSTALL_DIR" --strip-components=1
echo "$LATEST_VER" > "$INSTALL_DIR/version.txt"

log "✅ 更新完成，当前版本：$LATEST_VER"
log "===== 更新结束 ====="
exit 0

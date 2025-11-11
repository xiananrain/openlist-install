#!/bin/sh
# ============================================
# OpenList FreeBSD 自动更新脚本（含远程下载）
# 作者: ChatGPT (GPT-5)
# 来源: https://github.com/OpenListTeam/OpenList/releases/latest
# 功能:
#   - 自动检测新版本
#   - 从 GitHub 下载最新 .tar.gz
#   - 自动备份 + 日志记录
#   - 保留数据与配置
#   - 支持 --rollback 参数回滚
# ============================================

# === 基本配置 ===
APP_DIR="/usr/local/openlist"
TMP_DIR="/tmp/openlist_update"
BACKUP_DIR="/root/openlist_backups"
LOG_FILE="/var/log/openlist_update.log"
RELEASE_API="https://api.github.com/repos/OpenListTeam/OpenList/releases/latest"

# === 函数：输出日志 ===
log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

# === 函数：执行回滚 ===
rollback() {
    log "🌀 检测到 --rollback 参数，开始执行回滚..."

    latest_backup=$(ls -t "$BACKUP_DIR"/openlist-backup-*.tar.gz 2>/dev/null | head -n 1)
    if [ -z "$latest_backup" ]; then
        log "❌ 未找到任何备份文件，无法回滚。"
        exit 1
    fi

    log "📦 正在恢复备份：$latest_backup"
    tar -xzf "$latest_backup" -C /

    if [ $? -eq 0 ]; then
        log "✅ 回滚完成。"
    else
        log "❌ 回滚失败。"
        exit 1
    fi
    exit 0
}

# === 检测参数 ===
if [ "$1" = "--rollback" ]; then
    rollback
fi

# 初始化日志
mkdir -p "$(dirname "$LOG_FILE")"
log "========== OpenList 自动更新启动 =========="

# 检查依赖
for cmd in curl jq tar; do
    if ! command -v $cmd >/dev/null 2>&1; then
        log "❌ 缺少依赖：$cmd，请执行 pkg install $cmd 安装。"
        exit 1
    fi
done

# === 检测当前版本 ===
OLD_VER="unknown"
if [ -f "$APP_DIR/VERSION" ]; then
    OLD_VER=$(cat "$APP_DIR/VERSION")
fi
log "当前版本号：$OLD_VER"

# === 获取 GitHub 最新 release 信息 ===
log "🌐 正在获取最新版本信息..."
JSON=$(curl -s "$RELEASE_API")
PKG_URL=$(echo "$JSON" | jq -r '.assets[] | select(.name | test("freebsd-amd64.*\\.tar\\.gz")) | .browser_download_url')
PKG_VER=$(echo "$JSON" | jq -r '.tag_name')

if [ -z "$PKG_URL" ] || [ "$PKG_URL" = "null" ]; then
    log "❌ 未找到 FreeBSD 版本下载链接。"
    exit 1
fi

log "最新版本：$PKG_VER"
log "下载链接：$PKG_URL"

if [ "$OLD_VER" = "$PKG_VER" ]; then
    log "⚠️ 当前版本已是最新 ($PKG_VER)，无需更新。"
    exit 0
fi

# === 下载更新包 ===
mkdir -p "$TMP_DIR"
UPDATE_PKG="$TMP_DIR/openlist-freebsd-amd64.tar.gz"
log "⬇️ 正在下载新版本包..."
curl -L -o "$UPDATE_PKG" "$PKG_URL"

if [ $? -ne 0 ] || [ ! -s "$UPDATE_PKG" ]; then
    log "❌ 下载失败，请检查网络或 GitHub 访问。"
    exit 1
fi
log "✅ 下载完成。"

# === 备份旧版本 ===
mkdir -p "$BACKUP_DIR"
DATE=$(date +%F-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/openlist-backup-$DATE.tar.gz"
log "📦 正在备份旧版本到：$BACKUP_FILE"
tar -czf "$BACKUP_FILE" "$APP_DIR" >>"$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    log "❌ 备份失败。"
    exit 1
fi

# === 解压更新包 ===
log "📂 正在解压更新包..."
tar -xzf "$UPDATE_PKG" -C "$TMP_DIR"
if [ $? -ne 0 ]; then
    log "❌ 解压失败。"
    exit 1
fi

# === 更新程序文件 ===
log "🔄 开始更新程序文件..."
for dir in bin lib plugins; do
    if [ -d "$TMP_DIR/$dir" ]; then
        log "→ 更新目录：$dir"
        cp -r "$TMP_DIR/$dir/"* "$APP_DIR/$dir/" 2>/dev/null
    fi
done

# === 更新 VERSION 文件 ===
echo "$PKG_VER" > "$APP_DIR/VERSION"

# === 清理 ===
log "🧹 清理临时文件..."
rm -rf "$TMP_DIR"

# === 尝试重启服务 ===
if service -e | grep -q "openlist"; then
    log "🚀 正在重启 openlist 服务..."
    service openlist restart
else
    log "⚠️ 未检测到 openlist 服务，请手动重启。"
fi

log "✅ 更新完成！"
log "新版本：$PKG_VER"
log "备份位置：$BACKUP_FILE"
log "日志：$LOG_FILE"
log "======================================="
exit 0

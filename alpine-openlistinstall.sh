#!/bin/sh

set -euo pipefail

DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-linux-musl-amd64.tar.gz"
TARGET_DIR="/opt/openlist"
FILE_NAME="openlist-linux-musl-amd64.tar.gz"

check_dependencies() {
  # 增加了 openrc 依赖检查（绝大多数 Alpine 默认自带）
  local dependencies="curl tar openrc"
  for tool in $dependencies; do
    if ! command -v "$tool" > /dev/null 2>&1; then
      echo "❌ 错误：未找到必需工具 $tool，请先通过 apk add $tool 安装"
      exit 1
    fi
  done
  echo "✅ 依赖工具检查完成"
}

create_target_dir() {
  if [ ! -d "$TARGET_DIR" ]; then
    echo "📂 创建目录 $TARGET_DIR..."
    mkdir -p "$TARGET_DIR" || { echo "❌ 目录创建失败"; exit 1; }
  else
    echo "📂 目标目录 $TARGET_DIR 已存在"
  fi
  cd "$TARGET_DIR" || { echo "❌ 无法进入目录 $TARGET_DIR"; exit 1; }
}

download_file() {
  echo -e "\n🚀 开始下载 OpenList"
  if [ -f "$FILE_NAME" ]; then
    echo "⚠️ 已存在同名安装包，是否覆盖？(y/n)"
    read -r confirm
    if [ "$confirm" != "y" ]; then
      echo "ℹ️ 取消覆盖"
      return
    fi
  fi
  curl -L -o "$FILE_NAME" -# "$DOWNLOAD_URL" || { echo -e "\n❌ 下载失败"; exit 1; }
  echo -e "\n✅ 下载完成"
}

extract_file() {
  echo -e "\n📦 开始解压..."
  if ! tar -zxvf "$FILE_NAME" > /dev/null 2>&1; then
    echo "❌ 解压失败"
    exit 1
  fi
  
  if [ ! -f "./openlist" ]; then
    echo "❌ 错误：解压后未找到可执行文件 ./openlist"
    exit 1
  fi
  chmod +x ./openlist
  echo "✅ 解压完成"
}

configure_daemon() {
  echo -e "\n⚙️ 配置 OpenRC 守护进程..."
  
  # 写入 OpenRC 服务脚本
  cat > /etc/init.d/openlist << 'EOF'
#!/sbin/openrc-run

name="openlist"
description="OpenList Daemon Service"
command="/opt/openlist/openlist"
command_args="server"
command_background="yes"
directory="/opt/openlist"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/openlist.log"
error_log="/var/log/openlist.err"

depend() {
    need net
    use dns logger
    after firewall
}
EOF

  # 赋予执行权限
  chmod +x /etc/init.d/openlist
  
  # 添加到开机自启
  rc-update add openlist default > /dev/null 2>&1
  echo "✅ 守护进程配置完成，已设置开机自启"
}

restart_service() {
  echo -e "\n🔄 启动服务..."
  
  # 通过 OpenRC 启动/重启服务
  if rc-service openlist restart || rc-service openlist start; then
    echo -e "\n🎉 操作成功！OpenList 已作为守护进程在后台运行。"
    echo -e "📄 运行日志: \033[36m/var/log/openlist.log\033[0m"
    echo -e "📄 错误日志: \033[31m/var/log/openlist.err\033[0m"
  else
    echo -e "\n❌ 启动失败，请检查日志 /var/log/openlist.err"
    exit 1
  fi
}

clear
check_dependencies
create_target_dir
download_file
extract_file
configure_daemon
restart_service

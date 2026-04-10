#!/bin/sh

set -euo pipefail

DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-linux-musl-amd64.tar.gz"
TARGET_DIR="/opt/openlist"
FILE_NAME="openlist-linux-musl-amd64.tar.gz"

check_dependencies() {
  local dependencies="curl tar"
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
  # 进入目标目录后，后续的下载和解压都在此目录下进行
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
  # 移除了 EXTRACTED_DIR 的获取逻辑，因为文件直接解压在当前目录
  echo "✅ 解压完成"
}

restart_service() {
  echo -e "\n🔄 启动服务..."
  # 移除了 cd 命令，当前已经在 $TARGET_DIR 中
  
  if [ ! -f "./openlist" ]; then
    echo "❌ 错误：未找到可执行文件 ./openlist"
    exit 1
  fi
  
  chmod +x ./openlist
  
  if ./openlist restart; then
    echo -e "\n🎉 操作成功"
  else
    echo -e "\n❌ 重启失败"
    exit 1
  fi
}

clear
check_dependencies
create_target_dir
download_file
extract_file
restart_service

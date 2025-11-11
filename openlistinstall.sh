#!/bin/bash
set -euo pipefail

# ================= 已预设配置（无需修改）=================
DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-freebsd-amd64.tar.gz"
TARGET_DIR="$HOME/openlist"  # 下载和解压目录
FILE_NAME="openlist-freebsd-amd64.tar.gz"  # 下载文件名

# ================= 核心功能函数 =================
# 1. 检查依赖工具
check_dependencies() {
  local dependencies=("curl" "tar")
  for tool in "${dependencies[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      echo "❌ 错误：未找到必需工具 $tool，请先通过 pkg install $tool 安装"
      exit 1
    fi
  done
  echo "✅ 依赖工具检查完成"
}

# 2. 创建目标目录
create_target_dir() {
  if [ ! -d "$TARGET_DIR" ]; then
    echo "📂 创建目录 $TARGET_DIR..."
    mkdir -p "$TARGET_DIR" || { echo "❌ 目录创建失败"; exit 1; }
  else
    echo "📂 目标目录 $TARGET_DIR 已存在"
  fi
  cd "$TARGET_DIR" || { echo "❌ 无法进入目录 $TARGET_DIR"; exit 1; }
}

# 3. 下载文件
download_file() {
  echo -e "\n🚀 开始下载 OpenList（FreeBSD-amd64 版本）"
  if [ -f "$FILE_NAME" ]; then
    echo "⚠️  已存在同名安装包，是否覆盖？(y/n)"
    read -r confirm
    if [ "$confirm" != "y" ]; then
      echo "ℹ️  取消覆盖，使用现有安装包"
      return
    fi
  fi
  # 断点续传 + 进度条下载
  curl -L -o "$FILE_NAME" -# "$DOWNLOAD_URL" || { echo -e "\n❌ 下载失败，请检查网络或链接有效性"; exit 1; }
  echo -e "\n✅ 下载完成：$TARGET_DIR/$FILE_NAME"
}

# 4. 解压文件
extract_file() {
  echo -e "\n📦 开始解压安装包..."
  if ! tar -zxvf "$FILE_NAME" &> /dev/null; then
    echo "❌ 解压失败！请确认文件为合法 tar.gz 格式"
    exit 1
  fi
  # 自动获取解压后的核心目录（适配官方包结构）
  EXTRACTED_DIR=$(tar -ztf "$FILE_NAME" | head -1 | cut -d '/' -f1)
  echo "✅ 解压完成，文件路径：$TARGET_DIR/$EXTRACTED_DIR"
}

# 5. 执行重启命令
restart_service() {
  echo -e "\n🔄 启动并重启 OpenList 服务..."
  cd "$HOME/$EXTRACTED_DIR" || { echo "❌ 无法进入解压目录"; exit 1; }
  if [ ! -f "./openlist" ]; then
    echo "❌ 错误：未找到 openlist 可执行文件"
    exit 1
  fi
  # 直接执行重启命令（不添加执行权限）
  if ./openlist restart; then
    echo -e "\n🎉 操作成功！OpenList 已重启完成"
  else
    echo -e "\n❌ OpenList 重启失败，可能是文件缺少执行权限，可手动运行 chmod +x ./openlist 后重试"
    exit 1
  fi
}

# ================= 脚本执行流程 =================
clear
echo "======================================"
echo "   OpenList (FreeBSD-amd64) 自动部署脚本   "
echo "======================================"

check_dependencies
create_target_dir
download_file
extract_file
restart_service

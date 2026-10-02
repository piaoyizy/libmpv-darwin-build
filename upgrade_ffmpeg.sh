#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FFMPEG_VERSION="${FFMPEG_VERSION:-9.0.2}"
FFMPEG_URL="${FFMPEG_URL:-https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz}"
LOCK_FILE="$SCRIPT_DIR/packages.lock.nix"
BACKUP_FILE="$LOCK_FILE.bak"
BUILD=false
TARGET="${TARGET:-}"
BUILD_VERSION="${VERSION:-v0.0.1}"

usage() {
  printf '%s\n' \
    "用法：$0 [--build] [--target TARGET] [--version VERSION]" \
    "" \
    "环境变量：" \
    "  FFMPEG_VERSION  FFmpeg 版本，默认 9.0.2" \
    "  FFMPEG_URL      FFmpeg 源码地址，默认使用官方 release 地址" \
    "  TARGET          --build 时传给 make 的目标" \
    "  VERSION         --build 时传给 make 的产物版本" \
    "" \
    "默认只更新 packages.lock.nix；传入 --build 后才会编译。"
}

while (($# > 0)); do
  case "$1" in
    --build)
      BUILD=true
      shift
      ;;
    --target)
      (($# >= 2)) || { echo "错误：--target 缺少参数。" >&2; exit 2; }
      TARGET="$2"
      shift 2
      ;;
    --version)
      (($# >= 2)) || { echo "错误：--version 缺少参数。" >&2; exit 2; }
      BUILD_VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "错误：未知参数 '$1'。" >&2
      usage >&2
      exit 2
      ;;
  esac
done

command -v nix >/dev/null 2>&1 || {
  echo "错误：未找到 nix 命令。" >&2
  exit 1
}
command -v perl >/dev/null 2>&1 || {
  echo "错误：未找到 perl 命令。" >&2
  exit 1
}
[[ -f "$LOCK_FILE" ]] || {
  echo "错误：未找到 $LOCK_FILE。" >&2
  exit 1
}

git diff --quiet -- "$LOCK_FILE" || {
  echo "错误：$LOCK_FILE 已存在未提交修改，已停止以避免覆盖。" >&2
  exit 1
}

old_block="$(perl -0ne 'if (/  ffmpeg = \{.*?\n  \};/s) { print $&; exit }' "$LOCK_FILE")"
[[ -n "$old_block" ]] || {
  echo "错误：未找到 FFmpeg 锁定块。" >&2
  exit 1
}

old_version="$(printf '%s\n' "$old_block" | sed -n 's/^    version = "\([^"]*\)";$/\1/p')"
old_url="$(printf '%s\n' "$old_block" | sed -n 's/^    url = "\([^"]*\)";$/\1/p')"
old_sha256="$(printf '%s\n' "$old_block" | sed -n 's/^    sha256 = "\([^"]*\)";$/\1/p')"

[[ -n "$old_version" && -n "$old_url" && -n "$old_sha256" ]] || {
  echo "错误：FFmpeg 锁定块格式不符合预期。" >&2
  exit 1
}

if [[ "$old_version" == "$FFMPEG_VERSION" && "$old_url" == "$FFMPEG_URL" ]]; then
  echo "FFmpeg 版本和 URL 已经是 $FFMPEG_VERSION，仍会重新计算 SHA-256。"
fi

echo "获取 FFmpeg $FFMPEG_VERSION 源码哈希：$FFMPEG_URL"
new_sha256="$(nix-prefetch-url --type sha256 "$FFMPEG_URL" | tail -n 1 | tr -d '\r\n')"
[[ -n "$new_sha256" ]] || {
  echo "错误：未获取到源码哈希。" >&2
  exit 1
}

cp -p "$LOCK_FILE" "$BACKUP_FILE"

new_block="  ffmpeg = {
    version = \"$FFMPEG_VERSION\";
    url = \"$FFMPEG_URL\";
    sha256 = \"$new_sha256\";
  };"

NEW_BLOCK="$new_block" perl -0pi -e 's/  ffmpeg = \{.*?\n  \};/$ENV{NEW_BLOCK}/s' "$LOCK_FILE"

updated_block="$(perl -0ne 'if (/  ffmpeg = \{.*?\n  \};/s) { print $&; exit }' "$LOCK_FILE")"
expected_block="$new_block"
if [[ "$updated_block" != "$expected_block" ]]; then
  cp -p "$BACKUP_FILE" "$LOCK_FILE"
  echo "错误：更新后的 FFmpeg 锁定块校验失败，已恢复原文件。" >&2
  exit 1
fi

echo "FFmpeg 锁定信息已更新："
printf '  版本：%s -> %s\n' "$old_version" "$FFMPEG_VERSION"
printf '  地址：%s\n' "$FFMPEG_URL"
printf '  哈希：%s\n' "$new_sha256"
printf '  备份：%s\n' "$BACKUP_FILE"

if [[ "$BUILD" == true ]]; then
  build_args=(nix develop -c make VERSION="$BUILD_VERSION")
  if [[ -n "$TARGET" ]]; then
    build_args+=(TARGET="$TARGET")
  fi
  echo "开始编译 FFmpeg $FFMPEG_VERSION 及相关 libmpv 产物。"
  "${build_args[@]}"
else
  echo "未执行编译。需要编译时执行：$0 --build"
fi

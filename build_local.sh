#!/usr/bin/env bash
# 本地编译 libmpv 动态 Mpv.xcframework（macOS + iOS 真机）。
#
# 用法：
#   bash build_local.sh                  # 同时构建 macos 与 ios
#   bash build_local.sh macos            # 只构建 macOS
#   bash build_local.sh ios              # 只构建 iOS
#   bash build_local.sh both             # 与默认一致，同时构建两者
#
# 可选环境变量：
#   XCODE_PATH  覆盖 Xcode 路径（默认 /Applications/Xcode.app）
#   VERSION     覆盖版本号（默认读取 .nix/config/version.txt）
#   OUT_DIR     产物输出目录（默认 ./build/artifacts）
#
# 产物命名遵循 mk-out-archive 约定：
#   libmpv-xcframeworks_<version>_<os>-universal-video-default.tar.gz

set -euo pipefail

# 进入工程根目录（脚本自身所在目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ------------- 前置校验 -------------
command -v nix >/dev/null 2>&1 || {
  echo "错误：未找到 nix 命令。请先安装 Determinate Nix，并确保 nix 在 PATH 中。" >&2
  exit 1
}

XCODE_PATH="${XCODE_PATH:-/Applications/Xcode.app}"
if [[ ! -d "$XCODE_PATH" ]]; then
  echo "错误：Xcode 路径不存在：$XCODE_PATH（可用 XCODE_PATH 环境变量覆盖）" >&2
  exit 1
fi

OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/build/artifacts}"
mkdir -p "$OUT_DIR"

# ------------- 选择目标 -------------
TARGET_ARG="${1:-both}"
case "$TARGET_ARG" in
  macos) TARGETS=(macos) ;;
  ios)   TARGETS=(ios) ;;
  both)  TARGETS=(macos ios) ;;
  *)
    echo "错误：未知目标 '$TARGET_ARG'（可用 macos / ios / both）" >&2
    exit 1
    ;;
esac

# ------------- 版本 ------------
trap 'git checkout -- .nix/config/xcode.path .nix/config/version.txt 2>/dev/null || true' EXIT

if [[ -n "${XCODE_PATH:-}" ]]; then
  printf '%s\n' "$XCODE_PATH" > .nix/config/xcode.path
fi
if [[ -n "${VERSION:-}" ]]; then
  printf '%s\n' "$VERSION" > .nix/config/version.txt
fi
raw_version="$(cat .nix/config/version.txt 2>/dev/null || true)"
VERSION_VAL="${VERSION:-$raw_version}"
VERSION_VAL="$(printf '%s' "$VERSION_VAL" | tr -d '\r\n')"

echo "==== 开始本地编译 libmpv（版本：${VERSION_VAL}）===="
echo "Xcode：$XCODE_PATH"
echo "目标：${TARGETS[*]}"
echo "输出目录：$OUT_DIR"

# ------------- 构建 -------------
for os in "${TARGETS[@]}"; do
  target="mk-out-archive-xcframeworks-${os}-universal-video-default"
  echo "---- 构建 $target ----"
  nix build -L \
    --option sandbox true \
    --option sandbox-fallback false \
    --option extra-sandbox-paths "$XCODE_PATH" \
    ".#$target"

  result_marker="result"
  # nix build 默认生成 result 符号链接
  if [[ -L "$result_marker" ]]; then
    result_dir=$(readlink -f "$result_marker")
  else
    result_dir=$(nix path-info ".#$target")
    result_dir=$(realpath "$result_dir" 2>/dev/null || echo "$result_dir")
  fi
  echo "构建完成：$result_dir"

  found=$(find "$result_dir" -maxdepth 1 -type f -name '*.tar.gz' -print -quit)
  if [[ -z "$found" ]]; then
    echo "警告：$target 产物中未找到 tar.gz，跳过复制。" >&2
  else
    cp -f "$result_dir"/*.tar.gz "$OUT_DIR/"
    echo "已复制产物到 $OUT_DIR"
  fi
done

# 清理符号链接，避免后续 git 误判
[[ -e result ]] && rm -f result

echo "==== 校验产物 ===="
for os in "${TARGETS[@]}"; do
  shopt -s nullglob
  matches=("$OUT_DIR"/libmpv-xcframeworks_*_${os}-universal-video-default.tar.gz)
  shopt -u nullglob
  if (( ${#matches[@]} == 1 )) && [[ -f "${matches[0]}" ]]; then
    echo "  [OK] ${matches[0]##*/}"
  else
    echo "  [缺失] ${os} 的 tar.gz 未生成（期望一份）：$OUT_DIR" >&2
  fi
done

echo "==== 本地编译脚本执行结束 ===="
echo "产物目录：$OUT_DIR"

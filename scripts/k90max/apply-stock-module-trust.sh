#!/usr/bin/env bash
# 将原厂内核公钥加入 GKI 受信密钥环，保留 CONFIG_MODULE_SIG_PROTECT。
# 用法：KERNEL_ROOT=/path/to/android16-6.12 GITHUB_WORKSPACE=/path/to/repo \
#       bash scripts/k90max/apply-stock-module-trust.sh <stock_signing_key.pem>
set -euo pipefail

KEY="${1:?missing stock signing key path}"
KERNEL_ROOT="${KERNEL_ROOT:?missing KERNEL_ROOT}"
GITHUB_WORKSPACE="${GITHUB_WORKSPACE:?missing GITHUB_WORKSPACE}"
PATCH_DIR="$GITHUB_WORKSPACE/patches/k90max-wifi-bt"
case "$KEY" in
  /*) ;;
  *) KEY="$GITHUB_WORKSPACE/$KEY" ;;
esac

test -s "$KEY"
test -f "$KERNEL_ROOT/common/BUILD.bazel"
test -f "$KERNEL_ROOT/build/kernel/kleaf/common_kernels.bzl"

mkdir -p "$KERNEL_ROOT/common/certs"
cp -f "$KEY" "$KERNEL_ROOT/common/certs/stock_signing_key.pem"

if grep -q 'system_trusted_key = "//common:certs/stock_signing_key.pem"' \
  "$KERNEL_ROOT/common/BUILD.bazel" &&
  grep -q 'system_trusted_key = system_trusted_key' \
  "$KERNEL_ROOT/build/kernel/kleaf/common_kernels.bzl"; then
  echo "原厂模块信任补丁已存在，跳过"
  exit 0
fi

patch --batch -p1 -d "$KERNEL_ROOT" \
  < "$PATCH_DIR/0001-gki-system-trusted-key.patch"

grep -q 'system_trusted_key = "//common:certs/stock_signing_key.pem"' \
  "$KERNEL_ROOT/common/BUILD.bazel"
grep -q 'system_trusted_key = system_trusted_key' \
  "$KERNEL_ROOT/build/kernel/kleaf/common_kernels.bzl"
echo "原厂模块信任公钥已写入 GKI 构建：$KEY"

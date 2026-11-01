# K90 Max Wi-Fi / 蓝牙模块信任修复

## 背景

仅替换 GKI boot 内核时，原厂 `vendor_dlkm` / `system_dlkm` 中的模块仍由原厂内核密钥签名。若新内核没有信任该公钥，`rfkill` 会因为 `CONFIG_MODULE_SIG_PROTECT` 被拒绝导出受保护符号，随后 `cfg80211` 和 Wi-Fi/BT 主驱动无法加载。

日志特征：

```text
rfkill: exports protected symbol rfkill_alloc
insmod: Permission denied
cfg80211: Unknown symbol rfkill_alloc (err -2)
```

## 修复内容

- 把原厂 boot 内核公钥加入 GKI 的 `CONFIG_SYSTEM_TRUSTED_KEYS`。
- 保留 `CONFIG_MODULE_SIG_PROTECT=y`，不关闭模块签名保护，不修改 Wi-Fi/BT 驱动源码。
- `stock_signing_key.pem` 是公开证书，不是私钥；更换 ROM 或 vendor 分区后需要从新 boot 镜像重新提取。

## 自动应用

`config/config` 中的配置：

```text
stock_signing_key=patches/k90max-wifi-bt/stock_signing_key.pem
```

`build.yml` 在 6.12 内核执行 `repo sync` 后会调用：

```bash
scripts/k90max/apply-stock-module-trust.sh "$KEY"
```

本地构建也可以手动执行：

```bash
KERNEL_ROOT=/path/to/android16-6.12 \
GITHUB_WORKSPACE=/path/to/AnyKernel3 \
bash scripts/k90max/apply-stock-module-trust.sh \
  patches/k90max-wifi-bt/stock_signing_key.pem
```

## 验证

```bash
grep -n 'system_trusted_key' "$KERNEL_ROOT/common/BUILD.bazel"
grep -n 'system_trusted_key' "$KERNEL_ROOT/build/kernel/kleaf/common_kernels.bzl"
unzip -p k90max-*.zip Image | strings | grep 'Linux version'
```

刷入后只读检查：

```bash
adb shell 'cat /proc/modules | grep -E "rfkill|cfg80211|wlan|bt"'
adb shell 'dmesg | grep -iE "rfkill|protected symbol|Unknown symbol"'
```

预期 `rfkill`、`cfg80211`、`wlan_drv_gen4m_6993_6653`、`btmtk_uart_unify` 均已加载。

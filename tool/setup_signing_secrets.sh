#!/usr/bin/env bash
# 一次性配置 Android 正式签名密钥（只需跑一次，之后所有发版都自动用它）
#
# 为什么需要这个：
#   Android 不允许换签名覆盖安装。此前 release 直接复用 debug 签名，
#   而 debug keystore 每台机器随机生成、CI runner 更是一次性的，
#   导致 v1.0.5 / v1.0.6 / v1.0.7 三个包三把不同的钥匙，
#   用户点「更新」装到最后一步被系统拦下：「安装包的开发者签名异常」。
#
# 这个脚本做什么：
#   1. 生成一把固定的正式签名密钥（RSA 4096，有效期 10000 天）
#   2. 上传成 4 个 GitHub Secrets，供发版流水线使用
#   3. 提示你备份，确认后把本地文件彻底销毁
#
# 密钥只存在于 GitHub Secrets 与你自己的备份里，不留在任何开发机上。
# 本地构建取不到密钥会退回 debug 签名，并自动换成 .dev 包名，
# 与正式版并排安装、互不冲突（见 android/app/build.gradle.kts）。
#
# ⚠️ 这把密钥一旦丢失，就永远无法再给已安装的用户推送更新，只能让所有人卸载重装。
#    GitHub Secrets 是只写的、读不回来，所以第 3 步的备份不能跳过。
#
# 用法：bash tool/setup_signing_secrets.sh

set -euo pipefail

REPO="Kline-x/novel-reader-flutter"
ALIAS="novel-reader"
WORKDIR="$(mktemp -d)"
JKS="$WORKDIR/novel-reader-release.jks"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

command -v gh >/dev/null || { echo "✕ 需要 gh CLI"; exit 1; }
command -v keytool >/dev/null || { echo "✕ 需要 keytool（JDK 自带，把 <JDK>/bin 加进 PATH）"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "✕ gh 未登录，先跑 gh auth login"; exit 1; }

if gh secret list --repo "$REPO" 2>/dev/null | grep -q ANDROID_KEYSTORE_BASE64; then
  echo "✕ $REPO 已配置 ANDROID_KEYSTORE_BASE64。"
  echo "  覆盖它会让已发布版本的用户再也收不到更新（新旧签名不一致），"
  echo "  确实要换请先手动删除该 Secret 并准备好让所有用户卸载重装。"
  exit 1
fi

PW="$(head -c 24 /dev/urandom | base64 | tr -d '+/=' | head -c 32)"

echo "→ 生成签名密钥..."
keytool -genkeypair -v \
  -keystore "$JKS" -storetype JKS \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias "$ALIAS" \
  -dname "CN=Novel Reader, OU=Kline-x, O=Kline-x, C=CN" \
  -storepass "$PW" -keypass "$PW" >/dev/null

echo "→ 上传 GitHub Secrets 到 $REPO ..."
base64 -w0 "$JKS" | gh secret set ANDROID_KEYSTORE_BASE64   --repo "$REPO"
printf '%s' "$PW"  | gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$REPO"
printf '%s' "$PW"  | gh secret set ANDROID_KEY_PASSWORD      --repo "$REPO"
printf '%s' "$ALIAS" | gh secret set ANDROID_KEY_ALIAS       --repo "$REPO"
gh secret list --repo "$REPO"

BACKUP="$HOME/novel-reader-keystore-backup"
mkdir -p "$BACKUP"
cp "$JKS" "$BACKUP/"
printf 'keystore=novel-reader-release.jks\nalias=%s\npassword=%s\n' "$ALIAS" "$PW" > "$BACKUP/credentials.txt"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Secrets 已配好。现在把备份存进密码管理器，然后回来确认。

  备份目录：$BACKUP
    · novel-reader-release.jks   密钥本体
    · credentials.txt            别名与口令

GitHub Secrets 读不回来。这份备份丢了 = 永远无法再推更新。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

read -r -p "已妥善备份、可以销毁本地副本了吗？(输入 yes 确认) " ANSWER
if [ "$ANSWER" = "yes" ]; then
  rm -rf "$BACKUP"
  echo "✓ 本地副本已销毁，密钥现在只存在于 GitHub Secrets 和你的备份里。"
else
  echo "⚠ 已保留 $BACKUP，请尽快备份后自行删除。"
fi

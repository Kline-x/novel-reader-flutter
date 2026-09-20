#!/usr/bin/env bash
# 一次性配置 Android 正式签名密钥（只需跑一次，之后所有发版都自动用它）
#
# 为什么需要这个：
#   Android 不允许换签名覆盖安装。此前 release 直接复用 debug 签名，
#   而 debug keystore 每台机器随机生成、CI runner 更是一次性的，
#   导致已发布的 v1.0.1 / v1.0.4 / v1.0.5 / v1.0.6 / v1.0.7 五个包五把不同的钥匙，
#   用户点「更新」装到最后一步被系统拦下：「安装包的开发者签名异常」。
#
# 这个脚本做什么：
#   1. 生成一把固定的正式签名密钥（RSA 4096，有效期 10000 天）
#   2. 上传成 4 个 GitHub Secrets，供发版流水线使用
#   3. 备份到一个**私有**仓库（读得回来，Secrets 读不回来）
#   4. 确认备份可取回后，销毁本地副本
#
# 密钥不留在任何开发机上。本地构建取不到密钥会退回 debug 签名，
# 并自动换成 .dev 包名，与正式版并排安装、互不冲突
# （见 android/app/build.gradle.kts）。
#
# ⚠️ 这把密钥一旦丢失，就永远无法再给已安装的用户推送更新，只能让所有人卸载重装。
#
# 用法：bash tool/setup_signing_secrets.sh

set -euo pipefail

ALIAS="novel-reader"
WORKDIR="$(mktemp -d)"
JKS="$WORKDIR/novel-reader-release.jks"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

command -v gh      >/dev/null || { echo "✕ 需要 gh CLI"; exit 1; }
command -v keytool >/dev/null || { echo "✕ 需要 keytool（JDK 自带，把 <JDK>/bin 加进 PATH）"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "✕ gh 未登录，先跑 gh auth login"; exit 1; }

# 仓库名从当前 git remote 推导，fork 的人直接跑这个脚本不会误操作上游仓库。
# 放在依赖检查之后，否则 gh 不存在时会先抛一个看不懂的错。
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
BACKUP_REPO="${REPO%%/*}/novel-reader-signing"
echo "→ 目标仓库 $REPO，备份仓库 $BACKUP_REPO"

if gh secret list --repo "$REPO" 2>/dev/null | grep -q ANDROID_KEYSTORE_BASE64; then
  echo "✕ $REPO 已配置 ANDROID_KEYSTORE_BASE64。"
  echo "  覆盖它会让已发布版本的用户再也收不到更新（新旧签名不一致），"
  echo "  确实要换请先手动删除该 Secret，并准备好让所有用户卸载重装。"
  exit 1
fi

# ---------- 1. 生成密钥 ----------
PW="$(head -c 24 /dev/urandom | base64 | tr -d '+/=' | head -c 32)"

echo "→ 生成签名密钥..."
keytool -genkeypair -v \
  -keystore "$JKS" -storetype JKS \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias "$ALIAS" \
  -dname "CN=Novel Reader, OU=Kline-x, O=Kline-x, C=CN" \
  -storepass "$PW" -keypass "$PW" >/dev/null

# ---------- 2. 上传 Secrets ----------
echo "→ 上传 GitHub Secrets 到 $REPO ..."
base64 -w0 "$JKS"    | gh secret set ANDROID_KEYSTORE_BASE64   --repo "$REPO"
printf '%s' "$PW"    | gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$REPO"
printf '%s' "$PW"    | gh secret set ANDROID_KEY_PASSWORD      --repo "$REPO"
printf '%s' "$ALIAS" | gh secret set ANDROID_KEY_ALIAS         --repo "$REPO"
gh secret list --repo "$REPO"

# ---------- 3. 备份到私有仓库 ----------
# Secrets 只能写、读不回来。必须另有一份能取回的副本，
# 否则 Secrets 被误删 / 仓库重建时，这把密钥就永久失去了。
echo "→ 备份到私有仓库 $BACKUP_REPO ..."
if ! gh repo view "$BACKUP_REPO" >/dev/null 2>&1; then
  gh repo create "$BACKUP_REPO" --private \
    --description "藏书阁 Android 正式签名密钥备份（私有，勿公开）"
  echo "  已新建私有仓库 $BACKUP_REPO"
fi

# 二次确认：万一仓库早已存在且是公开的，绝不能往里塞私钥
VIS="$(gh repo view "$BACKUP_REPO" --json visibility --jq .visibility)"
if [ "$VIS" != "PRIVATE" ]; then
  echo "✕ $BACKUP_REPO 的可见性是 $VIS，不是 PRIVATE。拒绝上传私钥。"
  exit 1
fi

CLONE="$WORKDIR/backup"
gh repo clone "$BACKUP_REPO" "$CLONE" -- --quiet 2>/dev/null || git clone -q "https://github.com/$BACKUP_REPO.git" "$CLONE"
cp "$JKS" "$CLONE/novel-reader-release.jks"
printf 'keystore=novel-reader-release.jks\nalias=%s\npassword=%s\n' "$ALIAS" "$PW" > "$CLONE/credentials.txt"
cat > "$CLONE/README.md" <<'EOF'
# 藏书阁 Android 正式签名密钥备份

这是 [__REPO__](https://github.com/__REPO__) 的正式签名密钥。

## 千万不要

- **不要把这个仓库改成公开**。任何人拿到这把密钥，就能给同一个包名签出「官方更新」。
- **不要删除这个仓库**。发版用的 GitHub Secrets 只能写、读不回来，这里是唯一能取回密钥的地方。

## 丢了会怎样

再也无法给已安装的用户推送更新——新签名与旧签名不一致，系统会拒绝覆盖安装。
所有用户只能卸载重装，书架和阅读进度全部丢失。

## 怎么用

正常发版不需要碰它，流水线直接读 Secrets。
只有在 Secrets 丢失、需要重新配置时才用得上：

```bash
gh repo clone __BACKUP_REPO__
cd novel-reader-signing
base64 -w0 novel-reader-release.jks | gh secret set ANDROID_KEYSTORE_BASE64 --repo __REPO__
# 口令与别名见 credentials.txt，另外三个 Secret 同法设置
```
EOF
# 占位符在此替换：README 里有 Markdown 反引号，
# 直接用可插值 heredoc 会被当成命令替换执行。
sed -i "s|__REPO__|$REPO|g; s|__BACKUP_REPO__|$BACKUP_REPO|g" "$CLONE/README.md"

git -C "$CLONE" add -A
git -C "$CLONE" -c user.name="$(git config user.name || echo backup)" \
                -c user.email="$(git config user.email || echo backup@local)" \
                commit -q -m "chore: 备份正式签名密钥"
git -C "$CLONE" push -q origin HEAD

# ---------- 4. 确认能取回，再销毁本地 ----------
# 先验证备份真的推上去且拿得回来，否则销毁的就是唯一一份。
echo "→ 校验备份可取回..."
VERIFY="$WORKDIR/verify"
git clone -q "https://github.com/$BACKUP_REPO.git" "$VERIFY"
if ! cmp -s "$JKS" "$VERIFY/novel-reader-release.jks"; then
  echo "✕ 备份校验失败：$BACKUP_REPO 里的密钥与本地不一致。"
  echo "  本地副本保留在 $WORKDIR，请手动处理后再删。"
  trap - EXIT
  exit 1
fi

echo ""
echo "✓ 完成。"
echo "  · 发版密钥已写入 $REPO 的 Secrets"
echo "  · 备份已推送到私有仓库 $BACKUP_REPO 并校验可取回"
echo "  · 本地副本随脚本退出即销毁（$WORKDIR）"

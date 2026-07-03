# CoinBar

macOS 菜单栏加密货币行情工具。

## 安装

### 本地编译安装

```bash
./scripts/install.sh
```

### 下载 Release 安装

1. 从 [Releases](https://github.com/renkun/coinbar/releases) 下载 `CoinBar.dmg`
2. 打开 DMG，将 CoinBar 拖入 `/Applications`

### 首次启动

由于未付费的 Apple Developer 签名，首次打开会被 macOS 拦截：

```bash
# 方法一：右键 → 打开
# 在 Finder 中对 CoinBar.app 右键，选择「打开」

# 方法二：命令行移除隔离标记
xattr -dr com.apple.quarantine /Applications/CoinBar.app
```

## 开发

- Swift 5.9+, macOS 13+
- `swift build` 编译
- `swift run` 直接运行

## 替换应用图标

准备一张 **1024×1024 PNG** 图片（建议 macOS Big Sur 风格的圆角方形图标），然后：

```bash
# 1. 替换源文件
cp 你的设计稿.png Resources/AppIcon-1024.png

# 2. 生成各分辨率并打包为 .icns
cd Resources
ICONSET="AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for s in 16 32 64 128 256 512; do
  sips -z $s $s AppIcon-1024.png --out "$ICONSET/icon_${s}x${s}.png"
  sips -z $((s*2)) $((s*2)) AppIcon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png"
done
cp AppIcon-1024.png "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$ICONSET"
cd ..

# 3. 重新打包安装
./scripts/install.sh

# 4. 清理图标缓存（让 Finder/Spo tlight 识别新图标）
rm -rf ~/Library/Caches/com.apple.iconservices.store
killall Finder
killall Dock
```

或直接用生成脚本（从 PNG 重新生成）：

```bash
# 把你的 1024 PNG 放到 Resources/AppIcon-1024.png 后：
cd Resources
ICONSET="AppIcon.iconset" && rm -rf "$ICONSET" && mkdir -p "$ICONSET"
SRC="AppIcon-1024.png"
for s in 16 32 64 128 256 512; do
  sips -z $s $s "$SRC" --out "$ICONSET/icon_${s}x${s}.png"
  sips -z $((s*2)) $((s*2)) "$SRC" --out "$ICONSET/icon_${s}x${s}@2x.png"
done
cp "$SRC" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o AppIcon.icns && rm -rf "$ICONSET"
cd .. && ./scripts/install.sh
```

> **注意**：由于本项目使用 ad-hoc 签名，Finder 可能不立即显示自定义图标。运行一次 app 后，Spotlight 和 Launchpad 通常能正确显示。

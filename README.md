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

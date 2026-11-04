# PDDGecko iOS（WKWebView 壳）0.1.0

把安卓版 GeckoView 壳的能力搬到 iOS：WKWebView 加载拼多多商家客服工作台，注入同一套界面增强脚本，多账号用独立存储隔离。

> 本工程在 Windows 上生成，尚未在 Xcode 中编译过；首次编译如遇问题，按文末“常见问题”排查。

---

## 1. 环境要求

| 项 | 要求 |
|---|---|
| 系统 | macOS 13 Ventura 及以上 |
| Xcode | 15.0 及以上（建议最新稳定版） |
| 命令行工具 | `xcodegen`（`brew install xcodegen`） |
| 设备 | iPhone，iOS 17.0 及以上（多账号隔离依赖 iOS 17 API） |
| 账号 | 免费 Apple ID 可自签真机运行；TestFlight/上架需 Apple Developer Program |

---

## 2. 生成工程并运行

```bash
cd ios/PDDGecko
xcodegen generate
open PDDGecko.xcodeproj
```

在 Xcode 里：

1. 选中 `PDDGecko` target → **Signing & Capabilities**；
2. **Team** 选择你的 Apple ID（没有的话 Xcode → Settings → Accounts 添加）；
3. 如需改 Bundle ID，在 **Build Settings → Product Bundle Identifier** 修改（默认 `com.pdd.gecko.ios`，与他人冲突时改掉）；
4. 连接 iPhone（需在手机上信任开发者证书），选择该设备，点 Run。

首次运行后，iPhone 上会安装“PDD 客服”图标；打开即加载工作台，扫码登录即可。

---

## 3. 打包 ipa / TestFlight

**方式一：Xcode 图形界面**

1. 顶部设备选 **Any iOS Device (arm64)**；
2. 菜单 **Product → Archive**；
3. Organizer 里点 **Distribute App**：
   - 自用/内测：选 **Ad Hoc** 或 **Development**；
   - TestFlight：选 **App Store Connect → Upload**（需开发者账号，并先在 App Store Connect 建好 App）。

**方式二：命令行（适合 CI）**

```bash
cd ios/PDDGecko
xcodegen generate

xcodebuild -project PDDGecko.xcodeproj \
  -scheme PDDGecko \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/PDDGecko.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath build/PDDGecko.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist` 已附模板：`method` 可选 `development` / `ad-hoc` / `app-store`。

---

## 4. 工程结构

```
ios/PDDGecko/
├── project.yml                       # XcodeGen 配置（生成 .xcodeproj）
├── ExportOptions.plist               # 导出 ipa 的模板
├── README.md
└── PDDGecko/
    ├── App/
    │   ├── PDDGeckoApp.swift         # @main 入口
    │   └── ContentView.swift         # 主界面：账号栏 + WebView + 手势 + 弹窗
    ├── Core/
    │   ├── AccountStore.swift        # 账号列表/当前账号，UserDefaults 持久化
    │   ├── Injection.swift           # 读取并注入 CSS/JS（复用安卓端脚本）
    │   ├── NavigationGuard.swift     # 域名白名单、拦截下载/外部跳转
    │   ├── WebViewFactory.swift      # 创建 WKWebView / 按账号隔离 dataStore
    │   └── WebViewPool.swift         # 每账号一个 WKWebView，切换只切显示
    ├── UI/
    │   └── AccountBarView.swift      # 顶部账号 chip + ＋账号 + 会话按钮
    ├── Resources/
    │   ├── pdd-mobile.css            # 与安卓端同一份
    │   ├── pdd-mobile-drawer.css
    │   └── pdd-mobile-drawer.js
    ├── Assets.xcassets/              # AppIcon（1024）+ AccentColor
    └── Info.plist
```

---

## 5. 功能对照（与安卓版）

| 功能 | iOS 实现 |
|---|---|
| 多账号隔离 | `WKWebsiteDataStore(forIdentifier:)`，每账号一个 UUID 存储 |
| 账号栏 | 顶部横向 chip，点切换、长按重命名/删除 |
| 新增账号 | 输入名称 → 新 dataStore → 打开扫码登录页 |
| 删除账号 | 二次确认 → `WKWebsiteDataStore.remove` 清除该账号数据 |
| 会话抽屉 / 三页签 / 收藏 / 在线状态 | 由注入的 `pdd-mobile-drawer.js` + CSS 提供，与安卓端一致 |
| 返回/左滑 | 屏幕左边缘右滑打开/关闭会话列表（`pdd-mobile-drawer` 类） |
| 域名白名单 | 只允许 `*.pinduoduo.com` / `*.yangkeduo.com`，拦截 `intent:`、`market:`、`/other/downloadapp` |
| 键盘 | `.ignoresSafeArea(.keyboard)` + 网页 `visualViewport` 自行抬升 |

---

## 6. 常见问题

**Q1：`xcodegen: command not found`**
→ `brew install xcodegen`；没有 Homebrew 先装 Homebrew。

**Q2：真机报 “Untrusted Developer”**
→ iPhone 设置 → 通用 → VPN 与设备管理 → 信任你的开发者证书。

**Q3：运行后白屏**
→ 检查网络；确认 Bundle 里包含 `pdd-mobile.css`、`pdd-mobile-drawer.css`、`pdd-mobile-drawer.js`（Target → Build Phases → Copy Bundle Resources）。

**Q4：样式没生效**
→ 打开 Safari 的“开发 → 你的 iPhone → 页面”看控制台；确认 `Injection.scripts()` 注入成功（页面里应有 `#pdd-ios-style`）。

**Q5：多账号变成同一个登录**
→ 确认 iPhone 是 iOS 17+，且 `account.id` 是合法 UUID（工程里用 `UUID().uuidString` 生成）。

**Q6：Bundle ID 冲突**
→ 改 `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER`，重新 `xcodegen generate`。

**Q7：想上 TestFlight**
→ 需要 Apple Developer Program（$99/年）；在 App Store Connect 建 App，Bundle ID 与工程一致，Archive 后 Upload，等构建处理完即可邀请测试。

---

## 7. 合规边界

- 不修改 User-Agent、不伪造设备指纹；
- 不绕过登录、验证码、风控；
- 不自动发送消息，所有发送由人工操作；
- 仅用于本账号的客服会话。

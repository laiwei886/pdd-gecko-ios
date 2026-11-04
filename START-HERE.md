# 从这里开始（iOS 版）

> 已替你完成：源码、XcodeGen 配置、GitHub Actions 自动编译、本地 git 仓库（已提交）。
> 只剩一步需要你的 GitHub 账号授权——我无法代替你登录 GitHub。

---

## 你要做的两件事

### 1. 在 GitHub 网页新建空仓库

1. 打开 https://github.com/new
2. Repository name 填：`pdd-gecko-ios`
3. 可见性选 **Public**（公开仓库的 macOS 编译免费，不占额度；你已同意公开）
4. **不要**勾选 Add a README / .gitignore / license
5. 点 Create repository

### 2. 运行推送脚本（会自动弹浏览器让你授权一次）

在本文件夹里，右键 `push-to-github.ps1` → **使用 PowerShell 运行**；

或者打开 PowerShell 执行：

```powershell
cd D:\PDD_DS\ios\PDDGecko
powershell -ExecutionPolicy Bypass -File .\push-to-github.ps1
```

按提示输入你的 GitHub 用户名，仓库名直接回车（默认 `pdd-gecko-ios`）。

- 首次会弹出 GitHub 登录窗口：登录 → 授权（一次即可，之后自动记住）；
- 看到「推送成功」后，打开它给出的 Actions 链接。

> 如果提示“无法加载文件，因为在此系统上禁止运行脚本”，就是上面那条带 `-ExecutionPolicy Bypass` 的命令没加；加上即可。

---

## 推送成功后

1. 打开 `https://github.com/<你的用户名>/pdd-gecko-ios/actions`
2. 等 “iOS Build (unsigned IPA)” 变绿（约 8–12 分钟）
3. 点进去 → 页面底部 **Artifacts** → 下载 `PDDGecko-unsigned-ipa`
4. 解压得到 `PDDGecko-unsigned.ipa`

## 装到 iPhone（Windows 上完成）

1. iPhone 数据线连电脑，信任电脑；
2. 打开爱思助手 → 工具箱 → **IPA 签名**；
3. 选择 `PDDGecko-unsigned.ipa`；
4. 登录你的 Apple ID（密码用 appleid.apple.com 生成的“App 专用密码”）；
5. 签名完成后安装到设备；
6. 手机：设置 → 通用 → VPN与设备管理 → 信任开发者证书；
7. 若是 iOS 16+，还要开：设置 → 隐私与安全性 → 开发者模式 → 打开并重启。

免费签名有效期 **7 天**，到期用爱思助手重签一次即可，不用重新编译。

---

## 以后改代码怎么出包

改完代码后在本目录执行：

```powershell
git add .
git commit -m "说明这次改了什么"
git push
```

GitHub 会自动重新编译，你再去 Actions 下载新 IPA 即可。

---

## 常见问题

| 现象 | 处理 |
|---|---|
| push 报 404 | 仓库还没建，或用户名/仓库名写错 |
| push 报认证失败 | 删掉 Windows 凭据里的 github 条目，重新运行脚本授权 |
| Actions 报 Swift 编译错误 | 把红色错误文本发我，我改源码后重新打包 |
| 安装后闪退 | 先确认已“信任开发者证书”；仍闪退把爱思助手日志发我 |
| 签名 7 天到期 | 爱思助手重新签一次，不用改工程 |

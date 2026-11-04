# 一键推送到 GitHub（首次需浏览器授权一次）

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo

Write-Host '=== PDDGecko iOS 推送到 GitHub ===' -ForegroundColor Cyan
Write-Host ''
Write-Host '前提：你已经在 GitHub 网页上新建了一个空仓库。'
Write-Host '建议选择 Public（公开仓库的 macOS 编译免费，不占额度）。'
Write-Host '仓库名建议：pdd-gecko-ios'
Write-Host ''

$user = Read-Host '请输入你的 GitHub 用户名'
if ([string]::IsNullOrWhiteSpace($user)) {
    Write-Host '用户名不能为空' -ForegroundColor Red
    exit 1
}

$name = Read-Host '请输入仓库名（直接回车使用 pdd-gecko-ios）'
if ([string]::IsNullOrWhiteSpace($name)) {
    $name = 'pdd-gecko-ios'
}

$url = "https://github.com/$user/$name.git"

# 使用 Windows 自带的 Git Credential Manager：首次会弹浏览器登录
git config --local credential.helper manager

git remote remove origin 2>$null | Out-Null
git remote add origin $url

Write-Host ''
Write-Host "推送目标：$url" -ForegroundColor Yellow
Write-Host '如果弹出 GitHub 登录窗口，请在浏览器里完成授权（只需一次）。'
Write-Host ''

git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ''
    Write-Host '推送成功！' -ForegroundColor Green
    Write-Host "查看编译进度：https://github.com/$user/$name/actions" -ForegroundColor Cyan
    Write-Host '绿勾后进入该次运行，下载 Artifacts → PDDGecko-unsigned-ipa。'
    Write-Host '然后用爱思助手做 IPA 签名并安装到 iPhone。'
} else {
    Write-Host ''
    Write-Host '推送失败，常见原因：' -ForegroundColor Red
    Write-Host '1) 仓库还没创建：先去 https://github.com/new 新建空仓库（不要勾选 README）'
    Write-Host '2) 用户名或仓库名写错'
    Write-Host '3) 浏览器授权被取消：重新运行本脚本'
}

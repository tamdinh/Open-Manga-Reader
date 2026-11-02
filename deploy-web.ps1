# deploy-web.ps1
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = $scriptDir
if (-not (Test-Path "$projectDir\pubspec.yaml")) {
    $projectDir = Join-Path $scriptDir "Open-Manga-Reader"
}
if (-not (Test-Path "$projectDir\pubspec.yaml")) {
    Write-Error "Could not find Open-Manga-Reader project directory."
    exit 1
}

Set-Location $projectDir
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   Open Manga Reader - Web Deploy Script     " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Locate Flutter
$flutterCmd = "flutter"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\Users\Tam\flutter\bin\flutter.bat") {
        $flutterCmd = "C:\Users\Tam\flutter\bin\flutter.bat"
    } else {
        Write-Error "Flutter not found in PATH or at C:\Users\Tam\flutter\bin\flutter.bat"
        exit 1
    }
}

# 2. Build Web
if (-not $SkipBuild) {
    Write-Host "[1/3] Building Flutter Web (Release)..." -ForegroundColor Yellow
    & $flutterCmd build web --release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter web build failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
} else {
    Write-Host "[1/3] Skipping build step (using existing build/web)..." -ForegroundColor Yellow
}

# 3. Ensure _redirects exists for Cloudflare Pages SPA routing
Write-Host "[2/3] Verifying Cloudflare Pages _redirects configuration..." -ForegroundColor Yellow
$redirectsSrc = Join-Path $projectDir "web\_redirects"
$redirectsDest = Join-Path $projectDir "build\web\_redirects"
if (Test-Path $redirectsSrc) {
    Copy-Item $redirectsSrc $redirectsDest -Force
    Write-Host "   -> Copied _redirects to build/web/_redirects" -ForegroundColor Green
} else {
    Set-Content -Path $redirectsDest -Value "/*    /index.html   200" -Encoding ASCII
    Write-Host "   -> Created build/web/_redirects (SPA fallback)" -ForegroundColor Green
}

# 4. Deploy via Wrangler
Write-Host "[3/3] Deploying to Cloudflare Pages (open-manga-reader)..." -ForegroundColor Yellow
$deployCmd = "npx wrangler pages deploy build/web --project-name=open-manga-reader --commit-dirty=true"
cmd.exe /c $deployCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host " Deployment completed successfully!" -ForegroundColor Green
    Write-Host " Live URL: https://open-manga-reader.pages.dev" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host " Deployment failed (Exit Code: $LASTEXITCODE)!" -ForegroundColor Red
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host "If you see 'auth token has expired' or authentication errors, please run:" -ForegroundColor Yellow
    Write-Host "   npx wrangler login" -ForegroundColor White
    Write-Host "to log in to your Cloudflare account again, then re-run this script." -ForegroundColor Yellow
    exit $LASTEXITCODE
}

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

# 3b. Everything in build/web is public, and flutter_dotenv ships .env as build/web/assets/.env.
# The web app signs in with a Firebase popup and does not use the desktop OAuth client, so remove those keys
# from the deployed copy, and refuse to deploy if anything that looks like a secret is still in it.
$publicEnv = Join-Path $projectDir "build\web\assets\.env"
if (Test-Path $publicEnv) {
    $kept = Get-Content $publicEnv | Where-Object { $_ -notmatch '^\s*GOOGLE_DESKTOP_CLIENT_(ID|SECRET)\s*=' }
    [IO.File]::WriteAllLines($publicEnv, $kept, (New-Object System.Text.UTF8Encoding($false)))
    $leaked = $kept | Where-Object { $_ -match '^\s*[A-Za-z0-9_]*(SECRET|PASSWORD|PRIVATE)[A-Za-z0-9_]*\s*=' }
    if ($leaked) {
        Write-Error "build/web/assets/.env still contains secret-looking keys (public file). Remove them from .env or from this script's list. Not deploying."
        exit 1
    }
    Write-Host "   -> Removed desktop OAuth keys from the public assets/.env" -ForegroundColor Green
}

# 4. Deploy via Wrangler
Write-Host "[3/3] Deploying to Cloudflare Pages (open-manga)..." -ForegroundColor Yellow
$deployCmd = "npx wrangler pages deploy build/web --project-name=open-manga --branch=main --commit-dirty=true"
cmd.exe /c $deployCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host " Deployment completed successfully!" -ForegroundColor Green
    Write-Host " Live URL: https://open-manga.pages.dev" -ForegroundColor Cyan
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

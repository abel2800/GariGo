# GariGo — one-command Chrome preview (no phone / emulator needed)
# Usage:  .\start-all.cmd   or   npm start
#
# Port 8080 is EnterpriseDB ("Server is up and running") — we use 5180–5182.

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ApiUrl = "http://localhost:4000"
$Defines = @("--dart-define=GARI_API_URL=$ApiUrl", "--dart-define=GARI_SOCKET_URL=$ApiUrl")

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

Write-Host @"

  GariGo Chrome preview
  API     $ApiUrl/health
  Admin   http://localhost:5180
  Rider   http://localhost:5181
  Driver  http://localhost:5182

"@ -ForegroundColor Green

# --- API ---
Write-Step "API…"
$healthOk = $false
try {
  $h = Invoke-RestMethod -Uri "$ApiUrl/health" -TimeoutSec 2
  $healthOk = [bool]$h.ok
} catch {}

if (-not $healthOk) {
  Start-Process powershell -WorkingDirectory (Join-Path $Root "backend") -ArgumentList @(
    "-NoExit", "-Command", "Write-Host 'GariGo API' -ForegroundColor Green; npm run dev"
  )
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    try {
      if ((Invoke-RestMethod -Uri "$ApiUrl/health" -TimeoutSec 1).ok) { $healthOk = $true; break }
    } catch {}
  }
  if (-not $healthOk) {
    Write-Host "API failed to start. Check backend/.env DATABASE_URL (port 5433)." -ForegroundColor Red
    exit 1
  }
} else {
  Write-Host "Already running."
}

# --- Build web if missing ---
$apps = @(
  @{ Name = "Admin";  Dir = "apps\garigo_admin";  Port = 5180 },
  @{ Name = "Rider";  Dir = "apps\garigo_rider";  Port = 5181 },
  @{ Name = "Driver"; Dir = "apps\garigo_driver"; Port = 5182 }
)

foreach ($app in $apps) {
  $web = Join-Path $Root "$($app.Dir)\build\web\index.html"
  if (-not (Test-Path $web)) {
    Write-Step "Building $($app.Name) for web (first time ~2 min)…"
    Push-Location (Join-Path $Root $app.Dir)
    flutter pub get | Out-Null
    flutter build web --no-wasm-dry-run @Defines
    if ($LASTEXITCODE -ne 0) {
      Write-Host "Build failed for $($app.Name)" -ForegroundColor Red
      Pop-Location
      exit 1
    }
    Pop-Location
  } else {
    Write-Host "$($app.Name) web build ready."
  }
}

# --- Serve + open Chrome ---
foreach ($app in $apps) {
  $dir = Join-Path $Root "$($app.Dir)\build\web"
  $port = $app.Port
  Write-Step "Serving $($app.Name) on :$port…"

  # Free the port if a previous python server is still there
  $listeners = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  foreach ($l in $listeners) {
    Stop-Process -Id $l.OwningProcess -Force -ErrorAction SilentlyContinue
  }

  Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "`$Host.UI.RawUI.WindowTitle = 'GariGo $($app.Name) :$port'; Set-Location '$dir'; Write-Host 'http://localhost:$port' -ForegroundColor Green; python -m http.server $port"
  )
  Start-Process "chrome" "http://localhost:$port"
  Start-Sleep -Milliseconds 400
}

Write-Host @"

Open these (Chrome should open automatically):
  Admin  http://localhost:5180
  Rider  http://localhost:5181
  Driver http://localhost:5182

Ignore http://localhost:8080 — that is EnterpriseDB, not GariGo.

Demo: OTP/2FA 123456 · Admin ops@garigo.et / admin123 · Driver phone ends with 9
"@ -ForegroundColor Yellow

# -------------------------------------------------------------
#  Priyanshu's PC Setup Toolkit (PowerShell 5+ / PowerShell 7+)
#  Inspired by Chris Titus Tech
# -------------------------------------------------------------
# ---------- 1️⃣  Utility Functions --------------------------------
function Get-FreePort {
    # Find the first unused port between 3422–3500
    $used = Get-NetTCPConnection -State Listen | Select-Object -ExpandProperty LocalPort
    for ($p = 3422; $p -lt 3500; $p++) {
        if ($used -notcontains $p) { return $p }
    }
    throw "❌ No free port available between 3422–3500."
}
function Ensure-Winget {
    Write-Host "🔍 Checking Winget..." -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "⬇️ Installing Winget (App Installer)..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\AppInstaller.msixbundle"
            Add-AppxPackage -Path "$env:TEMP\AppInstaller.msixbundle"
        } catch {
            Write-Host "❌ Winget installation failed. Please install manually: https://aka.ms/getwinget" -ForegroundColor Red
            pause
            exit
        }
    }
    Write-Host "✅ Winget ready." -ForegroundColor Green
}
function Ensure-Chocolatey {
    Write-Host "🔍 Checking Chocolatey..." -ForegroundColor Cyan
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "🍫 Installing Chocolatey..." -ForegroundColor Yellow
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        } catch {
            Write-Host "❌ Chocolatey installation failed!" -ForegroundColor Red
            pause
            exit
        }
    }
    Write-Host "✅ Chocolatey ready." -ForegroundColor Green
}
# ---------- 2️⃣  Web Listener -------------------------------------
function Start-WebListener {
    $port      = Get-FreePort
    $htmlUrl   = "https://priyanshu8494.github.io/pc-setup-dashboard/index.html"
    $htmlPath  = "$env:TEMP\index.html"
    Write-Host "⬇️ Downloading Web Dashboard..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $htmlUrl -OutFile $htmlPath
    } catch {
        Write-Host "❌ Failed to download index.html from GitHub Pages." -ForegroundColor Red
        return
    }
    if (-not (Test-Path $htmlPath)) {
        Write-Host "❌ index.html could not be loaded!" -ForegroundColor Red
        return
    }
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$port/")
    $listener.Start()
    Write-Host "✅ Listener started at http://localhost:$port" -ForegroundColor Green
    # Open the dashboard in the default browser
    Start-Process "http://localhost:$port"
    try {
        while ($listener.IsListening) {
            $context  = $listener.GetContext()
            $request  = $context.Request
            $response = $context.Response
            switch ($request.Url.AbsolutePath) {
                '/' { $path = '/' }
                '/index.html' { $path = '/index.html' }
                default { $path = $request.Url.AbsolutePath }
            }
            # ---- Serve the dashboard --------------------------------
            if ($path -in @('/', '/index.html')) {
                $html   = Get-Content $htmlPath -Raw
                $bytes  = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentType    = 'text/html'
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            # ---- Install via Winget --------------------------------
            elseif ($path -eq '/install') {
                $pkg = $request.QueryString["pkg"]
                if ($pkg) {
                    Write-Host "⬇️ Installing package: $pkg" -ForegroundColor Cyan
                    $installCmd = "winget install --id $pkg --silent"
                    Start-Process -FilePath 'powershell.exe' 
                        -ArgumentList '-NoProfile','-WindowStyle','Hidden','-Command',$installCmd 
                        -Verb RunAs
                }
                $response.StatusCode = 200
            }
            # ---- Run Advance Toolkit --------------------------------
            elseif ($path -eq '/advance') {
                Write-Host "🚀 Launching Advance Toolkit..." -ForegroundColor Magenta
                Start-Process -FilePath 'powershell.exe' 
                    -ArgumentList '-NoProfile','-WindowStyle','Hidden','-Command','irm christitus.com/win | iex' 
                    -Verb RunAs
                $response.StatusCode = 200
            }
            # ---- Unknown path ----------------------------------------
            else {
                $response.StatusCode = 404
            }
            $response.OutputStream.Close()
        }
    } catch {
        Write-Host "❌ Listener error: $_" -ForegroundColor Red
    } finally {
        if ($listener -and $listener.IsListening) { $listener.Stop() }
    }
}
# ---------- 3️⃣  Bootstrap ----------------------------------------
Write-Host "🚀 Starting Priyanshu's PC Setup Toolkit..." -ForegroundColor Cyan
Ensure-Winget
Ensure-Chocolatey
Start-WebListener

                        -ArgumentList '-NoProfile','-WindowStyle','Hidden','-Command',$installCmd 
                    -ArgumentList '-NoProfile','-WindowStyle','Hidden','-Command','irm christitus.com/win | iex' 

# ================================
#  Priyanshu's PC Setup Toolkit
#  Inspired by Chris Titus Tech
# ================================

function Get-FreePort {
    $tcpListeners = Get-NetTCPConnection -State Listen | Select-Object -ExpandProperty LocalPort
    for ($p = 3422; $p -lt 3500; $p++) {
        if ($tcpListeners -notcontains $p) { return $p }
    }
    throw "❌ No free port available between 3422–3500."
}

function Ensure-Winget {
    Write-Host "🔍 Checking Winget..." -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "⬇️ Installing Winget (App Installer)..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest "https://aka.ms/getwinget" -OutFile "$env:TEMP\AppInstaller.msixbundle"
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

function Start-WebListener {
    $port = Get-FreePort
    $htmlUrl = "https://priyanshu8494.github.io/pc-setup-dashboard/index.html"
    $htmlPath = "$env:TEMP\index.html"

    Write-Host "⬇️ Downloading Web Dashboard..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest $htmlUrl -OutFile $htmlPath -UseBasicParsing
    } catch {
        Write-Host "❌ Failed to download index.html from GitHub Pages." -ForegroundColor Red
        return
    }

    if (-not (Test-Path $htmlPath)) {
        Write-Host "❌ index.html could not be loaded!" -ForegroundColor Red
        return
    }

    try {
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:$port/")
        $listener.Start()
        Write-Host "✅ Listener started at http://localhost:$port" -ForegroundColor Green
        Start-Process "http://localhost:$port"

        while ($listener.IsListening) {
            $context   = $listener.GetContext()
            $request   = $context.Request
            $response  = $context.Response

            if ($request.Url.AbsolutePath -eq "/" -or $request.Url.AbsolutePath -eq "/index.html") {
                $html   = Get-Content $htmlPath -Raw
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentType    = "text/html"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } elseif ($request.Url.AbsolutePath -like "/install") {
                $pkg = $request.QueryString["pkg"]
                if ($pkg) {
                    Write-Host "⬇️ Installing package: $pkg" -ForegroundColor Cyan
                    Start-Process "powershell" "-NoProfile -WindowStyle Hidden -Command winget install --id $pkg --silent" -Verb RunAs
                }
                $response.StatusCode = 200
            } else {
                $response.StatusCode = 404
            }

            $response.OutputStream.Close()
        }
    } catch {
        Write-Host "❌ Failed to start listener. Try running PowerShell as Administrator or freeing ports 3422–3500." -ForegroundColor Red
    }
}

# ================================
# Main Bootstrap Execution
# ================================
Write-Host "🚀 Starting Priyanshu's PC Setup Toolkit..." -ForegroundColor Cyan
Ensure-Winget
Ensure-Chocolatey
Start-WebListener

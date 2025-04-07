# Priyanshu's PC Setup Script
# Run with:
# irm "https://raw.githubusercontent.com/Priyanshu8494/pc-setup-dashboard/main/setup.ps1" | iex

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Winget not found. Please install manually from https://aka.ms/getwinget" -ForegroundColor Red
        pause
        exit
    }
}

function Ensure-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "🍫 Installing Chocolatey..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

function Start-WebListener {
    $port = 3422

    # If running via irm | iex, $MyInvocation.MyCommand.Path will be null
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not $scriptDir) {
        $scriptDir = "$env:TEMP\pc-setup-dashboard"
        if (-not (Test-Path $scriptDir)) { New-Item -ItemType Directory -Path $scriptDir | Out-Null }

        $htmlUrl = "https://raw.githubusercontent.com/Priyanshu8494/pc-setup-dashboard/main/index.html"
        $htmlPath = Join-Path $scriptDir "index.html"
        Invoke-WebRequest -Uri $htmlUrl -OutFile $htmlPath -UseBasicParsing
    } else {
        $htmlPath = Join-Path $scriptDir "index.html"
    }

    if (-not (Test-Path $htmlPath)) {
        Write-Host "❌ index.html not found!" -ForegroundColor Red
        return
    }

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$port/")

    try {
        $listener.Start()
        Write-Host "✅ Listener started at http://localhost:$port" -ForegroundColor Green
        Start-Process "http://localhost:$port"

        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            if ($request.Url.AbsolutePath -eq "/" -or $request.Url.AbsolutePath -eq "/index.html") {
                $html = Get-Content $htmlPath -Raw
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentType = "text/html"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            elseif ($request.Url.AbsolutePath -eq "/install") {
                $pkg = $request.QueryString["pkg"]
                if ($pkg) {
                    Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -Command winget install --id `"$pkg`" -e --silent" -Verb RunAs
                    $response.StatusCode = 200
                } else {
                    $response.StatusCode = 400
                }
                $response.OutputStream.Close()
                continue
            } else {
                $response.StatusCode = 404
            }

            $response.OutputStream.Close()
        }
    } catch {
        Write-Host "❌ Failed to start listener. Try running PowerShell as Administrator or freeing port 3422." -ForegroundColor Red
    }
}

# ---- Run the script ----

Ensure-Winget
Ensure-Chocolatey
Start-WebListener

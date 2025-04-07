# Priyanshu's PC Setup Toolkit - setup.ps1
# Run using: irm "https://raw.githubusercontent.com/Priyanshu8494/pc-setup-dashboard/main/setup.ps1" | iex

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

function Get-FreePort {
    $tcpListeners = Get-NetTCPConnection -State Listen | Select-Object -ExpandProperty LocalPort
    for ($p = 3422; $p -lt 3500; $p++) {
        if ($tcpListeners -notcontains $p) { return $p }
    }
    throw "❌ No free port available between 3422–3500."
}

function Start-WebListener {
    $port = Get-FreePort

    # Get correct path to index.html even if script is run via iex
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = Get-Location }
    $htmlPath = Join-Path $scriptDir "index.html"

    if (-not (Test-Path $htmlPath)) {
        Write-Host "❌ index.html not found in: $htmlPath" -ForegroundColor Red
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
                    Write-Host "📦 Installing $pkg via winget..."
                    Start-Process "winget" -ArgumentList "install --id $pkg --silent --accept-source-agreements --accept-package-agreements" -NoNewWindow
                    $response.StatusCode = 200
                } else {
                    $response.StatusCode = 400
                }
                $response.OutputStream.Write([byte[]]::new(0), 0, 0)
            }
            else {
                $response.StatusCode = 404
            }

            $response.OutputStream.Close()
        }
    } catch {
        Write-Host "❌ Failed to start listener. Try running PowerShell as Administrator or check your firewall." -ForegroundColor Red
    }
}

# MAIN
Ensure-Winget
Ensure-Chocolatey
Start-WebListener

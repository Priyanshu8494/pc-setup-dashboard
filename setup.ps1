# setup.ps1
# Run via: irm "https://raw.githubusercontent.com/Priyanshu8494/pc-setup-dashboard/main/setup.ps1" | iex

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Winget not found. Please install it manually from https://aka.ms/getwinget" -ForegroundColor Red
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
    $usedPorts = Get-NetTCPConnection -State Listen | Select-Object -ExpandProperty LocalPort
    for ($p = 3422; $p -le 3500; $p++) {
        if ($usedPorts -notcontains $p) {
            return $p
        }
    }
    throw "❌ No free ports available in 3422–3500 range."
}

function Start-WebListener {
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }

    $htmlPath = Join-Path $scriptDir "index.html"
    if (-not (Test-Path $htmlPath)) {
        Write-Host "❌ index.html not found in $scriptDir" -ForegroundColor Red
        return
    }

    try {
        $port = Get-FreePort
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:$port/")
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
            } elseif ($request.Url.AbsolutePath -like "/install") {
                $pkg = $request.QueryString["pkg"]
                if ($pkg) {
                    Start-Process "winget" -ArgumentList "install --id=$pkg -e --silent" -WindowStyle Hidden
                    $response.StatusCode = 200
                    $msg = "Installing $pkg"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($msg)
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                } else {
                    $response.StatusCode = 400
                }
            } else {
                $response.StatusCode = 404
            }

            $response.OutputStream.Close()
        }
    } catch {
        Write-Host "❌ Failed to start listener. Try running PowerShell as Administrator or freeing ports 3422–3500." -ForegroundColor Red
    }
}

# ---- MAIN START ----
Ensure-Winget
Ensure-Chocolatey
Start-WebListener

# Priyanshu's PC Setup Listener Script

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Winget not found. Please install manually: https://aka.ms/getwinget" -ForegroundColor Red
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

    # Fallback if $MyInvocation is null (when run via `iex`)
    $scriptDir = if ($MyInvocation.MyCommand.Path) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $env:TEMP
    }

    $htmlPath = Join-Path $scriptDir "index.html"

    # Download index.html if it doesn't exist
    if (-not (Test-Path $htmlPath)) {
        Write-Host "🌐 Downloading index.html from GitHub..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Priyanshu8494/pc-setup-dashboard/main/index.html" -OutFile $htmlPath
    }

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$port/")

    try {
        $listener.Start()
        Write-Host "`n✅ Listener started at http://localhost:$port" -ForegroundColor Green
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
                    Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -Command `"winget install --id $pkg -e --accept-source-agreements --accept-package-agreements`""
                    $message = "Installing $pkg"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($message)
                    $response.StatusCode = 200
                    $response.ContentType = "text/plain"
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                } else {
                    $response.StatusCode = 400
                }
            }
            else {
                $response.StatusCode = 404
            }

            $response.OutputStream.Close()
        }
    } catch {
        Write-Host "❌ Failed to start listener. Try running PowerShell as Administrator or freeing port $port." -ForegroundColor Red
    }
}

# 🛠️ Main Execution
Ensure-Winget
Ensure-Chocolatey
Start-WebListener

function Get-FreePort {
    $tcpListeners = Get-NetTCPConnection -State Listen | Select-Object -ExpandProperty LocalPort
    for ($p = 3422; $p -lt 3500; $p++) {
        if ($tcpListeners -notcontains $p) { return $p }
    }
    throw "❌ No free port available between 3422–3500."
}

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
    $port = Get-FreePort
    $htmlUrl = "https://raw.githubusercontent.com/Priyanshu8494/pc-setup-dashboard/main/index.html"
    $htmlPath = "$env:TEMP\index.html"

    try {
        Invoke-WebRequest $htmlUrl -OutFile $htmlPath -UseBasicParsing
    } catch {
        Write-Host "❌ Failed to download index.html" -ForegroundColor Red
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

# Main Execution
Ensure-Winget
Ensure-Chocolatey
Start-WebListener

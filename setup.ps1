# setup.ps1
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

function Grant-HttpPermission {
    $port = 3422
    $url = "http://+:$port/"
    $check = netsh http show urlacl | Select-String $url
    if (-not $check) {
        try {
            Write-Host "🛠 Granting HTTP permission using netsh..." -ForegroundColor Cyan
            Start-Process netsh -ArgumentList "http add urlacl url=$url user=Everyone" -Verb runAs -WindowStyle Hidden -Wait
        } catch {
            Write-Host "❌ Failed to grant HTTP permission. Try running as Administrator." -ForegroundColor Red
            exit
        }
    }
}

function Start-WebListener {
    $port = 3422
    $htmlPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "index.html"

    if (-not (Test-Path $htmlPath)) {
        Write-Host "❌ index.html not found in script directory!" -ForegroundColor Red
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

            $path = $request.Url.AbsolutePath
            Write-Host "Received: $path"

            if ($path -eq "/" -or $path -eq "/index.html") {
                $html = Get-Content $htmlPath -Raw
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentType = "text/html"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } elseif ($path.StartsWith("/install")) {
                $query = [System.Web.HttpUtility]::ParseQueryString($request.Url.Query)
                $pkg = $query["pkg"]
                if ($pkg) {
                    Start-Process "winget" -ArgumentList "install --id $pkg --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow
                    $msg = "✅ Installing $pkg"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($msg)
                    $response.ContentType = "text/plain"
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            } else {
                $response.StatusCode = 404
            }

            $response.OutputStream.Close()
        }
    } catch {
        Write-Host "❌ Failed to start listener. Try running as Administrator." -ForegroundColor Red
    }
}

# ==== MAIN ====
Ensure-Winget
Ensure-Chocolatey
Grant-HttpPermission
Start-WebListener

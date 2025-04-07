# setup.ps1
# Run via:
# irm "https://raw.githubusercontent.com/Priyanshu8494/pc-setup-dashboard/main/setup.ps1" | iex

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Winget not found. Please install it from https://aka.ms/getwinget" -ForegroundColor Red
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
    $htmlPath = Join-Path $PSScriptRoot "index.html"

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
                    Start-Job {
                        param($pkgId)
                        Start-Process -FilePath "winget" -ArgumentList "install", "$pkgId", "--silent", "--accept-source-agreements", "--accept-package-agreements" -NoNewWindow -Wait
                    } -ArgumentList $pkg | Out-Null

                    $msg = "Installing $pkg silently..."
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($msg)
                    $response.ContentType = "text/plain"
                    $response.ContentLength64 = $buffer.Length
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
        Write-Host "❌ Failed to start listener. Try running PowerShell as Administrator." -ForegroundColor Red
    }
}

# Main Execution
Ensure-Winget
Ensure-Chocolatey
Start-WebListener

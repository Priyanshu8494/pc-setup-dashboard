# setup.ps1
# Run via:
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

function Get-FreePort {
    $usedPorts = Get-NetTCPConnection -State Listen | Select-Object -ExpandProperty LocalPort
    for ($p = 3422; $p -lt 3500; $p++) {
        if ($usedPorts -notcontains $p) { return $p }
    }
    throw "❌ No free port available between 3422–3500."
}

function Start-WebListener {
    try {
        $port = Get-FreePort
        $html = Invoke-WebRequest "https://raw.githubusercontent.com/Priyanshu8494/pc-setup-dashboard/main/index.html" -UseBasicParsing
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:$port/")
        $listener.Start()

        Write-Host "✅ Listener started at http://localhost:$port" -ForegroundColor Green
        Start-Process "http://localhost:$port"

        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $response = $context.Response
            $request = $context.Request

            if ($request.Url.AbsolutePath -eq "/" -or $request.Url.AbsolutePath -eq "/index.html") {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html.Content)
                $response.ContentType = "text/html"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } elseif ($request.Url.AbsolutePath -like "/install") {
                $pkg = $request.QueryString["pkg"]
                if ($pkg) {
                    Start-Process "winget" -ArgumentList "install --id $pkg -e --silent" -WindowStyle Hidden
                    $response.StatusCode = 200
                    $message = "✅ Installing $pkg"
                } else {
                    $response.StatusCode = 400
                    $message = "❌ No package specified"
                }
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($message)
                $response.ContentType = "text/plain"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } else {
                $response.StatusCode = 404
            }

            $response.OutputStream.Close()
        }
    } catch {
        Write-Host "❌ Failed to start listener. Try running PowerShell as Administrator or freeing ports 3422–3500." -ForegroundColor Red
    }
}

# Main
Ensure-Winget
Ensure-Chocolatey
Start-WebListener

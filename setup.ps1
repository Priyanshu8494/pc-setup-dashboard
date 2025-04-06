# Ensure Winget and Chocolatey are installed (basic check, can be improved)
function Ensure-PackageManagers {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "[!] Winget not found. Please install Winget manually from the Microsoft Store." -ForegroundColor Red
    }

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

# Start the local HTTP listener
function Start-Listener {
    Add-Type -AssemblyName System.Net.HttpListener
    $global:listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:3422/")
    $listener.Start()
    Write-Host "[+] Listener started at http://localhost:3422/"

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.RawUrl.TrimStart('/')

        switch ($path) {
            "ping" {
                $content = '{ "status": "ok" }'
                $response.ContentType = "application/json"
            }
            "install/winrar" {
                Start-Process "choco" -ArgumentList "install winrar -y" -NoNewWindow
                $content = '{ "status": "installed", "package": "winrar" }'
                $response.ContentType = "application/json"
            }
            default {
                $content = "Invalid route: $path"
                $response.StatusCode = 404
            }
        }

        $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    }
}

# Main Entry
Ensure-PackageManagers

Start-Sleep -Seconds 2
Start-Process "http://localhost:3422/index.html"

Start-Listener

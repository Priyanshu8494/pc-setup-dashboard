# Priyanshu PC Setup Toolkit Bootstrap Script

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Winget not found. Please install it manually: https://aka.ms/getwinget" -ForegroundColor Red
        Start-Process "https://aka.ms/getwinget"
        exit
    }
}

function Ensure-Choco {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "🍫 Installing Chocolatey..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

function Start-Listener {
@"
`$listener = [System.Net.HttpListener]::new()
`$listener.Prefixes.Add('http://localhost:54321/')
`$listener.Start()
Write-Host '🔁 Listening on http://localhost:54321 ...'

while ($true) {
    `$context = `$listener.GetContext()
    `$app = `$context.Request.QueryString['app']
    `$response = `$context.Response

    if (`$app) {
        Write-Host "📦 Installing: `$app"
        Start-Process "winget" -ArgumentList "install `$app --silent --accept-source-agreements --accept-package-agreements" -NoNewWindow
        `$msg = [System.Text.Encoding]::UTF8.GetBytes("Installing `$app")
    } else {
        `$msg = [System.Text.Encoding]::UTF8.GetBytes("No app specified")
    }

    `$response.OutputStream.Write(`$msg, 0, `$msg.Length)
    `$response.Close()
}
"@ | Set-Content "$env:TEMP\\listener.ps1"
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$env:TEMP\\listener.ps1`"" -WindowStyle Minimized
}

function Launch-Web {
    Start-Sleep -Seconds 2
    Start-Process "https://Priyanshu8494.github.io/pc-setup-dashboard/"
}

# MAIN
Ensure-Winget
Ensure-Choco
Start-Listener
Launch-Web

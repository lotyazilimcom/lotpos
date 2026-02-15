param(
  [int]$DelaySeconds = 30,
  [string]$RunValueName = 'PatisyoPostgresAutostart'
)

$ErrorActionPreference = 'Stop'

$sourceScript = Join-Path $PSScriptRoot 'patisyo_postgres_autostart.ps1'
if (-not (Test-Path $sourceScript)) {
  throw "Kaynak script bulunamadı: $sourceScript"
}

$targetDir = Join-Path $env:LOCALAPPDATA 'Patisyo\\autostart'
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

$targetScript = Join-Path $targetDir 'patisyo_postgres_autostart.ps1'
Copy-Item -Path $sourceScript -Destination $targetScript -Force

$command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetScript`" -DelaySeconds $DelaySeconds"

$runKey = 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run'
New-Item -Path $runKey -Force | Out-Null
New-ItemProperty -Path $runKey -Name $RunValueName -Value $command -PropertyType String -Force | Out-Null

Write-Host "OK: Windows başlangıcına eklendi (HKCU Run): $RunValueName"
Write-Host "Komut: $command"

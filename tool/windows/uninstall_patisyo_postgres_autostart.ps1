param(
  [string]$RunValueName = 'PatisyoPostgresAutostart'
)

$ErrorActionPreference = 'Stop'

$runKey = 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run'
Remove-ItemProperty -Path $runKey -Name $RunValueName -ErrorAction SilentlyContinue

$targetDir = Join-Path $env:LOCALAPPDATA 'Patisyo\\autostart'
$targetScript = Join-Path $targetDir 'patisyo_postgres_autostart.ps1'
if (Test-Path $targetScript) {
  Remove-Item -Force $targetScript
}

Write-Host "OK: Windows başlangıcından kaldırıldı (HKCU Run): $RunValueName"

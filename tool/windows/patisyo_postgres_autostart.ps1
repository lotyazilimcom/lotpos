param(
  [int]$DelaySeconds = 15,
  [string]$LogDir = (Join-Path $env:LOCALAPPDATA 'Patisyo\\logs')
)

$ErrorActionPreference = 'Stop'

function Write-Log {
  param([string]$Message)
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  Add-Content -Path $script:LogFile -Value "[$ts] $Message"
}

function Get-PostgresPort {
  param([string]$DataDir)
  $conf = Join-Path $DataDir 'postgresql.conf'
  if (Test-Path $conf) {
    $line = Get-Content $conf | Where-Object { $_ -match '^\s*port\s*=\s*(\d+)' } | Select-Object -First 1
    if ($line -match '^\s*port\s*=\s*(\d+)') {
      return [int]$Matches[1]
    }
  }
  return 5432
}

function Test-PostgresReady {
  param(
    [string]$PgCtlPath,
    [int]$Port
  )
  $pgBin = Split-Path -Parent $PgCtlPath
  $pgIsReady = Join-Path $pgBin 'pg_isready.exe'
  if (-not (Test-Path $pgIsReady)) {
    return $false
  }
  & $pgIsReady -h 127.0.0.1 -p $Port | Out-Null
  return ($LASTEXITCODE -eq 0)
}

function Get-PostgresInstall {
  # 1) Prefer installed Windows service (most reliable source of -D path)
  $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name LIKE 'postgresql-x64-%'" `
    | Sort-Object Name -Descending `
    | Select-Object -First 1

  if ($null -ne $svc -and $svc.PathName) {
    $pathName = $svc.PathName

    $pgCtl = $null
    if ($pathName -match '^"([^"]+pg_ctl\.exe)"') {
      $pgCtl = $Matches[1]
    }

    $dataDir = $null
    if ($pathName -match '-D\s+"([^"]+)"') {
      $dataDir = $Matches[1]
    }

    if ($pgCtl -and $dataDir -and (Test-Path $pgCtl) -and (Test-Path $dataDir)) {
      return [pscustomobject]@{
        PgCtl   = $pgCtl
        DataDir = $dataDir
        Source  = "service:$($svc.Name)"
      }
    }
  }

  # 2) Fallback: search Program Files
  $root = 'C:\\Program Files\\PostgreSQL'
  if (-not (Test-Path $root)) {
    return $null
  }

  $best = Get-ChildItem $root -Directory `
    | Where-Object { $_.Name -match '^\d+$' } `
    | Sort-Object { [int]$_.Name } -Descending `
    | Select-Object -First 1

  if ($null -eq $best) {
    return $null
  }

  $pgCtl2 = Join-Path $best.FullName 'bin\\pg_ctl.exe'
  $dataDir2 = Join-Path $best.FullName 'data'
  if ((Test-Path $pgCtl2) -and (Test-Path $dataDir2)) {
    return [pscustomobject]@{
      PgCtl   = $pgCtl2
      DataDir = $dataDir2
      Source  = "programfiles:$($best.Name)"
    }
  }

  return $null
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir 'postgres-autostart.log'

try {
  Write-Log "Autostart tetiklendi (DelaySeconds=$DelaySeconds)."

  if ($DelaySeconds -gt 0) {
    Start-Sleep -Seconds $DelaySeconds
  }

  $pg = Get-PostgresInstall
  if ($null -eq $pg) {
    Write-Log 'PostgreSQL bulunamadi (ne servis ne Program Files).'
    exit 2
  }

  $port = Get-PostgresPort -DataDir $pg.DataDir
  Write-Log "PostgreSQL bulundu: $($pg.Source) PgCtl=$($pg.PgCtl) DataDir=$($pg.DataDir) Port=$port"

  if (Test-PostgresReady -PgCtlPath $pg.PgCtl -Port $port) {
    Write-Log 'PostgreSQL zaten baglanti kabul ediyor.'
    exit 0
  }

  # Zaten calisiyorsa cik.
  & $pg.PgCtl status -D $pg.DataDir | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Log 'PostgreSQL zaten calisiyor.'
    exit 0
  }

  $serverLog = Join-Path $LogDir 'postgres-server.log'
  Write-Log "Baslatiliyor... (server log: $serverLog)"

  & $pg.PgCtl start -D $pg.DataDir -w -l $serverLog | Out-Null

  # Son kontrol
  & $pg.PgCtl status -D $pg.DataDir | Out-Null
  if ($LASTEXITCODE -eq 0 -or (Test-PostgresReady -PgCtlPath $pg.PgCtl -Port $port)) {
    Write-Log 'PostgreSQL basariyla baslatildi.'
    exit 0
  }

  Write-Log 'PostgreSQL baslatilamadi (status hala down).'
  exit 1
} catch {
  try {
    Write-Log "Hata: $($_.Exception.Message)"
  } catch {
    # ignore logging failure
  }
  throw
}

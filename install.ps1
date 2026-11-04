<#
.SYNOPSIS
  Install the Knowz CLI on Windows x64 from the public release channel.

.DESCRIPTION
  Latest release:
    irm https://raw.githubusercontent.com/knowz-io/knowz-cli/main/install.ps1 | iex
  A specific release:
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/knowz-io/knowz-cli/main/install.ps1))) -Version 0.5.5

  Downloads knowz-cli-v<version>-win32-x64.tar.gz and SHA256SUMS, verifies the checksum, installs
  into %LOCALAPPDATA%\Knowz\cli\<version> and puts a knowz launcher in %LOCALAPPDATA%\Knowz\bin,
  which is added to your user PATH. No administrator rights are needed. Files fetched this way
  carry no Mark-of-the-Web, so no SmartScreen prompt appears for the unsigned CLI.

  Environment: KNOWZ_VERSION (same as -Version), KNOWZ_INSTALL_REPO (owner/repository of the
  public release channel, default knowz-io/knowz-cli).

  Works on Windows PowerShell 5.1 and PowerShell 7. Windows on ARM: use npm i -g @knowzai/cli.
#>
param(
  [string]$Version = '',
  [string]$Prefix = ''
)

& {
  param([string]$RequestedVersion, [string]$RequestedPrefix)

  # Everything lives in this script block so `irm | iex` leaves no variables or preferences behind.
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  $npmHint = 'or install with npm instead: npm i -g @knowzai/cli (Node >=22).'

  # Test-only hooks: a file stands in for the HKCU user Path (which also allows a non-Windows
  # host), and the architecture can be simulated. Never set these for a real install.
  $testUserPathFile = $env:KNOWZ_INSTALL_TEST_USER_PATH_FILE
  $testMode = -not [string]::IsNullOrEmpty($testUserPathFile)

  if ($PSVersionTable.PSVersion.Major -lt 6) {
    # Windows PowerShell 5.1 may default to TLS 1.0/1.1, which GitHub refuses.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $onWindows = $true
  } else {
    $onWindows = [bool]$IsWindows
  }
  if (-not $onWindows -and -not $testMode) {
    throw 'install.ps1 installs the Windows CLI. On macOS or Linux run: curl -fsSL https://raw.githubusercontent.com/knowz-io/knowz-cli/main/install.sh | sh'
  }

  $arch = ''
  if ($testMode -and $env:KNOWZ_INSTALL_TEST_ARCH) {
    $arch = $env:KNOWZ_INSTALL_TEST_ARCH
  } else {
    try { $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() } catch { $arch = '' }
    if (-not $arch) {
      if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 } else { $arch = $env:PROCESSOR_ARCHITECTURE }
    }
  }
  if ($arch -match '^(arm64|aarch64)$') {
    throw "The native Knowz CLI for Windows is x64 only and this PC is ARM64. Install with npm instead: npm i -g @knowzai/cli (Node >=22)."
  }
  if ($arch -notmatch '^(x64|amd64)$') {
    throw "Unsupported architecture '$arch'. The native Knowz CLI for Windows is x64 only; $npmHint"
  }

  $repository = $env:KNOWZ_INSTALL_REPO
  if ([string]::IsNullOrEmpty($repository)) { $repository = 'knowz-io/knowz-cli' }
  if ($repository -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
    throw 'KNOWZ_INSTALL_REPO must be an owner/repository pair.'
  }

  $versionPattern = '^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
  $requested = $RequestedVersion
  if ([string]::IsNullOrEmpty($requested)) { $requested = $env:KNOWZ_VERSION }
  if ([string]::IsNullOrEmpty($requested)) { $requested = 'latest' }

  function Resolve-LatestVersion {
    $apiUrl = $env:KNOWZ_INSTALL_API_URL
    $customApi = -not [string]::IsNullOrEmpty($apiUrl)
    if (-not $customApi) { $apiUrl = "https://api.github.com/repos/$repository/releases?per_page=20" }
    $releases = $null
    try {
      $releases = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    } catch {
      $releases = $null
    }
    $resolved = $null
    if ($null -ne $releases) {
      $candidates = @()
      foreach ($release in @($releases)) {
        $tag = $release.tag_name
        if (-not ($tag -is [string]) -or $tag -cnotmatch '^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$') { continue }
        if (-not ($release.draft -is [bool]) -or $release.draft) { continue }
        $core = $tag.Substring(1)
        $suffix = ''
        $dash = $core.IndexOf('-')
        if ($dash -ge 0) { $suffix = $core.Substring($dash + 1); $core = $core.Substring(0, $dash) }
        $isStable = ($release.prerelease -is [bool]) -and -not $release.prerelease -and $suffix -eq ''
        $candidates += New-Object PSObject -Property @{
          Tag = $tag
          Core = [version]$core
          NoSuffix = [int]($suffix -eq '')
          Suffix = $suffix
          Stable = $isStable
        }
      }
      # Newest stable (not prerelease, no -suffix) release; else the newest non-draft release.
      $pool = @($candidates | Where-Object { $_.Stable })
      if ($pool.Count -eq 0) { $pool = $candidates }
      if ($pool.Count -gt 0) {
        $resolved = ($pool | Sort-Object Core, NoSuffix, Suffix | Select-Object -Last 1).Tag
      }
    } elseif (-not $customApi) {
      # API unavailable (for example rate-limited): fall back to the latest-release redirect.
      try {
        $response = Invoke-WebRequest -Uri "https://github.com/$repository/releases/latest" -UseBasicParsing -Method Head
        $finalUri = $null
        if ($response.BaseResponse.ResponseUri) { $finalUri = $response.BaseResponse.ResponseUri.AbsoluteUri }
        elseif ($response.BaseResponse.RequestMessage) { $finalUri = $response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri }
        if ($finalUri) { $resolved = ($finalUri -split '/')[-1] }
      } catch {
        $resolved = $null
      }
    }
    if ([string]::IsNullOrEmpty($resolved) -or $resolved -notmatch $versionPattern) {
      throw "Could not resolve the latest Knowz CLI release from $repository. Pass -Version X.Y.Z (or set KNOWZ_VERSION), $npmHint"
    }
    return $resolved
  }

  if ($requested -eq 'latest') { $requested = Resolve-LatestVersion }
  if ($requested -notmatch $versionPattern) {
    throw "Invalid version: $requested (expected X.Y.Z or X.Y.Z-suffix)."
  }
  $ver = $requested -replace '^v', ''

  if (-not [string]::IsNullOrEmpty($RequestedPrefix)) {
    if (-not [System.IO.Path]::IsPathRooted($RequestedPrefix)) { throw '-Prefix must be an absolute path.' }
    $root = [System.IO.Path]::GetFullPath($RequestedPrefix)
  } else {
    if ([string]::IsNullOrEmpty($env:LOCALAPPDATA)) { throw 'LOCALAPPDATA is not set; pass -Prefix C:\path\to\Knowz.' }
    $root = Join-Path $env:LOCALAPPDATA 'Knowz'
  }
  $cliRoot = Join-Path $root 'cli'
  $installDir = Join-Path $cliRoot $ver
  $binDir = Join-Path $root 'bin'
  $shim = Join-Path $binDir 'knowz.cmd'
  $cliCmd = Join-Path (Join-Path $installDir 'bin') 'knowz.cmd'
  # Relative to the launcher, so non-ASCII profile paths never meet the batch code page.
  $shimContent = "@echo off`r`nrem Knowz CLI launcher written by install.ps1. Remove with cli\$ver\uninstall.ps1.`r`n`"%~dp0..\cli\$ver\bin\knowz.cmd`" %*`r`n"

  function Get-UserPathValue {
    if ($testMode) {
      if (Test-Path -LiteralPath $testUserPathFile) { return [System.IO.File]::ReadAllText($testUserPathFile) }
      return ''
    }
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    if ($null -eq $key) { return '' }
    try {
      # Raw value: keeps entries such as %USERPROFILE%\bin unexpanded.
      $value = $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
      if ($null -eq $value) { return '' }
      return [string]$value
    } finally {
      $key.Close()
    }
  }

  function Set-UserPathValue([string]$Value) {
    if ($testMode) { [System.IO.File]::WriteAllText($testUserPathFile, $Value); return }
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
      $key.SetValue('Path', $Value, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    } finally {
      $key.Close()
    }
    # [Environment]::SetEnvironmentVariable(..., 'User') broadcasts WM_SETTINGCHANGE so terminals
    # opened from now on see the new Path. (Writing Path itself through it would turn REG_EXPAND_SZ
    # into REG_SZ and freeze any %VAR% entries, so a marker variable carries the broadcast.)
    [Environment]::SetEnvironmentVariable('KNOWZ_INSTALL_PATH_REFRESH', '1', 'User')
    [Environment]::SetEnvironmentVariable('KNOWZ_INSTALL_PATH_REFRESH', $null, 'User')
  }

  function Test-PathListHas([string]$List, [string]$Directory, [string]$Separator) {
    $want = $Directory.TrimEnd([char]'\', [char]'/')
    foreach ($entry in ($List -split [regex]::Escape($Separator))) {
      $candidate = [Environment]::ExpandEnvironmentVariables($entry.Trim()).TrimEnd([char]'\', [char]'/')
      if ($candidate -and ($candidate -eq $want)) { return $true }
    }
    return $false
  }

  function Add-KnowzPath {
    $userPath = Get-UserPathValue
    if (-not (Test-PathListHas $userPath $binDir ';')) {
      $trimmed = $userPath.TrimEnd(';')
      if ($trimmed.Trim()) { Set-UserPathValue ($trimmed + ';' + $binDir) } else { Set-UserPathValue $binDir }
    }
    $separator = [string][System.IO.Path]::PathSeparator
    if (-not (Test-PathListHas $env:PATH $binDir $separator)) { $env:PATH = $binDir + $separator + $env:PATH }
  }

  function Write-NextSteps {
    Write-Host ''
    Write-Host 'Next steps (open a new terminal if knowz is not found):'
    Write-Host '  knowz --version'
    Write-Host '  knowz up                      # free selfhosted edition; needs Docker Desktop running'
    Write-Host '  knowz up --edition portable   # Knowz platform with a Knowz plan (device link, no GHCR token)'
    Write-Host "Uninstall: powershell -ExecutionPolicy Bypass -File `"$(Join-Path $installDir 'uninstall.ps1')`""
  }

  if ((Test-Path -LiteralPath $cliCmd) -and (Test-Path -LiteralPath $shim) -and
      ([System.IO.File]::ReadAllText($shim) -eq $shimContent) -and
      (Test-PathListHas (Get-UserPathValue) $binDir ';')) {
    Add-KnowzPath
    Write-Host "Knowz CLI $ver is already installed."
    return
  }

  $asset = "knowz-cli-v$ver-win32-x64.tar.gz"
  if ($env:KNOWZ_INSTALL_BASE_URL) {
    $baseUrl = $env:KNOWZ_INSTALL_BASE_URL.TrimEnd('/') + "/v$ver"
  } else {
    $baseUrl = "https://github.com/$repository/releases/download/v$ver"
  }

  New-Item -ItemType Directory -Force -Path $cliRoot | Out-Null
  $stage = Join-Path $cliRoot ('.staging-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  try {
    $archive = Join-Path $stage $asset
    $sums = Join-Path $stage 'SHA256SUMS'
    try {
      Invoke-WebRequest -Uri "$baseUrl/$asset" -OutFile $archive -UseBasicParsing
    } catch {
      throw "CLI $ver for Windows x64 is unavailable in the configured public channel ($repository). Verify the release, $npmHint"
    }
    Invoke-WebRequest -Uri "$baseUrl/SHA256SUMS" -OutFile $sums -UseBasicParsing

    $expected = $null
    foreach ($line in [System.IO.File]::ReadAllLines($sums)) {
      $parts = $line.Trim() -split '\s+', 2
      if ($parts.Count -eq 2 -and $parts[1].TrimStart([char]'*') -eq $asset) { $expected = $parts[0].ToLowerInvariant() }
    }
    if (-not $expected) { throw "No checksum published for $asset." }
    # .NET hashing rather than Get-FileHash: Windows PowerShell 5.1 started from PowerShell 7
    # inherits PS7's module path and cannot load Get-FileHash.
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($archive)
    try {
      $actual = ([System.BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-', '').ToLowerInvariant()
    } finally {
      $stream.Dispose()
      $sha.Dispose()
    }
    if ($actual -ne $expected) { throw "Checksum mismatch for $asset; nothing was installed." }

    # The built-in bsdtar (Windows 10 1803+). Never a GNU tar from PATH, which reads C: as a host.
    $tar = 'tar'
    if ($env:SystemRoot) {
      $systemTar = Join-Path $env:SystemRoot 'System32\tar.exe'
      if (Test-Path -LiteralPath $systemTar) { $tar = $systemTar }
      elseif ($onWindows) { throw "tar.exe was not found (it ships with Windows 10 1803 and later); $npmHint" }
    }
    $extract = Join-Path $stage 'extract'
    New-Item -ItemType Directory -Force -Path $extract | Out-Null
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $tar -xzf $archive -C $extract
    $tarExit = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($tarExit -ne 0) { throw "Could not extract $asset (tar exit $tarExit); nothing was installed." }
    $payload = Join-Path $extract 'knowz'
    if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $payload 'bin') 'knowz.cmd'))) {
      throw 'Release archive does not contain knowz/bin/knowz.cmd; nothing was installed.'
    }

    $uninstall = @'
<#
.SYNOPSIS
  Remove this Knowz CLI version. Runtime data, credentials and profiles are kept unless -Purge.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File uninstall.ps1
  powershell -ExecutionPolicy Bypass -File uninstall.ps1 -Purge -Edition selfhosted -Name personal
#>
param(
  [switch]$Purge,
  [ValidateSet('selfhosted', 'portable')][string]$Edition = '',
  [string]$Name = '',
  [string]$ConfigDir = ''
)
$ErrorActionPreference = 'Stop'
$installDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$version = Split-Path -Leaf $installDir
$cliRoot = Split-Path -Parent $installDir
$root = Split-Path -Parent $cliRoot
$binDir = Join-Path $root 'bin'
$shim = Join-Path $binDir 'knowz.cmd'
$cli = Join-Path (Join-Path $installDir 'bin') 'knowz.cmd'
$testUserPathFile = $env:KNOWZ_INSTALL_TEST_USER_PATH_FILE
# The exact PATH entry install.ps1 added (it may be an 8.3 short path that never matches the
# long path derived above).
$pathEntries = @($binDir)
$recordedEntry = Join-Path $installDir '.path-entry'
if (Test-Path -LiteralPath $recordedEntry) {
  $recorded = [System.IO.File]::ReadAllText($recordedEntry).Trim()
  if ($recorded) { $pathEntries = @($recorded, $binDir) }
}

if (-not $Purge -and ($Edition -or $Name -or $ConfigDir)) {
  [Console]::Error.WriteLine('Usage: uninstall.ps1 [-Purge [-Edition selfhosted|portable] [-Name NAME] [-ConfigDir DIR]]')
  exit 2
}
if ($Purge) {
  # Teardown must succeed before the CLI is removed. Other runtimes and profiles survive.
  $runtimeArgs = @('runtime', 'destroy', '--yes', '--purge-profile')
  if ($Edition) { $runtimeArgs += @('--edition', $Edition) }
  if ($Name) { $runtimeArgs += @('--name', $Name) }
  if ($ConfigDir) { $runtimeArgs += @('--config-dir', $ConfigDir) }
  & $cli @runtimeArgs
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Runtime teardown failed (exit $LASTEXITCODE); the CLI was kept so you can retry."
    exit $LASTEXITCODE
  }
} else {
  Write-Host 'Preserving runtime data and credentials. Use -Purge to destroy a selected runtime first.'
}

function Get-UserPathValue {
  if ($testUserPathFile) {
    if (Test-Path -LiteralPath $testUserPathFile) { return [System.IO.File]::ReadAllText($testUserPathFile) }
    return ''
  }
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
  if ($null -eq $key) { return '' }
  try {
    $value = $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    if ($null -eq $value) { return '' }
    return [string]$value
  } finally {
    $key.Close()
  }
}

function Set-UserPathValue([string]$Value) {
  if ($testUserPathFile) { [System.IO.File]::WriteAllText($testUserPathFile, $Value); return }
  $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
  try {
    $key.SetValue('Path', $Value, [Microsoft.Win32.RegistryValueKind]::ExpandString)
  } finally {
    $key.Close()
  }
  [Environment]::SetEnvironmentVariable('KNOWZ_INSTALL_PATH_REFRESH', '1', 'User')
  [Environment]::SetEnvironmentVariable('KNOWZ_INSTALL_PATH_REFRESH', $null, 'User')
}

function Remove-PathEntry([string]$List, [string]$Directory, [string]$Separator) {
  $want = $Directory.TrimEnd([char]'\', [char]'/')
  $kept = @()
  foreach ($entry in ($List -split [regex]::Escape($Separator))) {
    $candidate = [Environment]::ExpandEnvironmentVariables($entry.Trim()).TrimEnd([char]'\', [char]'/')
    if ($entry.Trim() -and $candidate -ne $want) { $kept += $entry }
  }
  return ($kept -join $Separator)
}

# Only the launcher that points at this version is removed, so removing an older version never
# breaks a newer one.
if ((Test-Path -LiteralPath $shim) -and [System.IO.File]::ReadAllText($shim).Contains("..\cli\$version\bin\knowz.cmd")) {
  Remove-Item -LiteralPath $shim -Force
  if (-not (Get-ChildItem -LiteralPath $binDir -Force | Select-Object -First 1)) {
    Remove-Item -LiteralPath $binDir -Force
    $userPath = Get-UserPathValue
    $updated = $userPath
    foreach ($entry in $pathEntries) { $updated = Remove-PathEntry $updated $entry ';' }
    if ($updated -ne $userPath) { Set-UserPathValue $updated }
    foreach ($entry in $pathEntries) {
      $env:PATH = Remove-PathEntry $env:PATH $entry ([string][System.IO.Path]::PathSeparator)
    }
  }
}
Remove-Item -LiteralPath $installDir -Recurse -Force
if (-not (Get-ChildItem -LiteralPath $cliRoot -Force | Select-Object -First 1)) {
  Remove-Item -LiteralPath $cliRoot -Force
}
Write-Host 'Knowz CLI removed.'
'@
    [System.IO.File]::WriteAllText((Join-Path $payload 'uninstall.ps1'), $uninstall, (New-Object System.Text.UTF8Encoding $true))

    [System.IO.File]::WriteAllText((Join-Path $payload '.path-entry'), $binDir, [System.Text.Encoding]::UTF8)
    if (Test-Path -LiteralPath $installDir) { Remove-Item -LiteralPath $installDir -Recurse -Force }
    Move-Item -LiteralPath $payload -Destination $installDir
  } finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
  }

  New-Item -ItemType Directory -Force -Path $binDir | Out-Null
  [System.IO.File]::WriteAllText($shim, $shimContent, [System.Text.Encoding]::ASCII)
  Add-KnowzPath

  Write-Host "Installed Knowz CLI $ver at $installDir"
  Write-Host "Launcher: $shim (on your user PATH)"
  Write-NextSteps
} $Version $Prefix

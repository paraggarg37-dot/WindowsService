<#
.SYNOPSIS
    Builds the JavaHttpService MSI installer.

.DESCRIPTION
    1. Builds the fat JAR via Gradle
    2. Downloads WinSW if not present
    3. Stages all files into installer\staging\
    4. Compiles the WiX source into an MSI

.NOTES
    Prerequisites:
      - JAVA_HOME set (or java on PATH)
      - WiX Toolset 3.14 installed (candle.exe / light.exe on PATH or in default location)
#>

param(
    [string]$JavaHome = "C:\Users\Chirag\.jdks\ms-21.0.10"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$InstallerDir = Join-Path $ProjectRoot "installer"
$StagingDir   = Join-Path $InstallerDir "staging"
$OutputDir    = Join-Path $InstallerDir "output"
$WinswDir     = Join-Path $ProjectRoot "winsw"

# ── Helper ────────────────────────────────────────────────────────
function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }

# ── 1. Set JAVA_HOME ─────────────────────────────────────────────
Write-Step "Setting JAVA_HOME to $JavaHome"
$env:JAVA_HOME = $JavaHome

# ── 2. Build the JAR ─────────────────────────────────────────────
Write-Step "Building JAR with Gradle..."
& "$ProjectRoot\gradlew.bat" jar
if ($LASTEXITCODE -ne 0) { throw "Gradle build failed" }

$JarPath = Join-Path $ProjectRoot "build\libs\JavaHttpService.jar"
if (-not (Test-Path $JarPath)) { throw "JAR not found at $JarPath" }
Write-Host "   JAR built: $JarPath"

# ── 3. Download WinSW if needed ──────────────────────────────────
$WinswExe = Join-Path $WinswDir "JavaHttpService.exe"
if (-not (Test-Path $WinswExe)) {
    Write-Step "Downloading WinSW..."
    $WinswUrl = "https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe"
    New-Item -ItemType Directory -Path $WinswDir -Force | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $WinswUrl -OutFile $WinswExe -UseBasicParsing
    Write-Host "   Downloaded to: $WinswExe"
} else {
    Write-Step "WinSW already present at $WinswExe"
}

# ── 4. Stage files ───────────────────────────────────────────────
Write-Step "Staging files..."
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

Copy-Item $JarPath                                    (Join-Path $StagingDir "JavaHttpService.jar") -Force
Copy-Item $WinswExe                                   (Join-Path $StagingDir "JavaHttpService.exe") -Force
Copy-Item (Join-Path $WinswDir "JavaHttpService.xml") (Join-Path $StagingDir "JavaHttpService.xml") -Force

Write-Host "   Staged files:"
Get-ChildItem $StagingDir | ForEach-Object { Write-Host "     - $($_.Name)  ($([math]::Round($_.Length/1KB, 1)) KB)" }

# ── 5. Find WiX tools ───────────────────────────────────────────
Write-Step "Locating WiX tools..."
$WixBin = $null
$WixPaths = @(
    "${env:ProgramFiles(x86)}\WiX Toolset v3.14\bin",
    "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin",
    "${env:ProgramFiles}\WiX Toolset v3.14\bin"
)
foreach ($p in $WixPaths) {
    if (Test-Path (Join-Path $p "candle.exe")) { $WixBin = $p; break }
}
if (-not $WixBin) {
    # Try PATH
    $candle = Get-Command candle.exe -ErrorAction SilentlyContinue
    if ($candle) { $WixBin = Split-Path $candle.Source }
}
if (-not $WixBin) { throw "WiX Toolset not found. Install wix314.exe first." }
Write-Host "   WiX bin: $WixBin"

$Candle = Join-Path $WixBin "candle.exe"
$Light  = Join-Path $WixBin "light.exe"

# ── 6. Compile WiX source ───────────────────────────────────────
Write-Step "Compiling Product.wxs (candle)..."
$WxsFile  = Join-Path $InstallerDir "Product.wxs"
$WixObjFile = Join-Path $InstallerDir "Product.wixobj"

& $Candle $WxsFile -out $WixObjFile
if ($LASTEXITCODE -ne 0) { throw "candle.exe failed" }

# ── 7. Link into MSI ────────────────────────────────────────────
Write-Step "Linking MSI (light)..."
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$MsiFile = Join-Path $OutputDir "JavaHttpService.msi"

& $Light $WixObjFile -out $MsiFile -ext WixUIExtension -ext WixUtilExtension -sice:ICE61
if ($LASTEXITCODE -ne 0) { throw "light.exe failed" }

# ── Done! ────────────────────────────────────────────────────────
Write-Host "`n" -NoNewline
Write-Host "============================================" -ForegroundColor Green
Write-Host "  MSI Installer built successfully!" -ForegroundColor Green
Write-Host "  $MsiFile" -ForegroundColor Green
Write-Host "  Size: $([math]::Round((Get-Item $MsiFile).Length / 1KB, 1)) KB" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "`nTo install:  msiexec /i `"$MsiFile`""
Write-Host "To uninstall: msiexec /x `"$MsiFile`""

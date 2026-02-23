<#
.SYNOPSIS
    Stops and uninstalls the Java HTTP Service.

.DESCRIPTION
    1. Stops the "JavaHttpService" Windows service (if running)
    2. Uninstalls the MSI package silently
    3. Verifies the service and install directory are removed

.NOTES
    Must be run as Administrator (will self-elevate if needed).
#>

$ErrorActionPreference = "Stop"
$ServiceName = "JavaHttpService"
$MsiPath     = Join-Path $PSScriptRoot "installer\output\JavaHttpService.msi"
$InstallDir  = Join-Path $env:ProgramFiles "JavaHttpService"

function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }

# ── Check for admin privileges ────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Restarting as Administrator..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList (
        '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
    )
    exit
}

# ── 1. Stop the service ──────────────────────────────────────────
Write-Step "Checking service status..."
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($svc) {
    if ($svc.Status -eq "Running") {
        Write-Step "Stopping service '$ServiceName'..."
        Stop-Service -Name $ServiceName -Force
        Write-Host "   Service stopped." -ForegroundColor Green
    } else {
        Write-Host "   Service exists but is already stopped." -ForegroundColor Yellow
    }
} else {
    Write-Host "   Service '$ServiceName' not found (already removed?)." -ForegroundColor Yellow
}

# ── 2. Uninstall the MSI ─────────────────────────────────────────
Write-Step "Uninstalling MSI..."
if (Test-Path $MsiPath) {
    $proc = Start-Process msiexec -ArgumentList '/x', "`"$MsiPath`"", '/quiet' -Wait -PassThru
    if ($proc.ExitCode -eq 0) {
        Write-Host "   MSI uninstalled successfully." -ForegroundColor Green
    } else {
        Write-Host "   msiexec exited with code $($proc.ExitCode)" -ForegroundColor Yellow
        Write-Host "   (This may be OK if the product was already uninstalled)" -ForegroundColor Yellow
    }
} else {
    Write-Host "   MSI not found at: $MsiPath" -ForegroundColor Yellow
    Write-Host "   Attempting to remove service registration directly..." -ForegroundColor Yellow
    sc.exe delete $ServiceName 2>$null
}

# ── 3. Verify cleanup ────────────────────────────────────────────
Write-Step "Verifying cleanup..."

$svcCheck = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svcCheck) {
    Write-Host "   WARNING: Service still exists!" -ForegroundColor Red
} else {
    Write-Host "   Service removed." -ForegroundColor Green
}

if (Test-Path $InstallDir) {
    Write-Host "   WARNING: Install directory still exists: $InstallDir" -ForegroundColor Red
} else {
    Write-Host "   Install directory removed." -ForegroundColor Green
}

# ── Done ──────────────────────────────────────────────────────────
Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  Uninstall complete!" -ForegroundColor Green
Write-Host "============================================`n" -ForegroundColor Green

Read-Host "Press Enter to close"

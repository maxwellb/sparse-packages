<#
.SYNOPSIS
    Creates a self-signed code-signing certificate for local development/testing
    of sparse packages.

.DESCRIPTION
    Generates a self-signed certificate, exports the public key as a .cer file
    (safe to commit), and exports the full key pair as a .pfx file (keep secret,
    never commit).

    The certificate Subject must match the Publisher value in every
    AppxManifest.xml that will be signed with this cert.

.PARAMETER Subject
    The certificate Subject string (CN=...).  Must match the Publisher field
    in AppxManifest.xml.  Default: "CN=Developer".

.PARAMETER FriendlyName
    Human-readable label shown in the certificate store.

.PARAMETER PfxPassword
    Password used to protect the exported .pfx file.  Will be prompted
    interactively if not supplied.

.PARAMETER OutDir
    Directory where DevCert.cer and DevCert.pfx are written.
    Default: repo root (current directory).

.EXAMPLE
    # Interactive — prompts for PFX password
    .\New-DevCertificate.ps1

.EXAMPLE
    # With explicit subject matching your AppxManifest.xml Publisher
    .\New-DevCertificate.ps1 -Subject "CN=My Dev Cert, O=MyOrg"
#>
[CmdletBinding()]
param(
    [string] $Subject     = 'CN=Developer',
    [string] $FriendlyName = 'Sparse Packages Dev Certificate',
    [SecureString] $PfxPassword,
    [string] $OutDir      = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Prompt for password if not supplied -------------------------------------------
if (-not $PfxPassword) {
    $PfxPassword = Read-Host -AsSecureString `
        'Enter a password to protect the .pfx file (do NOT commit the .pfx)'
}

$cerPath = Join-Path $OutDir 'DevCert.cer'
$pfxPath = Join-Path $OutDir 'DevCert.pfx'

Write-Host "Creating self-signed certificate: $Subject" -ForegroundColor Cyan

$cert = New-SelfSignedCertificate `
    -Type           CodeSigningCert `
    -Subject        $Subject `
    -FriendlyName   $FriendlyName `
    -CertStoreLocation Cert:\CurrentUser\My `
    -HashAlgorithm  SHA256 `
    -NotAfter       (Get-Date).AddYears(3)

Write-Host "  Thumbprint : $($cert.Thumbprint)"
Write-Host "  Subject    : $($cert.Subject)"
Write-Host "  Expires    : $($cert.NotAfter)"

# --- Export public key (.cer) — safe to commit ------------------------------------
Export-Certificate -Cert $cert -FilePath $cerPath -Type CERT | Out-Null
Write-Host ""
Write-Host "Public certificate written to: $cerPath" -ForegroundColor Green
Write-Host "  --> This file is safe to commit to the repository."

# --- Export private key (.pfx) — keep secret, never commit -----------------------
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $PfxPassword | Out-Null
Write-Host ""
Write-Host "Private key bundle written to: $pfxPath" -ForegroundColor Yellow
Write-Host "  --> Keep this file secret. It is excluded by .gitignore."

# --- Trust the certificate on this machine ----------------------------------------
$addTrust = Read-Host `
    'Add the certificate to the Trusted Root store on this machine? [y/N]'
if ($addTrust -match '^[Yy]') {
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
        [System.Security.Cryptography.X509Certificates.StoreName]::Root,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
    )
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $store.Add($cert)
    $store.Close()
    Write-Host "Certificate added to LocalMachine\Root." -ForegroundColor Green
    Write-Host "  Packages signed with DevCert.pfx will now install without warnings."
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. Update the Publisher field in each AppxManifest.xml to: $Subject"
Write-Host "  2. Run .\Build-Packages.ps1 -PfxPath DevCert.pfx to build and sign packages."

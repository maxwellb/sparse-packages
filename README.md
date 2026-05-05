# sparse-packages

Windows [Sparse Packages][sparse-pkg-docs] that register custom
[App Execution Aliases][aea-docs] for traditionally-installed software.

Each subfolder is an independent sparse package containing a single
`AppxManifest.xml` (and required logo assets).  Packages are built with
`MakeAppx.exe` and signed with either a local development certificate or
[Azure Trusted Signing][ats-docs] for production releases.

## Why Sparse Packages?

Some installers (e.g. Git for Windows) place executables in `PATH` but do
not register an App Execution Alias, so tools like the Windows Run dialog or
certain shell integrations cannot resolve them by short name.  A sparse
package solves this without re-installing or patching the original software —
it simply registers an alias alongside the existing installation.

**Example:** `bash.exe` → `C:\Program Files\Git\usr\bin\bash.exe`

## Repository layout

```
sparse-packages/
├── .github/
│   └── workflows/
│       └── build.yml           # CI: build + Azure Trusted Signing on main
├── git-bash/
│   ├── AppxManifest.xml        # Registers bash.exe alias for Git for Windows
│   └── Assets/
│       ├── Square44x44Logo.png
│       ├── Square150x150Logo.png
│       └── StoreLogo.png
├── Build-Packages.ps1          # Local build + sign helper
├── New-DevCertificate.ps1      # Create a self-signed dev certificate
└── README.md
```

Add a new package by creating a new subdirectory with its own
`AppxManifest.xml` (and `Assets\` folder).  The build scripts and workflow
will pick it up automatically.

## Prerequisites

| Tool | Where to get it |
|------|----------------|
| **MakeAppx.exe** | [Windows SDK][sdk] (included with Visual Studio) |
| **SignTool.exe** | Windows SDK (same installer) |
| **PowerShell 5.1+** | Built into Windows 10/11 |

For production signing you also need an
[Azure Trusted Signing][ats-docs] account.

## Quick start — local development

### 1 — Create a self-signed development certificate

```powershell
.\New-DevCertificate.ps1
```

This creates `DevCert.cer` (public key, safe to commit) and `DevCert.pfx`
(private key, excluded by `.gitignore`).

> **Important:** update the `Publisher` field in each `AppxManifest.xml` to
> match the Subject of the certificate you just created (default:
> `CN=Developer`).

### 2 — Build and sign all packages

```powershell
.\Build-Packages.ps1 -PfxPath DevCert.pfx
```

Signed `.msix` files are written to `_output\`.

### 3 — Install a package

```powershell
# Requires Developer Mode OR the signing certificate trusted on the machine.
Add-AppxPackage -Path _output\git-bash.msix
```

To uninstall:

```powershell
Get-AppxPackage -Name GitBash.AliasPackage | Remove-AppxPackage
```

## Adding a new alias package

1. Create a new subdirectory (e.g. `my-tool\`).
2. Copy `git-bash\AppxManifest.xml` into it and update:
   - `Identity Name` — unique reverse-DNS style name, e.g. `MyTool.AliasPackage`
   - `Executable` attributes — absolute path to the target binary
   - `desktop:ExecutionAlias Alias` — the short name to register (e.g. `mytool.exe`)
   - Display names and description strings
3. Add or replace the placeholder logo images in `Assets\` (see sizes below).
4. Run `.\Build-Packages.ps1 -PfxPath DevCert.pfx` and test locally.

### Required asset sizes

| File | Dimensions |
|------|-----------|
| `Assets\StoreLogo.png` | 50 × 50 px |
| `Assets\Square44x44Logo.png` | 44 × 44 px |
| `Assets\Square150x150Logo.png` | 150 × 150 px |

## CI / CD (GitHub Actions)

The workflow in `.github/workflows/build.yml`:

- **Pull requests** — builds all packages to verify the manifests are valid.
- **Push to `main`** — builds and signs packages via Azure Trusted Signing,
  then uploads the signed `.msix` files as workflow artifacts.

### Required GitHub secrets for production signing

| Secret | Description |
|--------|-------------|
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_CLIENT_ID` | Service principal / managed identity client ID |
| `AZURE_CLIENT_SECRET` | Service principal secret |
| `AZURE_TRUSTED_SIGNING_ENDPOINT` | e.g. `https://eus.codesigning.azure.net` |
| `AZURE_TRUSTED_SIGNING_ACCOUNT` | Trusted Signing account name |
| `AZURE_TRUSTED_SIGNING_PROFILE` | Certificate profile name |

See the [Azure Trusted Signing documentation][ats-docs] for how to create
and configure these resources.

## Sparse package requirements

- Windows 10 version 2004 (build 19041) or later is required to register
  sparse packages.
- The target executable **must already exist** at the path specified in
  `AppxManifest.xml` when the package is installed.
- The `Publisher` in `Identity` must **exactly match** the Subject CN of the
  signing certificate.

[sparse-pkg-docs]: https://learn.microsoft.com/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps
[aea-docs]: https://learn.microsoft.com/windows/apps/desktop/modernize/app-execution-alias
[ats-docs]: https://learn.microsoft.com/azure/trusted-signing/
[sdk]: https://developer.microsoft.com/windows/downloads/windows-sdk/

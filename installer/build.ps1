# build.ps1 — compila o instalador .exe do teclado UKPTES.
#
#   powershell -ExecutionPolicy Bypass -File installer\build.ps1
#
# Saida: dist\UKPTES-Setup-<versao>.exe
#
# Antes de compilar, garante que o .iss e os .ps1 estao em UTF-8 COM BOM.
# Sem BOM, o Windows PowerShell 5.1 e o compilador do Inno leem os arquivos
# como ANSI e os acentos vao corrompidos para o registro ("PortuguÃªs").

[CmdletBinding()]
param(
    # Caminho do ISCC.exe, se estiver fora dos lugares padrao.
    [string] $Iscc
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$iss  = Join-Path $here 'UKPTES.iss'

# --------------------------------------------------------------------------
# 1. localiza o ISCC.exe
# --------------------------------------------------------------------------
if (-not $Iscc) {
    $candidatos = @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )
    $Iscc = $candidatos | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $Iscc -or -not (Test-Path $Iscc)) {
    Write-Host 'ISCC.exe (Inno Setup 6) nao encontrado.' -ForegroundColor Red
    Write-Host 'Instale com:  winget install JRSoftware.InnoSetup' -ForegroundColor Yellow
    exit 1
}
Write-Host "Compilador: $Iscc" -ForegroundColor Cyan

# --------------------------------------------------------------------------
# 2. garante UTF-8 com BOM nos arquivos de texto do instalador
# --------------------------------------------------------------------------
function Confirm-Bom {
    param([string] $Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $temBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    if ($temBom) {
        Write-Host "  BOM ok:      $(Split-Path -Leaf $Path)" -ForegroundColor DarkGray
        return
    }

    # le como UTF-8 (sem BOM) e regrava com BOM
    $texto = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($Path, $texto, (New-Object Text.UTF8Encoding $true))
    Write-Host "  BOM added:   $(Split-Path -Leaf $Path)" -ForegroundColor Yellow
}

Write-Host 'Conferindo encoding (UTF-8 com BOM):' -ForegroundColor Cyan
Get-ChildItem $here -Include '*.iss', '*.ps1' -Recurse | ForEach-Object { Confirm-Bom $_.FullName }

# --------------------------------------------------------------------------
# 3. confere se as DLLs existem
# --------------------------------------------------------------------------
$dlls = 'UKPTES_amd64.dll', 'UKPTES_arm64.dll', 'UKPTES_wow64.dll'
$faltando = $dlls | Where-Object { -not (Test-Path (Join-Path $root "bin\$_")) }
if ($faltando) {
    Write-Host "DLLs faltando em bin\: $($faltando -join ', ')" -ForegroundColor Red
    exit 1
}

# --------------------------------------------------------------------------
# 4. compila
# --------------------------------------------------------------------------
$dist = Join-Path $root 'dist'
if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }

Write-Host ''
& $Iscc $iss
if ($LASTEXITCODE -ne 0) {
    Write-Host "Falha na compilacao (codigo $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host ''
Get-ChildItem $dist -Filter '*.exe' | ForEach-Object {
    Write-Host ('OK: {0}  ({1:N0} KB)' -f $_.FullName, ($_.Length / 1KB)) -ForegroundColor Green
}

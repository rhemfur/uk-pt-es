# reparar-teclado.ps1 — conserta o teclado UKPTES depois de uma atualizacao
# grande do Windows.
#
# O problema classico: updates de versao do Windows 11 apagam DLLs de terceiros
# do System32. O registro continua intacto, entao o teclado aparece na lista mas
# nao funciona (ou some). A correcao e so recopiar a DLL.
#
# Este script fica em {app} junto com uma copia das DLLs (bin\). Roda pelo
# atalho "Reparar teclado" no menu Iniciar, ou direto:
#   powershell -ExecutionPolicy Bypass -File .\reparar-teclado.ps1
#
# Mensagens em ASCII de proposito (ver comentario em configurar-teclado.ps1).

$ErrorActionPreference = 'Stop'

# --- autoeleva se nao for admin ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($MyInvocation.MyCommand.Path)`""
    )
    exit
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$bin  = Join-Path $here 'bin'

# --- detecta a arquitetura NATIVA (correto mesmo sob emulacao x64 em ARM64) ---
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NativeArch {
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern bool IsWow64Process2(IntPtr hProcess, out ushort pProcessMachine, out ushort pNativeMachine);
  [DllImport("kernel32.dll")]
  public static extern IntPtr GetCurrentProcess();
  public static ushort Native() { ushort p, n; IsWow64Process2(GetCurrentProcess(), out p, out n); return n; }
}
'@

$native = [NativeArch]::Native()   # 0xAA64 = ARM64, 0x8664 = x64
switch ($native) {
    0xAA64  { $nativeDll = Join-Path $bin 'UKPTES_arm64.dll'; $archName = 'ARM64' }
    0x8664  { $nativeDll = Join-Path $bin 'UKPTES_amd64.dll'; $archName = 'x64'   }
    default {
        Write-Host ('Arquitetura nao suportada: 0x{0:X}' -f $native) -ForegroundColor Red
        Read-Host 'Pressione Enter para fechar'
        exit 1
    }
}

if (-not (Test-Path $nativeDll)) {
    Write-Host "DLL nao encontrada: $nativeDll" -ForegroundColor Red
    Write-Host 'Reinstale o teclado pelo instalador (.exe).' -ForegroundColor Yellow
    Read-Host 'Pressione Enter para fechar'
    exit 1
}

Write-Host "Arquitetura detectada: $archName" -ForegroundColor Cyan

# --- tira pendencias de boot que apagariam a DLL que vamos copiar ---
$limpar = Join-Path $here 'limpar-pendencias.ps1'
if (Test-Path $limpar) { & $limpar }

# --- recopia as DLLs ---
Copy-Item $nativeDll (Join-Path $env:SystemRoot 'System32\UKPTES.dll') -Force
Copy-Item (Join-Path $bin 'UKPTES_wow64.dll') (Join-Path $env:SystemRoot 'SysWOW64\UKPTES.dll') -Force
Write-Host 'DLLs recopiadas para System32 e SysWOW64.' -ForegroundColor Green

# --- confere o registro; se o update tambem apagou a chave, avisa ---
$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a0000809'
if (-not (Test-Path $key)) {
    Write-Host 'A chave de registro do layout sumiu. Rode o instalador (.exe) de novo.' -ForegroundColor Yellow
}
else {
    Write-Host 'Registro do layout: OK.' -ForegroundColor Green
}

# --- garante que a conta atual ainda tem o teclado na lista ---
$config = Join-Path $here 'configurar-teclado.ps1'
if (Test-Path $config) {
    & $config -Mode Install -Klid 'a0000809'
}

Write-Host ''
Write-Host 'Pronto. Saia da conta e entre de novo para aplicar.' -ForegroundColor Green
Read-Host 'Pressione Enter para fechar'

# Instala o teclado "Reino Unido - Português e Espanhol" no Windows ARM64
# (Surface Laptop 7 / Snapdragon) e o define como ÚNICO teclado da conta
# atual (+ tela de logon e contas novas).
#
# Como usar: botão direito neste arquivo > "Run with PowerShell".
# Ele pede elevação (UAC) sozinho. Depois, saia da conta e entre de novo.
#
# Requisitos: Windows ARM64. Usa UKPTES_arm64.dll (nativa) no System32 e
# UKPTES_wow64.dll (x86) no SysWOW64 para apps de 32-bit emulados.
# Para Windows x64 (Intel/AMD) use o instalar-teclado.ps1 normal.

$ErrorActionPreference = 'Stop'

# autoeleva se não for admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$($MyInvocation.MyCommand.Path)`""
    exit
}

# Detecta a arquitetura NATIVA do hardware via IsWow64Process2 (funciona mesmo
# quando o PowerShell roda emulado em x64 sobre ARM64).
$sig = @"
using System;
using System.Runtime.InteropServices;
public static class NativeArch {
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern bool IsWow64Process2(IntPtr hProcess, out ushort pProcessMachine, out ushort pNativeMachine);
  [DllImport("kernel32.dll")]
  public static extern IntPtr GetCurrentProcess();
  public static ushort Native() {
    ushort proc, native;
    IsWow64Process2(GetCurrentProcess(), out proc, out native);
    return native;
  }
}
"@
Add-Type -TypeDefinition $sig
$native = [NativeArch]::Native()   # 0xAA64 = ARM64, 0x8664 = x64, 0x14c = x86
if ($native -ne 0xAA64) {
    Write-Host ("Este script é só para Windows ARM64. Máquina nativa detectada: 0x{0:X}." -f $native) -ForegroundColor Red
    Write-Host "Em Windows x64 (Intel/AMD) use o instalar-teclado.ps1 normal." -ForegroundColor Yellow
    Read-Host "Pressione Enter para fechar"
    exit 1
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# as DLLs vivem em ..\bin (layout do repositório); cai para $here se estiverem juntas
$bin = Join-Path (Split-Path -Parent $here) 'bin'
if (-not (Test-Path $bin)) { $bin = $here }

# 1. copia as DLLs (ARM64 nativa no System32; x86 no SysWOW64 p/ apps 32-bit emulados)
Copy-Item "$bin\UKPTES_arm64.dll" 'C:\Windows\System32\UKPTES.dll' -Force
Copy-Item "$bin\UKPTES_wow64.dll" 'C:\Windows\SysWOW64\UKPTES.dll' -Force

# 2. registra o layout (KLID a0000809)
$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a0000809'
New-Item -Path $key -Force | Out-Null
Set-ItemProperty $key -Name 'Layout Text' -Value 'Reino Unido - Português e Espanhol'
Set-ItemProperty $key -Name 'Layout File' -Value 'UKPTES.dll'
Set-ItemProperty $key -Name 'Layout Id' -Value '00c1'
Set-ItemProperty $key -Name 'Layout Display Name' -Value '@%SystemRoot%\system32\UKPTES.dll,-1000'

# 3. define como único teclado da conta atual (idioma English UK)
$l = New-WinUserLanguageList en-GB
$l[0].InputMethodTips.Clear()
$l[0].InputMethodTips.Add('0809:A0000809')
Set-WinUserLanguageList $l -Force

# 4. copia para a tela de logon e contas novas
try { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true } catch {}

Write-Host ""
Write-Host "Pronto (ARM64)! Saia da conta e entre de novo para aplicar." -ForegroundColor Green
Read-Host "Pressione Enter para fechar"

# Instala o teclado "Reino Unido - Português e Espanhol" (UKPTES) e REMOVE todos
# os outros idiomas de ENTRADA / teclados do Windows, deixando SOMENTE o UKPTES.
#
# O que faz (na conta onde roda + tela de logon + contas novas):
#   - detecta a arquitetura (ARM64 ou x64) e copia a DLL certa;
#   - registra o layout (KLID a0000809);
#   - zera a lista de idiomas de entrada -> apenas en-GB com APENAS o UKPTES;
#   - limpa restos de teclados no registro (Preload / Substitutes).
#
# NÃO mexe no idioma de EXIBIÇÃO do Windows (menus continuam como estão) nem
# desinstala pacotes de idioma. Só teclados/idiomas de entrada.
#
# É por CONTA: se houver outras contas de usuário na máquina, rode em cada uma.
# Como usar: botão direito > "Run with PowerShell". Autoeleva (UAC). Depois
# saia da conta e entre de novo.
#
# Reverter: Configurações > Hora e Idioma > Idioma e região > Adicionar idioma
# (ou reinstale os idiomas que quiser de volta).

$ErrorActionPreference = 'Stop'

# --- autoeleva se não for admin ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$($MyInvocation.MyCommand.Path)`""
    exit
}

# --- detecta arquitetura NATIVA (funciona mesmo sob emulação x64 no ARM64) ---
$sig = @"
using System;
using System.Runtime.InteropServices;
public static class NativeArch {
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern bool IsWow64Process2(IntPtr hProcess, out ushort pProcessMachine, out ushort pNativeMachine);
  [DllImport("kernel32.dll")]
  public static extern IntPtr GetCurrentProcess();
  public static ushort Native() { ushort p, n; IsWow64Process2(GetCurrentProcess(), out p, out n); return n; }
}
"@
Add-Type -TypeDefinition $sig
$native = [NativeArch]::Native()   # 0xAA64 = ARM64, 0x8664 = x64

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# as DLLs vivem em ..\bin (layout do repositório); cai para $here se estiverem juntas
$bin = Join-Path (Split-Path -Parent $here) 'bin'
if (-not (Test-Path $bin)) { $bin = $here }
switch ($native) {
    0xAA64 { $nativeDll = "$bin\UKPTES_arm64.dll"; $archName = 'ARM64' }
    0x8664 { $nativeDll = "$bin\UKPTES_amd64.dll"; $archName = 'x64'   }
    default {
        Write-Host ("Arquitetura nativa nao suportada: 0x{0:X}" -f $native) -ForegroundColor Red
        Read-Host "Pressione Enter para fechar"; exit 1
    }
}
if (-not (Test-Path $nativeDll)) {
    Write-Host "DLL nao encontrada: $nativeDll" -ForegroundColor Red
    Read-Host "Pressione Enter para fechar"; exit 1
}
Write-Host "Arquitetura detectada: $archName" -ForegroundColor Cyan

# --- 1. copia as DLLs ---
Copy-Item $nativeDll 'C:\Windows\System32\UKPTES.dll' -Force            # nativa
Copy-Item "$bin\UKPTES_wow64.dll" 'C:\Windows\SysWOW64\UKPTES.dll' -Force  # x86 p/ apps 32-bit

# --- 2. registra o layout (KLID a0000809) ---
$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a0000809'
New-Item -Path $key -Force | Out-Null
Set-ItemProperty $key -Name 'Layout Text' -Value 'Reino Unido - Português e Espanhol'
Set-ItemProperty $key -Name 'Layout File' -Value 'UKPTES.dll'
Set-ItemProperty $key -Name 'Layout Id' -Value '00c1'
Set-ItemProperty $key -Name 'Layout Display Name' -Value '@%SystemRoot%\system32\UKPTES.dll,-1000'

# --- 3. zera a lista de idiomas de entrada: SOMENTE en-GB com SOMENTE o UKPTES ---
$l = New-WinUserLanguageList en-GB
$l[0].InputMethodTips.Clear()
$l[0].InputMethodTips.Add('0809:A0000809')
Set-WinUserLanguageList $l -Force

# --- 4. limpa restos de teclados no registro do usuario atual ---
# Preload = so o nosso KLID; remove Substitutes (mapeamentos de layouts antigos)
try {
    $preload = 'HKCU:\Keyboard Layout\Preload'
    if (Test-Path $preload) { Remove-Item $preload -Recurse -Force }
    New-Item -Path $preload -Force | Out-Null
    Set-ItemProperty $preload -Name '1' -Value 'a0000809'

    $subs = 'HKCU:\Keyboard Layout\Substitutes'
    if (Test-Path $subs) {
        Get-Item $subs | Select-Object -ExpandProperty Property | ForEach-Object {
            Remove-ItemProperty -Path $subs -Name $_ -ErrorAction SilentlyContinue
        }
    }
} catch { Write-Host "Aviso: limpeza de registro parcial: $_" -ForegroundColor Yellow }

# --- 5. propaga para a tela de logon e contas novas ---
try { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true } catch {}

Write-Host ""
Write-Host "Pronto! So o teclado 'Reino Unido - Portugues e Espanhol' ficou ($archName)." -ForegroundColor Green
Write-Host "Saia da conta e entre de novo para aplicar." -ForegroundColor Green
Read-Host "Pressione Enter para fechar"

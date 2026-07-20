# Instala o teclado "Reino Unido - Português e Espanhol" e o define como
# ÚNICO teclado da conta atual (+ tela de logon e contas novas).
#
# Como usar: botão direito neste arquivo > "Run with PowerShell".
# Ele pede elevação (UAC) sozinho. Depois, saia da conta e entre de novo.
#
# Requisitos: Windows x64 (Intel/AMD). Para ARM (Surface Snapdragon) é
# preciso compilar a DLL ARM64 a partir da pasta src\ — não use este script lá.

$ErrorActionPreference = 'Stop'

# autoeleva se não for admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$($MyInvocation.MyCommand.Path)`""
    exit
}

if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
    Write-Host "Este script é só para Windows x64 (Intel/AMD). Detectado: $env:PROCESSOR_ARCHITECTURE" -ForegroundColor Red
    Read-Host "Pressione Enter para fechar"
    exit 1
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# as DLLs vivem em ..\bin (layout do repositório); cai para $here se estiverem juntas
$bin = Join-Path (Split-Path -Parent $here) 'bin'
if (-not (Test-Path $bin)) { $bin = $here }

# 1. copia as DLLs
Copy-Item "$bin\UKPTES_amd64.dll" 'C:\Windows\System32\UKPTES.dll' -Force
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
Write-Host "Pronto! Saia da conta e entre de novo para aplicar." -ForegroundColor Green
Read-Host "Pressione Enter para fechar"

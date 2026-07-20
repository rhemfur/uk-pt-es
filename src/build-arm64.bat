@echo off
REM Compila UKPTES.dll NATIVA ARM64 a partir desta pasta src\.
REM Usado em jul/2026 no Surface Laptop 7 (Snapdragon) — gerou UKPTES_arm64.dll.
REM
REM Requisito: VS Build Tools 2022 com o componente ARM64 + Windows SDK:
REM   winget install --id Microsoft.VisualStudio.2022.BuildTools --override ^
REM     "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools ^
REM      --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 ^
REM      --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended"
REM
REM O kbd.h vem no proprio Windows SDK (Include\<ver>\um\kbd.h) — nao precisa do WDK.
REM Warnings LNK4070 e LNK4254 sao esperados e inofensivos.
REM
REM Uso: dar duplo clique ou rodar num cmd. Gera UKPTES_arm64.dll nesta pasta;
REM copiar para a pasta de cima e rodar o instalador.

setlocal
set VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat
if not exist "%VCVARS%" (
  echo ERRO: vcvarsall.bat nao encontrado em:
  echo   %VCVARS%
  echo Instale o VS Build Tools com o componente ARM64 ^(veja o cabecalho deste arquivo^).
  pause & exit /b 1
)
call "%VCVARS%" arm64
if errorlevel 1 (echo ERRO ao inicializar o ambiente ARM64 & pause & exit /b 1)

cd /d "%~dp0"

echo === Compilando (cl) ===
cl /nologo /c /W3 /DNOGDICAPMASKS /DNOWINMESSAGES /DNOWINSTYLES /DNOSYSMETRICS /DNOMENUS /DNOICONS /DNOSYSCOMMANDS /DNORASTEROPS /DNOSHOWWINDOW /DOEMRESOURCE /DNOATOM /DNOCLIPBOARD /DNOCOLOR /DNOCTLMGR /DNODRAWTEXT /DNOGDI /DNOKERNEL /DNONLS /DNOMB /DNOMEMMGR /DNOMETAFILE /DNOMINMAX /DNOMSG /DNOOPENFILE /DNOSCROLL /DNOSERVICE /DNOSOUND /DNOTEXTMETRIC /DNOWINOFFSETS /DNOWH /DNOCOMM /DNOKANJI /DNOHELP /DNOPROFILER /DNODEFERWINDOWPOS /DNOMCX /DROOT_HAS_ALTGR UKPTES.C
if errorlevel 1 (echo ERRO no cl & pause & exit /b 1)

echo === Recursos (rc) ===
rc /nologo UKPTES.RC
if errorlevel 1 (echo ERRO no rc & pause & exit /b 1)

echo === Linkando (link) ===
link /NOLOGO /DLL /NOENTRY /DEF:UKPTES.DEF /SUBSYSTEM:NATIVE /MERGE:.rdata=.data /MACHINE:ARM64 UKPTES.obj UKPTES.res /OUT:UKPTES_arm64.dll
if errorlevel 1 (echo ERRO no link & pause & exit /b 1)

echo.
echo === OK: UKPTES_arm64.dll gerada ===
echo Copie-a para a pasta de cima e rode instalar-apenas-ukptes.ps1
pause
endlocal

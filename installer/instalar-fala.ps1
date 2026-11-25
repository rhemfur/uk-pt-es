# instalar-fala.ps1 — instala o reconhecimento de voz em Portugues (Brasil),
# para o ditado do Windows (Win+H) funcionar sem pedir para "instalar o idioma".
#
# Chamado pelo instalador (UKPTES.iss) quando a opcao de ditado esta marcada.
# Precisa de administrador e de internet: os componentes sao "Features on
# Demand" da Microsoft, baixados do Windows Update. Nao da para embuti-los no
# .exe (sao especificos de cada versao do Windows e nao sao redistribuiveis).
#
# Instala SO os componentes de entrada/fala. NAO instala o pacote de exibicao,
# entao os menus do Windows continuam no idioma atual.
#
#   Language.Basic   ortografia e base do idioma (pre-requisito da fala)
#   Language.Speech  reconhecimento de voz (o que o Win+H usa)
#
# Nunca falha o instalador: se nao houver internet, registra no log e sai com
# 0 — o Windows oferece o download sozinho na primeira vez que voce ditar.
#
# Mensagens em ASCII de proposito (ver comentario em configurar-teclado.ps1).

[CmdletBinding()]
param(
    [string] $Language = 'pt-BR',

    # Se algum componente pedir reinicio, este arquivo e criado. O instalador
    # (NeedRestart no UKPTES.iss) ve o arquivo e oferece reiniciar no final.
    [string] $RestartFlag = ''
)

$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'ukptes-configurar.log'

function Write-Log {
    param([string] $Message)
    $line = '{0}  [fala] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch { }
}

Write-Log "=== Instalando reconhecimento de voz $Language ==="

$capabilities = @(
    "Language.Basic~~~$Language~0.0.1.0",
    "Language.Speech~~~$Language~0.0.1.0"
)

foreach ($name in $capabilities) {
    try {
        $cap = Get-WindowsCapability -Online -Name $name
        if (-not $cap -or -not $cap.Name) {
            Write-Log "$name nao existe nesta versao do Windows; pulado."
            continue
        }
        if ($cap.State -eq 'Installed') {
            Write-Log "$name ja instalado."
            continue
        }
        Write-Log "Baixando e instalando $name (pode levar alguns minutos)..."
        $r = Add-WindowsCapability -Online -Name $name
        Write-Log ("{0}: instalado. Reinicio necessario: {1}" -f $name, $r.RestartNeeded)
        if ($r.RestartNeeded -and $RestartFlag) {
            try { Set-Content -Path $RestartFlag -Value $name } catch { }
        }
    }
    catch {
        Write-Log "Aviso: nao foi possivel instalar ${name}: $_"
    }
}

Write-Log '=== Fim (fala) ==='
exit 0

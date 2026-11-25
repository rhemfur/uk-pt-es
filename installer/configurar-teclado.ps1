# configurar-teclado.ps1 — parte "por usuario" da instalacao do UKPTES.
#
# Chamado pelo instalador (UKPTES.iss). Nao precisa ser rodado a mao:
# o .exe cuida de copiar as DLLs e escrever o registro do sistema; este
# script so mexe na lista de idiomas de ENTRADA da conta atual.
#
#   -Mode Install    adiciona o UKPTES a conta (e opcionalmente remove os outros)
#   -Mode Uninstall  remove o UKPTES da conta, garantindo que sobre algum teclado
#   -RemoveOthers    (so com Install) deixa SOMENTE o UKPTES
#   -Ditado          (so com Install) o UKPTES fica sob o idioma Portugues
#                    (Brasil) em vez de Ingles (Reino Unido). O teclado e o
#                    mesmo; muda so o idioma de entrada, que e o que o ditado
#                    do Windows (Win+H) usa para reconhecer a voz.
#   -Klid            KLID do layout, em minusculas (padrao: a0000809)
#
# Por que um idioma so: com dois idiomas (pt-BR + en-GB) o Windows mostra o
# indicador "POR/ENG" na barra de tarefas e o Win+Espaco troca entre eles.
# Com -Ditado -RemoveOthers a conta fica com UM idioma e UM teclado, entao
# nao aparece indicador nenhum e o Win+H dita direto em portugues.
#
# Mensagens sao ASCII de proposito: o Windows PowerShell 5.1 le .ps1 sem BOM
# como ANSI e corrompe acentos. O texto acentuado que vai pro registro
# ("Reino Unido - Portugues e Espanhol") e escrito pelo Inno Setup, nao aqui.

[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall')]
    [string] $Mode = 'Install',

    [switch] $RemoveOthers,

    [switch] $Ditado,

    [string] $Klid = 'a0000809'
)

$ErrorActionPreference = 'Stop'

# Tip = "<idioma em hex>:<KLID em maiusculas>". en-GB = 0809, pt-BR = 0416.
$klidUpper   = $Klid.ToUpperInvariant()
$tipGb       = '0809:{0}' -f $klidUpper
$tipBr       = '0416:{0}' -f $klidUpper
$allTips     = @($tipGb, $tipBr)
if ($Ditado) { $langTag = 'pt-BR'; $tip = $tipBr }
else         { $langTag = 'en-GB'; $tip = $tipGb }
$log         = Join-Path $env:TEMP 'ukptes-configurar.log'

function Write-Log {
    param([string] $Message)
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch { }
}

Write-Log "=== Mode=$Mode RemoveOthers=$RemoveOthers Ditado=$Ditado Klid=$Klid Tip=$tip ==="
Write-Log "Conta: $env:USERNAME"

# Nota: a limpeza de PendingFileRenameOperations fica em limpar-pendencias.ps1,
# chamado pelo instalador la no InitializeSetup — precisa acontecer ANTES de o
# Inno decidir que ha reinicio pendente e abortar.

# --------------------------------------------------------------------------
# 0. idioma de exibicao (menus) nao pode mudar
# --------------------------------------------------------------------------
# Sem override, o Windows usa como idioma dos menus o primeiro idioma da lista
# que tenha pacote de exibicao. Trocar en-GB por pt-BR poderia mudar os menus
# no proximo logon. Fixamos o idioma de exibicao atual antes de mexer na lista.
if ($Mode -eq 'Install') {
    try {
        $override = Get-WinUILanguageOverride
        if (-not $override) {
            $ui = (Get-UICulture).Name
            Set-WinUILanguageOverride -Language $ui
            Write-Log "Idioma de exibicao fixado em $ui (para os menus nao mudarem)."
        }
        else {
            Write-Log ('Idioma de exibicao ja fixado em {0}; mantido.' -f $override.Name)
        }
    }
    catch {
        Write-Log "Aviso: nao foi possivel fixar o idioma de exibicao: $_"
    }
}

# --------------------------------------------------------------------------
# 1. lista de idiomas de entrada da conta
# --------------------------------------------------------------------------
if ($Mode -eq 'Install') {

    if ($RemoveOthers) {
        # Zera tudo: um idioma so, e dentro dele so o nosso layout.
        $list = New-WinUserLanguageList $langTag
        $list[0].InputMethodTips.Clear()
        $list[0].InputMethodTips.Add($tip)
        Write-Log "Lista zerada: somente $langTag com o UKPTES."
    }
    else {
        # Preserva o que ja existe e apenas acrescenta o nosso layout ao idioma.
        $list = Get-WinUserLanguageList
        $lang = $list | Where-Object { $_.LanguageTag -eq $langTag } | Select-Object -First 1
        if (-not $lang) {
            $novo = New-WinUserLanguageList $langTag
            $novo[0].InputMethodTips.Clear()
            $novo[0].InputMethodTips.Add($tip)
            if ($Ditado) { $list.Insert(0, $novo[0]) } else { $list.Add($novo[0]) }
            Write-Log "Idioma $langTag nao existia na conta; adicionado com o UKPTES."
        }
        elseif ($lang.InputMethodTips -notcontains $tip) {
            $lang.InputMethodTips.Insert(0, $tip)
            Write-Log "UKPTES adicionado ao $langTag (outros teclados preservados)."
        }
        else {
            Write-Log 'UKPTES ja estava na lista; nada a fazer.'
        }

        # Com ditado, pt-BR vai para o topo: e o idioma que o Win+H usa por padrao.
        if ($Ditado -and $list[0].LanguageTag -ne $langTag) {
            $item = $list | Where-Object { $_.LanguageTag -eq $langTag } | Select-Object -First 1
            [void] $list.Remove($item)
            $list.Insert(0, $item)
            Write-Log "$langTag movido para o primeiro lugar da lista."
        }
    }
}
else {
    # Uninstall: tira os nossos tips (en-GB e pt-BR) de todos os idiomas e
    # limpa os idiomas que ficaram vazios.
    $list = Get-WinUserLanguageList

    foreach ($lang in $list) {
        foreach ($t in $allTips) {
            while ($lang.InputMethodTips -contains $t) {
                [void] $lang.InputMethodTips.Remove($t)
            }
        }
    }
    for ($i = $list.Count - 1; $i -ge 0; $i--) {
        if ($list[$i].InputMethodTips.Count -eq 0) {
            Write-Log ('Idioma {0} ficou sem teclado; removido.' -f $list[$i].LanguageTag)
            $list.RemoveAt($i)
        }
    }

    # Nunca deixar a conta sem teclado nenhum.
    if ($list.Count -eq 0) {
        $list = New-WinUserLanguageList en-GB
        Write-Log 'Nao sobrou nenhum teclado; restaurado o UK padrao (en-GB).'
    }
}

Set-WinUserLanguageList $list -Force
Write-Log ('InputMethodTips agora: {0}' -f (($list | ForEach-Object { $_.InputMethodTips }) -join ', '))

# --------------------------------------------------------------------------
# 2. restos no registro do usuario (Preload / Substitutes)
# --------------------------------------------------------------------------
# Set-WinUserLanguageList costuma cuidar disso, mas o Windows as vezes deixa
# mapeamentos antigos em Substitutes que fazem ele voltar sozinho pro US/BR.
#
# Com o layout sob en-GB (sem -Ditado), Preload "1" = a0000809 basta.
# Sob pt-BR o Windows precisa de um substituto: Preload aponta para um id
# "xxxx0416" (na pratica 00000416) e Substitutes mapeia esse id para
# a0000809. Por isso, no modo
# ditado, so apagamos o que NAO aponta para o nosso layout.
try {
    $preload = 'HKCU:\Keyboard Layout\Preload'
    $subs    = 'HKCU:\Keyboard Layout\Substitutes'

    if ($Mode -eq 'Install' -and $RemoveOthers -and -not $Ditado) {
        if (Test-Path $preload) { Remove-Item $preload -Recurse -Force }
        New-Item -Path $preload -Force | Out-Null
        Set-ItemProperty $preload -Name '1' -Value $Klid

        if (Test-Path $subs) {
            Get-Item $subs |
                Select-Object -ExpandProperty Property |
                ForEach-Object { Remove-ItemProperty -Path $subs -Name $_ -ErrorAction SilentlyContinue }
        }
        Write-Log 'Preload/Substitutes limpos (somente o UKPTES).'
    }
    elseif ($Mode -eq 'Install' -and $RemoveOthers -and $Ditado) {
        if (-not (Test-Path $subs))    { New-Item -Path $subs -Force | Out-Null }
        if (-not (Test-Path $preload)) { New-Item -Path $preload -Force | Out-Null }

        # Substitutes: fica so o que aponta para o nosso layout.
        $nossos = @()
        foreach ($n in @((Get-Item $subs).Property)) {
            if ((Get-ItemPropertyValue -Path $subs -Name $n) -eq $Klid) { $nossos += $n }
            else { Remove-ItemProperty -Path $subs -Name $n -ErrorAction SilentlyContinue }
        }

        # Preload: fica so o substituto pt-BR do nosso layout.
        $okPreload = $false
        foreach ($n in @((Get-Item $preload).Property)) {
            $v = Get-ItemPropertyValue -Path $preload -Name $n
            if ($nossos -contains $v -and $v -like '*0416') { $okPreload = $true }
            else { Remove-ItemProperty -Path $preload -Name $n -ErrorAction SilentlyContinue }
        }

        # Se o Windows nao escreveu o par, escrevemos nos (padrao d0010416).
        if (-not $okPreload) {
            Get-Item $preload | Select-Object -ExpandProperty Property |
                ForEach-Object { Remove-ItemProperty -Path $preload -Name $_ -ErrorAction SilentlyContinue }
            Set-ItemProperty $subs    -Name 'd0010416' -Value $Klid
            Set-ItemProperty $preload -Name '1'        -Value 'd0010416'
            Write-Log 'Preload/Substitutes gravados: 1=d0010416 -> a0000809.'
        }
        else {
            Write-Log 'Preload/Substitutes limpos (somente o UKPTES sob pt-BR).'
        }
    }
    elseif ($Mode -eq 'Uninstall') {
        # Tira o nosso KLID (e os substitutos que apontam pra ele) do Preload.
        $nossos = @($Klid)
        if (Test-Path $subs) {
            $nossos += @(Get-Item $subs |
                Select-Object -ExpandProperty Property |
                Where-Object { (Get-ItemPropertyValue -Path $subs -Name $_) -eq $Klid })
        }
        if (Test-Path $preload) {
            foreach ($n in @((Get-Item $preload).Property)) {
                if ($nossos -contains (Get-ItemPropertyValue -Path $preload -Name $n)) {
                    Remove-ItemProperty -Path $preload -Name $n -ErrorAction SilentlyContinue
                }
            }
            if (-not @((Get-Item $preload).Property)) {
                Set-ItemProperty $preload -Name '1' -Value '00000809'
                Write-Log 'Preload ficou vazio; gravado o UK padrao (00000809).'
            }
        }
        if (Test-Path $subs) {
            Get-Item $subs |
                Select-Object -ExpandProperty Property |
                Where-Object { (Get-ItemPropertyValue -Path $subs -Name $_) -eq $Klid } |
                ForEach-Object { Remove-ItemProperty -Path $subs -Name $_ -ErrorAction SilentlyContinue }
        }
        Write-Log 'Referencias ao UKPTES removidas do Preload/Substitutes.'
    }
}
catch {
    Write-Log "Aviso: limpeza de registro parcial: $_"
}

# --------------------------------------------------------------------------
# 3. propaga para a tela de logon e contas novas
# --------------------------------------------------------------------------
# Cmdlet existe a partir do Windows 11 / Server 2022; em versoes antigas falha
# e tudo bem — a conta atual ja esta configurada.
try {
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    Write-Log 'Configuracao propagada para a tela de logon e contas novas.'
}
catch {
    Write-Log "Aviso: nao foi possivel propagar para a tela de logon: $_"
}

Write-Log '=== Fim ==='
exit 0

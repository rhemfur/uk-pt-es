# configurar-teclado.ps1 — parte "por usuario" da instalacao do UKPTES.
#
# Chamado pelo instalador (UKPTES.iss). Nao precisa ser rodado a mao:
# o .exe cuida de copiar as DLLs e escrever o registro do sistema; este
# script so mexe na lista de idiomas de ENTRADA da conta atual.
#
#   -Mode Install    adiciona o UKPTES a conta (e opcionalmente remove os outros)
#   -Mode Uninstall  remove o UKPTES da conta, garantindo que sobre algum teclado
#   -RemoveOthers    (so com Install) deixa SOMENTE o UKPTES
#   -Klid            KLID do layout, em minusculas (padrao: a0000809)
#
# Mensagens sao ASCII de proposito: o Windows PowerShell 5.1 le .ps1 sem BOM
# como ANSI e corrompe acentos. O texto acentuado que vai pro registro
# ("Reino Unido - Portugues e Espanhol") e escrito pelo Inno Setup, nao aqui.

[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall')]
    [string] $Mode = 'Install',

    [switch] $RemoveOthers,

    [string] $Klid = 'a0000809'
)

$ErrorActionPreference = 'Stop'

# Tip = "<idioma em hex>:<KLID em maiusculas>". en-GB = 0809.
$tip         = '0809:{0}' -f $Klid.ToUpperInvariant()
$fallbackTip = '0809:00000809'   # teclado UK padrao, usado se sobrar nada
$log         = Join-Path $env:TEMP 'ukptes-configurar.log'

function Write-Log {
    param([string] $Message)
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch { }
}

Write-Log "=== Mode=$Mode RemoveOthers=$RemoveOthers Klid=$Klid Tip=$tip ==="
Write-Log "Conta: $env:USERNAME"

# Nota: a limpeza de PendingFileRenameOperations fica em limpar-pendencias.ps1,
# chamado pelo instalador la no InitializeSetup — precisa acontecer ANTES de o
# Inno decidir que ha reinicio pendente e abortar.

# --------------------------------------------------------------------------
# 1. lista de idiomas de entrada da conta
# --------------------------------------------------------------------------
if ($Mode -eq 'Install') {

    if ($RemoveOthers) {
        # Zera tudo: so en-GB, e dentro dele so o nosso layout.
        $list = New-WinUserLanguageList en-GB
        $list[0].InputMethodTips.Clear()
        $list[0].InputMethodTips.Add($tip)
        Write-Log 'Lista zerada: somente en-GB com o UKPTES.'
    }
    else {
        # Preserva o que ja existe e apenas acrescenta o nosso layout ao en-GB.
        $list = Get-WinUserLanguageList
        $gb = $list | Where-Object { $_.LanguageTag -eq 'en-GB' } | Select-Object -First 1
        if (-not $gb) {
            $novo = New-WinUserLanguageList en-GB
            $list.Add($novo[0])
            $gb = $list[$list.Count - 1]
            Write-Log 'Idioma en-GB nao existia na conta; adicionado.'
        }
        if ($gb.InputMethodTips -notcontains $tip) {
            $gb.InputMethodTips.Add($tip)
            Write-Log 'UKPTES adicionado ao en-GB (outros teclados preservados).'
        }
        else {
            Write-Log 'UKPTES ja estava na lista; nada a fazer.'
        }
    }
}
else {
    # Uninstall: tira o nosso tip de todos os idiomas e limpa os que ficaram vazios.
    $list = Get-WinUserLanguageList

    foreach ($lang in $list) {
        while ($lang.InputMethodTips -contains $tip) {
            [void] $lang.InputMethodTips.Remove($tip)
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
try {
    $preload = 'HKCU:\Keyboard Layout\Preload'
    $subs    = 'HKCU:\Keyboard Layout\Substitutes'

    if ($Mode -eq 'Install' -and $RemoveOthers) {
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
    elseif ($Mode -eq 'Uninstall') {
        # Tira o nosso KLID do Preload; se ficar vazio, poe o UK padrao.
        if (Test-Path $preload) {
            $item  = Get-Item $preload
            $names = @($item.Property)
            foreach ($n in $names) {
                if ((Get-ItemPropertyValue -Path $preload -Name $n) -eq $Klid) {
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

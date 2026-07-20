# limpar-pendencias.ps1 — remove operacoes de boot pendentes que afetam a
# UKPTES.dll. Chamado pelo instalador logo no inicio (InitializeSetup) e pelo
# reparar-teclado.ps1. Precisa de direitos de administrador.
#
# Por que existe
# --------------
# Quando o layout esta carregado na sessao, a UKPTES.dll do System32 fica em uso
# e o Inno Setup nao consegue substituir/apagar o arquivo na hora: ele agenda a
# operacao para o proximo boot em PendingFileRenameOperations. Duas consequencias
# ruins se nada limpar isso:
#
#   1. Depois de DESINSTALAR fica pendente "apagar C:\Windows\System32\UKPTES.dll".
#      Se a pessoa reinstalar antes de reiniciar, o Windows apagaria no boot
#      seguinte a DLL recem-instalada.
#   2. Com reinicio pendente, o proprio Inno se recusa a instalar e sai com o
#      codigo 8 ("Preparing to Install" aborta) — a instalacao nao acontece.
#
# Formato do valor
# ----------------
# REG_MULTI_SZ com PARES (origem, destino), cada caminho no formato NT (\??\...)
# e com o marcador do Inno (*1 / *1!) na frente:
#
#   destino vazio      -> apagar a origem no boot
#   destino preenchido -> renomear origem sobre destino no boot (substituicao)
#
# Removemos qualquer par cuja ORIGEM ou DESTINO seja a nossa DLL:
#   (a) "apagar a nossa DLL" — apagaria a que estamos instalando agora;
#   (b) "substituir a nossa DLL por um temporario" — pendencia de uma instalacao
#       ANTERIOR. So e seguro descartar porque este script roda no
#       InitializeSetup, ou seja, ANTES de o Inno enfileirar as operacoes desta
#       instalacao; tudo que esta na fila neste instante e obsoleto, e quem
#       chama vai gravar a versao atual da DLL logo em seguida. Se ficasse,
#       o proximo boot poderia sobrescrever a DLL nova com uma antiga.
#
# O arquivo temporario orfao tambem e apagado, para nao entulhar o System32.
# Qualquer outra pendencia do sistema e preservada intacta.

$ErrorActionPreference = 'Stop'

$chave = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
$nome  = 'PendingFileRenameOperations'
$log   = Join-Path $env:TEMP 'ukptes-configurar.log'

function Write-Log {
    param([string] $Message)
    $line = '{0}  [pendencias] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch { }
}

# Tira o marcador do Inno (*1, *1!) e o prefixo NT (\??\).
function ConvertTo-Caminho {
    param([string] $Entrada)
    ($Entrada -replace '^\*\d*!?', '') -replace '^\\\?\?\\', ''
}

try {
    $valores = (Get-ItemProperty -Path $chave -Name $nome -ErrorAction SilentlyContinue).$nome
    if (-not $valores) {
        Write-Log 'Nada pendente.'
        exit 0
    }

    $nossas = @(
        (Join-Path $env:SystemRoot 'System32\UKPTES.dll')
        (Join-Path $env:SystemRoot 'SysWOW64\UKPTES.dll')
    )

    $mantidos  = New-Object System.Collections.Generic.List[string]
    $removidos = 0

    for ($i = 0; $i -lt $valores.Count; $i += 2) {
        $origem  = $valores[$i]
        $destino = if ($i + 1 -lt $valores.Count) { $valores[$i + 1] } else { '' }

        $pOrigem  = ConvertTo-Caminho $origem
        $pDestino = ConvertTo-Caminho $destino

        $descartar = $false
        if ($pDestino -eq '' -and $nossas -contains $pOrigem) {
            $descartar = $true      # apagar a nossa DLL no boot
        }
        elseif ($nossas -contains $pDestino) {
            $descartar = $true      # substituir a nossa DLL: pendencia obsoleta

            # o temporario da substituicao vira lixo no System32; apaga
            if (Test-Path -LiteralPath $pOrigem) {
                try {
                    Remove-Item -LiteralPath $pOrigem -Force
                    Write-Log "temporario orfao apagado: '$pOrigem'"
                }
                catch { Write-Log "nao consegui apagar o temporario '$pOrigem': $_" }
            }
        }

        if ($descartar) {
            $removidos++
            Write-Log "removido: '$origem' -> '$destino'"
        }
        else {
            $mantidos.Add($origem)
            $mantidos.Add($destino)
        }
    }

    if ($removidos -eq 0) {
        Write-Log 'Nenhuma pendencia da UKPTES.dll.'
        exit 0
    }

    if ($mantidos.Count -eq 0) {
        Remove-ItemProperty -Path $chave -Name $nome
        Write-Log 'Valor PendingFileRenameOperations removido (so tinha pendencias nossas).'
    }
    else {
        Set-ItemProperty -Path $chave -Name $nome -Value $mantidos.ToArray() -Type MultiString
        Write-Log "$removidos par(es) removido(s); $($mantidos.Count / 2) preservado(s)."
    }
}
catch {
    # Nao e fatal: no pior caso o usuario precisa reiniciar antes de instalar.
    Write-Log "Aviso: falhou: $_"
    exit 0
}

exit 0

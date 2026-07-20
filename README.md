# Teclado Reino Unido – Português e Espanhol (UKPTES)

Layout de teclado para Windows que usa o **teclado físico britânico (UK)** e acrescenta
a acentuação completa de **português** e **espanhol** — sem trocar de idioma, sem
`Win+Espaço`, sem perder o `£`, o `@` e o `"` nos lugares certos do UK.

Feito para quem escreve nos três idiomas no mesmo teclado.

| | |
|---|---|
| **Instalador** | `.exe` único para Windows **x64** e **ARM64** |
| **Requer** | Windows 10/11, direitos de administrador |
| **Licença** | MIT |

---

## Instalar

1. Baixe o `UKPTES-Setup-x.y.z.exe` mais recente na aba
   [**Releases**](../../releases).
2. Execute e aprove o UAC.
3. Deixe marcada a opção **"Remover todos os outros teclados e deixar somente este"**
   se quiser que o Windows pare de voltar sozinho para o teclado US/BR.
4. **Saia da sua conta do Windows e entre de novo.** Layouts de teclado só recarregam
   no logon — não precisa reiniciar a máquina.

O instalador detecta sozinho se a máquina é Intel/AMD (x64) ou ARM64 (Snapdragon) e
instala a DLL certa.

> **SmartScreen:** o `.exe` não é assinado digitalmente, então o Windows mostra
> "O Windows protegeu o computador". Clique em **Mais informações → Executar assim
> mesmo**. Assinar exigiria um certificado de code signing pago.

### Desinstalar

**Configurações → Aplicativos → Aplicativos instalados → Teclado Reino Unido -
Português e Espanhol → Desinstalar.**

A desinstalação remove as DLLs, apaga a chave de registro e devolve um teclado
funcional para a conta — se o UKPTES era o único, o **UK padrão** volta no lugar.
Você nunca fica sem teclado.

### É por conta de usuário

As DLLs e o registro do layout são da **máquina inteira**, mas a *lista de teclados*
é de cada conta do Windows. O instalador configura a conta que o executou e propaga
para a **tela de logon** e para **contas novas**. Se a máquina tem outras contas já
existentes, rode o instalador logado em cada uma (ele detecta que já está instalado e
só ajusta a conta).

O instalador mexe **apenas em teclados/idiomas de entrada**. Não desinstala pacotes de
idioma e não muda o idioma de **exibição** do Windows — seus menus continuam como estão.

---

## O que cada tecla faz (além do UK padrão)

| Tecla | Resultado |
|---|---|
| `AltGr` + `a e i o u` | á é í ó ú (com `Shift` = maiúscula) |
| `AltGr` + `c` | ç |
| `AltGr` + `n` | **ñ** |
| `AltGr` + `1` | **¡** |
| `AltGr` + `/` | **¿** |
| `AltGr` + `4` | € |
| `'` (tecla do `@`) — *morta* | `'` + vogal = aguda (á é í ó ú ý), `'` + `c` = ç |
| `Shift`+`6` (`^`) — *morta* | â ê î ô û |
| `Shift`+`#` (`~`) — *morta* | ã õ e **ñ** |
| `` ` `` (à esquerda do `1`) — *morta* | à è ì ò ù |
| `AltGr`+`2` (`¨`) — *morta* | ä ë ï ö **ü** ÿ |

Tecla morta + espaço imprime o próprio símbolo. Todas as combinações foram verificadas
programaticamente (`ToUnicodeEx`) contra a DLL instalada.

---

## Estrutura do repositório

```
bin/          DLLs compiladas (amd64, wow64/x86, arm64) — são o que vai para o System32
src/          fonte do layout: UKPTES.klc + código C gerado pelo kbdutool + build ARM64
installer/    Inno Setup (.iss) + scripts PowerShell que o instalador chama
scripts/      instaladores PowerShell avulsos, anteriores ao .exe (ainda funcionam)
dist/         saída do build (ignorada pelo git; o .exe vai para Releases)
```

### Como o instalador funciona

| Etapa | Quem faz | O quê |
|---|---|---|
| DLL nativa | Inno Setup | `bin\UKPTES_{amd64,arm64}.dll` → `%SystemRoot%\System32\UKPTES.dll` |
| DLL 32-bit | Inno Setup | `bin\UKPTES_wow64.dll` → `%SystemRoot%\SysWOW64\UKPTES.dll` (apps de 32 bits) |
| Registro do layout | Inno Setup | `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a0000809` |
| Lista de teclados da conta | `installer/configurar-teclado.ps1` | `Set-WinUserLanguageList` + limpeza de `Preload`/`Substitutes` |
| Tela de logon / contas novas | idem | `Copy-UserInternationalSettingsToSystem` |

Detalhes do registro:

- **KLID** `a0000809` — registrado sob `en-GB`, então aparece dentro de
  "English (United Kingdom)".
- `Layout Text` = `Reino Unido - Português e Espanhol`
- `Layout File` = `UKPTES.dll`
- `Layout Id` — **calculado na instalação**, não fixo. Esse valor precisa ser único
  entre *todos* os layouts da máquina; o instalador varre os já registrados e escolhe
  o primeiro livre a partir de `00c1` (reaproveitando o anterior se já houver um).
- `Layout Display Name` = `@%SystemRoot%\system32\UKPTES.dll,-1000`
- InputMethodTip da conta: `0809:A0000809`

---

## Compilar o instalador

Precisa do [Inno Setup 6](https://jrsoftware.org/isinfo.php):

```powershell
winget install JRSoftware.InnoSetup
powershell -ExecutionPolicy Bypass -File installer\build.ps1
```

Saída em `dist\UKPTES-Setup-<versão>.exe`. O `build.ps1` acha o `ISCC.exe` sozinho,
confere que as DLLs existem e **garante o BOM** nos arquivos de texto (veja abaixo).

Para publicar: crie um release no GitHub e anexe o `.exe`. Ele não é versionado no
repositório.

### ⚠️ UTF-8 **com BOM** é obrigatório

O `.iss` e os `.ps1` deste projeto têm acentos e **precisam ser salvos em UTF-8 com
BOM**. Sem BOM, o Windows PowerShell 5.1 e o compilador do Inno leem os arquivos como
ANSI e os acentos vão corrompidos — foi assim que `Reino Unido - PortuguÃªs e Espanhol`
foi parar no registro em jul/2026. O `build.ps1` verifica e corrige o BOM antes de
compilar; se editar algum arquivo em outro editor, rode o build de novo.

Conferir manualmente:

```powershell
$b = [IO.File]::ReadAllBytes('.\installer\UKPTES.iss')
$b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF
```

---

## Editar o layout

1. Edite `src/UKPTES.klc` (é texto — seções `LAYOUT` e `DEADKEY`).
2. Recompile as DLLs x86/x64 com o `kbdutool` do MSKLC 1.4:
   ```cmd
   kbdutool -n -u -m UKPTES.klc     :: amd64
   kbdutool -n -u -o UKPTES.klc     :: wow64 (x86)
   kbdutool -n -u -s UKPTES.klc     :: regera o C em src\, para o ARM64
   ```
   Dá para extrair o `kbdutool.exe` **sem instalar o MSKLC**:
   `msiexec /a MSKLC.msi /qn TARGETDIR=<pasta>` (útil quando um reinício pendente
   está bloqueando instaladores).
3. Para a DLL ARM64 é preciso compilar o C — o `kbdutool` não gera binário ARM.
   Em uma máquina ARM64 com **VS Build Tools 2022 + componente ARM64**, rode
   `src\build-arm64.bat`. O `kbd.h` vem no próprio Windows SDK; não precisa do WDK.
4. Copie as DLLs novas para `bin/`, suba a versão em `installer\UKPTES.iss`
   (`#define AppVersion`) e rode o `build.ps1`.

Alternativa sem compilar nada: o app pago **[KbdEdit](https://kbdedit.com)** importa
`.klc` e gera instalador com suporte a ARM64.

---

## Solução de problemas

**O teclado sumiu depois de uma atualização do Windows.**
É o problema clássico: updates grandes do Windows 11 apagam DLLs de terceiros do
System32 — o registro sobrevive, a DLL não. Use o atalho **"Reparar teclado"** no menu
Iniciar (ele recopia a DLL e pede UAC). Reinstalar o `.exe` também resolve.

**"Running scripts is disabled on this system"** ao rodar os `.ps1` de `scripts/`.
Libere uma vez com `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`, ou chame sem
mudar nada: `powershell -ExecutionPolicy Bypass -File .\scripts\instalar-teclado.ps1`.
O instalador `.exe` não sofre disso.

**Instalei e não mudou nada.**
Saia da conta e entre de novo — layouts só recarregam no logon.

**O nome do teclado aparece com acentos errados.**
Registro antigo, escrito por um `.ps1` sem BOM. Rodar o instalador `.exe` reescreve o
valor corretamente.

**Outra conta do Windows continua com o teclado antigo.**
A lista de teclados é por conta. Logue nela e rode o instalador lá também.

**Diagnóstico rápido:**

```powershell
# o layout está registrado?
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a0000809'
# a DLL existe?
Test-Path C:\Windows\System32\UKPTES.dll
# a conta está usando só ele?  (esperado: 0809:A0000809)
(Get-WinUserLanguageList).InputMethodTips
```

Os scripts do instalador deixam log em `%TEMP%\ukptes-configurar.log`.

---

## Histórico

- **2009** — layout original **"Reino Unido - Português"** (KLID `a0000416`, `UK-PT.dll`),
  gerado pelo MSKLC. Só cobria português: faltavam `ñ ¿ ¡ ü`, e o til morto não
  combinava com `n`. Aposentado, mantido só como referência histórica.
- **jul/2026** — sucessor **UKPTES** criado do zero a partir de `UKPTES.klc`, somando o
  espanhol e preservando 100% do comportamento português anterior.
- **jul/2026** — versão **ARM64** compilada nativamente (PE Machine `0xAA64`), para o
  Windows ARM, que não carrega DLLs de layout x64/x86.
- **jul/2026** — descoberto o bug do BOM: `.ps1` salvos em UTF-8 sem BOM eram lidos como
  ANSI pelo PowerShell 5.1 e gravavam `PortuguÃªs` no registro.
- **jul/2026** — este instalador `.exe` (Inno Setup), que substitui os scripts avulsos:
  arquitetura automática, `Layout Id` sem conflito, desinstalador de verdade e o texto
  acentuado escrito pelo próprio Inno, imune ao problema de BOM.

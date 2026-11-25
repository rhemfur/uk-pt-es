; ============================================================================
;  Teclado "Reino Unido - Português e Espanhol" (UKPTES)
;  Instalador Inno Setup 6 — gera um .exe único para Windows x64 e ARM64.
;
;  Compilar:  installer\build.ps1        (ou ISCC.exe installer\UKPTES.iss)
;  Saída:     dist\UKPTES-Setup-<versão>.exe
;
;  ATENÇÃO: este arquivo tem acentos e PRECISA ficar salvo em UTF-8 COM BOM,
;  senão o Inno Setup lê os textos como ANSI e o nome do teclado vai corrompido
;  para o registro (foi o bug do "PortuguÃªs" em jul/2026).
; ============================================================================

#define AppName        "Teclado Reino Unido - Português e Espanhol"
#define AppShortName   "UKPTES"
#define AppVersion     "1.1.0"
#define AppPublisher   "Rhener Furtado"
#define AppUrl         "https://github.com/rhemfur/uk-pt-es"
#define Klid           "a0000809"
#define LayoutText     "Reino Unido - Português e Espanhol"
#define LayoutsKey     "SYSTEM\CurrentControlSet\Control\Keyboard Layouts"

[Setup]
AppId={{8F3C1A62-5D74-4E9B-9C21-7A6E0B4D2F18}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
VersionInfoVersion={#AppVersion}
VersionInfoDescription={#AppName}

DefaultDirName={autopf}\{#AppShortName}
DefaultGroupName={#AppShortName}
DisableProgramGroupPage=yes
DisableDirPage=yes
UninstallDisplayName={#AppName}

; Precisa de admin: escreve em System32 e em HKLM.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=

; Roda em modo 64-bit tanto em x64 quanto em ARM64, para que {sys} aponte para
; o System32 nativo (e não seja redirecionado para o SysWOW64).
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

OutputDir=..\dist
OutputBaseFilename=UKPTES-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=auto

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english";            MessagesFile: "compiler:Default.isl"
Name: "spanish";            MessagesFile: "compiler:Languages\Spanish.isl"

[CustomMessages]
brazilianportuguese.RemoveOthers=Remover todos os outros teclados e deixar somente este
brazilianportuguese.RemoveOthersInfo=Recomendado. Impede que o Windows volte sozinho para o teclado US/BR. Não altera o idioma dos menus do Windows.
brazilianportuguese.RepairName=Reparar teclado (após atualização do Windows)
brazilianportuguese.ConfiguringUser=Configurando o teclado da sua conta...
brazilianportuguese.RestoringUser=Restaurando os teclados da sua conta...
brazilianportuguese.Ditado=Ditado por voz em português do Brasil (Win+H)
brazilianportuguese.DitadoInfo=O teclado fica sob o idioma Português (Brasil) e o reconhecimento de voz pt-BR é baixado agora (precisa de internet; pode levar alguns minutos). Junto com a opção acima, a conta fica com um idioma só: sem indicador de idioma na barra de tarefas.
brazilianportuguese.InstallingSpeech=Baixando o reconhecimento de voz em português (pode levar alguns minutos)...
brazilianportuguese.FinishedInfo=Instalação concluída. Saia da sua conta do Windows e entre de novo para o teclado passar a valer.

english.RemoveOthers=Remove all other keyboards and keep only this one
english.RemoveOthersInfo=Recommended. Stops Windows from switching back to US/BR on its own. Does not change the Windows display language.
english.RepairName=Repair keyboard (after a Windows update)
english.ConfiguringUser=Configuring the keyboard for your account...
english.RestoringUser=Restoring your account's keyboards...
english.Ditado=Voice typing in Brazilian Portuguese (Win+H)
english.DitadoInfo=The keyboard goes under the Portuguese (Brazil) language and pt-BR speech recognition is downloaded now (needs internet; may take a few minutes). Together with the option above, the account has a single language: no language indicator on the taskbar.
english.InstallingSpeech=Downloading Portuguese speech recognition (may take a few minutes)...
english.FinishedInfo=Installation finished. Sign out of Windows and sign back in for the keyboard to take effect.

spanish.RemoveOthers=Quitar todos los demás teclados y dejar solo este
spanish.RemoveOthersInfo=Recomendado. Evita que Windows vuelva solo al teclado US/BR. No cambia el idioma de los menús de Windows.
spanish.RepairName=Reparar teclado (tras una actualización de Windows)
spanish.ConfiguringUser=Configurando el teclado de tu cuenta...
spanish.RestoringUser=Restaurando los teclados de tu cuenta...
spanish.Ditado=Dictado por voz en portugués de Brasil (Win+H)
spanish.DitadoInfo=El teclado queda bajo el idioma Portugués (Brasil) y se descarga ahora el reconocimiento de voz pt-BR (necesita internet; puede tardar unos minutos). Junto con la opción de arriba, la cuenta queda con un solo idioma: sin indicador de idioma en la barra de tareas.
spanish.InstallingSpeech=Descargando el reconocimiento de voz en portugués (puede tardar unos minutos)...
spanish.FinishedInfo=Instalación finalizada. Cierra la sesión de Windows y vuelve a entrar para que el teclado surta efecto.

[Tasks]
Name: "removeothers"; Description: "{cm:RemoveOthers}"; GroupDescription: "{cm:RemoveOthersInfo}"
Name: "ditado";       Description: "{cm:Ditado}";       GroupDescription: "{cm:DitadoInfo}"

[Files]
; O compilador avisa "Unsafe flag usage ... ignoreversion ... {sys}". É esperado
; e proposital: UKPTES.dll é um arquivo nosso, não da Microsoft, e precisa ser
; sempre reescrito — inclusive quando o layout é recompilado e a versão do
; recurso não muda. Sem ignoreversion, o Inno pularia a cópia.
;
; --- DLL nativa: ARM64 ou x64, sempre gravada como UKPTES.dll no System32 ---
Source: "..\bin\UKPTES_arm64.dll"; DestDir: "{sys}"; DestName: "UKPTES.dll"; \
    Check: IsArm64; Flags: ignoreversion restartreplace uninsrestartdelete

Source: "..\bin\UKPTES_amd64.dll"; DestDir: "{sys}"; DestName: "UKPTES.dll"; \
    Check: not IsArm64; Flags: ignoreversion restartreplace uninsrestartdelete

; --- DLL x86 no SysWOW64, para os aplicativos de 32 bits ---
Source: "..\bin\UKPTES_wow64.dll"; DestDir: "{syswow64}"; DestName: "UKPTES.dll"; \
    Flags: ignoreversion restartreplace uninsrestartdelete

; --- cópias em {app}: usadas pelo "Reparar" e pelo desinstalador ---
Source: "..\bin\*.dll";              DestDir: "{app}\bin"; Flags: ignoreversion
Source: "configurar-teclado.ps1";    DestDir: "{app}";     Flags: ignoreversion
Source: "reparar-teclado.ps1";       DestDir: "{app}";     Flags: ignoreversion
Source: "limpar-pendencias.ps1";     DestDir: "{app}";     Flags: ignoreversion
Source: "instalar-fala.ps1";         DestDir: "{app}";     Flags: ignoreversion
Source: "..\README.md";              DestDir: "{app}";     Flags: ignoreversion isreadme

; Extraído para {tmp} e executado ainda no InitializeSetup — antes de o Inno
; avaliar se há reinício pendente. Ver LimparPendencias() no [Code].
Source: "limpar-pendencias.ps1";     Flags: dontcopy noencryption

[Registry]
; Registro do layout. O "Layout Id" precisa ser único na máquina, por isso é
; calculado em tempo de instalação (GetLayoutId) em vez de fixo.
Root: HKLM; Subkey: "{#LayoutsKey}\{#Klid}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "{#LayoutsKey}\{#Klid}"; ValueType: string; \
    ValueName: "Layout Text";         ValueData: "{#LayoutText}"
Root: HKLM; Subkey: "{#LayoutsKey}\{#Klid}"; ValueType: string; \
    ValueName: "Layout File";         ValueData: "UKPTES.dll"
Root: HKLM; Subkey: "{#LayoutsKey}\{#Klid}"; ValueType: string; \
    ValueName: "Layout Id";           ValueData: "{code:GetLayoutId}"
Root: HKLM; Subkey: "{#LayoutsKey}\{#Klid}"; ValueType: string; \
    ValueName: "Layout Display Name"; ValueData: "@%SystemRoot%\system32\UKPTES.dll,-1000"

[Icons]
Name: "{group}\{cm:RepairName}"; Filename: "powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\reparar-teclado.ps1"""; \
    WorkingDir: "{app}"

[Run]
; Parte por usuário: lista de idiomas de entrada da conta que está instalando.
; Os argumentos extras (-RemoveOthers / -Ditado) saem das tarefas: ConfigArgs.
Filename: "powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\configurar-teclado.ps1"" -Mode Install -Klid {#Klid}{code:ConfigArgs}"; \
    StatusMsg: "{cm:ConfiguringUser}"; \
    Flags: runhidden waituntilterminated

; Reconhecimento de voz pt-BR (Feature on Demand, vem do Windows Update).
; Roda depois do teclado: se não houver internet, o teclado já está pronto.
Filename: "powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\instalar-fala.ps1"" -Language pt-BR -RestartFlag ""{tmp}\fala-reiniciar.flag"""; \
    StatusMsg: "{cm:InstallingSpeech}"; Tasks: ditado; \
    Flags: runhidden waituntilterminated

[UninstallRun]
; Roda ANTES de apagar os arquivos, para a conta não ficar sem teclado nenhum.
Filename: "powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\configurar-teclado.ps1"" -Mode Uninstall -Klid {#Klid}"; \
    StatusMsg: "{cm:RestoringUser}"; RunOnceId: "UkptesRestoreUserLayouts"; \
    Flags: runhidden waituntilterminated

[Code]
var
  CachedLayoutId: String;

{ Verifica se algum OUTRO layout da máquina já usa este "Layout Id". }
function IsLayoutIdUsed(Id: String): Boolean;
var
  Names: TArrayOfString;
  I: Integer;
  Value: String;
begin
  Result := False;
  if not RegGetSubkeyNames(HKEY_LOCAL_MACHINE, '{#LayoutsKey}', Names) then
    Exit;

  for I := 0 to GetArrayLength(Names) - 1 do
  begin
    { a nossa própria chave não conta como conflito }
    if CompareText(Names[I], '{#Klid}') = 0 then
      Continue;

    if RegQueryStringValue(HKEY_LOCAL_MACHINE, '{#LayoutsKey}\' + Names[I], 'Layout Id', Value) then
      if CompareText(Trim(Value), Id) = 0 then
      begin
        Result := True;
        Exit;
      end;
  end;
end;

{ Devolve um "Layout Id" livre. Reaproveita o de uma instalação anterior se
  ainda estiver livre; senão procura a partir de 00c1 (faixa que o MSKLC usa). }
function GetLayoutId(Param: String): String;
var
  N: Integer;
  Existing, Candidate: String;
begin
  if CachedLayoutId <> '' then
  begin
    Result := CachedLayoutId;
    Exit;
  end;

  if RegQueryStringValue(HKEY_LOCAL_MACHINE, '{#LayoutsKey}\{#Klid}', 'Layout Id', Existing) then
  begin
    Existing := Trim(Existing);
    if (Existing <> '') and not IsLayoutIdUsed(Existing) then
    begin
      CachedLayoutId := Existing;
      Result := CachedLayoutId;
      Exit;
    end;
  end;

  for N := $C1 to $FF do
  begin
    Candidate := LowerCase(Format('%.4x', [N]));
    if not IsLayoutIdUsed(Candidate) then
    begin
      CachedLayoutId := Candidate;
      Result := CachedLayoutId;
      Exit;
    end;
  end;

  { faixa toda ocupada — improvável; usa o valor histórico }
  CachedLayoutId := '00c1';
  Result := CachedLayoutId;
end;

{ Argumentos extras do configurar-teclado.ps1, conforme as tarefas marcadas. }
function ConfigArgs(Param: String): String;
begin
  Result := '';
  if WizardIsTaskSelected('removeothers') then
    Result := Result + ' -RemoveOthers';
  if WizardIsTaskSelected('ditado') then
    Result := Result + ' -Ditado';
end;

{ O reconhecimento de voz (Add-WindowsCapability) só passa a valer depois de
  reiniciar. instalar-fala.ps1 cria este arquivo quando o Windows pede reinício,
  e aí o Inno oferece reiniciar na última tela. }
function NeedRestart(): Boolean;
begin
  Result := FileExists(ExpandConstant('{tmp}\fala-reiniciar.flag'));
end;

{ Remove operações de boot pendentes que afetam a UKPTES.dll.

  Precisa rodar bem cedo. Se uma desinstalação anterior deixou pendente um
  "apagar C:\Windows\System32\UKPTES.dll" (porque a DLL estava em uso), então:
    - o Inno aborta em "Preparing to Install" com o código 8, e nada é instalado;
    - e se conseguisse instalar, o boot seguinte apagaria a DLL nova.
  Por isso a limpeza é feita aqui no InitializeSetup, antes de tudo. }
procedure LimparPendencias;
var
  Script: String;
  ResultCode: Integer;
begin
  try
    ExtractTemporaryFile('limpar-pendencias.ps1');
  except
    Exit;
  end;

  Script := ExpandConstant('{tmp}\limpar-pendencias.ps1');
  if not Exec('powershell.exe',
              '-NoProfile -ExecutionPolicy Bypass -File "' + Script + '"',
              '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Log('Nao foi possivel executar limpar-pendencias.ps1');
end;

function InitializeSetup(): Boolean;
begin
  LimparPendencias;
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    MsgBox(ExpandConstant('{cm:FinishedInfo}'), mbInformation, MB_OK);
end;

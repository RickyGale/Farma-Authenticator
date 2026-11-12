; Installer Windows per Farma Authenticator (Inno Setup 6)
; Prima: flutter build windows --release
; Poi:   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\farma_auth.iss
; Ricordarsi di aggiornare MyAppVersion insieme a pubspec.yaml.

#define MyAppName "Farma Authenticator"
#define MyAppVersion "1.13.08"
#define MyAppExeName "farma_auth.exe"
#define BuildDir "..\build\windows\x64\runner\Release"
; DLL a 64 bit del runtime VC++: se il compilatore gira a 32 bit, System32 viene
; rediretto su SysWOW64 (DLL a 32 bit), quindi si passa da Sysnative.
#if FileExists("C:\Windows\Sysnative\vcruntime140_1.dll")
  #define SysDir64 "C:\Windows\Sysnative"
#else
  #define SysDir64 "C:\Windows\System32"
#endif

[Setup]
; NON cambiare AppId: serve a far riconoscere gli aggiornamenti della stessa app.
AppId={{62dc7b64-aaff-4dde-b3a6-88e7f251f522}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=FarmaAuthenticator-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Avvia automaticamente all'accesso a Windows"; GroupDescription: "Avvio:"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Runtime Visual C++ accanto all'exe, così l'app parte anche su PC senza vc_redist
Source: "{#SysDir64}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SysDir64}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SysDir64}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
; Esecuzione automatica per tutti gli utenti del PC; la disinstallazione la rimuove
Name: "{commonstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

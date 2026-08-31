; ──────────────────────────────────────────────────────────────────────────────
;  PlayTorrioMov — Windows Installer (Inno Setup 6)
;  Built by CI from: build\windows\x64\runner\Release\
; ──────────────────────────────────────────────────────────────────────────────

#define MyAppName      "PlayTorrioMov"
#ifndef MyAppVersion
#define MyAppVersion   "1.1.0"
#endif
#define MyAppPublisher "MediaHub-Org"
#define MyAppExeName   "PlayTorrioMov.exe"
#define MyAppURL       "https://github.com/MediaHub-Org/PlayTorrioMov"

[Setup]
AppId={{17554E15-6F22-497C-9B63-9D05B793B89A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
OutputDir=Output
OutputBaseFilename=PlayTorrioMov-Windows-Setup
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequired=lowest
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; Clean up old files that might conflict with new version
Type: filesandordirs; Name: "{app}\data\flutter_assets\*"
Type: files; Name: "{app}\*.dll.old"

[Icons]
Name: "{group}\{#MyAppName}";    Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

unit lazdebianprocess;

{$mode objfpc}{$H+}

interface
uses
  lazdebiansettings;

procedure StartMakeBinaryPackage(Settings: TSettings; Sign: Boolean);
procedure StartMakeSourcePackage(Settings: TSettings; Sign: Boolean; Upload: Boolean);

var
  IsBuildingPackage: Boolean = False;

implementation
uses
  Classes,
  SysUtils,
  Forms,
  FileUtil,
  LCLType,
  LazIDEIntf,
  IDEExternToolIntf;

type
  { TDummy need only one instance of this and only because
    QueueAsyncCall wants a method and not a procedure}
  TDummy = class
    procedure RunBuildScriptLater(D: PtrInt);
  end;

var
  DummyObj: TDummy;

procedure CreateFile(FullPathName, Contents: String);
var
  S: TFileStream;
begin
  try
    S := TFileStream.Create(FullPathName, fmCreate);
    S.Write(Contents[1], Length(Contents));
  finally
    S.Free;
  end;
end;

procedure CreateBuildScript(Settings: TSettings; Binary, Sign, Upload: Boolean);
var
  S: String;
  SName: String;
  DEBUILD: STRING;
begin
  s := '#!/bin/sh' + LF
    + LF
    + Format('cd "%s"', [Settings.GetProjectPathAbsolute]) + LF
    + Format('mkdir -p %s', [Settings.GetTempPathAbsolute]) + LF
    + Settings.FillTemplate(Settings.ExportCommands) + LF
    + LF
    + Format('cd %s', [Settings.GetTempPathAbsolute]) + LF
    + 'rm -rf DEBUILD' + LF
    + 'rm -f DEBUILD.sh' + LF
    + LF
    + 'cd ..' + LF
    + Format('tar czf %s %s', [Settings.GetOrigTarNameOnly, Settings.GetOrigFolderNameOnly]) + LF
    + Format('mv %s "%s"', [Settings.GetOrigFolderNameOnly, Settings.GetDebuildPathAbsolute]) + LF
    + Format('mv %s "%s"', [Settings.GetOrigTarNameOnly, Settings.GetDebuildPathAbsolute]) + LF
    + LF
    + Format('cd "%s"', [Settings.GetDebuildSrcPathAbsolute]) + LF
    + 'mkdir debian' + LF
    + 'mv ../control debian/' + LF
    + 'mv ../rules debian/' + LF
    + 'mv ../changelog debian/' + LF
    + 'mv ../copyright debian/' + LF
    + 'mv ../compat debian/' + LF
    + 'mv ../Makefile ./' + LF
    + LF;

  if Binary then
    S += 'debuild -d -us -uc' + LF
  else
    S += 'debuild -S -us -uc' + LF;

  if Sign then begin
    S += 'cd ..' + LF;
    S += 'xterm -e "debsign *.changes"' + LF;
  end;

  SName := ConcatPaths([Settings.GetProjectPathAbsolute, 'DEBUILD.sh']);
  CreateFile(SName, S);
end;

procedure CreateDebianFiles(Settings: TSettings);
var
  DirDebuild: String;
begin
  DirDebuild :=ConcatPaths([Settings.GetProjectPathAbsolute, 'DEBUILD']);
  if DirectoryExists(DirDebuild) then
    DeleteDirectory(DirDebuild, False);
  MkDir(DirDebuild);
  CreateFile(ConcatPaths([DirDebuild, 'compat']), '8');
  CreateFile(ConcatPaths([DirDebuild, 'control']), Settings.FillTemplate(Settings.Control));
  CreateFile(ConcatPaths([DirDebuild, 'rules']), Settings.FillTemplate(Settings.Rules));
  CreateFile(ConcatPaths([DirDebuild, 'changelog']), Settings.FillTemplate(Settings.Changelog));
  CreateFile(ConcatPaths([DirDebuild, 'copyright']), Settings.FillTemplate(Settings.Copyright));
  {$warning FIXME: respect the setting "Makefile / Use Existing", implement this!}
  CreateFile(ConcatPaths([DirDebuild, 'Makefile']), Settings.FillTemplate(Settings.Makefile));
end;

procedure RunBuildScript(Settings: TSettings);
begin
  Application.QueueAsyncCall(@DummyObj.RunBuildScriptLater, PtrInt(Settings));
end;

procedure WarnStillRunning;
begin
  Application.MessageBox('LazDebian still running', 'LazDebian', MB_OK + MB_ICONWARNING);
end;

procedure StartMakeBinaryPackage(Settings: TSettings; Sign: Boolean);
begin
  CreateDebianFiles(Settings);
  CreateBuildScript(Settings, True, Sign, False);
  RunBuildScript(Settings);
end;

procedure StartMakeSourcePackage(Settings: TSettings; Sign: Boolean; Upload: Boolean);
begin
  CreateDebianFiles(Settings);
  CreateBuildScript(Settings, False, Sign, Upload);
  RunBuildScript(Settings);
end;

{ TScriptRunner }

procedure TDummy.RunBuildScriptLater(D: PtrInt);
var
  Settings: TSettings;
  Tool: TIDEExternalToolOptions;
begin
  Settings := TSettings(D);
  Tool := TIDEExternalToolOptions.Create;
  Tool.Filename := '/bin/sh';
  Tool.CmdLineParams := 'DEBUILD.sh';
  Tool.WorkingDirectory := Settings.GetProjectPathAbsolute;
  Tool.ShowAllOutput := True;
  RunExternalTool(Tool);
  Tool.Free;
  Settings.Free;
end;

initialization
  DummyObj := TDummy.Create;
finalization
  DummyObj.Free;
end.


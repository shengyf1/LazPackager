{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit lazdebian;

interface

uses
  frmDebianOptions, LazPackagerMain, LazPackagerBase, frmLazPackagerPreview, 
  frmLazPackagerMakeDeb, LazPackagerDebian, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('LazPackagerMain', @LazPackagerMain.Register);
end;

initialization
  RegisterPackage('lazdebian', @Register);
end.

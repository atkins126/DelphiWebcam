unit fmSelectFormat;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils,
  System.Variants, System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.ComCtrls,
  UWebcam;

type
  TfrmSelectFormat = class(TForm)
    lvFormatInfo: TListView;
    procedure lvFormatInfoDblClick(Sender: TObject);
  public
    Caps: TStreamCaps;
  end;

var
  frmSelectFormat: TfrmSelectFormat;

function CreateSelectFormatForm(pCaps: TList<TStreamCaps>; pParent: TComponent = nil): TfrmSelectFormat;

implementation

{$R *.dfm}

function CreateSelectFormatForm(pCaps: TList<TStreamCaps>; pParent: TComponent = nil): TfrmSelectFormat;
var
  vListItem: TListItem;
  vCount: Integer;
begin
  Result := TfrmSelectFormat.Create(pParent);

  if (pCaps = nil) or (pCaps.Count = 0) then
    Exit;

  for vCount := 0 to pCaps.Count - 1 do
  begin
    vListItem := Result.lvFormatInfo.Items.Add;
    vListItem.Caption := IntToStr(pCaps[vCount].MaxWidth);
    vListItem.SubItems.Add(IntToStr(pCaps[vCount].MaxHeight));
    vListItem.SubItems.Add(IntToStr(pCaps[vCount].MinWidth));
    vListItem.SubItems.Add(IntToStr(pCaps[vCount].MinHeight));
    vListItem.SubItems.Add(IntToStr(pCaps[vCount].MaxFrameRate));
    vListItem.SubItems.Add(IntToStr(pCaps[vCount].MinFrameRate));
    vListItem.SubItems.Add(IntToStr(pCaps[vCount].MaxBitrate));
    vListItem.SubItems.Add(IntToStr(pCaps[vCount].MinBitrate));
  end;
end;

procedure TfrmSelectFormat.lvFormatInfoDblClick(Sender: TObject);
var
  vSelected: TListItem;
begin
  vSelected := lvFormatInfo.Selected;

  Self.Caps.MaxWidth := StrToInt(vSelected.Caption);
  Self.Caps.MaxHeight := StrToInt(vSelected.SubItems[0]);
  Self.Caps.MinWidth := StrToInt(vSelected.SubItems[1]);
  Self.Caps.MinHeight := StrToInt(vSelected.SubItems[2]);

  Self.Caps.MaxFrameRate := StrToInt(vSelected.SubItems[3]);
  Self.Caps.MinFrameRate := StrToInt(vSelected.SubItems[4]);
  Self.Caps.MaxBitrate := StrToInt(vSelected.SubItems[5]);
  Self.Caps.MinBitrate := StrToInt(vSelected.SubItems[6]);
  Self.Close;
end;

end.

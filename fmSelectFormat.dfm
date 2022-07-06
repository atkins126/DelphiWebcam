object frmSelectFormat: TfrmSelectFormat
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'frmSelectFormat'
  ClientHeight = 299
  ClientWidth = 558
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object lvFormatInfo: TListView
    Left = -1
    Top = 0
    Width = 586
    Height = 300
    Columns = <
      item
        Caption = 'MaxWidth'
        Width = 65
      end
      item
        Caption = 'MaxHeight'
        Width = 65
      end
      item
        Caption = 'MinWidth'
        Width = 60
      end
      item
        Caption = 'MinHeight'
        Width = 60
      end
      item
        Caption = 'MaxFrameRate'
        Width = 85
      end
      item
        Caption = 'MinFrameRate'
        Width = 82
      end
      item
        Caption = 'MaxBitrate'
        Width = 70
      end
      item
        Caption = 'MinBitrate'
        Width = 70
      end>
    GridLines = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnDblClick = lvFormatInfoDblClick
  end
end

object frmWebcam: TfrmWebcam
  Left = 0
  Top = 0
  Caption = 'Webcam'
  ClientHeight = 422
  ClientWidth = 1122
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object imWebcam: TImage
    Left = 176
    Top = 8
    Width = 474
    Height = 385
  end
  object lblLogger: TLabel
    Left = 664
    Top = 8
    Width = 80
    Height = 23
    Caption = 'LOGGER'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblWebcamState: TLabel
    Left = 664
    Top = 155
    Width = 63
    Height = 23
    Caption = 'State: '
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblWebcamStateValue: TLabel
    Left = 733
    Top = 155
    Width = 39
    Height = 23
    Caption = 'Null'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -19
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblFrameRate: TLabel
    Left = 664
    Top = 195
    Width = 110
    Height = 23
    Caption = 'FrameRate:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblFrameRateValue: TLabel
    Left = 788
    Top = 195
    Width = 12
    Height = 23
    Caption = '0'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 4259584
    Font.Height = -19
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblDeviceList: TLabel
    Left = 9
    Top = 141
    Width = 58
    Height = 13
    Caption = 'DeviceList'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblFrameRateOptions: TLabel
    Left = 9
    Top = 226
    Width = 63
    Height = 13
    Caption = 'FrameRate'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object btnPlay: TButton
    Left = 8
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Play'
    TabOrder = 0
    OnClick = btnPlayClick
  end
  object mem: TMemo
    Left = 664
    Top = 37
    Width = 449
    Height = 100
    TabOrder = 1
  end
  object btnStop: TButton
    Left = 8
    Top = 102
    Width = 75
    Height = 25
    Caption = 'Stop'
    TabOrder = 2
    OnClick = btnStopClick
  end
  object btnPause: TButton
    Left = 8
    Top = 70
    Width = 75
    Height = 25
    Caption = 'Pause'
    TabOrder = 3
    OnClick = btnPauseClick
  end
  object btnResume: TButton
    Left = 8
    Top = 39
    Width = 75
    Height = 25
    Caption = 'Resume'
    TabOrder = 4
    OnClick = btnResumeClick
  end
  object cmbxDevices: TComboBox
    Left = 9
    Top = 160
    Width = 145
    Height = 21
    Style = csDropDownList
    TabOrder = 5
  end
  object btnUpdateDeviceList: TButton
    Left = 9
    Top = 187
    Width = 96
    Height = 25
    Caption = 'UpdateDeviceList'
    TabOrder = 6
    OnClick = btnUpdateDeviceListClick
  end
  object cmbxFrameRate: TComboBox
    Left = 9
    Top = 245
    Width = 145
    Height = 21
    Style = csDropDownList
    TabOrder = 7
    OnSelect = cmbxFrameRateSelect
  end
end

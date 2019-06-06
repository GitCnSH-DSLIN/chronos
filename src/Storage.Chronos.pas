unit Storage.Chronos;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Atom, System.Rtti;

type

  TChronosManager = class(TInterfacedObject, IAtomConsumer)
  private
    FData: TDictionary<string, TAtom>;

  public
    constructor Create; reintroduce;

    procedure SetItem<AtomType>(ATag: string; const AData: AtomType); overload;
    procedure SetItem<AtomType>(ATag: string; const AData: AtomType; ATTL: Int64); overload;
    function GetItem<AtomType>(ATag: string): AtomType;
    procedure RemoveItem(ATag: string);
    function ContainsItem(ATag: string): Boolean;
    function TryGetItem<AtomType>(ATag: string; out AValue: AtomType): Boolean;

    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string);

    destructor Destroy; override;
  end;


 TChronos = class(TComponent)
  public
    procedure SetItem<AtomType>(ATag: string; const AData: AtomType); overload;
    procedure SetItem<AtomType>(ATag: string; const AData: AtomType; ATTL: Int64); overload;
    function GetItem<AtomType>(ATag: string): AtomType;
    procedure RemoveItem(ATag: string);
    function ContainsItem(ATag: string): Boolean;
    function TryGetItem<AtomType>(ATag: string; out AValue: AtomType): Boolean;
  end;


var
  Chronos: TChronos;

procedure Register;

implementation

uses
  System.IniFiles;

const
  C_SECTION = 'CHRONOS';

procedure TChronosManager.SetItem<AtomType>(ATag: string; const AData: AtomType);
begin
  SetItem<AtomType>(ATag, AData, -1);
end;

procedure TChronosManager.SetItem<AtomType>(ATag: string; const AData: AtomType; ATTL: Int64);
var
  LData: TAtom;
begin
  System.TMonitor.Enter(Self);
  ATag := ATag.ToUpper;
  try
    if FData.TryGetValue(ATag, LData) then
      LData.SetValue(AData)
    else
    begin
      LData := TAtom.Create(Self);
      FData.Add(ATag, LData);
      LData.Tag := ATag;
      LData.SetValue(AData);
    end;
    LData.TTL := ATTL;
  finally
    System.TMonitor.Exit(Self);
  end;
end;

function TChronosManager.ContainsItem(ATag: string): Boolean;
begin
  Result := FData.ContainsKey(ATag);
end;

constructor TChronosManager.Create;
begin
  FData := TObjectDictionary<string, TAtom>.Create([doOwnsValues]);
end;

destructor TChronos.Destroy;
begin
  FData.DisposeOf;
  inherited;
end;

function TChronosManager.GetItem<AtomType>(ATag: string): AtomType;
var
  LData: TAtom;
begin
  System.TMonitor.Enter(Self);
  try
    ATag := ATag.ToUpper;
    if FData.TryGetValue(ATag, LData) then
      Result := LData.GetValue<AtomType>
  finally
    System.TMonitor.Exit(Self);
  end;
end;

procedure TChronosManager.LoadFromFile(const AFileName: string);
var
  LFile: TIniFile;
  LFileName: string;
  LAtom: TAtom;
  LStream: TMemoryStream;
  LKeys: TStringList;
  LKey: string;

begin
  LFileName := ChangeFileExt(AFileName, '.ini');
  LKeys := TStringList.Create;
  try

    LFile := TIniFile.Create(LFileName);
    try
      LFile.ReadSection(C_SECTION, LKeys);
      for LKey in LKeys do
      begin
        if not FData.TryGetValue(LKey, LAtom) then
        begin
          LAtom := TAtom.Create(Self);
          FData.Add(LKey, LAtom);
        end;

        LStream := TMemoryStream.Create;
        try
          LFile.ReadBinaryStream(C_SECTION, LKey, LStream);
          LAtom.Restore(LStream);
        finally
          LStream.Free;
        end;

      end;

    finally
      LFile.DisposeOf;
    end;
  finally
    LKeys.DisposeOf;
  end;
end;

procedure TChronosManager.RemoveItem(ATag: string);
begin
  System.TMonitor.Enter(Self);
  try
    ATag := ATag.ToUpper;
    FData.Remove(ATag);
  finally
    System.TMonitor.Exit(Self);
  end;
end;

procedure TChronosManager.SaveToFile(const AFileName: string);
var
  LFile: TIniFile;
  LFileName: string;
  LAtomPair: TPair<string, TAtom>;
  LStream: TStream;
  LFileTmp: TextFile;
begin
  LFileName := ChangeFileExt(AFileName, '.ini');
  if not FileExists(LFileName) then
  begin
    AssignFile(LFileTmp, LFileName);
    Rewrite(LFileTmp);
    CloseFile(LFileTmp);
  end;

  LFile := TIniFile.Create(LFileName);
  try
    for LAtomPair in FData do
    begin
      LStream := LAtomPair.Value.Raw;
      try
        LFile.WriteBinaryStream(C_SECTION, LAtomPair.Key, LStream);
      finally
        LStream.DisposeOf;
      end;
    end;

    LFile.UpdateFile;
  finally
    LFile.DisposeOf;
  end;
end;

function TChronosManager.TryGetItem<AtomType>(ATag: string; out AValue: AtomType): Boolean;
var
  LAtom: TAtom;
begin
  Result := FData.TryGetValue(ATag, LAtom);
  if Result then
    AValue := LAtom.GetValue<AtomType>;
end;

{ TChronosComponent }

function TChronos.ContainsItem(ATag: string): Boolean;
begin
  Result := Chronos.ContainsItem(ATag)
end;

function TChronos.GetItem<AtomType>(ATag: string): AtomType;
begin
  Result := Chronos.GetItem<AtomType>(ATag);
end;

procedure TChronos.RemoveItem(ATag: string);
begin
  Chronos.RemoveItem(ATag);
end;

procedure TChronos.SetItem<AtomType>(ATag: string; const AData: AtomType);
begin
  Chronos.SetItem<AtomType>(ATag, AData);
end;

procedure TChronos.SetItem<AtomType>(ATag: string; const AData: AtomType; ATTL: Int64);
begin
  Chronos.SetItem<AtomType>(ATag, AData, ATTL);
end;

function TChronos.TryGetItem<AtomType>(ATag: string; out AValue: AtomType): Boolean;
begin
  Result := Chronos.TryGetItem<AtomType>(ATag, AData);
end;

procedure Register;
begin
  Classes.RegisterComponents('HashLoad', [TChronosComponent]);
end;

initialization

Chronos := TChronosManager.Create;

end.

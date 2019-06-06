unit ChronosDb;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Atom, System.Rtti;

type
  TChronos = class(TInterfacedObject, IAtomConsumer)
  private
    FData: TDictionary<string, TAtom>;

  public
    constructor Create; reintroduce;

    procedure Add<AtomType>(ATag: string; const AData: AtomType); overload;
    procedure Add<AtomType>(ATag: string; const AData: AtomType; ATTL: Int64); overload;
    function Get<AtomType>(ATag: string): AtomType;
    procedure Remove(ATag: string);
    function Contains(ATag: string): Boolean;
    function TryGet<AtomType>(ATag: string; out AValue: AtomType): Boolean;

    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string);

    destructor Destroy; override;
  end;

var
  Chronos: TChronos;

implementation

uses
  System.IniFiles;

const
  C_SECTION = 'CHRONOS';

procedure TChronos.Add<AtomType>(ATag: string; const AData: AtomType);
begin
  Add<AtomType>(ATag, AData, -1);
end;

procedure TChronos.Add<AtomType>(ATag: string; const AData: AtomType; ATTL: Int64);
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

function TChronos.Contains(ATag: string): Boolean;
begin
  Result := FData.ContainsKey(ATag);
end;

constructor TChronos.Create;
begin
  FData := TObjectDictionary<string, TAtom>.Create([doOwnsValues]);
end;

destructor TChronos.Destroy;
begin
  FData.DisposeOf;
  inherited;
end;

function TChronos.Get<AtomType>(ATag: string): AtomType;
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

procedure TChronos.LoadFromFile(const AFileName: string);
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

procedure TChronos.Remove(ATag: string);
begin
  System.TMonitor.Enter(Self);
  try
    ATag := ATag.ToUpper;
    FData.Remove(ATag);
  finally
    System.TMonitor.Exit(Self);
  end;
end;

procedure TChronos.SaveToFile(const AFileName: string);
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

function TChronos.TryGet<AtomType>(ATag: string; out AValue: AtomType): Boolean;
var
  LAtom: TAtom;
begin
  Result := FData.TryGetValue(ATag, LAtom);
  if Result then
    AValue := LAtom.GetValue<AtomType>;
end;

initialization

Chronos := TChronos.Create;

end.

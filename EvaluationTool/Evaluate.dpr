program Evaluate;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Classes,
  Vcl.Forms,
  uLevenshtein,
  System.StrUtils,
  System.Types,
  System.TypInfo,
  Dialogs,
  System.Generics.Collections,
  UTools;

type
  TConflations = Class;

  TWordStem = class
  private
    FWord: string;
    FStem1: string;
    FStem2: string;
    procedure SetWord(const Value: string);
    procedure SetStem1(const Value: string);
    procedure SetStem2(const Value: string);
  Public
    function IsSame(const AStem: string): Boolean; overload;
    function IsSame(const AStem1, AStem2: string): Boolean; overload;
  published
    Property Word: String read FWord write SetWord;
    Property Stem1: String read FStem1 write SetStem1;
    Property Stem2: String read FStem2 write SetStem2;
  end;

  { TWordStem = class
    Public
    Word: string;
    Stem1: string;
    Stem2: string;
    function IsSame(const AStem: string): Boolean; overload;
    function IsSame(const AStem1, AStem2: string): Boolean; overload;
    end; }

  TWordStemArray = array of TWordStem;

  TConflation = Class(TCollectionItem)
  private
    FMainStem1: String;
    FMainStem2: String;
    FGroups: TWordStemArray;
    Procedure SetMainStem1(Value: String);
    Procedure SetMainStem2(Value: String);
    function GetWordStemArray: TWordStemArray;
    Function GetConflations: TConflations;
    function GetSize: Integer;
    function GetDMT: Double;
    function GetUMT: Double;
    function GetDNT: Double;
    function GetWMT: Double;
    function GetAMT: Double;
  public
    Constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    Procedure Assign(Source: TPersistent); override;
    Property Conflations: TConflations read GetConflations;
    Procedure AddWordStem(Const sWord, sStem1, sStem2: string);
  published
    Property MainStem1: String read FMainStem1 write SetMainStem1;
    Property MainStem2: String read FMainStem2 write SetMainStem2;
    Property Groups: TWordStemArray read GetWordStemArray;
    Property Size: Integer read GetSize;
    property DMT: Double read GetDMT;
    property UMT: Double read GetUMT;
    property DNT: Double read GetDNT;
    property WMT: Double read GetWMT;
    property AMT: Double read GetAMT;
  End;

  TConflations = Class(TOwnedCollection)
  private
    FWordCount: Integer;
    Function GetItem(Index: Integer): TConflation;
    Procedure SetItem(Index: Integer; Value: TConflation);
    function GetGDMT: Double;
    function GetGUMT: Double;
    function GetGAMT: Double;
    function GetGDNT: Double;
    function GetGWMT: Double;
  public
    Constructor Create(AOwner: TPersistent);
    Procedure AssignValues(Value: TConflations);
    Procedure AddConflation(Value: TConflation);
    Procedure RemoveConflation(Value: TConflation);
    Function CreateConflation(Const AMainStem1, AMainStem2, AWord, AStem1,
      AStem2: String): TConflation;
    Function IndexOf(Const AMainStem1: String): Integer;
    Property Items[Index: Integer]: TConflation read GetItem
      write SetItem; default;

    property WordCount: Integer read FWordCount write FWordCount;
    property GDNT: Double read GetGDNT;
    property GAMT: Double read GetGAMT;
    property GWMT: Double read GetGWMT;
    property GDMT: Double read GetGDMT;
    property GUMT: Double read GetGUMT;
  End;

  TStemmingResult = class(TComponent)
  private
    FConflations: TConflations;
    Procedure SetConflations(Value: TConflations);
    function GetUI: Double;
    function GetCI: Double;
    function GetDI: Double;
    function GetOI: Double;
    function GetOIL: Double;
  public
    Constructor Create(AOwner: TComponent); override;
    Destructor Destroy; override;
    Procedure Assign(Source: TPersistent); override;
    Function ConflactionCount: Integer;
    Function GetErrorCount: Integer;
  published
    Property ErrorCount: Integer read GetErrorCount;
    Property Conflations: TConflations read FConflations write SetConflations;
    property UI: Double read GetUI;
    property CI: Double read GetCI;

    property OI: Double read GetOI;
    property OIL: Double read GetOIL;
    property DI: Double read GetDI;
  end;

  TRec = record
    All: Integer;
    Error: Integer;
  end;

var
  Rec: TRec;
  TestWords: TStrings;
  StemIdx, MyStemIdx, PoSIdx: Integer;
  Words, Stems: TStringDynArray;
  sInputFile, sOutputFile: string;
  fPercision, fRecall, fF: Double;
  I, J, WordsCount, ErrorsCount, CommErr, OmmErr, UnderErr, OverErr,
    iConstantStemCount: Integer;
  OutputFile, Commission, Ommission: TStringList;
  Understemming, Overstemming: TStemmingResult;
  TagDict: TDictionary<String, TRec>;

const
  SSeprator = #9;

function GetMostLikeIdx(const S: string; const sList: TStringDynArray): Integer;
var
  I: Integer;
  fMin, fTemp: Double;
begin
  Result := 0;
  fMin := StringSimilarityRatio(S, sList[0], False);
  for I := 1 to High(sList) do
  begin
    fTemp := uLevenshtein.StringSimilarityRatio(S, sList[I], False);
    if fMin < fTemp then
    begin
      Result := I;
      fMin := fTemp;
    end;
  end;
end;

{ TWordStem }

function TWordStem.IsSame(const AStem: string): Boolean;
begin
  Result := (not ParamIsEmpty(AStem)) and ((AStem = Stem1) Or (AStem = Stem2));
end;

function TWordStem.IsSame(const AStem1, AStem2: string): Boolean;
begin
  Result := IsSame(AStem1) or IsSame(AStem2);
end;

procedure TWordStem.SetStem1(const Value: string);
begin
  FStem1 := Value;
end;

procedure TWordStem.SetStem2(const Value: string);
begin
  FStem2 := Value;
end;

procedure TWordStem.SetWord(const Value: string);
begin
  FWord := Value;
end;

{ TConflation }

constructor TConflation.Create(Collection: TCollection);
begin
  Inherited Create(Collection);

  FMainStem1 := '';
  FMainStem2 := '';
  SetLength(FGroups, 0);
end;

destructor TConflation.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FGroups) do
    FGroups[I].Free;

  SetLength(FGroups, 0);
  inherited Destroy;
end;

function TConflation.GetWordStemArray: TWordStemArray;
begin
  Result := FGroups;
  // SetLength(Result, Length(FGroups));
  // CopyArray(Result, FGroups, TypeInfo(TObject), Length(FGroups));
end;

procedure TConflation.Assign(Source: TPersistent);
Var
  S: TConflation;
Begin
  If Source Is TConflation Then
  Begin
    If Collection <> Nil Then
      Collection.BeginUpdate;
    Try
      S := TConflation(Source);
      FMainStem1 := S.MainStem1;
      FMainStem2 := S.MainStem2;
      FGroups := S.Groups;
    Finally
      If Collection <> Nil Then
        Collection.EndUpdate;
    End;
  End
  Else
    Inherited Assign(Source);
end;

procedure TConflation.AddWordStem(const sWord, sStem1, sStem2: string);
var
  L: Integer;
begin
  L := Length(FGroups);
  SetLength(FGroups, L + 1);
  FGroups[High(FGroups)] := TWordStem.Create;
  with FGroups[High(FGroups)] do
  begin
    Word := sWord;
    Stem1 := sStem1;
    Stem2 := sStem2;
  end;
end;

function TConflation.GetConflations: TConflations;
begin
  If Collection Is TConflations Then
    Result := TConflations(Collection)
  Else
    Result := Nil;
end;

function TConflation.GetSize: Integer;
begin
  Result := Length(FGroups);
end;

// *****   Method to calculate the "actual merge total" for a stem group   *****
function TConflation.GetAMT: Double;
var
  n: Integer;
begin
  n := Size;
  Result := (0.5 * n * (n - 1));
end;

// *****   Method to calculate the 'desired merge total' (DMT)   *****
function TConflation.GetDMT: Double;
var
  n: Integer;
begin
  n := Size;
  Result := 0;
  if (n <> 0) then
    Result := 0.5 * (n * (n - 1));
end;

// *****   Method to calculate the "desired non-merge total" for a number group   *****
function TConflation.GetDNT: Double;
var
  n: Integer;
begin
  n := Size;
  Result := 0.5 * (n * (Conflations.WordCount - n));
end;

// *****   Method to calculate the 'unacheived merge total' (UMT)   *****
function TConflation.GetUMT: Double;
var
  uNg: Double;
  I, iCount: Integer;
  sCount: string;
  sl: TStringList;
begin
  uNg := Size;
  Result := 0;

  if uNg = 1 then
    Result := 0
  else
  begin
    sl := TStringList.Create;
    try
      sl.NameValueSeparator := #9;
      for I := 0 to High(FGroups) do
      begin
        sCount := sl.Values[FGroups[I].Stem1];
        if sCount = '' then
          sl.Values[FGroups[I].Stem1] := '1'
        else
          sl.Values[FGroups[I].Stem1] := IntToStr(StrToInt(sCount.Trim) + 1);
      end;

      for I := 0 to sl.Count - 1 do
      begin
        iCount := StrToInt(sl.ValueFromIndex[I]);
        Result := Result + (iCount * (uNg - iCount));
      end;
    finally
      sl.Free;
    end;
  end;

  Result := 0.5 * Result;
end;

// *****   Method to calculate the 'wrongly-merged total' for a stem group
function TConflation.GetWMT: Double;
var
  uNg: Double;
  I, iCount: Integer;
  sCount, S: string;
  sl: TStringList;
begin
  uNg := Size;
  Result := 0;

  if uNg = 1 then
    Result := 0
  else
  begin
    sl := TStringList.Create;
    try
      sl.NameValueSeparator := '=';

      S := '';
      for I := 0 to High(FGroups) do
        S := S + ',' + FGroups[I].Stem1;
      try
        for I := 0 to High(FGroups) do
        begin
          sCount := sl.Values[FGroups[I].Stem1];
          if sCount = '' then
            sl.Values[FGroups[I].Stem1] := '1'
          else
            sl.Values[FGroups[I].Stem1] := IntToStr(StrToInt(sCount) + 1);
        end;
      except
        ShowMessage(nl2br(sl.Text) + S);
      end;

      for I := 0 to sl.Count - 1 do
      begin
        iCount := StrToInt(sl.ValueFromIndex[I]);
        Result := Result + (iCount * (uNg - iCount));
      end;
    finally
      sl.Free;
    end;
  end;

  Result := 0.5 * Result;
end;

procedure TConflation.SetMainStem1(Value: String);
begin
  FMainStem1 := Value;
end;

procedure TConflation.SetMainStem2(Value: String);
begin
  FMainStem2 := Value;
end;

{ TConflations }

constructor TConflations.Create(AOwner: TPersistent);
begin
  Inherited Create(AOwner, TConflation);
end;

procedure TConflations.AssignValues(Value: TConflations);
Var
  I: Integer;
  // P: TConflation;
Begin
  BeginUpdate;
  Try
    { For I := 0 To Value.Count - 1 Do
      Begin
      P := FindField(Value[I].Name);
      If P <> Nil Then
      P.Assign(Value[I]);
      End; }
  Finally
    EndUpdate;
  End;
End;

procedure TConflations.AddConflation(Value: TConflation);
begin
  Value.Collection := Self;
end;

function TConflations.CreateConflation(const AMainStem1, AMainStem2, AWord,
  AStem1, AStem2: String): TConflation;
var
  Idx: Integer;
begin
  Idx := IndexOf(AMainStem1);

  if Idx = -1 then
    Result := Add As TConflation
  else
    Result := Items[Idx];

  Result.MainStem1 := AMainStem1;
  Result.MainStem2 := AMainStem2;
  Result.AddWordStem(AWord, AStem1, AStem2);
end;

function TConflations.GetGAMT: Double;
var
  I: Integer;
begin
  Result := 0;
  For I := 0 To Count - 1 Do
    Result := Result + Items[I].AMT;
end;

function TConflations.GetGDMT: Double;
var
  I: Integer;
begin
  Result := 0;
  For I := 0 To Count - 1 Do
    Result := Result + Items[I].DMT;
end;

function TConflations.GetGDNT: Double;
var
  I: Integer;
begin
  Result := 0;
  For I := 0 To Count - 1 Do
    Result := Result + Items[I].DNT;
end;

function TConflations.GetGUMT: Double;
var
  I: Integer;
begin
  Result := 0;
  For I := 0 To Count - 1 Do
    Result := Result + Items[I].UMT;
end;

function TConflations.GetGWMT: Double;
var
  I: Integer;
begin
  Result := 0;
  For I := 0 To Count - 1 Do
    Result := Result + Items[I].WMT;
end;

function TConflations.GetItem(Index: Integer): TConflation;
begin
  Result := TConflation(Inherited Items[Index]);
end;

function TConflations.IndexOf(const AMainStem1: String): Integer;
begin
  For Result := 0 To Count - 1 Do
    If SameText(TConflation(Items[Result]).MainStem1, AMainStem1) Then
      Exit;
  Result := -1;
end;

procedure TConflations.RemoveConflation(Value: TConflation);
begin
  If Value.Collection = Self Then
    Value.Collection := Nil;
end;

procedure TConflations.SetItem(Index: Integer; Value: TConflation);
begin
  Inherited SetItem(Index, TCollectionItem(Value));
end;

{ TStemmingResult }

constructor TStemmingResult.Create(AOwner: TComponent);
begin
  Inherited Create(AOwner);

  FConflations := TConflations.Create(Self);
end;

destructor TStemmingResult.Destroy;
begin
  FreeAndNil(FConflations);
  Inherited Destroy;
end;

procedure TStemmingResult.Assign(Source: TPersistent);
begin
  Inherited Assign(Source);
end;

function TStemmingResult.ConflactionCount: Integer;
begin
  Result := FConflations.Count;
end;

function TStemmingResult.GetErrorCount: Integer;
Var
  I, J: Integer;
Begin
  Result := 0;
  For I := 0 To ConflactionCount - 1 Do
    with Conflations[I] do
    Begin
      if Length(Groups) = 1 then
        Continue;

      for J := 0 to High(Groups) do
      begin
        if not Groups[J].IsSame(MainStem1, MainStem2) then
          Inc(Result);
      end;
    End;
End;

function TStemmingResult.GetCI: Double;
begin
  Result := 1 - UI;
end;

function TStemmingResult.GetOI: Double;
var
  fTemp: Double;
begin
  Result := 0;
  fTemp := Conflations.GDNT;
  if fTemp <> 0 then
    Result := Conflations.GWMT / fTemp;
end;

function TStemmingResult.GetOIL: Double;
var
  fTemp: Double;
begin
  Result := 0;
  fTemp := Conflations.GAMT;
  if fTemp <> 0 then
    Result := Conflations.GWMT / fTemp;
end;

function TStemmingResult.GetDI: Double;
begin
  Result := 1 - OIL;
end;

function TStemmingResult.GetUI: Double;
var
  fTemp: Double;
begin
  Result := 0;
  fTemp := Conflations.GDMT;
  if fTemp <> 0 then
    Result := Conflations.GUMT / fTemp;
end;

procedure TStemmingResult.SetConflations(Value: TConflations);
begin
  FConflations.AssignValues(Value);
end;

function IsEqual(const str1, str2: string): Boolean;
begin
  Result := ArabicStr(str1.Trim) = ArabicStr(str2.Trim);
end;

Function Contains(Const Arr: TStringDynArray; Const sValue: String): Integer;
Begin
  For Result := Low(Arr) To High(Arr) Do
    If IsEqual(Arr[Result], sValue) Then
      Exit;

  Result := -1;
End;

begin
  ReportMemoryLeaksOnShutdown := True;

  try
    sInputFile := ParamStr(1);
    if not FileExists(sInputFile) then
    begin
      Writeln('file not found!');
      Exit;
    end;

    StemIdx := StrToIntDef(ParamStr(2), 1);
    MyStemIdx := StrToIntDef(ParamStr(3), 3);
    PoSIdx := MyStemIdx - 1;

    sOutputFile := UnUsedFileName('Output_', '.txt');
    if ParamCount >= 1 then
      sOutputFile := ChangeFileExt(ParamStr(4), '.txt');

    OutputFile := TStringList.Create;
    Commission := TStringList.Create;
    Ommission := TStringList.Create;
    TagDict := TDictionary<string, TRec>.Create;
    Understemming := TStemmingResult.Create(nil);
    Overstemming := TStemmingResult.Create(nil);
    try
      TestWords := TStringList.Create;
      try
        TestWords.LoadFromFile(sInputFile, TEncoding.UTF8);

        WordsCount := TestWords.Count;
        CommErr := 0;
        OmmErr := 0;
        ErrorsCount := 0;
        iConstantStemCount := 0;
        Understemming.Conflations.WordCount := TestWords.Count;
        Overstemming.Conflations.WordCount := TestWords.Count;
        for I := 0 to TestWords.Count - 1 do
        begin
          Words := Explode(TestWords[I], SSeprator);
          Stems := Explode(Words[StemIdx] + ',,', ',');

          if ParamIsEmpty(Stems[1]) then
            Stems[1] := Stems[0];

          if TagDict.TryGetValue(Words[PoSIdx][1], Rec) then
          begin
            Rec.All := Rec.All + 1;
            TagDict.AddOrSetValue(Words[PoSIdx][1], Rec);
          end
          else
          begin
            Rec.All := 1;
            Rec.Error := 0;
            TagDict.Add(Words[PoSIdx][1], Rec);
          end;

          if (IsEqual(Stems[0], Words[0]) or IsEqual(Stems[1], Words[0])) then
            Inc(iConstantStemCount);

          if Contains(Stems, Words[MyStemIdx]) = -1 then // error in stemming
          begin
            TagDict.TryGetValue(Words[PoSIdx][1], Rec);
            Rec.Error := Rec.Error + 1;
            TagDict.AddOrSetValue(Words[PoSIdx][1], Rec);

            Inc(ErrorsCount);
            if Length(Stems) = 1 then
            begin
              if Length(Stems[0]) < Length(Words[MyStemIdx]) then
                // understemming
                Commission.Add(TestWords[I])
              else
                Ommission.Add(TestWords[I]);
            end
            else // length(stems) > 1
            begin
              J := GetMostLikeIdx(Words[MyStemIdx], Stems);
              if Length(Stems[J]) < Length(Words[MyStemIdx]) then
                // understemming
                Commission.Add(TestWords[I])
              else
                Ommission.Add(TestWords[I]);
            end;
          end;

          try
            Understemming.Conflations.CreateConflation(ArabicStr(Stems[1].Trim),
              ArabicStr(Stems[2].Trim), Words[0],
              ArabicStr(Words[MyStemIdx].Trim), '');

            Overstemming.Conflations.CreateConflation
              (ArabicStr(Words[MyStemIdx].Trim), '', Words[0],
              ArabicStr(Stems[1].Trim), ArabicStr(Stems[2].Trim));
          except
            ShowMessage(IntToStr(I));
            Exit;
          end;

        end;
      finally
        TestWords.Free;
      end; // try

      CommErr := Commission.Count;
      OmmErr := Ommission.Count;
      ErrorsCount := CommErr + OmmErr;

      OutputFile.Add(Format('Words count: %d', [WordsCount]));
      OutputFile.Add(Format('Stemming Errors: %d, %0.2f%%',
        [ErrorsCount, Percent(ErrorsCount, WordsCount)]));

      OutputFile.Add(Format('Accuracy: %d, %0.2f%%', [WordsCount - ErrorsCount,
        100 - Percent(ErrorsCount, WordsCount)]));

      fPercision := (WordsCount - ErrorsCount) / WordsCount;
      fRecall := (WordsCount - ErrorsCount) /
        (WordsCount - ErrorsCount + iConstantStemCount);
      fF := (2 * fPercision * fRecall) / (fPercision + fRecall);

      OutputFile.Add(Format('Percision: %0.2f%%', [fPercision * 100]));
      OutputFile.Add(Format('Recall: %0.2f%%', [fRecall * 100]));
      OutputFile.Add(Format('F Measure: %0.2f%%', [fF * 100]));

      UnderErr := Understemming.ErrorCount;
      OverErr := Overstemming.ErrorCount;

      OutputFile.Add('');
      OutputFile.Add(Format('Conflaction Groups in Understemming: %d, %f%%, %f',
        [Understemming.ConflactionCount, Percent(Understemming.ConflactionCount,
        WordsCount), WordsCount / Understemming.ConflactionCount]));
      OutputFile.Add(Format('UI: %f%%, CI: %f%%', [Understemming.UI,
        Understemming.CI]));
      OutputFile.Add
        (Format('Overstemming Groups in Understemming: %d, %f%%, %f',
        [Overstemming.ConflactionCount, Percent(Overstemming.ConflactionCount,
        WordsCount), WordsCount / Overstemming.ConflactionCount]));
      OutputFile.Add(Format('OI: %f%%, OIL: %f%%, DI: %f%%',
        [Overstemming.OI, Overstemming.OIL, Overstemming.DI]));
      OutputFile.Add(Format('SW: %f%%, SW: %f%%',
        [Overstemming.OI / Understemming.UI, Overstemming.OIL /
        Understemming.UI]));

      OutputFile.Add('');
      OutputFile.Add(Format('Understemming Errors: %d, %0.2f%%, %0.2f%%',
        [UnderErr, Percent(UnderErr, WordsCount), Percent(UnderErr,
        Understemming.ConflactionCount)]));
      OutputFile.Add(Format('Overstemming Errors: %d, %0.2f%%, %0.2f%%',
        [OverErr, Percent(OverErr, WordsCount), Percent(OverErr,
        Overstemming.ConflactionCount)]));

      OutputFile.Add('');
      OutputFile.Add(Format('Commission Errors: %d, %0.2f%%, %0.2f%%',
        [CommErr, Percent(CommErr, ErrorsCount), Percent(CommErr,
        WordsCount)]));
      OutputFile.Add(Format('Ommission Errors: %d, %0.2f%%, %0.2f%%',
        [OmmErr, Percent(OmmErr, ErrorsCount), Percent(OmmErr, WordsCount)]));

      TagDict.TrimExcess;

      OutputFile.Add('');
      OutputFile.Add('Error count per PoS tag:');
      for sInputFile in TagDict.Keys do
      begin
        Rec := TagDict.Items[sInputFile];
        if Rec.Error = 0 then
          Continue;

        OutputFile.Add(Format('%s: %d of %d, %0.2f%%', [sInputFile, Rec.Error,
          Rec.All, Percent(Rec.Error, Rec.All)]));
      end;

      OutputFile.Add('');
      OutputFile.Add('Commission errors:');
      OutputFile.AddStrings(Commission);
      OutputFile.Add('');
      OutputFile.Add('Ommission errors:');
      OutputFile.AddStrings(Ommission);
      OutputFile.SaveToFile(sOutputFile, TEncoding.UTF8);
    finally
      TagDict.Free;
      Commission.Free;
      Ommission.Free;
      Understemming.Free;
      Overstemming.Free;
      OutputFile.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.

unit FastStrList;

interface

uses Windows, KOL;

type
  PFastStrListEx = ^TFastStrListEx;

  TFastStrListEx = object(TObj)
  private
    function GetItemLen(Idx: Integer): Integer;
    function GetObject(Idx: Integer): DWORD;
    procedure SetObject(Idx: Integer; const Value: DWORD);
    function GetValues(AName: PAnsiChar): PAnsiChar;
  protected
    procedure Init; virtual;
  protected
    fList: PList;
    fCount: Integer;
    fCaseSensitiveSort: Boolean;
    fTextBuf: PAnsiChar;
    fTextSiz: DWORD;
    fUsedSiz: DWORD;
  protected
    procedure ProvideSpace(AddSize: DWORD);
    function Get(Idx: Integer): ansistring;
    function GetTextStr: ansistring;
    procedure Put(Idx: Integer; const Value: ansistring);
    procedure SetTextStr(const Value: ansistring);
    function GetPAnsiChars(Idx: Integer): PAnsiChar;
    { ++ }(* public *){ -- }
    destructor Destroy; { - } virtual; { + }{ ++ }(* override; *){ -- }
  public
    function AddAnsi(const S: AnsiString): Integer;
    { * Adds Ansi AnsiString to a list. }
    function AddAnsiObject(const S: AnsiString; Obj: DWORD): Integer;
    { * Adds Ansi AnsiString and correspondent object to a list. }
    function Add(S: PAnsiChar): Integer;
    { * Adds a string to list. }
    function AddLen(S: PAnsiChar; Len: Integer): Integer;
    { * Adds a string to list. The string can contain #0 characters. }
    procedure Clear;
    { * Makes string list empty. }
    procedure Delete(Idx: Integer);
    { * Deletes string with given index (it *must* exist). }
    function IndexOf(const S: ansistring): Integer;
    { * Returns index of first string, equal to given one. }
    function IndexOf_NoCase(const S: ansistring): Integer;
    { * Returns index of first string, equal to given one (while comparing it
      without case sensitivity). }
    function IndexOfStrL_NoCase(Str: PAnsiChar; L: Integer): Integer;
    { * Returns index of first string, equal to given one (while comparing it
      without case sensitivity). }
    function Find(const S: AnsiString; var Index: Integer): Boolean;
    { * Returns Index of the first string, equal or greater to given pattern, but
      works only for sorted TFastStrListEx object. Returns TRUE if exact string found,
      otherwise nearest (greater then a pattern) string index is returned,
      and the result is FALSE. }
    procedure InsertAnsi(Idx: Integer; const S: AnsiString);
    { * Inserts ANSI string before one with given index. }
    procedure InsertAnsiObject(Idx: Integer; const S: AnsiString; Obj: DWORD);
    { * Inserts ANSI string before one with given index. }
    procedure Insert(Idx: Integer; S: PAnsiChar);
    { * Inserts string before one with given index. }
    procedure InsertLen(Idx: Integer; S: PAnsiChar; Len: Integer);
    { * Inserts string from given PAnsiChar. It can contain #0 characters. }
    function LoadFromFile(const FileName: ansistring): Boolean;
    { * Loads string list from a file. (If file does not exist, nothing
      happens). Very fast even for huge text files. }
    procedure LoadFromStream(Stream: PStream; Append2List: Boolean);
    { * Loads string list from a stream (from current position to the end of
      a stream). Very fast even for huge text. }
    procedure MergeFromFile(const FileName: ansistring);
    { * Merges string list with strings in a file. Fast. }
    procedure Move(CurIndex, NewIndex: Integer);
    { * Moves string to another location. }
    procedure SetText(const S: ansistring; Append2List: Boolean);
    { * Allows to set strings of string list from given string (in which
      strings are separated by $0D,$0A or $0D characters). Text can
      contain #0 characters. Works very fast. This method is used in
      all others, working with text arrays (LoadFromFile, MergeFromFile,
      Assign, AddAnsiStrings). }
    function SaveToFile(const FileName: ansistring): Boolean;
    { * Stores string list to a file. }
    procedure SaveToStream(Stream: PStream);
    { * Saves string list to a stream (from current position). }
    function AppendToFile(const FileName: ansistring): Boolean;
    { * Appends strings of string list to the end of a file. }
    property Count: Integer read fCount;
    { * Number of strings in a string list. }
    property Items[Idx: Integer]: ansistring read Get write Put; default;
    { * AnsiStrings array items. If item does not exist, empty string is returned.
      But for assign to property, string with given index *must* exist. }
    property ItemPtrs[Idx: Integer]: PAnsiChar read GetPAnsiChars;
    { * Fast access to item strings as PAnsiChars. }
    property ItemLen[Idx: Integer]: Integer read GetItemLen;
    { * Length of string item. }
    function Last: AnsiString;
    { * Last item (or '', if string list is empty). }
    property Text: ansistring read GetTextStr write SetTextStr;
    { * Content of string list as a single string (where strings are separated
      by characters $0D,$0A). }
    procedure Swap(Idx1, Idx2: Integer);
    { * Swaps to strings with given indeces. }
    procedure Sort(CaseSensitive: Boolean);
    { * Call it to sort string list. }
  public
    function AddObject(S: PAnsiChar; Obj: DWORD): Integer;
    function AddObjectLen(S: PAnsiChar; Len: Integer; Obj: DWORD): Integer;
    procedure InsertObject(Idx: Integer; S: PAnsiChar; Obj: DWORD);
    procedure InsertObjectLen(Idx: Integer; S: PAnsiChar; Len: Integer; Obj: DWORD);
    property Objects[Idx: Integer]: DWORD read GetObject write SetObject;
  public
    property Values[Name: PAnsiChar]: PAnsiChar read GetValues;
    function IndexOfName(AName: PAnsiChar): Integer;
  end;

function NewFastStrListEx: PFastStrListEx;

var
  Upper: array [AnsiChar] of AnsiChar;
  Upper_Initialized: Boolean;

procedure InitUpper;

implementation

function NewFastStrListEx: PFastStrListEx;
begin
  new(Result, Create);
end;

procedure InitUpper;
var
  c: AnsiChar;
begin
  for c := #0 to #255 do
    Upper[c] := AnsiUpperCase(c + #0)[1];
  Upper_Initialized := TRUE;
end;

{ TFastStrListEx }

function TFastStrListEx.AddAnsi(const S: AnsiString): Integer;
begin
  Result := AddObjectLen(PAnsiChar(S), Length(S), 0);
end;

function TFastStrListEx.AddAnsiObject(const S: AnsiString; Obj: DWORD): Integer;
begin
  Result := AddObjectLen(PAnsiChar(S), Length(S), Obj);
end;

function TFastStrListEx.Add(S: PAnsiChar): Integer;
begin
  Result := AddObjectLen(S, StrLen(S), 0)
end;

function TFastStrListEx.AddLen(S: PAnsiChar; Len: Integer): Integer;
begin
  Result := AddObjectLen(S, Len, 0)
end;

function TFastStrListEx.AddObject(S: PAnsiChar; Obj: DWORD): Integer;
begin
  Result := AddObjectLen(S, StrLen(S), Obj)
end;

function TFastStrListEx.AddObjectLen(S: PAnsiChar; Len: Integer;
  Obj: DWORD): Integer;
var
  Dest: PAnsiChar;
begin
  ProvideSpace(Len + 9);
  Dest := PAnsiChar(DWORD(fTextBuf) + fUsedSiz);
  Result := fCount;
  Inc(fCount);
  fList.Add(Pointer(DWORD(Dest) - DWORD(fTextBuf)));
  PDWORD(Dest)^ := Obj;
  Inc(Dest, 4);
  PDWORD(Dest)^ := Len;
  Inc(Dest, 4);
  if S <> nil then
    System.Move(S^, Dest^, Len);
  Inc(Dest, Len);
  Dest^ := #0;
  Inc(fUsedSiz, Len + 9);
end;

function TFastStrListEx.AppendToFile(const FileName: ansistring): Boolean;
var
  F: HFile;
  Txt: AnsiString;
begin
  Txt := Text;
  F := FileCreate(FileName, ofOpenAlways or ofOpenReadWrite or
    ofShareDenyWrite);
  if F = INVALID_HANDLE_VALUE then
    Result := FALSE
  else
  begin
    FileSeek(F, 0, spEnd);
    Result := FileWrite(F, PAnsiChar(Txt)^, Length(Txt)) = DWORD(Length(Txt));
    FileClose(F);
  end;
end;

procedure TFastStrListEx.Clear;
begin
  fList.Clear;
  if fTextBuf <> nil then
    FreeMem(fTextBuf);
  fTextBuf := nil;
  fTextSiz := 0;
  fUsedSiz := 0;
  fCount := 0;
end;

procedure TFastStrListEx.Delete(Idx: Integer);
begin
  if (Idx < 0) or (Idx >= Count) then
    Exit;
  if Idx = Count - 1 then
    Dec(fUsedSiz, ItemLen[Idx] + 9);
  fList.Delete(Idx);
  Dec(fCount);
end;

destructor TFastStrListEx.Destroy;
begin
  Clear;
  fList.Free;
  inherited;
end;

function TFastStrListEx.Find(const S: AnsiString; var Index: Integer): Boolean;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if (ItemLen[i] = Length(S)) and
      ((S = '') or CompareMem(ItemPtrs[i], @S[1], Length(S))) then
    begin
      Index := i;
      Result := TRUE;
      Exit;
    end;
  Result := FALSE;
end;

function TFastStrListEx.Get(Idx: Integer): ansistring;
begin
  if (Idx >= 0) and (Idx <= Count) then
    SetString(Result, PAnsiChar(DWORD(fTextBuf) + DWORD(fList.Items[Idx]) + 8), ItemLen[Idx])
  else
    Result := '';
end;

function TFastStrListEx.GetItemLen(Idx: Integer): Integer;
var
  Src: PDWORD;
begin
  if (Idx >= 0) and (Idx <= Count) then
  begin
    Src := PDWORD(DWORD(fTextBuf) + DWORD(fList.Items[Idx]) + 4);
    Result := Src^
  end
  else
    Result := 0;
end;

function TFastStrListEx.GetObject(Idx: Integer): DWORD;
var
  Src: PDWORD;
begin
  if (Idx >= 0) and (Idx <= Count) then
  begin
    Src := PDWORD(DWORD(fTextBuf) + DWORD(fList.Items[Idx]));
    Result := Src^
  end
  else
    Result := 0;
end;

function TFastStrListEx.GetPAnsiChars(Idx: Integer): PAnsiChar;
begin
  if (Idx >= 0) and (Idx <= Count) then
    Result := PAnsiChar(DWORD(fTextBuf) + DWORD(fList.Items[Idx]) + 8)
  else
    Result := nil;
end;

function TFastStrListEx.GetTextStr: ansistring;
var
  L, i: Integer;
  p: PAnsiChar;
begin
  L := 0;
  for i := 0 to Count - 1 do
    Inc(L, ItemLen[i] + 2);
  SetLength(Result, L);
  p := PAnsiChar(Result);
  for i := 0 to Count - 1 do
  begin
    L := ItemLen[i];
    if L > 0 then
    begin
      System.Move(ItemPtrs[i]^, p^, L);
      Inc(p, L);
    end;
    p^ := #13;
    Inc(p);
    p^ := #10;
    Inc(p);
  end;
end;

function TFastStrListEx.IndexOf(const S: ansistring): Integer;
begin
  if not Find(S, Result) then
    Result := -1;
end;

function TFastStrListEx.IndexOf_NoCase(const S: ansistring): Integer;
begin
  Result := IndexOfStrL_NoCase(PAnsiChar(S), Length(S));
end;

function TFastStrListEx.IndexOfStrL_NoCase(Str: PAnsiChar; L: Integer): Integer;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if (ItemLen[i] = L) and
      ((L = 0) or (StrLComp_NoCase(ItemPtrs[i], Str, L) = 0)) then
    begin
      Result := i;
      Exit;
    end;
  Result := -1;
end;

procedure TFastStrListEx.Init;
begin
  fList := NewList;
end;

procedure TFastStrListEx.InsertAnsi(Idx: Integer; const S: AnsiString);
begin
  InsertObjectLen(Idx, PAnsiChar(S), Length(S), 0);
end;

procedure TFastStrListEx.InsertAnsiObject(Idx: Integer; const S: AnsiString;
  Obj: DWORD);
begin
  InsertObjectLen(Idx, PAnsiChar(S), Length(S), Obj);
end;

procedure TFastStrListEx.Insert(Idx: Integer; S: PAnsiChar);
begin
  InsertObjectLen(Idx, S, StrLen(S), 0)
end;

procedure TFastStrListEx.InsertLen(Idx: Integer; S: PAnsiChar; Len: Integer);
begin
  InsertObjectLen(Idx, S, Len, 0)
end;

procedure TFastStrListEx.InsertObject(Idx: Integer; S: PAnsiChar; Obj: DWORD);
begin
  InsertObjectLen(Idx, S, StrLen(S), Obj);
end;

procedure TFastStrListEx.InsertObjectLen(Idx: Integer; S: PAnsiChar; Len: Integer;
  Obj: DWORD);
var
  Dest: PAnsiChar;
begin
  ProvideSpace(Len + 9);
  Dest := PAnsiChar(DWORD(fTextBuf) + fUsedSiz);
  fList.Insert(Idx, Pointer(DWORD(Dest) - DWORD(fTextBuf)));
  PDWORD(Dest)^ := Obj;
  Inc(Dest, 4);
  PDWORD(Dest)^ := Len;
  Inc(Dest, 4);
  if S <> nil then
    System.Move(S^, Dest^, Len);
  Inc(Dest, Len);
  Dest^ := #0;
  Inc(fUsedSiz, Len + 9);
  Inc(fCount);
end;

function TFastStrListEx.Last: AnsiString;
begin
  if Count > 0 then
    Result := Items[Count - 1]
  else
    Result := '';
end;

function TFastStrListEx.LoadFromFile(const FileName: ansistring): Boolean;
var
  Strm: PStream;
begin
  Strm := NewReadFileStream(FileName);
  TRY
    Result := Strm.Handle <> INVALID_HANDLE_VALUE;
    if Result then
      LoadFromStream(Strm, FALSE)
    else
      Clear;
  FINALLY
    Strm.Free;
  END;
end;

procedure TFastStrListEx.LoadFromStream(Stream: PStream; Append2List: Boolean);
var
  Txt: AnsiString;
begin
  SetLength(Txt, Stream.Size - Stream.Position);
  Stream.Read(Txt[1], Stream.Size - Stream.Position);
  SetText(Txt, Append2List);
end;

procedure TFastStrListEx.MergeFromFile(const FileName: ansistring);
var
  Strm: PStream;
begin
  Strm := NewReadFileStream(FileName);
  TRY
    LoadFromStream(Strm, TRUE);
  FINALLY
    Strm.Free;
  END;
end;

procedure TFastStrListEx.Move(CurIndex, NewIndex: Integer);
begin
  Assert((CurIndex >= 0) and (CurIndex < Count) and (NewIndex >= 0) and
    (NewIndex < Count), 'Item indexes violates TFastStrListEx range');
  fList.MoveItem(CurIndex, NewIndex);
end;

procedure TFastStrListEx.ProvideSpace(AddSize: DWORD);
var
  OldTextBuf: PAnsiChar;
begin
  Inc(AddSize, 9);
  if AddSize > fTextSiz - fUsedSiz then
  begin // увеличение размер?буфера
    fTextSiz := Max(1024, (fUsedSiz + AddSize) * 2);
    OldTextBuf := fTextBuf;
    GetMem(fTextBuf, fTextSiz);
    if OldTextBuf <> nil then
    begin
      System.Move(OldTextBuf^, fTextBuf^, fUsedSiz);
      FreeMem(OldTextBuf);
    end;
  end;
  if fList.Count >= fList.Capacity then
    fList.Capacity := Max(100, fList.Count * 2);
end;

procedure TFastStrListEx.Put(Idx: Integer; const Value: ansistring);
var
  Dest: PAnsiChar;
  OldLen: Integer;
  OldObj: DWORD;
begin
  OldLen := ItemLen[Idx];
  if Length(Value) <= OldLen then
  begin
    Dest := PAnsiChar(DWORD(fTextBuf) + DWORD(fList.Items[Idx]) + 4);
    PDWORD(Dest)^ := Length(Value);
    Inc(Dest, 4);
    if Value <> '' then
      System.Move(Value[1], Dest^, Length(Value));
    Inc(Dest, Length(Value));
    Dest^ := #0;
    if Idx = Count - 1 then
      Dec(fUsedSiz, OldLen - Length(Value));
  end
  else
  begin
    OldObj := 0;
    while Idx > Count do
      AddObjectLen(nil, 0, 0);
    if Idx = Count - 1 then
    begin
      OldObj := Objects[Idx];
      Delete(Idx);
    end;
    if Idx = Count then
      AddObjectLen(PAnsiChar(Value), Length(Value), OldObj)
    else
    begin
      ProvideSpace(Length(Value) + 9);
      Dest := PAnsiChar(DWORD(fTextBuf) + fUsedSiz);
      fList.Items[Idx] := Pointer(DWORD(Dest) - DWORD(fTextBuf));
      Inc(Dest, 4);
      PDWORD(Dest)^ := Length(Value);
      Inc(Dest, 4);
      if Value <> '' then
        System.Move(Value[1], Dest^, Length(Value));
      Inc(Dest, Length(Value));
      Dest^ := #0;
      Inc(fUsedSiz, Length(Value) + 9);
    end;
  end;
end;

function TFastStrListEx.SaveToFile(const FileName: ansistring): Boolean;
var
  Strm: PStream;
begin
  Strm := NewWriteFileStream(FileName);
  TRY
    if Strm.Handle <> INVALID_HANDLE_VALUE then
      SaveToStream(Strm);
    Result := TRUE;
  FINALLY
    Strm.Free;
  END;
end;

procedure TFastStrListEx.SaveToStream(Stream: PStream);
var
  Txt: AnsiString;
begin
  Txt := Text;
  Stream.Write(PAnsiChar(Txt)^, Length(Txt));
end;

procedure TFastStrListEx.SetObject(Idx: Integer; const Value: DWORD);
var
  Dest: PDWORD;
begin
  if Idx < 0 then
    Exit;
  while Idx >= Count do
    AddObjectLen(nil, 0, 0);
  Dest := PDWORD(DWORD(fTextBuf) + DWORD(fList.Items[Idx]));
  Dest^ := Value;
end;

procedure TFastStrListEx.SetText(const S: ansistring; Append2List: Boolean);
var
  Len2Add, NLines, L: Integer;
  p0, p: PAnsiChar;
begin
  if not Append2List then
    Clear;
  Len2Add := 0;
  NLines := 0;
  p := PAnsiChar(S);
  p0 := p;
  L := Length(S);
  while L > 0 do
  begin
    if p^ = #13 then
    begin
      Inc(NLines);
      Inc(Len2Add, 9 + DWORD(p) - DWORD(p0));
      REPEAT
        Inc(p);
        Dec(L);
      UNTIL (p^ <> #10) or (L = 0);
      p0 := p;
    end
    else
    begin
      Inc(p);
      Dec(L);
    end;
  end;
  if DWORD(p) > DWORD(p0) then
  begin
    Inc(NLines);
    Inc(Len2Add, 9 + DWORD(p) - DWORD(p0));
  end;
  if Len2Add = 0 then
    Exit;
  ProvideSpace(Len2Add - 9);
  if fList.Capacity <= fList.Count + NLines then
    fList.Capacity := Max((fList.Count + NLines) * 2, 100);
  p := PAnsiChar(S);
  p0 := p;
  L := Length(S);
  while L > 0 do
  begin
    if p^ = #13 then
    begin
      AddObjectLen(p0, DWORD(p) - DWORD(p0), 0);
      REPEAT
        Inc(p);
        Dec(L);
      UNTIL (p^ <> #10) or (L = 0);
      p0 := p;
    end
    else
    begin
      Inc(p);
      Dec(L);
    end;
  end;
  if DWORD(p) > DWORD(p0) then
    AddObjectLen(p0, DWORD(p) - DWORD(p0), 0);
end;

procedure TFastStrListEx.SetTextStr(const Value: ansistring);
begin
  SetText(Value, FALSE);
end;

function CompareFast(const Data: Pointer; const e1, e2: DWORD): Integer;
var
  FSL: PFastStrListEx;
  L1, L2: Integer;
  S1, S2: PAnsiChar;
begin
  FSL := Data;
  S1 := FSL.ItemPtrs[e1];
  S2 := FSL.ItemPtrs[e2];
  L1 := FSL.ItemLen[e1];
  L2 := FSL.ItemLen[e2];
  if FSL.fCaseSensitiveSort then
    Result := StrLComp(S1, S2, Min(L1, L2))
  else
    Result := StrLComp_NoCase(S1, S2, Min(L1, L2));
  if Result = 0 then
    Result := L1 - L2;
  if Result = 0 then
    Result := e1 - e2;
end;

procedure SwapFast(const Data: Pointer; const e1, e2: DWORD);
var
  FSL: PFastStrListEx;
begin
  FSL := Data;
  FSL.Swap(e1, e2);
end;

procedure TFastStrListEx.Sort(CaseSensitive: Boolean);
begin
  fCaseSensitiveSort := CaseSensitive;
  SortData(@Self, Count, CompareFast, SwapFast);
end;

procedure TFastStrListEx.Swap(Idx1, Idx2: Integer);
begin
  Assert((Idx1 >= 0) and (Idx1 <= Count - 1) and (Idx2 >= 0) and
    (Idx2 <= Count - 1), 'Item indexes violates TFastStrListEx range');
  fList.Swap(Idx1, Idx2);
end;

function TFastStrListEx.GetValues(AName: PAnsiChar): PAnsiChar;
var
  i: Integer;
  S, n: PAnsiChar;
begin
  if not Upper_Initialized then
    InitUpper;
  for i := 0 to Count - 1 do
  begin
    S := ItemPtrs[i];
    n := AName;
    while (Upper[S^] = Upper[n^]) and (S^ <> '=') and (S^ <> #0) and
      (n^ <> #0) do
    begin
      Inc(S);
      Inc(n);
    end;
    if (S^ = '=') and (n^ = #0) then
    begin
      Result := S;
      Inc(Result);
      Exit;
    end;
  end;
  Result := nil;
end;

function TFastStrListEx.IndexOfName(AName: PAnsiChar): Integer;
var
  i: Integer;
  S, n: PAnsiChar;
begin
  if not Upper_Initialized then
    InitUpper;
  for i := 0 to Count - 1 do
  begin
    S := ItemPtrs[i];
    n := AName;
    while (Upper[S^] = Upper[n^]) and (S^ <> '=') and (S^ <> #0) and
      (n^ <> #0) do
    begin
      Inc(S);
      Inc(n);
    end;
    if (S^ = '=') and (n^ = #0) then
    begin
      Result := i;
      Exit;
    end;
  end;
  Result := -1;
end;

end.

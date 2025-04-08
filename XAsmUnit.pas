unit XAsmUnit;

interface

{$O+}

uses
  Windows, Kol, FastStrList, XAsmTable;

// {$DEFINE NOERRORS}

const
  LabHashBits = 10;

type
  PIMAGE_IMPORT_BY_NAME = ^IMAGE_IMPORT_BY_NAME;
{$EXTERNALSYM PIMAGE_IMPORT_BY_NAME}

  _IMAGE_IMPORT_BY_NAME = record
    Hint: Word;
    Name: array [0 .. 0] of Byte;
  end;
{$EXTERNALSYM _IMAGE_IMPORT_BY_NAME}

  IMAGE_IMPORT_BY_NAME = _IMAGE_IMPORT_BY_NAME;
{$EXTERNALSYM IMAGE_IMPORT_BY_NAME}
  TImageImportByName = IMAGE_IMPORT_BY_NAME;
  PImageImportByName = PIMAGE_IMPORT_BY_NAME;

  TIIDUnion = record
    case Integer of
      0:
        (Characteristics: DWORD); // 0 for terminating null import descriptor
      1:
        (OriginalFirstThunk: DWORD);
        // RVA to original unbound IAT (PIMAGE_THUNK_DATA)
  end;

  PIMAGE_IMPORT_DESCRIPTOR = ^IMAGE_IMPORT_DESCRIPTOR;
{$EXTERNALSYM PIMAGE_IMPORT_DESCRIPTOR}

  _IMAGE_IMPORT_DESCRIPTOR = record
    Union: TIIDUnion;
    TimeDateStamp: DWORD; // 0 if not bound,
    // -1 if bound, and real date\time stamp
    // in IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT (new BIND)
    // O.W. date/time stamp of DLL bound to (Old BIND)

    ForwarderChain: DWORD; // -1 if no forwarders
    Name: DWORD;
    FirstThunk: DWORD; // RVA to IAT (if bound this IAT has actual addresses)
  end;
{$EXTERNALSYM _IMAGE_IMPORT_DESCRIPTOR}

  IMAGE_IMPORT_DESCRIPTOR = _IMAGE_IMPORT_DESCRIPTOR;
{$EXTERNALSYM IMAGE_IMPORT_DESCRIPTOR}
  TImageImportDecriptor = IMAGE_IMPORT_DESCRIPTOR;
  PImageImportDecriptor = PIMAGE_IMPORT_DESCRIPTOR;

  PXAsm = ^TXASM;

  TXASM = object(TObj)
  protected
    MacroList: PFastStrListEx;
    StructList: PFastStrListEx;
    Labels: PFastStrListEx;
    IP, IPStart: Integer;
    LineHandling: Integer;
    PEHEAD: Pointer;
    IMPTABLES: Pointer;
    IMPSTRINGS: Array of AnsiString;
    HEADSIZE: DWORD;
    IMPSIZE: DWORD;
    IMPNUM: DWORD;
    FTmport: Boolean;
    DstAddr: PByte;
    BaseAddr: Pointer;
    ImagBase: DWORD;
    AddrOfEP: DWORD;
    FileMode: Word;
    FILEALIGN: DWORD;
    CodeLen: Integer;
    FDll: Boolean;
    Tiny: Boolean;
    Step: Integer;
    SkipLevel: Integer;
    MacroNum, CallMacroNum, CallMacroFromLineNum: Integer;
    MacroLen: Integer;
    LabelsHashTable: array [0 .. (1 shl LabHashBits) - 1] of PList;
    procedure Init; virtual;
    procedure CompileStep(Lines: PFastStrListEx; From, ToIdx: Integer; Params: PFastStrListEx);
    procedure OutByte(B: Byte);
    procedure OutWord(W: Word);
    procedure OutDWord(D: DWORD);
    function LabelExists(AName: PAnsiChar; FromLine: Integer; Lines: PFastStrListEx): Boolean;
    function FindLabelStrL(Str: PAnsiChar; L: Integer; FromLine: Integer; Lines: PFastStrListEx; var FoundInLine: Integer): Integer;
    function FindLabelInSrc(Str: PAnsiChar; L: Integer; FromLine: Integer): Integer;
    procedure AddLabel2HashTable(LabName: PAnsiChar; Idx: Integer);
    procedure BuildHead;
    procedure BuildImportTable;
    procedure AddImportTable(Imp: AnsiString);
    procedure AddImportLabels;
  protected
    CallingMacroFromLine: Integer;
    Errors: Integer;
    Line_Diff: Integer;
    FSrc: PFastStrListEx;
    procedure Error(Line: Integer; const Msg: AnsiString);
    property Src: PFastStrListEx read FSrc;
  public
    Memory: Pointer;
    property Size: Integer read IP;
    property DatSize: DWORD read IMPSIZE;
    property Errs: Integer read Errors;
    property LineCount: Integer read CodeLen;
    property EP: DWORD read AddrOfEP;
    property ImageBase: DWORD read ImagBase write ImagBase;
    property PeMode: Word read FileMode write FileMode;
    property DllFile: Boolean read FDll Write FDll;
    property TINYPE: Boolean read Tiny write Tiny;
    destructor Destroy; virtual;
    procedure Clear;
    // procedure CompileFromRsrc( const RsrcName: AnsiString );
    procedure CompileFromFile(const Filename: AnsiString);
    procedure CompileSrc;
    procedure SaveBin2File(const Filename: AnsiString);
    procedure SaveExe2File(const Filename: AnsiString);
  protected
    Hints: array of TListHint;
    RebuildHints: Boolean;
    procedure ClearHints;
  public
    // procedure SetSrc( const NewSrcText: String; DoClearHints: Boolean );
    // function SrcText: String;
  end;

implementation

const
  HashBits = 8;

var
  Step1Addition: Integer;
  HashedTable: array [0 .. (1 shl HashBits) - 1] of PList;
  Upper: array [AnsiChar] of AnsiChar;
  InstrTable: PFastStrListEx;
  SibTable: array [TIdxBase, TIdxBase, TScale] of Byte;
  ModRmTable: array [TIdxBase] of Byte;

function Split(Input: ansistring; Deliminator: ansistring; Index: Integer): ansistring;
var
  StringLoop, StringCount: Integer;
  Buffer: ansistring;
begin
  Buffer := '';
  if Index < 1 then
    Exit;
  StringCount := 0;
  StringLoop := 1;
  while (StringLoop <= Length(Input)) do
  begin
    if (Copy(Input, StringLoop, Length(Deliminator)) = Deliminator) then
    begin
      Inc(StringLoop, Length(Deliminator) - 1);
      Inc(StringCount);
      if StringCount = Index then
      begin
        Result := Buffer;
        Exit;
      end
      else
        Buffer := '';
    end
    else
      Buffer := Buffer + Copy(Input, StringLoop, 1);
    Inc(StringLoop, 1);
  end;
  Inc(StringCount);
  if StringCount < Index then
    Buffer := '';
  Result := Buffer;
end;

function IndexOfStr( const S, Sub : AnsiString ) : Integer;
begin
  Result := pos( Sub, S );
  if  Result = 0 then Result := -1;
end;

function Parse( var S : AnsiString; const Separators : AnsiString ) : AnsiString;
var Pos : Integer;
begin
  Pos := IndexOfCharsMin( S, Separators );
  if Pos <= 0 then
     Pos := Length( S )+1;
  Result := Copy( S, 1, Pos-1 );
  Delete( S, 1, Pos );
end;

function StrIsStartingFrom( Str, Pattern: PAnsiChar ): Boolean;
begin
  Result := FALSE;
  if (Str = nil) or (Pattern = nil) then
  begin
    Result := (Integer(Str) = Integer(Pattern));
    Exit;
  end;

  while Pattern^ <> #0 do
  begin
    if Str^ <> Pattern^ then Exit;
    inc( Str );
    inc( Pattern );
  end;
  Result := TRUE;
end;

function StrScan(Str: PAnsiChar; Chr: AnsiChar): PAnsiChar; assembler;
asm
        PUSH    EDI
        PUSH    EAX
        MOV     EDI,Str
        OR      ECX, -1
        XOR     AL,AL
        REPNE   SCASB
        NOT     ECX
        POP     EDI
        XCHG    EAX, EDX
        REPNE   SCASB

        XCHG    EAX, EDI
        POP     EDI

        JE      @@1
        XOR     EAX, EAX
        RET

@@1:    DEC     EAX
end;

function StrLen(const Str: PAnsiChar): Cardinal; assembler;
asm
        XCHG    EAX, EDI
        XCHG    EDX, EAX
        OR      ECX, -1
        XOR     EAX, EAX
        CMP     EAX, EDI
        JE      @@exit0
        REPNE   SCASB
        DEC     EAX
        DEC     EAX
        SUB     EAX,ECX
@@exit0:
        MOV     EDI,EDX
end;

function StrCopy( Dest, Source: PAnsiChar ): PAnsiChar; assembler;
asm
        PUSH    EDI
        PUSH    ESI
        MOV     ESI,EAX
        MOV     EDI,EDX
        OR      ECX, -1
        XOR     AL,AL
        REPNE   SCASB
        NOT     ECX
        MOV     EDI,ESI
        MOV     ESI,EDX
        MOV     EDX,ECX
        MOV     EAX,EDI
        SHR     ECX,2
        REP     MOVSD
        MOV     ECX,EDX
        AND     ECX,3
        REP     MOVSB
        POP     ESI
        POP     EDI
end;

function StrLCopy(Dest: PAnsiChar; const Source: PAnsiChar; MaxLen: Cardinal): PAnsiChar; assembler;
asm
        PUSH    EDI
        PUSH    ESI
        PUSH    EBX
        MOV     ESI,EAX
        MOV     EDI,EDX
        MOV     EBX,ECX
        XOR     AL,AL
        TEST    ECX,ECX
        JZ      @@1
        REPNE   SCASB
        JNE     @@1
        INC     ECX
@@1:    SUB     EBX,ECX
        MOV     EDI,ESI
        MOV     ESI,EDX
        MOV     EDX,EDI
        MOV     ECX,EBX
        SHR     ECX,2
        REP     MOVSD
        MOV     ECX,EBX
        AND     ECX,3
        REP     MOVSB
        STOSB
        MOV     EAX,EDX
        POP     EBX
        POP     ESI
        POP     EDI
end;

function StrL2Comp(s1, s2: PAnsiChar; L1, L2: Integer): Integer;
begin
  Result := StrLComp(s1, s2, Min(L1, L2));
  if Result = 0 then
    Result := L1 - L2;
end;

procedure SaveBinAsStr(const Filename: AnsiString; M: PByte; Len: Integer);
var
  SL: PFastStrListEx;
  S: String;
  n: Integer;
begin
  SL := NewFastStrListEx;
  TRY
    while Len > 0 do
    begin
      S := '';
      for n := 1 to Min(Len, 16) do
      begin
        S := S + Int2Hex(M^, 2) + ' ';
        Inc(M);
        Dec(Len);
        if M^ = $E8 then
          break;
      end;
      SL.AddAnsi(Trim(S));
    end;
    SL.SaveToFile(Filename);
  FINALLY
    SL.Free;
  END;
end;

function CalcHash(S: PAnsiChar; Bits: Integer; MaxLen: Integer): Word;
begin
  Result := 0;
  while (S^ <> #0) and (MaxLen > 0) do
  begin
    Result := ((Result shl 1) or (Result shr (Bits - 1))) xor Byte(Upper[S^]);
    Inc(S);
    Dec(MaxLen);
  end;
  Result := Result and ((1 shl Bits) - 1);
end;

function StrIsL(p: PAnsiChar; L: Integer; const a: array of PAnsiChar; var k: Integer): Boolean;
var
  i: Integer;
begin
  Result := TRUE;
  for i := 0 to High(a) do
    if (StrLen(a[i]) = DWORD(L)) and (StrLComp_NoCase(p, a[i], L) = 0) then
    begin
      k := i;
      Exit;
    end;
  k := -1;
  Result := FALSE;
end;

function StrInL(p: PAnsiChar; L: Integer; const a: array of PAnsiChar): Boolean;
var
  i: Integer;
begin
  Result := TRUE;
  for i := 0 to High(a) do
    if (StrLen(a[i]) = DWORD(L)) and (StrLComp_NoCase(p, a[i], L) = 0) then
      Exit;
  Result := FALSE;
end;

procedure RemoveLast(S: PAnsiChar; c: AnsiChar);
begin
  if (S <> '') and (S[StrLen(S) - 1] = c) then
    S[StrLen(S) - 1] := #0;
end;

function IsDecimalStrL(S: PAnsiChar; L: Integer): Boolean;
begin
  Result := FALSE;
  while L > 0 do
  begin
    if not(S^ in ['0' .. '9']) then
      Exit;
    Inc(S);
    Dec(L);
  end;
  Result := TRUE;
end;

procedure InitUpper;
var
  c: AnsiChar;
begin
  for c := #0 to #255 do
    Upper[c] := AnsiUpperCase(c + #0)[1];
end;

procedure InitInstrTable;
  procedure MakeSibTable(const BaseRegs, MultRegs: array of TIdxBase);
  var
    i, j, n: Integer;
    k: TScale;
  begin
    n := -1;
    for k := mult1 to mult8 do
      for j := 0 to High(MultRegs) do
        for i := 0 to High(BaseRegs) do
        begin
          Inc(n);
          SibTable[BaseRegs[i], MultRegs[j], k] := n;
        end;
    { if n <> 255 then
      asm
      int 3
      end; }
  end;

  procedure MakeSibTable2(const MultRegs: array of TIdxBase);
  var
    n, j: Integer;
    k: TScale;
  begin
    n := 5;
    for k := mult1 to mult8 do
      for j := 0 to High(MultRegs) do
      begin
        SibTable[ibEBP, MultRegs[j], k] := n;
        Inc(n, 8);
      end;
    { if n <> $FD+8 then
      asm
      int 3
      end; }
  end;

  procedure MakeHashedTable;
  var
    i, hc: Integer;
    S, p: PAnsiChar;
  begin
    for i := 0 to InstrTable.Count - 1 do
    begin
      S := InstrTable.ItemPtrs[i];
      p := S;
      while (S^ > ' ') do
        Inc(S);
      hc := CalcHash(p, HashBits, DWORD(S) - DWORD(p));
      if HashedTable[hc] = nil then
      begin
        HashedTable[hc] := NewList;
        HashedTable[hc].AddBy := 10;
      end;
      HashedTable[hc].Add(InstrTable.ItemPtrs[i]);
    end;
  end;

var
  SL: PFastStrListEx;
  S, s1, Name, pattern, From, fromname, s2, s3, s4: AnsiString;
  i, j, k: Integer;
  // Found: Integer;
begin
  InstrTable := NewFastStrListEx;
  S := InstrDefs;
  for i := Length(S) downto 2 do
    if (S[i] = ' ') and (S[i - 1] = ' ') then
      Delete(S, i, 1);
  for i := 1 to Length(S) do
    if S[i] = ';' then
      S[i] := #13;
  SL := NewFastStrListEx;
  TRY
    SL.Text := S;
    for i := 0 to SL.Count - 1 do
    begin
      S := SL.Items[i];
      j := pos('<-', S);
      if j > 0 then
      begin
        s1 := Trim(Copy(S, 1, j - 1));
        S := Trim(CopyEnd(S, j + 2));
        pattern := s1;
        name := Trim(Parse(pattern, ' ')) + ' ';
        From := S;
        fromname := Trim(Parse(From, ' ')) + ' ';
        pattern := Trim(fromname + pattern);
        // Found := 0;
        for j := 0 to i - 1 do
        begin
          s2 := SL.Items[j];
          k := pos('->', s2);
          if k > 0 then
          begin
            s2 := Trim(Copy(s2, 1, k - 1));
            if StrIsStartingFrom(PAnsiChar(s2), PAnsiChar(fromname)) or (s2 = pattern)
            then
              if StrSatisfy(s2, pattern) then
              begin
                // Inc( Found );
                s2 := SL.Items[j];
                Parse(s2, ' ');
                s3 := name;
                k := pos('->', s2);
                { if k<=0 then
                  asm
                  int 3
                  end; }
                s3 := s3 + Copy(s2, 1, k - 1) + '->';
                s2 := Trim(CopyEnd(s2, k + 2));
                S := SL.Items[i];
                k := pos('<-', S);
                { if k <= 0 then
                  asm
                  int 3
                  end; }
                S := Trim(CopyEnd(S, k + 2));
                Parse(S, ' ');
                S := Trim(S);
                while s2 <> '' do
                begin
                  s4 := Trim(Parse(s2, ' '));
                  s2 := Trim(s2);
                  if s4 = '' then
                    break;
                  if s4[1] <> '!' then
                  begin
                    s1 := Trim(Parse(S, ' '));
                    S := Trim(S);
                    if s1 <> '' then
                      s4 := s4 + '+' + s1;
                  end;
                  s3 := s3 + ' ' + s4;
                end;
                InstrTable.AddAnsi(s3);
              end;
          end;
        end;
        { if Found = 0 then
          asm
          int 3
          end; }
      end
      else if pos('->', S) > 0 then
      begin
        InstrTable.AddAnsi(S);
      end;
      { else
        asm
        int 3;
        end; }
    end;
    // InstrTable.SavetoFile( GetStartDir + 'InstrTable-PCAsm.txt' );
  FINALLY
    SL.Free;
  END;
  ModRmTable[ibEAX] := 0;
  ModRmTable[ibECX] := 1;
  ModRmTable[ibEDX] := 2;
  ModRmTable[ibEBX] := 3;
  ModRmTable[ibEBP] := 6;
  ModRmTable[ibESI] := 6;
  ModRmTable[ibEDI] := 7;
  MakeSibTable([ibEAX, ibECX, ibEDX, ibEBX, ibESP, ibNone, ibESI, ibEDI],
    [ibEAX, ibECX, ibEDX, ibEBX, ibNone, ibEBP, ibESI, ibEDI]);
  MakeSibTable2([ibEAX, ibECX, ibEDX, ibEBX, ibNone, ibEBP, ibESI, ibEDI]);
  MakeHashedTable;
end;

procedure FinalTables;
var
  i: Integer;
begin
  InstrTable.Free;
  for i := 0 to High(HashedTable) do
    if HashedTable[i] <> nil then
      HashedTable[i].Free;
end;

{ TXASM }

procedure TXASM.AddLabel2HashTable(LabName: PAnsiChar; Idx: Integer);
var
  hc: DWORD;
begin
  hc := CalcHash(LabName, LabHashBits, StrLen(LabName));
  if LabelsHashTable[hc] = nil then
  begin
    LabelsHashTable[hc] := NewList;
    LabelsHashTable[hc].AddBy := 50;
  end;
  LabelsHashTable[hc].Add(Pointer(Idx));
end;

procedure TXASM.Clear;
var
  i: Integer;
begin
  for i := 0 to High(LabelsHashTable) do
    Free_And_Nil(LabelsHashTable[i]);
  FSrc.Clear;
  MacroList.Clear;
  StructList.Clear;
  Labels.Clear;
  if Memory <> nil then
    GlobalFree(DWORD(Memory));
  Memory := nil;
end;

procedure TXASM.ClearHints;
begin
  SetLength(Hints, 0);
end;

procedure TXASM.CompileFromFile(const Filename: AnsiString);
begin
  Clear;
  Src.LoadFromFile(Filename);
  if FindLabelInSrc('Start:', 0, 0) = 0 then
  begin
    Error(0, 'Label Start Not Found!');
    Halt;
  end;
  CompileSrc;
end;

{ procedure TXASM.CompileFromRsrc(const RsrcName:String);
  var M: PStream;
  begin
  Clear;
  M := NewMemoryStream;
  TRY
  Resource2Stream(M,hInstance,PAnsiChar(RsrcName),RT_RCDATA);
  M.Position:=0;
  Src.LoadFromStream(M,FALSE);
  FINALLY
  M.Free;
  END;
  CompileSrc;
  end; }

procedure TXASM.CompileSrc;
var
  Txt: AnsiString;
  i: Integer;
  Params0: PFastStrListEx;
  S: PAnsiChar;
begin
  RebuildHints := FALSE;
  if Src.Count <> Length(Hints) then
  begin
    ClearHints;
    SetLength(Hints, Src.Count);
    FillChar(Hints[0], Sizeof(Hints), 0);
    RebuildHints := TRUE;
  end;
  Txt := Src.Text;
  i := 1;
  while i <= Length(Txt) do
  begin
    CASE Txt[i] OF
      '/':
        if Txt[i + 1] = '/' then
        begin
          while (i <= Length(Txt)) and (Txt[i] <> #13) do
          begin
            Txt[i] := ' ';
            Inc(i);
          end;
        end
        else
        begin
          Inc(i);
        end;
      #0 .. #9, #11, #12, #14 .. #31:
        Txt[i] := ' ';
      '''':
        begin
          Inc(i);
          while (i <= Length(Txt)) and (Txt[i] <> #13) do
          begin
            if Txt[i] = '''' then
            begin
              if Txt[i + 1] = '''' then
                Inc(i, 2)
              else
              begin
                Inc(i);
                break;
              end;
            end
            else
              Inc(i);
          end;
        end;
      '{':
        begin
          while (i <= Length(Txt)) and (Txt[i] <> '}') do
          begin
            if Txt[i] <> #13 then
              Txt[i] := ' ';
            Inc(i);
          end;
          if Txt[i] = '}' then
            Txt[i] := ' ';
        end;
      '(':
        if Txt[i + 1] = '*' then
        begin
          Txt[i] := ' ';
          Inc(i);
          Txt[i] := ' ';
          while (i <= Length(Txt)) and
            ((Txt[i] <> '*') or (Txt[i + 1] <> ')')) do
          begin
            if Txt[i] <> #13 then
              Txt[i] := ' ';
            Inc(i);
          end;
          if Txt[i] = '*' then
          begin
            Txt[i] := ' ';
            Inc(i);
            Txt[i] := ' ';
          end;
        end
        else
          Inc(i);
    else
      Inc(i);
    END;
  end;
  Src.Text := Txt;
  Params0 := NewFastStrListEx;
  TRY
{$IFNDEF NOERRORS}
    Errors := 0;
{$ENDIF}
    Step := 1;
    IP := 0;
    LineHandling := 0;
    HEADSIZE := 0;
    FILEALIGN := 4;
    Step1Addition := ImagBase;
    MacroNum := 0;
    CallMacroNum := 0;
    CallMacroFromLineNum := 0;
    Line_Diff := 0;
    CompileStep(Src, 0, Src.Count - 1, Params0); // Ô¤±àÒë
    // IMPORT TABLE
    if FTmport then
      BuildImportTable;
    BuildHead;
    // BaseAddr:= Pointer(ImagBase+HEADSIZE);
    RebuildHints := FALSE;
    { -----------------
      if Errors > 0 then
      asm
      int 3
      end;-------------- }
    Step := 2;
    Memory := VirtualAlloc(nil, (IP + 65535) and not 65535, MEM_COMMIT,
      PAGE_EXECUTE_READWRITE);
    for i := 0 to Labels.Count - 1 do
    begin
      S := Labels.ItemPtrs[i];
      if S^ = #1 then
      begin
        Labels.Objects[i] := Labels.Objects[i] - DWORD(Step1Addition) +
          DWORD(BaseAddr); // DWORD( Memory );
      end;
    end;
    if FTmport then
      AddImportLabels;
    DstAddr := Memory;
    IP := 0;
    LineHandling := 0;
    Step1Addition := 0;
    MacroNum := 0;
    CallMacroNum := 0;
    CallMacroFromLineNum := 0;
    Params0.Clear;
    Line_Diff := 0;
    CompileStep(Src, 0, Src.Count - 1, Params0); // Õý±àÒë
    CodeLen := Src.Count - 1;
  FINALLY
    Params0.Free;
  END;
end;

procedure TXASM.CompileStep(Lines: PFastStrListEx; From, ToIdx: Integer; Params: PFastStrListEx);
const
  DataLength: array [0 .. 3] of Integer = (1, 2, 4, 8);
var
  Line: Integer;
  S, p: PAnsiChar;
  CmdLen: Integer;

  procedure SkipSp;
  begin
    while S^ = ' ' do
      Inc(S);
  end;

  procedure SkipToSp(LastChar: AnsiChar; Delims: PAnsiChar);
  var
    i: Integer;
  begin
    i := 0;
    while S^ > ' ' do
    begin
      if (i > 0) and (S[-1] = LastChar) or (StrScan(Delims, S^) <> nil) then
        break;
      Inc(S);
      Inc(i);
    end;
  end;

  function Next(Word: PAnsiChar): Boolean;
  var
    j: Integer;
  begin
    Result := FALSE;
    for j := 0 to StrLen(Word) - 1 do
      if Upper[S[j]] <> Word[j] then
        Exit;
    if (Word[0] in ['A' .. 'Z']) and (Upper[S[StrLen(Word)]] in ['A' .. 'Z'])
    then
      Exit;
    Inc(S, StrLen(Word));
    Result := TRUE;
  end;

  function NextIn(var j: Integer; var Key: PAnsiChar;
    const Keys: array of PAnsiChar): Boolean;
  var
    k: Integer;
  begin
    j := -1;
    Result := FALSE;
    if S^ = #0 then
      Exit;
    for k := 0 to High(Keys) do
      if Next(Keys[k]) then
      begin
        j := k;
        Key := Keys[k];
        Result := TRUE;
        Exit;
      end;
  end;

  function StrConst(var Buf: array of AnsiChar): Integer;
  var
    i: Integer;
  begin
    i := 0;
    Result := 0;
    if S^ <> '''' then
      Exit;
    Inc(S);
    while (S^ <> #0) do
    begin
      if S^ = '''' then
      begin
        Inc(S);
        if S^ <> '''' then
          break;
      end;
      Buf[i] := S^;
      Inc(i);
      Inc(S);
{$IFNDEF NOERRORS}
      if S^ = #0 then
        Error(Line, 'Unterminated string');
{$ENDIF}
    end;
    Buf[i] := #0;
    Result := i;
  end;

  function Expression(op1: PAnsiChar = nil; MustExists: Boolean = FALSE)
    : Int64; FORWARD;

    function Operand(MustExists: Boolean): Int64;
    var
      j: Integer;
      StrVal: array [0 .. 3] of AnsiChar;
{$IFNDEF NOERRORS} Name {$ENDIF}: String;
      p: PAnsiChar;
      IsNum: Boolean;
      FoundInLine: Integer;
      s1, s2: PAnsiChar;
      L1, L2: Integer;
      compare_op: PAnsiChar;
    label Ident;
    begin
      Result := 0;
      SkipSp;
      if S^ = #0 then
        Exit;
      IsNum := FALSE;
      TRY
        if S^ = '-' then
        begin
          Inc(S);
          Result := -Operand(MustExists);
          Exit;
        end;
        if Next('NOT') then
        begin
          Result := NOT Operand(MustExists);
          Exit;
        end;
        if S^ = '(' then
        begin
          Inc(S);
          Result := Expression;
          SkipSp;
          if S^ <> ')' then
{$IFNDEF NOERRORS}
            Error(Line, 'Waiting '')''')
{$ENDIF}
          else
            Inc(S);
          Exit;
        end;
        if S^ = '"' then
        begin
          Inc(S);
          s1 := S;
          p := S;
          while (S^ <> #0) and (S^ <> '"') do
            Inc(S);
          L1 := DWORD(S) - DWORD(p);
          // SetString( s1, p, DWORD(s)-DWORD(p) );
          s2 := '';
          if S^ = '"' then
            Inc(S);
          SkipSp;
          // p := s;
          if S^ in ['<', '>', '='] then
          begin
            compare_op := S;
            SkipToSp(#0, ' "');
            // SetString( compare_op, p, DWORD(s)-DWORD(p) );
            SkipSp;
            if S^ = '"' then
            begin
              Inc(S);
              p := S;
              s2 := S;
              while (S^ <> #0) and (S^ <> '"') do
                Inc(S);
              L2 := DWORD(S) - DWORD(p);
              // SetString( s2, p, DWORD(s)-DWORD(p) );
              if S^ = '"' then
                Inc(S);
            end
            else
              L2 := DWORD(S) - DWORD(p);
            CASE compare_op[0] OF
              '<':
                CASE compare_op[1] OF
                  '=':
                    Result := Integer(StrL2Comp(s1, s2, L1, L2) <= 0);
                  '>':
                    Result := Integer(StrL2Comp(s1, s2, L1, L2) <> 0);
                else
                  Result := Integer(StrL2Comp(s1, s2, L1, L2) < 0);
                END;
              '>':
                CASE compare_op[1] OF
                  '=':
                    Result := Integer(StrL2Comp(s1, s2, L1, L2) >= 0);
                else
                  Result := Integer(StrL2Comp(s1, s2, L1, L2) > 0);
                END;
            else
              Result := Integer(StrL2Comp(s1, s2, L1, L2) = 0);
            END;
          end
          else
          begin
            Result := Integer(s1 <> '');
          end;
          Result := -Result;
          IsNum := TRUE;
          Exit;
        end;
        if S^ = '.' then
        begin
          IsNum := TRUE;
          Inc(S);
          Result := Integer(BaseAddr) { BaseAddr {Integer( Memory ) } +
            Step1Addition + IPStart;
        end
        else if S^ = '$' then
        begin
          IsNum := TRUE;
          Inc(S);
          if Upper[S^] in ['0' .. '9', 'A' .. 'F'] then
          begin
            while Upper[S^] in ['0' .. '9', 'A' .. 'F'] do
            begin
              if S^ in ['0' .. '9'] then
                Result := Result * 16 + Ord(S^) - Ord('0')
              else
                Result := Result * 16 + Ord(Upper[S^]) - Ord('A') + 10;
              Inc(S);
            end;
          end
          else
          begin
            if Step = 1 then
              Result := IP + 6 + Step1Addition
            else
              Result := IP + Integer(BaseAddr) { BaseAddr {Integer( Memory ) } +
                Integer(Lines.Objects[Line]);
          end;
        end
        else if S^ in ['0' .. '9'] then
        begin
          IsNum := TRUE;
          while S^ in ['0' .. '9'] do
          begin
            Result := Result * 10 + Ord(S^) - Ord('0');
            Inc(S);
          end;
        end
        else if S^ = '''' then
        begin
          IsNum := TRUE;
          FillChar(StrVal, Sizeof(StrVal), 0);
          StrConst(StrVal);
          for j := 3 downto 0 do
          begin
            Result := Result * 256 + Ord(StrVal[j]);
          end;
        end
        else
        begin
        Ident:
          p := S;
          SkipToSp(#0, '.,;:+-*/<>= ()[]');
          // SetString( Name, p, DWORD(s)-DWORD(p) );
          j := FindLabelStrL(p, DWORD(S) - DWORD(p), Line, Lines, FoundInLine);
          if j < 0 then
          begin
            if StructList.IndexOfStrL_NoCase(p, DWORD(S) - DWORD(p)) >= 0 then
            begin
              SkipSp;
              if S^ <> '.' then
{$IFNDEF NOERRORS}
                Error(Line, 'Waiting for ''.''')
{$ENDIF}
              else
                Inc(S);
              SkipSp;
              goto Ident;
            end
            else
            begin
              if MustExists then
              begin
{$IFNDEF NOERRORS}
                SetString(Name, p, DWORD(S) - DWORD(p));
                Error(Line, 'Must be declared ' + Name);
{$ENDIF}
                Result := 0;
                Exit;
              end;
              if Step = 2 then
              begin
{$IFNDEF NOERRORS}
                SetString(Name, p, DWORD(S) - DWORD(p));
                Error(Line, 'Undeclared ' + Name);
{$ENDIF}
              end;
              Result := IP + Step1Addition + 256;
            end;
          end
          else
            Result := Labels.Objects[j];
        end;
      FINALLY
        if not IsNum then
        begin
          SkipSp;
          while S^ = '.' do
          begin
            Inc(S);
            SkipSp;
            p := S;
            SkipToSp(#0, '.,;:+-*/<>=()[] ');
            // SetString( Name, p, DWORD(s)-DWORD(p) );
{$IFNDEF NOERRORS}
            if S = p then
              Error(Line, 'Waiting for field identifier');
{$ENDIF}
            j := Labels.IndexOfStrL_NoCase(p, DWORD(S) - DWORD(p));
            if j < 0 then
            begin
{$IFNDEF NOERRORS}
              SetString(Name, p, DWORD(S) - DWORD(p));
              Error(Line, 'Field ' + Name + ' not found')
{$ENDIF}
            end
            else
              Inc(Result, Labels.Objects[j]);
            SkipSp;
          end;
        end;
      END;
    end;

    function Priority(op: PAnsiChar): Integer;
    const
      Prty: String = 'OR XOR 1 AND 2 < > <= >= <> = 3 + - 4 * ' +
        '/ MOD << >> SHL SHR 5';
    var
      i: Integer;
      pp: PAnsiChar;
    begin
      // i := pos( op, Prty );
      i := StrLen(op);
      pp := @Prty[1];
      while pp^ <> #0 do
      begin
        if (pp^ = op^) and (StrLComp(pp, op, i) = 0) and (pp[i] = ' ') then
        begin
          i := DWORD(pp) - DWORD(@Prty[1]);
          break;
        end;
        Inc(pp);
      end;

{$IFNDEF NOERRORS}
      if i < 0 then
        Error(Line, 'Unknown op ' + op);
{$ENDIF}
      while i <= Length(Prty) do
      begin
        Inc(i);
        if Prty[i] in ['0' .. '9'] then
        begin
          Result := Ord(Prty[i]) - Ord('0');
          Exit;
        end;
      end;
      Result := 0;
    end;

    function Expression(op1: PAnsiChar = nil; MustExists: Boolean = FALSE): Int64;
    var
      opd1, opd2: Integer;
      j: Integer;
      op2: PAnsiChar;
      p: PAnsiChar;
    label Get_op2;
    begin
      Result := 0;
      opd1 := Operand(MustExists);
    Get_op2:
      SkipSp;
      p := S;
      if NextIn(j, op2, ['+', '-', '*', '/', '<>', '<<', '<=', '<', '>>', '>=',
        '>', '=', 'AND', 'OR', 'XOR', 'MOD', 'SHL', 'SHR']) then
      begin
        if (op1 = nil) or (op1^ = #0) or (Priority(op2) > Priority(op1)) then
        begin
          opd2 := Expression(op2, MustExists);
          TRY
            CASE op2[0] OF
              '+':
                Result := opd1 + opd2;
              '-':
                Result := opd1 - opd2;
              '*':
                Result := opd1 * opd2;
              '/':
                Result := opd1 div opd2;
              'M':
                Result := opd1 mod opd2;
              'A':
                Result := opd1 and opd2;
              'O':
                Result := opd1 or opd2;
              'X':
                Result := opd1 xor opd2;
              '<':
                CASE op2[1] OF
                  '=':
                    Result := -Integer(opd1 <= opd2);
                  '<':
                    Result := opd1 shl opd2;
                  '>':
                    Result := -Integer(opd1 <> opd2);
                else
                  Result := -Integer(opd1 < opd2);
                END;
              '>':
                CASE op2[1] OF
                  '=':
                    Result := -Integer(opd1 >= opd2);
                  '>':
                    Result := opd1 shr opd2;
                else
                  Result := -Integer(opd1 > opd2);
                END;
              '=':
                Result := -Integer(opd1 = opd2);
              'S':
                CASE op2[2] OF
                  'L':
                    Result := opd1 shl opd2;
                  'R':
                    Result := opd1 shr opd2;
                END;
            END;
          EXCEPT
            Result := 0;
          END;
          opd1 := Result;
          goto Get_op2;
        end
        else
        begin
          S := p;
          Result := opd1;
          Exit;
        end;
      end
      else
      begin
        Result := opd1;
        Exit;
      end;
    end;

    procedure InstrOperand(Cmd: PAnsiChar; var Opd: TOperand);
    const
      RegNums: array [0 .. 47] of Byte = (
        // 'AL', 'AH', 'AX', 'EAX', 'DL', 'DH', 'DX', 'EDX',
        0, 4, 0, 0, 2, 6, 2, 2,
        // 'CL', 'CH', 'CX', 'ECX', 'BL', 'BH', 'BX', 'EBX',
        1, 5, 1, 1, 3, 7, 3, 3,
        // 'SI', 'ESI', 'DI', 'EDI', 'SP', 'ESP', 'BP', 'EBP',
        6, 6, 7, 7, 4, 4, 5, 5,
        // 'MM0', 'MM1', 'MM2', 'MM3', 'MM4', 'MM5', 'MM6', 'MM7',
        0, 1, 2, 3, 4, 5, 6, 7,
        // 'XMM0', 'XMM1', 'XMM2', 'XMM3', 'XMM4', 'XMM5', 'XMM6', 'XMM7',
        0, 1, 2, 3, 4, 5, 6, 7,
        // 'ST(0)', 'ST(1)', 'ST(2)', 'ST(3)', 'ST(4)', 'ST(5)', 'ST(6)', 'ST(7)'
        0, 1, 2, 3, 4, 5, 6, 7);
    var
      j, M: Integer;
      Key: PAnsiChar;
      p: PAnsiChar;
    begin
      FillChar(Opd, Sizeof(Opd), 0);
      if StrInL(Cmd, StrLen(Cmd), ['REP', 'REPE', 'REPNE', 'REPZ', 'REPNZ'])
      then
      begin
        Opd.OpdType := '!';
        StrLCopy(Opd.AsStr, S, 8);
        SkipToSp(#0, ' ');
        Exit;
      end;
      if NextIn(j, Key, ['SHORT', 'NEAR', 'LONG']) then
      begin
        CASE j OF
          0:
            Opd.OpdSize := 1;
          1:
            Opd.OpdSize := 2;
          2:
            Opd.OpdSize := 4;
        END;
        Opd.OpdType := 'f';
        Opd.Offset := Expression('');
        Exit;
      end
      else if (Upper[S^] in ['B', 'W', 'D', 'Q', 'T', 'A']) and (S[1] = '[')
      then
      begin
        CASE Upper[S^] OF
          'B':
            Opd.OpdSize := 1;
          'W':
            Opd.OpdSize := 2;
          'D':
            Opd.OpdSize := 4;
          'A':
            Opd.OpdSize := 4;
          'Q':
            Opd.OpdSize := 8;
          'T':
            Opd.OpdSize := 10;
        END;
        Inc(S);
      end
      else if NextIn(j, Key, ['BYTE', 'WORD', 'DWORD', 'QWORD', 'TBYTE']) then
      begin
        SkipSp;
        Next('PTR');
        CASE j OF
          0:
            Opd.OpdSize := 1;
          1:
            Opd.OpdSize := 2;
          2:
            Opd.OpdSize := 4;
          3:
            Opd.OpdSize := 8;
          4:
            Opd.OpdSize := 10;
        END;
      end;
      SkipSp;
      if Next('OFFSET') then
      begin
        Opd.IsOffset := TRUE;
        SkipSp;
      end;
      if S[2] = ':' then
      begin
        Opd.OpdType := 'm';
        Opd.Segment[0] := Upper[S[0]];
        Opd.Segment[1] := Upper[S[1]];
        Inc(S, 3);
        SkipSp;
      end;
      if S^ = '[' then
      begin
        Opd.OpdType := 'm';
        Inc(S);
        SkipSp;
        while (S^ <> #0) and (S^ <> ']') do
        begin
          if Upper[S^] in ['@', '_', 'A' .. 'Z'] then
          begin
            p := S;
            SkipToSp(#0, ',]()+-*/<>= ');
            // SetString( Name, p, DWORD(s)-DWORD(p) );
            // if StrIs( Name, [ 'EAX', 'EDX', 'ECX', 'EBX', 'ESI', 'EDI', 'ESP', 'EBP' ], j ) then
            if StrIsL(p, DWORD(S) - DWORD(p), ['EAX', 'EDX', 'ECX', 'EBX',
              'EBP', 'ESP', 'ESI', 'EDI'], j) then
            begin
              SkipSp;
              if S^ = '*' then
              begin
{$IFNDEF NOERRORS}
                if Opd.IdxBase2 <> ibNone then
                  Error(Line, 'Too many scaled base regs');
{$ENDIF}
                Inc(S);
                SkipSp;
                M := Expression('*');
                CASE M OF
                  1:
                    Opd.IdxMult2 := mult1;
                  2:
                    Opd.IdxMult2 := mult2;
                  4:
                    Opd.IdxMult2 := mult4;
                  8:
                    Opd.IdxMult2 := mult8;
                else
{$IFNDEF NOERRORS}
                  Error(Line, 'Incorrect scale: ' + Int2Str(M));
{$ENDIF}
                END;
                Opd.IdxBase2 := TIdxBase(j + 1);
              end
              else
              begin
                if Opd.IdxBase1 <> ibNone then
                begin
{$IFNDEF NOERRORS}
                  if Opd.IdxBase2 <> ibNone then
                    Error(Line, 'Too many base regs');
{$ENDIF}
                  Opd.IdxBase2 := TIdxBase(j + 1);
                  Opd.IdxMult2 := mult1;
                end
                else
                begin
                  Opd.IdxBase1 := TIdxBase(j + 1);
                end;
                SkipSp;
              end;
              if S^ = ']' then
                break;
              if S^ = '+' then
              begin
                Inc(S);
                SkipSp;
              end;
            end
            else
            begin
              S := p;
              Opd.Offset := Expression('');
              break;
            end;
          end
          else
          begin
            Opd.Offset := Expression('');
          end;
        end;
        if S^ = ']' then
        begin
          Inc(S);
          SkipSp;
          while S^ = '.' do
          begin
            Inc(S);
            SkipSp;
            j := Expression;
            Inc(Opd.Offset, j);
            (* p := s; SkipToSp( #0, '.,' );
              //SetString( Name, p, DWORD(s)-DWORD(p) );
              j := Labels.IndexOfStrL_NoCase( p, DWORD(s)-DWORD(p) );
              if j >= 0 then
              begin
              Inc( Opd.Offset, Labels.Objects[ j ] );
              end
              else
              begin
              {$IFNDEF NOERRORS}
              if StructList.IndexOfStrL_NoCase( p, DWORD(s)-DWORD(p) ) < 0 then
              begin
              SetString( Name, p, DWORD(s)-DWORD(p) );
              Error( Line, 'Undeclared ' + Name );
              end;
              {$ENDIF}
              end; *)
            SkipSp;
          end;
        end
        else
{$IFNDEF NOERRORS}
          Error(Line, 'Waiting for '']''')
{$ENDIF}
      end
      else
      begin
        if Opd.OpdType = #0 then
        begin
          Opd.OpdType := 'r';
          if Upper[S^] in ['A' .. 'Z'] then
          begin
            p := S;
            SkipToSp(#0, ', ');
            // SetString( Name, p, DWORD(s)-DWORD(p) );
            // if StrIs( Name,
            if StrIsL(p, DWORD(S) - DWORD(p), ['AL', 'AH', 'AX', 'EAX', 'DL',
              'DH', 'DX', 'EDX', 'CL', 'CH', 'CX', 'ECX', 'BL', 'BH', 'BX',
              'EBX', 'SI', 'ESI', 'DI', 'EDI', 'SP', 'ESP', 'BP', 'EBP', 'MM0',
              'MM1', 'MM2', 'MM3', 'MM4', 'MM5', 'MM6', 'MM7', 'XMM0', 'XMM1',
              'XMM2', 'XMM3', 'XMM4', 'XMM5', 'XMM6', 'XMM7', 'ST(0)', 'ST(1)',
              'ST(2)', 'ST(3)', 'ST(4)', 'ST(5)', 'ST(6)', 'ST(7)'], j) then
            begin
              CASE j OF
                0, 1, 4, 5, 8, 9, 12, 13:
                  Opd.OpdSize := 1;
                2, 6, 10, 14, 16, 18, 20, 22:
                  Opd.OpdSize := 2;
                3, 7, 11, 15, 17, 19, 21, 23:
                  Opd.OpdSize := 4;
                24 .. 31, 40 .. 47:
                  Opd.OpdSize := 8;
                32 .. 39:
                  Opd.OpdSize := 16;
              END;
              CASE j OF
                0 .. 23:
                  Opd.OpdType := 'r';
                24 .. 39:
                  Opd.OpdType := 'x';
                40 .. 47:
                  Opd.OpdType := 'z';
              END;
              Opd.RegNum := RegNums[j];
              StrLCopy(Opd.AsStr, p, DWORD(S) - DWORD(p));
            end
            else
              // if StrIs( Name, [ 'CS', 'DS', 'ES', 'SS', 'FS', 'GS' ], j ) then
              if StrIsL(p, DWORD(S) - DWORD(p), ['ES', 'CS', 'SS', 'DS', 'FS', 'GS'], j) then
              begin
                Opd.OpdType := 's';
                Opd.RegNum := j;
              end
              else if StrIsL(p, DWORD(S) - DWORD(p),
                ['CR0', 'CR1', 'CR2', 'CR3', 'CR4', 'CR5', 'CR6', 'CR7'], j)
              then
              begin
                Opd.OpdType := 'c';
                Opd.RegNum := j;
              end
              else if StrIsL(p, DWORD(S) - DWORD(p),
                ['DR0', 'DR1', 'DR2', 'DR3', 'DR4', 'DR5', 'DR6', 'DR7'], j)
              then
              begin
                Opd.OpdType := 'g';
                Opd.RegNum := j;
              end
              else
              begin
                S := p;
                Opd.OpdType := 'i';
              end;
          end
          else
            Opd.OpdType := 'i';
        end
        else
          Opd.OpdType := 'i';
        if Opd.OpdType in ['m', 'i'] then
          Opd.Offset := Expression('');
        { if Opd.OpdType = 'i' then
          begin
          if (Opd.Offset >= -128) and (Opd.Offset <= 127) then
          Opd.OpdSize := 1
          else
          if (Opd.Offset >= -32768) and (Opd.Offset <= 32767) then
          Opd.OpdSize := 2
          else
          Opd.OpdSize := 4;
          end; }
      end;
    end;

  var
    Operands: array [1 .. 3] of TOperand;
    OpdCount: Integer;
    ImmOpdCount: Integer;
    HasAmp: Boolean;

    procedure MachineCommand(Cmd: PAnsiChar);
    var
      opd_i: Integer;
      j: Integer;
      SibByte, ModRm: Byte;
      NeedSib, ReadySib: Boolean;
      op_matched: Boolean;
      InstrSubTable: PList;

      function InstrMatched(j: Integer): Boolean;
      var
        p, q, S: PAnsiChar;
        i, n, M, k: Integer;
        // OpdDef: String;
        ActualJmpOffset: Integer;
      begin
        Result := FALSE;
        S := PAnsiChar(InstrSubTable.Items[j]);
        p := S;
        while S^ > ' ' do
          Inc(S);
        if DWORD(S) - DWORD(p) <> StrLen(Cmd) then
          Exit;
        if StrLComp_NoCase(PAnsiChar(Cmd), p, DWORD(S) - DWORD(p)) <> 0 then
          Exit;
        op_matched := TRUE;
        for i := 1 to OpdCount do
        begin
          while S^ = ' ' do
            Inc(S);
          if S^ = '-' then
            Exit;
          CASE Operands[i].OpdType OF
            'r':
              begin
                p := S;
                while not(S^ in [',', ' ', '0' .. '9']) do
                  Inc(S);
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if not StrInL(p, DWORD(S) - DWORD(p), ['r', 'AL', 'AX', 'EAX', 'DX', 'CL']) then
                  Exit;
                if StrInL(p, DWORD(S) - DWORD(p), ['r']) then
                begin
                  n := 0;
                  while S^ in ['0' .. '9', 'A' .. 'Z'] do
                  begin
                    if S^ >= 'A' then
                      n := n * 16 + Ord(S^) - Ord('A') + 10
                    else
                      n := n * 16 + Ord(S^) - Ord('0');
                    Inc(S);
                  end;
                  { if n = 0 then
                    asm
                    int 3
                    end; }
                  if (n <> 0) and (n <> Operands[i].OpdSize) then
                    Exit;
                end
                else
                begin
                  if (StrLen(Operands[i].AsStr) <> DWORD(S) - DWORD(p)) or
                    (StrLComp_NoCase(Operands[i].AsStr, p, DWORD(S) - DWORD(p))
                    <> 0) then
                    Exit;
                end;
              end;
            'x':
              begin
                p := S;
                while not(S^ in [',', ' ', '0' .. '9']) do
                  Inc(S);
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if not StrInL(p, DWORD(S) - DWORD(p), ['X']) then
                  Exit;
                n := 0;
                while S^ in ['0' .. '9', 'A' .. 'Z'] do
                begin
                  if S^ >= 'A' then
                    n := n * 16 + Ord(S^) - Ord('A') + 10
                  else
                    n := n * 16 + Ord(S^) - Ord('0');
                  Inc(S);
                end;
                { if n = 0 then
                  asm
                  int 3
                  end; }
                if (n <> 0) and (n <> Operands[i].OpdSize) then
                  Exit;
              end;
            'z':
              begin
                p := S;
                while not(S^ in [',', ' ']) do
                  Inc(S);
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if not StrIsL(p, DWORD(S) - DWORD(p), ['ST(0)', 'ST(1)', 'z'], k)
                then
                  Exit;
                if not StrInL(p, DWORD(S) - DWORD(p), ['z']) then
                  if Operands[i].RegNum <> k then
                    Exit;
              end;
            'm':
              begin
                p := S;
                while not(S^ in [',', ' ', '0' .. '9']) do
                  Inc(S);
                q := S;
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if not StrInL(p, DWORD(q) - DWORD(p), ['m', 'u']) then
                  Exit;
                n := 0;
                while S^ in ['0' .. '9', 'A' .. 'Z'] do
                begin
                  if S^ >= 'A' then
                    n := n * 16 + Ord(S^) - Ord('A') + 10
                  else
                    n := n * 16 + Ord(S^) - Ord('0');
                  Inc(S);
                end;
                if StrInL(p, DWORD(q) - DWORD(p), ['u']) then
                begin
                  if NeedSib then
                    Exit;
                  if (Operands[i].IdxBase1 <> ibNone) or
                    (Operands[i].IdxBase2 <> ibNone) then
                    Exit;
                  CASE n OF
                    1:
                      if (Operands[i].Offset < -128) or
                        (Operands[i].Offset > 127) then
                        Exit;
                    2:
                      if (Operands[i].Offset < -32768) or
                        (Operands[i].Offset > 32767) then
                        Exit;
                  END;
                end
                else
                begin
                  if (n <> 0) and (Operands[i].OpdSize <> 0) and
                    (n <> Operands[i].OpdSize) then
                    Exit;
                end;
                if (Operands[i].OpdSize = 0) and (Step = 1) then
                begin
                  n := 0;
                  for j := 1 to OpdCount do
                  begin
                    if (Operands[j].OpdType in ['r', 'x', 'z', 's', 'c', 'g'])
                    then
                    begin
                      if StrInL(PAnsiChar(Cmd), StrLen(Cmd), ['MOVZX', 'MOVSX']) and
                        (Operands[j].OpdSize = 4) then
                      else
                        n := Operands[j].OpdSize;
                      break;
                    end;
                  end;
                  if n = 0 then
                    Exit;
                end;
              end;
            'n', 'o':
              begin
                p := S;
                while not(S^ in [',', ' ', '0' .. '9']) do
                  Inc(S);
                q := S;
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if not StrInL(p, DWORD(q) - DWORD(p), ['m']) then
                  Exit;
                n := 0;
                while S^ in ['0' .. '9', 'A' .. 'Z'] do
                begin
                  if S^ >= 'A' then
                    n := n * 16 + Ord(S^) - Ord('A') + 10
                  else
                    n := n * 16 + Ord(S^) - Ord('0');
                  Inc(S);
                end;
                if (n <> 0) and (Operands[i].OpdSize <> 0) and
                  (n <> Operands[i].OpdSize) then
                  Exit;
              end;
            'f', 'i':
              begin
                p := S;
                while not(S^ in [',', ' ', '0' .. '9', '-']) do
                  Inc(S);
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if not StrIsL(p, DWORD(S) - DWORD(p),
                  ['', 'b', 'w', 'd', 'f', 'n'], k) then
                  Exit;
                CASE k OF
                  0: { }
                    begin
                      if S^ in ['0' .. '9'] then
                      begin
                        n := 0;
                        while S^ in ['0' .. '9', 'A' .. 'Z'] do
                        begin
                          if S^ >= 'A' then
                            n := n * 16 + Ord(S^) - Ord('A') + 10
                          else
                            n := n * 16 + Ord(S^) - Ord('0');
                          Inc(S);
                        end;
                        if n <> Operands[i].Offset then
                          Exit;
                      end;
                      { else
                        begin
                        if Operands[ i ].Offset <> 1 then Exit;
                        end; }
                    end;
                  1: { b }
                    if (Operands[i].Offset < -128) or (Operands[i].Offset > 127)
                    then
                      Exit;
                  2: { w }
                    if (Operands[i].Offset < -32768) or
                      (Operands[i].Offset > 32767) then
                      Exit;
                  3: { d }
                    ;
                  4: { f }
                    begin
                      ActualJmpOffset := 0;
                      if ActualJmpOffset <> 0 then;
                      n := 0;
                      while S^ in ['0' .. '9', 'A' .. 'Z'] do
                      begin
                        if S^ >= 'A' then
                          n := n * 16 + Ord(S^) - Ord('A') + 10
                        else
                          n := n * 16 + Ord(S^) - Ord('0');
                        Inc(S);
                      end;
                      if StrInL(Cmd, StrLen(Cmd), ['JCXZ', 'JECXZ']) then
                      begin
                        M := 1;
                        Operands[i].OpdSize := 1;
                      end
                      else if Operands[i].OpdSize <> 0 then
                      begin
                        M := Operands[i].OpdSize;
                      end
                      else if Step = 1 then
                      begin
                        if Operands[i].Offset <> 0 then
                        begin
                          ActualJmpOffset := Operands[i].Offset - IP -
                            Integer(BaseAddr) { Integer(Memory) } -
                            Step1Addition - 2;
                          if (ActualJmpOffset < -128) or (ActualJmpOffset > 127)
                          then
                            M := 4
                          else
                            M := 1;
                        end
                        else
                        begin
                          M := 4;
                        end;
                      end
                      else
                      // if Step = 2 then
                      begin
                        if Lines.Objects[Line] > 2 then
                          M := 4
                        else
                          M := 1;
                      end;
                      if (n <> 0) and (M > n) then
                        Exit;
                      if Step <> 0 then
                      begin
                        if M = 1 then
                          ActualJmpOffset := Operands[i].Offset -
                            Integer(BaseAddr) { Integer( Memory ) } -
                            Step1Addition - (IP + 2)
                        else // m = 4
                          ActualJmpOffset := Operands[i].Offset -
                            Integer(BaseAddr) { Integer( Memory ) } -
                            Step1Addition - (IP + 6);
                        if (StrComp_NoCase(PAnsiChar(Cmd), 'LOOP') = 0) and (M > 1)
                        then
                          Dec(ActualJmpOffset)
                        else if (StrComp_NoCase(PAnsiChar(Cmd), 'JMP') = 0) and
                          (M > 1) then
                          Inc(ActualJmpOffset);
{$IFNDEF NOERRORS}
                        case M OF
                          1:
                            if (Operands[i].OpdSize <> 1) or (Step = 2) then
                              if (ActualJmpOffset < -128) or
                                (ActualJmpOffset > 127) then
                                if Step = 1 then
                                  Exit
                                else
                                  Error(Line, 'Too long jump: ' +
                                    Int2Str(ActualJmpOffset));
                          2:
                            if (ActualJmpOffset < -32768) or
                              (ActualJmpOffset > 32767) then
                              if Step = 1 then
                                Exit
                              else
                                Error(Line,
                                  'Too long jump' + Int2Str(ActualJmpOffset));
                        END;
{$ENDIF}
                        if Step = 1 then
                          CASE n OF
                            1:
                              begin
                                if ((ActualJmpOffset >= 0) or
                                  (ActualJmpOffset < -128)) and
                                  not StrInL(PAnsiChar(Cmd), StrLen(Cmd),
                                  ['JCXZ', 'JECXZ']) and
                                  (Operands[i].OpdSize <> 1) then
                                  Exit;
                              end;

                          END;
                      end;
                    end;
                  5: { n }
                    begin
                      if Operands[i].OpdType <> 'i' then
                        Exit;
                      Operands[i].OpdSize := 4;
                      n := 0;
                      while S^ in ['0' .. '9', 'A' .. 'Z'] do
                      begin
                        if S^ >= 'A' then
                          n := n * 16 + Ord(S^) - Ord('A') + 10
                        else
                          n := n * 16 + Ord(S^) - Ord('0');
                        Inc(S);
                      end;
                      if n <> 4 then
                        Exit;
                    end;
                END;
              end;
            's':
              begin
                p := S;
                while not(S^ in [',', ' ', '0' .. '9']) do
                  Inc(S);
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if not StrIsL(p, DWORD(S) - DWORD(p),
                  ['ES', 'CS', 'SS', 'DS', 'FS', 'GS', 's'], n) then
                  Exit;
                if (n < 6) and (Operands[i].RegNum <> n) then
                  Exit;
              end;
            'c':
              begin
                p := S;
                while not(S^ in [',', ' ']) do
                  Inc(S);
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if not StrIsL(p, DWORD(S) - DWORD(p),
                  ['CR0', 'CR0', 'CR2', 'CR3', 'CR4'], n) then
                  Exit;
                if n <> Operands[i].RegNum then
                  Exit;
              end;
            'g':
              begin
                p := S;
                while not(S^ in [',', ' ']) do
                  Inc(S);
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if not StrIsL(p, DWORD(S) - DWORD(p),
                  ['DR0', 'DR1', 'DR2', 'DR3', 'DR4', 'DR5', 'DR6', 'DR7'], n)
                then
                  Exit;
                if n <> Operands[i].RegNum then
                  Exit;
              end;
            '!':
              begin
                p := S;
                while not(S^ in [',', ' ']) do
                  Inc(S);
                q := @Operands[i].AsStr[0];
                while (q^ > ' ') and
                  (DWORD(q) <= DWORD(@Operands[i].AsStr[9])) do
                  Inc(q);
                // SetString( OpdDef, p, DWORD(s)-DWORD(p) );
                if DWORD(S) - DWORD(p) <> DWORD(q) - DWORD(@Operands[i].AsStr[0])
                then
                  Exit;
                if StrLComp_NoCase(p, Operands[i].AsStr, DWORD(S) - DWORD(p)) <> 0
                then
                  Exit;
              end;
          else
            asm
              // int 3
            end
            ;
          END;
          while S^ = ' ' do
            Inc(S);
          if S^ = ',' then
          begin
            Inc(S);
            while S^ = ' ' do
              Inc(S);
          end
          else
          begin
            while S^ = ' ' do
              Inc(S);
            Result := (i = OpdCount) and (S^ = '-');
            Exit;
          end;
        end;
        while S^ = ' ' do
          Inc(S);
        Result := S^ = '-';
      end;

      procedure PrepareSibByte(IdxReg1, IdxReg2: TIdxBase; Mult: TScale; Offset: Integer);
      begin
        NeedSib := (IdxReg1 <> ibNone) or (IdxReg2 <> ibNone) or
          (Mult <> mult1);
        if NeedSib and (IdxReg2 = ibNone) and
          (IdxReg1 in [ibEAX, ibECX, ibEDX, ibEBX, ibEBP, ibESI, ibEDI]) then
          NeedSib := FALSE;
        if NeedSib then
        begin
          { if (IdxReg1 = IdxReg2) and (Mult = mult1) then
            begin
            IdxReg1 := ibNone;
            Mult := mult2;
            end; }
          SibByte := SibTable[IdxReg1, IdxReg2, Mult];
          if (Mult = mult1) and (IdxReg2 = ibESP) or (Mult = mult1) and
            (IdxReg2 <> ibNone) and (IdxReg1 = ibEBP) or (Mult = mult1) and
            (IdxReg2 <> ibNone) and (IdxReg2 <> ibEBP) and (IdxReg1 <> ibESP)
          then
            SibByte := SibTable[IdxReg2, IdxReg1, mult1]
{$IFNDEF NOERRORS}
          else if (Mult <> mult1) and (IdxReg2 = ibESP) then
            Error(Line, 'Invalid addressing mode');
{$ENDIF}
        end;
        ReadySib := FALSE;
      end;

      procedure Prepare2ModRm(Reg, Mem: POperand);
      begin
        ModRm := 0;
        if NeedSib then
        begin
          Inc(ModRm, 4);
          if (Mem.IdxBase1 = ibEBP) and (Mem.IdxMult2 <> mult1) then
          begin
            if (Mem.Offset < -128) or (Mem.Offset > 127) then
              Inc(ModRm, $80)
            else
            begin
              Inc(ModRm, $40);
              Mem.OpdType := 'n';
            end;
          end
          else if not((Mem.IdxBase1 = ibNone) and (Mem.IdxMult2 <> mult1)) then
          begin
            if (Mem.Offset < -128) or (Mem.Offset > 127) then
              Inc(ModRm, $80)
            else if (Mem.Offset <> 0) then
            begin
              Inc(ModRm, $40);
              Mem.OpdType := 'n';
            end
            else
            begin
              Mem.OpdType := 'o';
            end;
          end
          else if (Mem.IdxBase1 = ibNone) and (Mem.IdxMult2 <> mult1) then
          begin
          end;
        end
        else
          CASE Mem.IdxBase1 OF
            ibEAX:
              if Mem.Offset = 0 then
                Mem.OpdType := 'o'
              else if (Mem.Offset >= -128) and (Mem.Offset <= 255) then
              begin
                Inc(ModRm, $40);
                Mem.OpdType := 'n';
              end
              else
                Inc(ModRm, $80);
            ibECX:
              if Mem.Offset = 0 then
              begin
                Inc(ModRm, 1);
                Mem.OpdType := 'o';
              end
              else if (Mem.Offset >= -128) and (Mem.Offset <= 255) then
              begin
                Inc(ModRm, $41);
                Mem.OpdType := 'n';
              end
              else
                Inc(ModRm, $81);
            ibEDX:
              if Mem.Offset = 0 then
              begin
                Inc(ModRm, 2);
                Mem.OpdType := 'o';
              end
              else if (Mem.Offset >= -128) and (Mem.Offset <= 255) then
              begin
                Inc(ModRm, $42);
                Mem.OpdType := 'n';
              end
              else
                Inc(ModRm, $82);
            ibEBX:
              if Mem.Offset = 0 then
              begin
                Inc(ModRm, 3);
                Mem.OpdType := 'o';
              end
              else if (Mem.Offset >= -128) and (Mem.Offset <= 255) then
              begin
                Inc(ModRm, $43);
                Mem.OpdType := 'n';
              end
              else
                Inc(ModRm, $83);
            ibNone:
              Inc(ModRm, 5);
            ibEBP:
              if (Mem.Offset >= -128) and (Mem.Offset <= 255) then
              begin
                Inc(ModRm, $45);
                Mem.OpdType := 'n';
              end
              else
                Inc(ModRm, $85);
            ibESI:
              if Mem.Offset = 0 then
              begin
                Inc(ModRm, 6);
                Mem.OpdType := 'o';
              end
              else if (Mem.Offset >= -128) and (Mem.Offset <= 255) then
              begin
                Inc(ModRm, $46);
                Mem.OpdType := 'n';
              end
              else
                Inc(ModRm, $86);
            ibEDI:
              if Mem.Offset = 0 then
              begin
                Inc(ModRm, 7);
                Mem.OpdType := 'o';
              end
              else if (Mem.Offset >= -128) and (Mem.Offset <= 255) then
              begin
                Inc(ModRm, $47);
                Mem.OpdType := 'n';
              end
              else
                Inc(ModRm, $87);
{$IFNDEF NOERRORS}
          else
            Error(Line, 'Could not generate r/m');
{$ENDIF}
          END;
      end;

      procedure PrepareModRm;
      begin
        ModRm := 0;
        if (OpdCount >= 2) AND (Operands[1].OpdType in ['r', 'x']) and
          (Operands[2].OpdType in ['r', 'x']) then
        begin
        end
        else if (OpdCount >= 2) AND
          ((Operands[1].OpdType = 'm') or (Operands[2].OpdType = 'm')) and
          ((Operands[2].OpdType in ['r', 'x', 's']) or
          (Operands[1].OpdType in ['r', 'x', 's'])) then
        begin
          if Operands[1].OpdType in ['r', 'x', 's'] then
            Prepare2ModRm(@Operands[1], @Operands[2])
          else
            Prepare2ModRm(@Operands[2], @Operands[1]);
        end
        else if (OpdCount >= 2) AND
          ((Operands[1].OpdType = 'm') or (Operands[2].OpdType = 'm')) and
          ((Operands[2].OpdType = 'z') or (Operands[1].OpdType = 'z')) then
        begin
          if Operands[1].OpdType = 'z' then
            Prepare2ModRm(nil, @Operands[2])
          else
            Prepare2ModRm(nil, @Operands[1]);
        end
        else
          if ((OpdCount = 1) or (OpdCount > 1) and (Operands[2].OpdType in ['i',
            's'])) then
          begin
            if Operands[1].OpdType in ['r', 'x'] then
            else if Operands[1].OpdType = 'm' then
              Prepare2ModRm(nil, @Operands[1]);
          end;
      end;

      function GetOpd1(var p: PAnsiChar): Int64;
      var
        i: Integer;
      begin
        Result := 0;
        CASE p^ OF
          'b', 'w', 'd':
            begin
              for i := 1 to OpdCount do
                if (Operands[i].OpdType = 'i') and
                  ((ImmOpdCount = 1) or (p^ = 'b') and (i = OpdCount) or
                  (p^ <> 'b') and (i < OpdCount)) then
                begin
                  Inc(p);
                  Result := Operands[i].Offset;
                  Exit;
                end;
{$IFNDEF NOERRORS}
              Error(Line, 'Operand <' + p^ + '> not found');
{$ENDIF}
              Inc(p);
            end;
          'r':
            begin
              for i := 1 to OpdCount do
                if Operands[i].OpdType = 'r' then
                begin
                  Inc(p);
                  Result := Operands[i].RegNum;
                  Exit;
                end;
{$IFNDEF NOERRORS}
              Error(Line, 'Operand <' + p^ + '> not found');
{$ENDIF}
              Inc(p);
            end;
          'R':
            begin
              for i := Min(OpdCount, 2) downto 1 do
                if Operands[i].OpdType = 'r' then
                begin
                  Inc(p);
                  Result := Operands[i].RegNum;
                  Exit;
                end;
{$IFNDEF NOERRORS}
              Error(Line, 'Operand <' + p^ + '> not found');
{$ENDIF}
              Inc(p);
            end;
          'x':
            begin
              for i := 1 to OpdCount do
                if Operands[i].OpdType = 'x' then
                begin
                  Inc(p);
                  Result := Operands[i].RegNum;
                  Exit;
                end;
{$IFNDEF NOERRORS}
              Error(Line, 'Operand <' + p^ + '> not found');
{$ENDIF}
              Inc(p);
            end;
          'X':
            begin
              for i := OpdCount downto 1 do
                if Operands[i].OpdType = 'x' then
                begin
                  Inc(p);
                  Result := Operands[i].RegNum;
                  Exit;
                end;
{$IFNDEF NOERRORS}
              Error(Line, 'Operand <' + p^ + '> not found');
{$ENDIF}
              Inc(p);
            end;
          'z':
            begin
              for i := 1 to OpdCount do
                if Operands[i].OpdType = 'z' then
                begin
                  Inc(p);
                  Result := Operands[i].RegNum;
                  Exit;
                end;
{$IFNDEF NOERRORS}
              Error(Line, 'Operand <' + p^ + '> not found');
{$ENDIF}
              Inc(p);
            end;
          'Z':
            begin
              for i := OpdCount downto 1 do
                if Operands[i].OpdType = 'z' then
                begin
                  Inc(p);
                  Result := Operands[i].RegNum;
                  Exit;
                end;
{$IFNDEF NOERRORS}
              Error(Line, 'Operand <' + p^ + '> not found');
{$ENDIF}
              Inc(p);
            end;
          's':
            begin
              for i := 1 to OpdCount do
                if Operands[i].OpdType = 's' then
                begin
                  Inc(p);
                  Result := Operands[i].RegNum;
                end;
            end;
          'm', 'u', 'o', 'n':
            begin
              for i := 1 to OpdCount do
                if Operands[i].OpdType in ['m', 'u', 'n'] then
                begin
                  Inc(p);
                  Result := Operands[i].Offset;
                  Exit;
                end;
{$IFNDEF NOERRORS}
              Error(Line, 'Operand <' + p^ + '> not found');
{$ENDIF}
              Inc(p);
            end;
          '?':
            begin
              Result := ModRm;
              Inc(p);
            end;
          'f':
            begin
{$IFNDEF NOERRORS}
              if not(Operands[1].OpdType in ['f', 'i']) or (OpdCount <> 1) then
                Error(Line, 'Not jump');
{$ENDIF}
              Result := Operands[1].Offset -
                (Integer(BaseAddr) { Integer( Memory ) } + IPStart +
                Integer(Lines.Objects[Line]));
              Inc(p);
            end;
        else
          if p^ in ['0' .. '9', 'A' .. 'F'] then
          begin
            if p^ in ['0' .. '9'] then
              Result := Ord(p^) - Ord('0')
            else
              Result := Ord(p^) - Ord('A') + 10;
            Inc(p);
            if p^ in ['0' .. '9'] then
              Result := Result * 16 + Ord(p^) - Ord('0')
            else if p^ in ['A' .. 'F'] then
              Result := Result * 16 + Ord(p^) - Ord('A') + 10
            else
              Exit;
            Inc(p);
          end;
        END;
      end;

      function Prty1(op: AnsiChar): Integer;
      begin
        CASE op OF
          '+', '-':
            Result := 1;
        else
          Result := 2;
        END;
      end;

      function Expr1(op1: AnsiChar; var S: PAnsiChar): Int64;
      var
        opd1, opd2: Integer;
        p: PAnsiChar;
        op2: AnsiChar;
      label Get_op2;
      begin
        opd1 := GetOpd1(S);
        Result := opd1;
      Get_op2:
        p := S;
        if not(S^ in ['+', '-', '<', '>']) then
          Exit;
        op2 := S^;
        Inc(S);
        if (op1 <> ' ') and (Prty1(op1) > Prty1(op2)) then
        begin
          S := p;
          Exit;
        end;
        opd2 := Expr1(op2, S);
        CASE op2 OF
          '+':
            Result := opd1 + opd2;
          '-':
            Result := opd1 - opd2;
          '<':
            Result := opd1 shl opd2;
          '>':
            Result := opd1 shr opd2;
        else
          asm
            // int 3
          end
          ;
        END;
        opd1 := Result;
        goto Get_op2;
      end;

      procedure GenerateMachineCommand(p: PAnsiChar);
      var
        e: array [0 .. 31] of AnsiChar;
        B: Byte;
        o_pos: Integer;
        q: PAnsiChar;
        Skipbyte: Boolean;
        i_memopd: Integer;
      begin
        while (p^ <> '-') and (p^ <> #0) do
          Inc(p);
        if p^ = #0 then
          Exit;
        Inc(p);
        if p^ <> '>' then
          Exit;
        Inc(p);
        while p^ = ' ' do
          Inc(p);
        o_pos := IP;
        while p^ <> #0 do
        begin
          if p^ = '!' then
            Inc(p);
          q := p;
          while (p^ <> ' ') and (p^ <> #0) do
            Inc(p);
          // SetString( e, q, DWORD(p)-DWORD(q) );
          StrLCopy(e, q, DWORD(p) - DWORD(q));
          q := @e[0];
          Skipbyte := FALSE;
          if q^ = 'm' then
          begin
            for i_memopd := 1 to OpdCount do
              if Operands[i_memopd].OpdType = 'n' then
              begin
                Skipbyte := q[1] = '>';
                break;
              end
              else if Operands[i_memopd].OpdType = 'o' then
              begin
                Skipbyte := TRUE;
                break;
              end
              else if Operands[i_memopd].OpdType = 'm' then
                break;
          end;
          if not Skipbyte then
          begin
            B := Expr1(' ', q);
            OutByte(B);
          end;
          while p^ = ' ' do
            Inc(p);
          if NeedSib and not ReadySib and (pos('?', e) > 0) then
          begin
            ReadySib := TRUE;
            OutByte(SibByte);
          end;
        end;
        Lines.Objects[Line] := IP - o_pos;
        Inc(MacroLen, Lines.Objects[Line]);
{$IFNDEF NOERRORS}
        if NeedSib and not ReadySib then
          Error(Line, 'SIB not generated!');
{$ENDIF}
      end;

    // MachineCommand implementation:
    var
      p, s0: PAnsiChar;
      hc: Word;
      s_opdstart: PAnsiChar;
      RebuildHintOperands: Boolean;
    begin
      { if (Line+1 = 394) then
        asm
        int 3
        end; }
      NeedSib := FALSE;
      SkipSp;
      opd_i := 0;
      OpdCount := 0;
      ImmOpdCount := 0;
      IPStart := IP;
      s_opdstart := S;
      if s_opdstart <> nil then;
      RebuildHintOperands := FALSE;
      if not HasAmp and (Hints[Line].HintTp = htNone) then
        RebuildHintOperands := TRUE;
      while S^ <> #0 do
      begin
        Inc(opd_i);
        if opd_i > 3 then
        begin
{$IFNDEF NOERRORS}
          Error(Line, 'Too many instruction operands');
{$ENDIF}
          break;
        end;
        Inc(OpdCount);
        if not RebuildHintOperands and
          (Hints[Line].HintOpds and (1 shl opd_i) <> 0) then
        begin
          Operands[opd_i] := Hints[Line].Operands[opd_i];
          Inc(S, Hints[Line].OpdLens[opd_i]);
        end
        else
        begin
          s0 := S;
          InstrOperand(Cmd, Operands[opd_i]);
          if RebuildHintOperands and (Operands[opd_i].OpdType in ['r', 'x', 's'])
          then
          begin
            Hints[Line].HintOpds := Hints[Line].HintOpds or (1 shl opd_i);
            Hints[Line].Operands[opd_i] := Operands[opd_i];
            Hints[Line].OpdLens[opd_i] := DWORD(S) - DWORD(s0);
          end;
        end;
        if Operands[opd_i].OpdType = 'i' then
          Inc(ImmOpdCount);
        SkipSp;
        if S^ = ',' then
        begin
          Inc(S);
          SkipSp;
        end
        else
          break;
      end;
      if OpdCount = 3 then
      begin
{$IFNDEF NOERRORS}
        if (Operands[3].OpdType <> 'i') and
          not((Operands[3].OpdType = 'r') and (Operands[3].RegNum = 1) and
          (Operands[3].OpdSize = 1)) then
          Error(Line, '3rd operand must not be immediate');
        if (Operands[3].OpdType = 'i') and (Operands[3].OpdSize > 1) then
          Error(Line, '3rd operand size exceed 1 byte');
{$ENDIF}
        Operands[3].OpdSize := 1;
      end;
      if OpdCount > 1 then
      begin
{$IFNDEF NOERRORS}
        if (Operands[1].OpdType = 'm') and (Operands[2].OpdType = 'm') then
          Error(Line, 'Both operands can not address memory')
        else
{$ENDIF}
          if Operands[1].OpdType = 'm' then
            PrepareSibByte(Operands[1].IdxBase1, Operands[1].IdxBase2,
              Operands[1].IdxMult2, Operands[1].Offset)
          else if Operands[2].OpdType = 'm' then
            PrepareSibByte(Operands[2].IdxBase1, Operands[2].IdxBase2,
              Operands[2].IdxMult2, Operands[2].Offset)
          else
            PrepareSibByte(ibNone, ibNone, mult1, 0);

        PrepareModRm;
      end
      else if OpdCount = 1 then
      begin
        if Operands[1].OpdType = 'm' then
          PrepareSibByte(Operands[1].IdxBase1, Operands[1].IdxBase2,
            Operands[1].IdxMult2, Operands[1].Offset)
        else
          PrepareSibByte(ibNone, ibNone, mult1, 0);
        PrepareModRm;
      end;
      op_matched := FALSE;
      hc := CalcHash(PAnsiChar(Cmd), HashBits, MaxInt);
      InstrSubTable := HashedTable[hc];
      if Hints[Line].HintTp = htCmd then
      begin
        p := InstrSubTable.Items[Hints[Line].CmdIdx];
        GenerateMachineCommand(p);
        Exit;
      end
      else
      begin
        if InstrSubTable <> nil then
          for j := 0 to InstrSubTable.Count - 1 do
          begin
            if InstrMatched(j) then
            begin
              if not HasAmp then
              begin
                Hints[Line].HintTp := htCmd;
                Hints[Line].CmdIdx := j;
              end;
              p := InstrSubTable.Items[j];
              GenerateMachineCommand(p);
              Exit;
            end;
          end;
      end;
{$IFNDEF NOERRORS}
      if op_matched then
        Error(Line, 'Operands are not matching to instruction op')
      else
        Error(Line, 'Invalid op ' + Cmd);
{$ENDIF}
    end;

  var
    AName: array [0 .. 256] of AnsiChar;
    Cmd: array [0 .. 256] of AnsiChar;
    Buf: array [0 .. 4096] of AnsiChar;
    j, k, n: Integer;
    Levels: PFastStrListEx;
    ForParam: array [0 .. 4096] of AnsiChar;
    ForValues: PFastStrListEx;
    StrVal: array [0 .. 4095] of AnsiChar;
    Temp: array [0 .. 4095] of AnsiChar;
    Addr: DWORD;

    procedure AddLabel;
    var
      Temp: array [0 .. 512] of AnsiChar;
      Temp1: array [0 .. 512] of AnsiChar;
      getEp: String;
      p: PAnsiChar;
      n: Integer;
      FoundInLine: Integer;
      j: Integer;
    begin
      if SkipLevel <= 1 then
      begin
        if Step = 1 then
        begin
          { if (Line+1 = 1258) then
            asm
            int 3
            end; }
          if (StrLen(AName) = 2) and (AName[0] = '@') and (AName[1] = '@') then
          begin
            StrCopy(Temp, AName);
            StrCat(Temp, '|');
            p := Temp + StrLen(Temp);
            n := CallMacroNum;
            while n > 0 do
            begin
              p^ := AnsiChar(Ord('0') + n mod 10);
              n := n div 10;
              Inc(p);
            end;
            p^ := #0;
            StrCat(Temp, '.');
            p := Temp + StrLen(Temp);
            n := Line;
            while n > 0 do
            begin
              p^ := AnsiChar(Ord('0') + n mod 10);
              n := n div 10;
              Inc(p);
            end;
            p^ := #0;
            { Temp := AName + '|' + Int2Str( CallMacroNum )
              + '.' + Int2Str( Line ); }
            StrCopy(Temp1, #1'');
            StrCat(Temp1, Temp);
            StrCat(Temp1, '#');
            p := Temp1 + StrLen(Temp1);
            n := CallMacroFromLineNum;
            while n > 0 do
            begin
              p^ := AnsiChar(Ord('0') + n mod 10);
              n := n div 10;
              Inc(p);
            end;
            p^ := #0;
            // Labels.AddObject( #1 + Temp + '#' + Int2Str( CallMacroFromLineNum ),
            Labels.AddObject(Temp1, IP + Step1Addition);
            AddLabel2HashTable(Temp, Labels.Count - 1);
          end
          else
          begin
            // Temp := AName;
            StrCopy(Temp1, #1'');
            StrCat(Temp1, AName);
{$IFNDEF NOERRORS}
            if LabelExists(AName, Line, Lines) then
              Error(Line, 'Duplicated label ' + AName);
{$ENDIF}
            // Labels.AddObject( #1 + Temp, IP + Step1Addition );
            getEp := Copy(Temp1, 2, 5);
            if getEp = 'Start' then
              AddrOfEP := IP;
            if getEp = 'Invok' then
            begin
              Error(Line, 'Invok No Support ');
              Halt;
            end;
            Labels.AddObject(Temp1, IP + Step1Addition);
            AddLabel2HashTable(AName, Labels.Count - 1);
          end;
        end
        else if Step = 2 then
        begin
          { if (Line+1 = 1258) then
            asm
            int 3
            end; }
          if (StrLen(AName) = 2) and (AName[0] = '@') and (AName[1] = '@') then
          begin
            StrCopy(Temp, AName);
            StrCat(Temp, '|');
            n := CallMacroNum;
            p := Temp + StrLen(Temp);
            while n > 0 do
            begin
              p^ := AnsiChar(Ord('0') + n mod 10);
              n := n div 10;
              Inc(p);
            end;
            p^ := #0;
            StrCat(Temp, '.');
            p := Temp + StrLen(Temp);
            n := Line;
            while n > 0 do
            begin
              p^ := AnsiChar(Ord('0') + n mod 10);
              n := n div 10;
              Inc(p);
            end;
            p^ := #0;
            // Temp := AName + '|' + Int2Str( CallMacroNum ) + '.' + Int2Str( Line );
            j := FindLabelStrL(Temp, StrLen(Temp), Line, Lines, FoundInLine)
          end
          else
            j := FindLabelStrL(AName, StrLen(AName), Line, Lines, FoundInLine);
          if j < 0 then
{$IFNDEF NOERRORS}
            Error(Line, 'Undeclared label ' + AName)
{$ENDIF}
          else
          begin
            Addr := DWORD(IP) + DWORD(BaseAddr); // DWORD( Memory );
{$IFNDEF NOERRORS}
            if Labels.Objects[j] <> Addr then
              Error(Line, 'Displaced ' + AName + ' on ' +
                Int2Str(Addr - Labels.Objects[j]));
{$ENDIF}
          end;
        end;
      end;
    end;

  var
    q, s1: PAnsiChar;
    OldCallMacroNum: Integer;
    OldCallMacroFromLineNum: Integer;
    OldMacroLen: Integer;
    FoundInLine: Integer;
    LevelRepFor: Integer;
    OldSkipLevel: Integer;
    OldIP: Integer;
    wasParamsCount: Integer;
    n1: Integer;
    p1: PAnsiChar;
    TempNameVal: array [0 .. 512] of AnsiChar;
  begin
    Levels := NewFastStrListEx;
    TRY
      Line := From - 1;
      while Line < ToIdx do
      begin
        CmdLen := -1;
        Inc(Line);
        Inc(LineHandling);
        S := Lines.ItemPtrs[Line];
        if S^ = #0 then
          continue;
        HasAmp := StrScan(S, '&') <> nil;
        if HasAmp then
        begin
          q := @Buf[0];

          while (DWORD(q) - DWORD(@Buf[0]) < Sizeof(Buf)) and (S^ <> #0) do
          begin
            if S^ = '&' then
            begin
              Inc(S);
              p := S;
              if S^ = '&' then
                Inc(S);
              SkipToSp('.', ' ,()[]+-*/<>=:&"''');
              s1 := S;
              if s1[-1] = '.' then
                Dec(s1);
              // SetString( Name, p, DWORD(s1)-DWORD(p) );
              StrLCopy(AName, p, Min(DWORD(s1) - DWORD(p), 255));
              if StrComp(AName, '&') = 0 then
              begin
                // StrCopy( Cmd, Int2Str( CallMacroNum ) );
                n1 := CallMacroNum;
                p1 := @Cmd[0];
                while n1 > 0 do
                begin
                  p1^ := AnsiChar(Ord('0') + n1 mod 10);
                  n1 := n1 div 10;
                  Inc(p1);
                end;
                p1^ := #0;
                s1 := @Cmd[0];
              end
              else
                // Cmd := Params.Values[ Name ];
                s1 := Params.Values[AName];
              if s1 = nil then
                Error(Line, 'Parameter ' + AName + ' not found');
              if s1 <> '' then
              begin
                while (DWORD(q) - DWORD(@Buf[0]) < Sizeof(Buf)) and
                  (s1^ <> #0) do
                begin
                  q^ := s1^;
                  Inc(q);
                  Inc(s1);
                end;
              end;
            end
            else
            begin
              q^ := S^;
              Inc(S);
              Inc(q);
            end;
          end;
          q^ := #0;
          S := @Buf[0];
        end;
        if (S^ <> ' ') and (S^ <> '.') then
        begin
          p := S;
          SkipToSp(':', ' ');
          StrLCopy(AName, p, Min(DWORD(S) - DWORD(p), 255));
          RemoveLast(AName, ':');
          SkipSp;
          if (S^ <> #0) and (S^ <> '.') then
          begin
            p := S;
            SkipToSp(#0, ' ');
            StrLCopy(Cmd, p, Min(DWORD(S) - DWORD(p), 255));
            if StrIsL(Cmd, StrLen(Cmd), ['MACRO', 'STRUCT', 'VAR'], j) then
            begin
              CASE j OF
                0: // MACRO
                  begin
{$IFNDEF NOERRORS}
                    if (SkipLevel <= 1) and (Step = 1) then
                      if MacroList.IndexOf_NoCase(AName) >= 0 then
                        Error(Line, 'Redeclare macro ' + AName);
{$ENDIF}
                    j := Line;
                    while Line < ToIdx do
                    begin
                      Inc(Line);
                      Inc(LineHandling);
                      S := Lines.ItemPtrs[Line];
                      if S^ = #0 then
                        continue;
                      if (S^ <> ' ') and (S^ <> '.') then
                        SkipToSp(':', ' ');
                      SkipSp;
                      if S^ = #0 then
                        continue;
                      p := S;
                      SkipToSp(#0, ' ');
                      // SetString( Cmd, p, DWORD(s)-DWORD(p) );
                      // if StrComp_NoCase( PAnsiChar( Cmd ), 'END' ) = 0 then
                      if StrInL(p, DWORD(S) - DWORD(p), ['END']) then
                      begin // âñ? íàøåëñÿ êîíå?ìàêðîñ?
                        if (SkipLevel <= 1) and (Step = 1) then
                          MacroList.AddObject(AName, j or (Line - 1) shl 16);
                        break;
                      end;
                    end;
                    continue;
                  end;
                1: // STRUCT
                  begin
                    if Step = 1 then
                    begin
{$IFNDEF NOERRORS}
                      if StructList.IndexOf_NoCase(AName) >= 0 then
                        Error(Line, 'Redeclare struct ' + AName);
{$ENDIF}
                      StructList.AddObject(AName, Line);
                    end;
                    j := 0;
                    while Line < ToIdx do
                    begin
                      Inc(Line);
                      Inc(LineHandling);
                      S := Lines.ItemPtrs[Line];
                      if S^ = #0 then
                        continue;
                      if S^ <> ' ' then
                      begin
                        p := S;
                        SkipToSp(':', ' ');
                        if SkipLevel <= 1 then
                        begin
                          q := S;
                          if S[-1] = ':' then
                            Dec(q);
                          // SetString( AName, p, DWORD(q)-DWORD(p) );
                          StrLCopy(AName, p, Min(DWORD(q) - DWORD(p), 255));
                          if Step = 1 then
                          begin
{$IFNDEF NOERRORS}
                            if FindLabelStrL(p, DWORD(q) - DWORD(p), Line,
                              Lines, FoundInLine) >= 0 then
                              Error(Line, 'Redeclared name ' + AName);
{$ENDIF}
                            Labels.AddObject(AName, j);
                            AddLabel2HashTable(AName, Labels.Count - 1);
                          end
                          else
                          begin
                            if Labels.Objects
                              [FindLabelStrL(p, DWORD(q) - DWORD(p), Line,
                              Lines, FoundInLine)] <> DWORD(j) then
                              Error(Line, 'Misplaced ' + AName);
                          end;
                        end;
                      end;
                      SkipSp;
                      if S^ = #0 then
                        continue;
                      p := S;
                      SkipToSp(#0, ' ');
                      // SetString( Cmd, p, DWORD(s)-DWORD(p) );
                      // if StrIs( Cmd, [ 'DB', 'DW', 'DD', 'DQ' ], k ) then
                      if StrIsL(p, DWORD(S) - DWORD(p),
                        ['DB', 'DW', 'DD', 'DQ'], k) then
                      begin
                        if SkipLevel <= 1 then
                        begin
                          SkipSp;
                          if S^ <> #0 then
                            n := Expression
                          else
                            n := 1;
                          Inc(j, DataLength[k] * n);
                        end;
                      end
                      else if StrInL(p, DWORD(S) - DWORD(p), ['END']) then
                      begin
                        StructList.Objects[StructList.Count - 1] := j;
                        break; // êîíå?îïðåäåëåíèÿ ñòðóêòóð?
                      end
                      else
                      begin // çíà÷èò ýò?âëîæåííàÿ ñòðóêòóð?
                        k := StructList.IndexOfStrL_NoCase(p,
                          DWORD(S) - DWORD(p));
                        if k < 0 then
                        begin
{$IFNDEF NOERRORS}
                          Error(Line, 'Unknown data spec ' + Cmd);
{$ENDIF}
                        end
                        else
                        begin
                          SkipSp;
                          if S^ <> #0 then
                            n := Expression
                          else
                            n := 1;
                          Inc(j, StructList.Objects[k] * DWORD(n));
                        end;
                      end;
                    end;
                  end;
                2: // EQU
                  if SkipLevel <= 1 then
                  begin
                    SkipSp;
                    if S^ <> '"' then
                    begin
                      n := Expression;
{$IFNDEF NOERRORS}
                      if (Step = 1) and LabelExists(AName, Line, Lines) then
                        Error(Line, 'Redeclare label ' + AName);
{$ENDIF}
                      if Step = 1 then
                      begin
                        Labels.AddObject(AName, n);
                        AddLabel2HashTable(AName, Labels.Count - 1);
                      end
                      else
                      begin
                        j := Labels.IndexOf_NoCase(AName);
{$IFNDEF NOERRORS}
                        if j < 0 then
                          Error(Line, 'Undeclared ' + AName);
                        if Labels.Objects[j] <> DWORD(n) then
                          Error(Line, 'Misplaced ' + AName);
{$ENDIF}
                      end;
                    end
                    else // s^ = "string"
                    begin
                      Inc(S);
                      p := S;
                      while (S^ <> #0) and (S^ <> '"') do
                        Inc(S);
                      // SetString( Cmd, p, DWORD(s)-DWORD(p) );
                      StrLCopy(Cmd, p, DWORD(S) - DWORD(p));
{$IFNDEF NOERRORS}
                      if Params.IndexOfName(AName) >= 0 then
                        Error(Line, 'Redefine VAR ' + AName);
{$ENDIF}
                      // Params.Add( AName + '=' + Cmd );
                      StrCopy(TempNameVal, AName);
                      StrCat(TempNameVal, '=');
                      StrCat(TempNameVal, Cmd);
                      Params.Add(TempNameVal);
                      if S^ = '"' then
                        Inc(S);
                    end;
                  end;
              END;
            end
            else
            begin
              AddLabel;
              S := p;
            end;
          end
          else
            AddLabel;
        end;
        SkipSp;
        if S^ = #0 then
          continue;
        if S^ = '.' then
        begin
          p := S;
          SkipToSp(#0, '( ');
          // SetString( Cmd, p, DWORD(s)-DWORD(p) );
          if StrIsL(p, DWORD(S) - DWORD(p), ['.IFDEF', '.ELSE', '.ELSEIF',
            '.ENDIF', '.REPEAT', '.FOR', '.ALIGN', '.BUILDMSG' { , '.LINE' } ,
            '.FILEALIGN', '.IMPORT', '.IMAGEBASE', '.DLLMODE', '.TINYPE',
            '.SUBSYSTEM'], k) then
          begin
            CASE k OF
              0: // .IF
                begin
                  { if Line+1 = 4229 then
                    asm
                    int 3
                    end; }
                  Levels.AddObject('.IFDEF', SkipLevel);
                  if SkipLevel >= 2 then
                    Inc(SkipLevel, 2)
                  else
                  begin
                    n := Expression;
                    if n = 0 then
                      SkipLevel := 2
                    else
                      SkipLevel := 1;
                  end;
                end;
              1: // .ELSE
                begin
                  if (Levels.Count = 0) or
                    not StrInL(Levels.ItemPtrs[Levels.Count - 1],
                    Levels.ItemLen[Levels.Count - 1], ['.IFDEF', '.ELSEIF'])
                  then
{$IFNDEF NOERRORS}
                    Error(Line, '.ELSE w/o .IFDEF')
{$ENDIF}
                  else
                  begin
                    CASE SkipLevel OF
                      0, 1:
                        SkipLevel := 2;
                      2:
                        SkipLevel := 0;
                    else
                      ;
                    END;
                    Levels.Items[Levels.Count - 1] := '.ELSE';
                  end;
                end;
              2: // .ELSEIF
                begin
                  { if Line+1 = 3626 then
                    asm
                    int 3
                    end; }
                  if (Levels.Count = 0) or
                    not StrInL(Levels.ItemPtrs[Levels.Count - 1],
                    Levels.ItemLen[Levels.Count - 1], ['.IFDEF', '.ELSEIF'])
                  then
{$IFNDEF NOERRORS}
                    Error(Line, '.ELSEIF w/o .IFDEF')
{$ENDIF}
                  else
                  begin
                    CASE SkipLevel OF
                      0, 1:
                        begin
                          SkipLevel := 3;
                        end;
                      2:
                        begin
                          n := Expression;
                          if n <> 0 then
                            SkipLevel := 1;
                        end;
                    else
                      ;
                    END;
                    Levels.Items[Levels.Count - 1] := '.ELSEIF';
                  end;
                end;
              3: // .ENDIF
                begin
                  if (Levels.Count = 0) or
                    not StrInL(Levels.ItemPtrs[Levels.Count - 1],
                    Levels.ItemLen[Levels.Count - 1],
                    ['.IFDEF', '.ELSEIF', '.ELSE']) then
{$IFNDEF NOERRORS}
                    Error(Line, '.ENDIF w/o .IFDEF')
{$ENDIF}
                  else
                  begin
                    SkipLevel := Levels.Objects[Levels.Count - 1];
                    Levels.Delete(Levels.Count - 1);
                  end;
                end;
              4: // .REPEAT
                begin
                  n := Expression(nil, TRUE);
                  if n < 0 then
                    n := 1;
                  j := Line + 1;
                  LevelRepFor := 1;
                  { if n <> 0 then
                    Lines.Objects[ Line ] := $20000000 or n; }
                  OldIP := IP;
                  OldCallMacroNum := CallMacroNum;
                  OldCallMacroFromLineNum := CallMacroFromLineNum;
                  if CallMacroFromLineNum = 0 then
                    CallMacroFromLineNum := Line;
                  while Line < ToIdx do
                  begin
                    Inc(Line);
                    Inc(LineHandling);
                    S := Lines.ItemPtrs[Line];
                    SkipSp;
                    if S^ = '.' then
                    begin
                      p := S;
                      SkipToSp(#0, ' ');
                      // SetString( Cmd, p, DWORD(s)-DWORD(p) );
                      // if StrComp_NoCase( PAnsiChar( Cmd ), '.ENDREP' ) = 0 then
                      if StrInL(p, DWORD(S) - DWORD(p), ['.ENDREP']) then
                      begin
                        Dec(LevelRepFor);
                        if LevelRepFor = 0 then
                        begin
                          if SkipLevel <= 1 then
                          begin
                            OldSkipLevel := SkipLevel;
                            for k := 1 to n do
                            begin
                              Inc(MacroNum);
                              CallMacroNum := MacroNum;
                              SkipLevel := 0;
                              CompileStep(Lines, j, Line - 1, Params);
                            end;
                            SkipLevel := OldSkipLevel;
                          end;
                          break;
                        end;
                      end
                      else if StrInL(p, DWORD(S) - DWORD(p), ['.REPEAT']) then
                        Inc(LevelRepFor);
                    end;
                  end;
                  CallMacroNum := OldCallMacroNum;
                  CallMacroFromLineNum := OldCallMacroFromLineNum;
                  Lines.Objects[j - 1] := $20000000 or (IP - OldIP);
                  Lines.Objects[Line] := $10000000 or (IP - OldIP);
                  if n = 0 then
                    for j := j to Line do
                      Lines.Objects[j] := 0;
                end;
              5: // .FOR
                begin
                  ForValues := NewFastStrListEx;
                  TRY
                    SkipSp;
                    if S^ = #0 then
                      break;
                    p := S;
                    SkipToSp(#0, '=');
                    // SetString( AName, p, DWORD(s)-DWORD(p) );
                    StrLCopy(AName, p, Min(DWORD(S) - DWORD(p), 255));
                    StrCopy(ForParam, AName);
                    SkipSp;
                    if S^ <> '=' then
                      Error(Line, 'Waiting =')
                    else
                      Inc(S);
                    SkipSp;
                    while S^ <> #0 do
                    begin
                      p := S;
                      SkipToSp(#0, ',; ');
                      // SetString( AName, p, DWORD(s)-DWORD(p) );
                      StrLCopy(AName, p, Min(DWORD(S) - DWORD(p), 255));
                      ForValues.Add(AName);
                      SkipSp;
                      if S^ in [',', ';'] then
                      begin
                        Inc(S);
                        SkipSp;
                        if S^ = #0 then
                        begin
                          Inc(Line);
                          Inc(LineHandling);
                          S := Lines.ItemPtrs[Line];
                        end;
                      end
                      else
                        break;
                    end;
                    if ForValues.Count = 0 then
                      ForValues.Add('');
                    // if ForValues.Count > 0 then
                    // Lines.Objects[ Line ] := $20000000 or ForValues.Count;
                    // .ENDFOR
                    j := Line + 1;
                    LevelRepFor := 1;
                    OldIP := IP;
                    while Line < ToIdx do
                    begin
                      Inc(Line);
                      Inc(LineHandling);
                      S := Lines.ItemPtrs[Line];
                      SkipSp;
                      if S^ = '.' then
                      begin
                        p := S;
                        SkipToSp(#0, ' ');
                        // SetString( Cmd, p, DWORD(s)-DWORD(p) );
                        // if StrComp_NoCase( Pchar( Cmd ), '.ENDFOR' ) = 0 then
                        if StrInL(p, DWORD(S) - DWORD(p), ['.ENDFOR']) then
                        begin
                          Dec(LevelRepFor);
                          if LevelRepFor = 0 then
                            break;
                        end
                        else if StrInL(p, DWORD(S) - DWORD(p), ['.FOR']) then
                          Inc(LevelRepFor);
                      end;
                    end;
                    if SkipLevel <= 1 then
                    begin
                      OldCallMacroNum := CallMacroNum;
                      OldCallMacroFromLineNum := CallMacroFromLineNum;
                      if CallMacroFromLineNum = 0 then
                        CallMacroFromLineNum := Line;
                      TRY
                        OldSkipLevel := SkipLevel;
                        for k := 0 to ForValues.Count - 1 do
                        begin
                          Inc(MacroNum);
                          CallMacroNum := MacroNum;
                          StrCopy(Temp, ForParam);
                          StrCat(Temp, '=');
                          StrCat(Temp, ForValues.ItemPtrs[k]);
                          Params.Add(Temp);
                          SkipLevel := 0;
                          TRY
                            CompileStep(Lines, j, Line - 1, Params);
                          EXCEPT
                            Error(Line, 'Unknown error');
                          END;
                          Params.Delete(Params.Count - 1);
                        end;
                        SkipLevel := OldSkipLevel;
                      FINALLY
                        CallMacroNum := OldCallMacroNum;
                        CallMacroFromLineNum := OldCallMacroFromLineNum;
                      END;
                      Lines.Objects[j - 1] := $20000000 or (IP - OldIP);
                      Lines.Objects[Line] := $10000000 or (IP - OldIP);
                    end;
                  FINALLY
                    ForValues.Free;
                  END;
                end;
              6: // .ALIGN
                begin
                  k := Expression;
                  CASE k OF
                    2, 4, 8, 16, 32, 64, 128, 256:
                      while IP mod k <> 0 do
                        OutByte(0);
                  else
{$IFNDEF NOERRORS}
                    Error(Line, 'Invalid align ' + Int2Str(k));
{$ENDIF}
                  END;
                end;
              7: // .BUILDMSG
                if SkipLevel <= 1 then
                  if Step = 2 then
                  begin
                    SkipSp;
                    Error(Line, S);
                  end;
              8: // .FILEALIGN
                begin
                  FILEALIGN := Expression;
                end;
              9: // .IMPORT
                begin
                  SkipSp;
                  if TINYPE then
                  begin
                    Error(Line, 'Not Support .IMPORT for TinyPe');
                    Halt;
                  end;
                  AddImportTable(S);
                end;
              10: // .IMAGEBASE
                begin
                  ImagBase := Expression;
                end;
              11: // .DLLMODE
                begin
                  FDll := TRUE;
                end;
              12: // .TINYPE
                begin
                  TINYPE := TRUE;
                end;
              13: // .SUBSYSTEM
                begin
                  FileMode := Expression;
                end;
              { 8: // .LINE
                begin
                n := Expression;
                Line_Diff := n - Line - 1;
                end; }
            END;
          end
{$IFNDEF NOERRORS}
          else
          begin
            // SetString( Cmd, p, DWORD(s)-DWORD(p) );
            StrLCopy(Cmd, p, Min(DWORD(S) - DWORD(p), 255));
            Error(Line, 'Unknown preprocessor ' + Cmd);
          end;
{$ENDIF}
        end
        else if SkipLevel <= 1 then
        begin
          p := S;
          SkipToSp(#0, ' ');
          StrLCopy(Cmd, p, Min(DWORD(S) - DWORD(p), 255));

          { if Hints[ Line ].HintTp = htMacro then
            j := Hints[ Line ].CmdIdx
            else
            if Hints[ Line ].HintTp = htNone then
            begin
            j := MacroList.IndexOf_NoCase( Cmd );
            if not HasAmp then
            begin
            Hints[ Line ].HintTp := htMacro;
            Hints[ Line ].CmdIdx := j;
            end;
            end
            else j := -1; }

          if Hints[Line].HintTp = htCmd then
            j := -1
          else
            j := MacroList.IndexOf_NoCase(Cmd);

          if j >= 0 then
          begin
            if not HasAmp then
              Hints[Line].HintTp := htMacro;

            OldMacroLen := MacroLen;
            MacroLen := 0;
            OldCallMacroNum := CallMacroNum;
            Inc(MacroNum);
            CallMacroNum := MacroNum;
            OldCallMacroFromLineNum := CallMacroFromLineNum;
            if CallMacroFromLineNum = 0 then
              CallMacroFromLineNum := Line;
            wasParamsCount := Params.Count;
            OldIP := IP;
            TRY
              SkipSp;
              while S^ <> #0 do
              begin
                p := S;
                SkipToSp(#0, ' =');
                // SetString( AName, p, DWORD(s)-DWORD(p) );
                StrLCopy(AName, p, Min(DWORD(S) - DWORD(p), 255));
                SkipSp;
                Cmd := '';
                if S^ = '=' then
                begin
                  Inc(S);
                  SkipSp;
                  if S^ <> #0 then
                  begin
                    p := S;
                    SkipToSp(#0, ', ');
                    // SetString( Cmd, p, DWORD(s)-DWORD(p) );
                    StrLCopy(Cmd, p, Min(DWORD(S) - DWORD(p), 255));
                  end;
                end;
                StrCopy(TempNameVal, AName);
                StrCat(TempNameVal, '=');
                StrCat(TempNameVal, Cmd);
                // Params.Add( AName + '=' + Cmd );
                Params.Add(TempNameVal);
                SkipSp;
                if S^ = ',' then
                begin
                  Inc(S);
                  SkipSp;
                  if S^ = #0 then
                  begin
                    Inc(Line);
                    Inc(LineHandling);
                    S := Lines.ItemPtrs[Line];
                  end;
                end
                else
                  break;
              end;
              k := MacroList.Objects[j];
              S := Lines.ItemPtrs[k and $FFFF];
              SkipToSp(#0, ' ');
              SkipSp;
              SkipToSp(#0, ' ');
              SkipSp;
              while S^ <> #0 do
              begin
                p := S;
                SkipToSp(#0, ',= ');
                q := S;
                SkipSp;
                if S^ = '=' then
                begin
                  // SetString( AName, p, DWORD(q)-DWORD(p) );
                  StrLCopy(AName, p, Min(DWORD(q) - DWORD(p), 255));
                  Inc(S);
                  SkipSp;
                  p := S;
                  SkipToSp(#0, ', ');
                  // SetString( Cmd, p, DWORD(s)-DWORD(p) );
                  StrLCopy(Cmd, p, Min(DWORD(S) - DWORD(p), 255));
                  StrCopy(TempNameVal, AName);
                  StrCat(TempNameVal, '=');
                  StrCat(TempNameVal, Cmd);
                  // Params.Add( Name + '=' + Cmd );
                  Params.Add(TempNameVal);
                  SkipSp;
                end;
                if S^ = ',' then
                begin
                  Inc(S);
                  SkipSp;
                end;
              end;

              if CallingMacroFromLine = 0 then CallingMacroFromLine := Line;
              CompileStep(Lines, k and $FFFF + 1, (k shr 16) and $FFFF, Params);
              CallingMacroFromLine := 0;
            FINALLY
              while Params.Count > wasParamsCount do
                Params.Delete(Params.Count - 1);
              CallMacroNum := OldCallMacroNum;
              CallMacroFromLineNum := OldCallMacroFromLineNum;
              Lines.Objects[Line] := IP - OldIP;
              MacroLen := OldMacroLen + IP - OldIP;
            END;
          end
          else if (StrLen(Cmd) = 2) and (Upper[Cmd[0]] = 'D') and
            (Upper[Cmd[1]] in ['B', 'W', 'D', 'Q']) then
          begin
            CASE Upper[Cmd[1]] OF
              'B':
                CmdLen := 1;
              'W':
                CmdLen := 2;
              'D':
                CmdLen := 4;
              'Q':
                CmdLen := 8;
            END;
            if CmdLen <> 0 then;
            SkipSp;
            while S^ <> #0 do
            begin
              SkipSp;
              if (S^ = '''') and (Upper[Cmd[1]] = 'B') then
              begin
                j := StrConst(StrVal);
                for j := 0 to j do
                  OutByte(Byte(StrVal[j]));
              end
              else
              begin
                n := Expression;
                CASE Upper[Cmd[1]] OF
                  'B':
                    OutByte(n);
                  'W':
                    OutWord(n);
                  'D':
                    OutDWord(n);
                  'Q':
                    begin
                      OutDWord(n);
                      OutDWord(n shr 32);
                    end;
                END;
              end;
              SkipSp;
              if S^ = ',' then
              begin
                Inc(S);
                SkipSp;
                while S^ = #0 do
                begin
                  Inc(Line);
                  Inc(LineHandling);
                  S := Lines.ItemPtrs[Line];
                  SkipSp;
                end;
              end
              else
                break;
            end;
          end
          else
          begin
            MachineCommand(Cmd);
          end;
        end;
      end;
{$IFNDEF NOERRORS}
      if Levels.Count > 0 then
        Error(Line, 'Not balanced ' + Levels.Text);
{$ENDIF}
    FINALLY
      Levels.Free;
    END;
  end;

  destructor TXASM.Destroy;
  begin
    Clear;
    ClearHints;
    Src.Free;
    MacroList.Free;
    StructList.Free;
    Labels.Free;
    inherited;
  end;

  procedure TXASM.Error(Line: Integer; const Msg: AnsiString);
  var
    e: String;
  begin
    e := Format('%.05d', [Line + Line_Diff + 1]);
    if CallingMacroFromLine <> 0 then
      e := e + '(' + Int2Str(CallingMacroFromLine + Line_Diff + 1) + ')';
    // if MessageBox( 0, PAnsiChar( e + ': ' + Msg ),nil, MB_OKCANCEL ) = ID_CANCEL then Halt;
    WriteLn('Line ' + e + ': ' + Msg);
    Inc(Errors);
  end;

  function TXASM.FindLabelInSrc(Str: PAnsiChar; L, FromLine: Integer): Integer;
  var
    Line: Integer;
    S: PAnsiChar;
  begin
    for Line := FromLine to Src.Count - 1 do
    begin
      S := Src.ItemPtrs[Line];
      if (S^ > ' ') and (S^ <> '.') then
        if StrLComp_NoCase(Str, S, L) = 0 then
          if (S[L] <= ' ') or (S[L] = ':') then
          begin
            Result := Line;
            Exit;
          end;
    end;
    Result := -1;
  end;

  function TXASM.FindLabelStrL(Str: PAnsiChar; L, FromLine: Integer;
    Lines: PFastStrListEx; var FoundInLine: Integer): Integer;
  var
    j1, j, L1, k: Integer;
    S, n, p: PAnsiChar;
    n1: Integer;
    Temp: array [0 .. 512] of AnsiChar;
    hc: Integer;
  begin
    Result := -1;
    if L = 0 then
      Exit;
    hc := CalcHash(Str, LabHashBits, L);
    if (LabelsHashTable[hc] = nil) and
      not((L = 2) and (Str[0] = '@') and (Str[1] = '@')) and
      not((Str[0] = '@') and (Upper[Str[1]] in ['F', 'B']) and
      ((L = 2) or IsDecimalStrL(@Str[2], L - 2))) then
      Exit;
    if (L = 2) and (Str[0] = '@') and (Str[1] = '@') then
    begin
      StrCopy(Temp, '@@|');
      n1 := CallMacroNum;
      p := Temp + StrLen(Temp);
      while n1 > 0 do
      begin
        p^ := AnsiChar(Ord('0') + n1 mod 10);
        n1 := n1 div 10;
        Inc(p);
      end;
      p^ := #0;
      StrCat(Temp, '.');
      n1 := FromLine;
      p := Temp + StrLen(Temp);
      while n1 > 0 do
      begin
        p^ := AnsiChar(Ord('0') + n1 mod 10);
        n1 := n1 div 10;
        Inc(p);
      end;
      p^ := #0;
      // Temp := '@@|' + Int2Str( CallMacroNum ) + '.' + Int2Str( FromLine );
      Result := FindLabelStrL(Temp, StrLen(Temp), FromLine, Lines, FoundInLine);
      Exit;
    end;
    if (Str[0] = '@') and (Str[1] = '@') then
      for j1 := 0 to LabelsHashTable[hc].Count - 1 do
      // for j := 0 to Labels.Count-1 do
      begin
        j := Integer(LabelsHashTable[hc].Items[j1]);
        S := Labels.ItemPtrs[j];
        if S^ = #1 then
          Inc(S);
        if S^ <> '@' then
          continue;
        Inc(S);
        if S^ <> '@' then
          continue;
        Inc(S);
        n := Str;
        Inc(n);
        Inc(n);
        L1 := L - 2;
        while (S^ <> #0) and (S^ <> '#') and (L1 > 0) do
        begin
          if Upper[S^] <> Upper[n^] then
            break;
          Inc(S);
          Inc(n);
          Dec(L1);
        end;
        if (L1 = 0) and (S^ in [#0, '#']) then
        begin
          FoundInLine := -1;
          Result := j;
          Exit;
        end;
      end
    else if (Str[0] = '@') and (Upper[Str[1]] in ['F', 'B']) and
      ((L = 2) or IsDecimalStrL(@Str[2], L - 2)) then
    begin
      n := Str;
      Inc(n);
      Inc(n);
      k := 0;
      while n^ in ['0' .. '9'] do
      begin
        k := k * 10 + Ord(n^) - Ord('0');
        Inc(n);
      end;
      Dec(k);
      if Upper[Str[1]] = 'F' then
      begin // FromLine+1
        for L1 := FromLine + 1 to Lines.Count - 1 do
        begin
          S := Lines.ItemPtrs[L1];
          if (S^ = '@') and (S[1] = '@') then
          begin
            n := S;
            while S^ > ' ' do
              Inc(S);
            if S[-1] = ':' then
              Dec(S);
            if k <= 0 then
            begin
              // SetString( Temp, n, DWORD(s)-DWORD(n) );
              Result := FindLabelStrL(n, DWORD(S) - DWORD(n), L1, Lines,
                FoundInLine);
              FoundInLine := L1;
              Exit;
            end;
            Dec(k);
          end;
        end;
      end
      else
      begin // FromLine
        for L1 := FromLine downto 0 do
        begin
          S := Lines.ItemPtrs[L1];
          if (S^ = '@') and (S[1] = '@') then
          begin
            n := S;
            while S^ > ' ' do
              Inc(S^);
            if S[-1] = ':' then
              Dec(S);
            if k <= 0 then
            begin
              // SetString( Temp, n, DWORD(s)-DWORD(n) );
              // Result := FindLabel( Temp, L, Lines );
              Result := FindLabelStrL(n, DWORD(S) - DWORD(n), L1, Lines,
                FoundInLine);
              FoundInLine := L1;
              Exit;
            end;
            Dec(k);
          end;
        end;
      end;
    end
    else
      for j1 := 0 to LabelsHashTable[hc].Count - 1 do
      // for j := 0 to Labels.Count-1 do
      begin
        j := Integer(LabelsHashTable[hc].Items[j1]);
        S := Labels.ItemPtrs[j];
        if S^ = #1 then
          Inc(S);
        if (StrLen(S) = DWORD(L)) and (StrLComp_NoCase(S, Str, L) = 0) then
        begin
          Result := j;
          FoundInLine := -1;
          Exit;
        end;;
      end;
  end;

  procedure TXASM.Init;
  begin
    inherited;
    MacroList := NewFastStrListEx;
    StructList := NewFastStrListEx;
    Labels := NewFastStrListEx;
    FSrc := NewFastStrListEx;
  end;

  function TXASM.LabelExists(AName: PAnsiChar; FromLine: Integer;
    Lines: PFastStrListEx): Boolean;
  var
    FoundInLine: Integer;
  begin
    Result := FindLabelStrL(AName, StrLen(AName), FromLine, Lines,
      FoundInLine) >= 0;
  end;

  procedure TXASM.OutByte(B: Byte);
  begin
    if Step = 2 then
    begin
      DstAddr^ := B;
      Inc(DstAddr);
    end;
    Inc(IP);
  end;

  procedure TXASM.OutDWord(D: DWORD);
  begin
    OutWord(D);
    OutWord(D shr 16);
  end;

  procedure TXASM.OutWord(W: Word);
  begin
    OutByte(W);
    OutByte(W shr 8);
  end;

  procedure TXASM.SaveBin2File(const Filename: AnsiString);
  var
    F: PStream;
  begin
    F := NewWriteFileStream(Filename);
    F.Write(Memory^, IP);
    F.Free;
  end;

  function GetAlignedSize(Size: DWORD; Alignment: DWORD): DWORD;
  begin
    if ((Size mod Alignment) = 0) then
      Result := Size
    else
      Result := ((Size div Alignment) + 1) * Alignment;
  end;

  function PtrAdd(Ptr: Pointer; Delta: Integer): Pointer;
  begin
    Result := Pointer(Integer(Ptr) + Delta);
  end;

  procedure FixImportRVA(pImpDir: PImageImportDecriptor; BaseRVA: Cardinal);
  // ½«Name, FirstThunk, pThunkÖµÐÞÕýÎªRVA!
  // BaseRVA: µ¼Èë±íµÄRVA
  // pImpDir: Ö¸Ïòµ¼Èë±íµÄÖ¸Õë
  var
    pThunk: PDWORD;
    BaseAdd: Pointer;
  begin
    BaseAdd := pImpDir;
    while pImpDir^.Name <> 0 do
    begin
      Inc(pImpDir^.Name, BaseRVA);
      pThunk := PtrAdd(BaseAdd, pImpDir^.FirstThunk);
      Inc(pImpDir^.FirstThunk, BaseRVA);
      while pThunk^ <> 0 do
      begin
        Inc(pThunk^, BaseRVA);
        Inc(pThunk);
      end;
      pImpDir := PtrAdd(pImpDir, Sizeof(TImageImportDecriptor));
    end;
  end;

  procedure TXASM.AddImportLabels;
  var
    pThunk: DWORD;
    i, n: Integer;
    pImpDir: PImageImportDecriptor;
  begin
    pImpDir := IMPTABLES;
    n := 0;
    while pImpDir^.Name <> 0 do
    begin
      i := 2;
      pThunk := pImpDir^.FirstThunk;
      while Split(IMPSTRINGS[n], ',', i) <> '' do
      begin
        Labels.AddObject(PAnsiChar(Split(IMPSTRINGS[n], ',', i)),
          pThunk + ImagBase);
        AddLabel2HashTable(PAnsiChar(Split(IMPSTRINGS[n], ',', i)),
          Labels.Count - 1);
        pThunk := pThunk + $4;
        Inc(i);
      end;
      Inc(n);
      pImpDir := PtrAdd(pImpDir, Sizeof(TImageImportDecriptor));
    end;
  end;

  procedure TXASM.BuildHead;
  var
    DosHead: PImageDosHeader;
    NtHead: PImageNtHeaders;
    SecHead: PImageSectionHeader;
    SecName: PAnsiChar;
    // FileTime:TFileTime;
  begin
    PEHEAD := AllocMem(10240);
    ZeroMemory(PEHEAD, 10240);
    HEADSIZE := $4 + IMAGE_SIZEOF_FILE_HEADER;

    DosHead := PEHEAD;
    NtHead := PImageNtHeaders(DWORD(PEHEAD) + $4);

    // DOS Head
    DosHead^.e_magic := IMAGE_DOS_SIGNATURE;
    DosHead^._lfanew := DWORD(PEHEAD) - DWORD(NtHead);

    // NT FileHead
    NtHead^.Signature := IMAGE_NT_SIGNATURE;
    NtHead^.FileHeader.Machine := IMAGE_FILE_MACHINE_I386;
    NtHead^.FileHeader.NumberOfSections := 1;
    // DateTime2FileTime(Now,FileTime);
    NtHead^.FileHeader.TimeDateStamp := 0; // DateTimeToFileDate(Now);
    NtHead^.FileHeader.PointerToSymbolTable := 0;
    NtHead^.FileHeader.NumberOfSymbols := 0;
    NtHead^.FileHeader.SizeOfOptionalHeader := IMAGE_SIZEOF_NT_OPTIONAL_HEADER;
    NtHead^.FileHeader.Characteristics := IMAGE_FILE_32BIT_MACHINE or
      IMAGE_FILE_RELOCS_STRIPPED or IMAGE_FILE_EXECUTABLE_IMAGE;
    if FDll then
      NtHead^.FileHeader.Characteristics :=
        NtHead^.FileHeader.Characteristics or IMAGE_FILE_DLL;

    // Nt OptionalHeader
    NtHead^.OptionalHeader.Magic := IMAGE_NT_OPTIONAL_HDR_MAGIC;
    NtHead^.OptionalHeader.MajorLinkerVersion := $0;
    NtHead^.OptionalHeader.MinorLinkerVersion := $1;
    NtHead^.OptionalHeader.SizeOfCode := 0;
    NtHead^.OptionalHeader.SizeOfInitializedData := 0;
    NtHead^.OptionalHeader.SizeOfUninitializedData := 0;
    NtHead^.OptionalHeader.BaseOfCode := $0; // DosHead._lfanew
    NtHead^.OptionalHeader.BaseOfData := $0; // SIZETODATA UNUSED
    NtHead^.OptionalHeader.ImageBase := ImagBase;
    NtHead^.OptionalHeader.SectionAlignment := $4; // DosHead._lfanew
    NtHead^.OptionalHeader.FileAlignment := FILEALIGN;
    NtHead^.OptionalHeader.MajorOperatingSystemVersion := 4;
    NtHead^.OptionalHeader.MinorOperatingSystemVersion := 0;
    NtHead^.OptionalHeader.MajorImageVersion := 0;
    NtHead^.OptionalHeader.MinorImageVersion := 0;
    NtHead^.OptionalHeader.MajorSubsystemVersion := 4;
    NtHead^.OptionalHeader.MinorSubsystemVersion := 0;
    NtHead^.OptionalHeader.Win32VersionValue := 0;
    NtHead^.OptionalHeader.SizeOfImage := 0;
    NtHead^.OptionalHeader.SizeOfHeaders := 0;
    NtHead^.OptionalHeader.Subsystem := IMAGE_SUBSYSTEM_WINDOWS_GUI;
    NtHead^.OptionalHeader.DllCharacteristics :=
      IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP;
    NtHead^.OptionalHeader.SizeOfStackReserve := $00100000;
    NtHead^.OptionalHeader.SizeOfStackCommit := $00001000;
    NtHead^.OptionalHeader.SizeOfHeapReserve := $00100000;
    NtHead^.OptionalHeader.SizeOfHeapCommit := $00001000;
    NtHead^.OptionalHeader.LoaderFlags := 0;
    NtHead^.OptionalHeader.NumberOfRvaAndSizes := $10;
    // Tiny
    if Tiny then
    begin
      // HeadSize
      NtHead^.OptionalHeader.NumberOfRvaAndSizes := 0;
      NtHead^.FileHeader.SizeOfOptionalHeader := $60;
      HEADSIZE := HEADSIZE + $60;
      SecHead := PImageSectionHeader(DWORD(PEHEAD) + HEADSIZE + 4);
      HEADSIZE := HEADSIZE + IMAGE_SIZEOF_SECTION_HEADER + 4;
      SecName := '.CODE';
      CopyMemory(@SecHead^.Name, SecName, 5);
      SecHead^.Misc.VirtualSize := IP;
      SecHead^.VirtualAddress := GetAlignedSize(HEADSIZE, 4);
      SecHead^.SizeOfRawData := GetAlignedSize(IP, FILEALIGN);
      SecHead^.PointerToRawData := HEADSIZE;
      SecHead^.Characteristics := IMAGE_SCN_CNT_CODE or IMAGE_SCN_MEM_EXECUTE or
        IMAGE_SCN_MEM_READ or IMAGE_SCN_MEM_WRITE;
      NtHead^.OptionalHeader.AddressOfEntryPoint := AddrOfEP + HEADSIZE;
      // Set EP
    end
    else
    begin
      // HeadSize
      HEADSIZE := HEADSIZE + IMAGE_SIZEOF_NT_OPTIONAL_HEADER;
      if FTmport then
        HEADSIZE := HEADSIZE + IMAGE_SIZEOF_SECTION_HEADER * 2 + 4
      else
        HEADSIZE := HEADSIZE + IMAGE_SIZEOF_SECTION_HEADER + 4;

      // SectionHeader
      SecHead := PImageSectionHeader(DWORD(PEHEAD) + $FC);
      SecName := '.CODE';
      CopyMemory(@SecHead^.Name, SecName, 5);
      SecHead^.Misc.VirtualSize := IP;
      SecHead^.VirtualAddress := GetAlignedSize(HEADSIZE, 4);
      SecHead^.SizeOfRawData := GetAlignedSize(IP, FILEALIGN);
      SecHead^.PointerToRawData := HEADSIZE;
      SecHead^.Characteristics := IMAGE_SCN_CNT_CODE or IMAGE_SCN_MEM_EXECUTE or
        IMAGE_SCN_MEM_READ or IMAGE_SCN_MEM_WRITE;
      NtHead^.OptionalHeader.AddressOfEntryPoint := AddrOfEP + HEADSIZE;
      // Set EP
      BaseAddr := Pointer(ImagBase + HEADSIZE); // Set Golbal CODE BaseAddr
      // IMPORT TABLE
      if FTmport then
      begin
        SecHead := PImageSectionHeader(DWORD(SecHead) +
          IMAGE_SIZEOF_SECTION_HEADER);
        SecName := '.IMPORT';
        CopyMemory(@SecHead^.Name, SecName, 7);
        SecHead^.Misc.VirtualSize := IMPSIZE;
        SecHead^.VirtualAddress := GetAlignedSize(HEADSIZE, 4);
        SecHead^.SizeOfRawData := GetAlignedSize(IMPSIZE, FILEALIGN);
        SecHead^.PointerToRawData := HEADSIZE;
        SecHead^.Characteristics := IMAGE_SCN_CNT_CODE or
          IMAGE_SCN_MEM_EXECUTE or IMAGE_SCN_MEM_READ or IMAGE_SCN_MEM_WRITE;
        // FIX Import Table RVA
        FixImportRVA(IMPTABLES, SecHead^.VirtualAddress);
        NtHead^.OptionalHeader.DataDirectory[1].VirtualAddress :=
          SecHead^.VirtualAddress;
        NtHead^.OptionalHeader.DataDirectory[1].Size := IMPSIZE;
        // FIX CODE Section
        SecHead := PImageSectionHeader(DWORD(PEHEAD) + $FC);
        SecHead^.VirtualAddress := GetAlignedSize(HEADSIZE + IMPSIZE, 4);
        SecHead^.SizeOfRawData := GetAlignedSize(IP, FILEALIGN);
        SecHead^.PointerToRawData := HEADSIZE + GetAlignedSize(IMPSIZE,
          FILEALIGN);
        // FIX NTHEAD
        NtHead^.FileHeader.NumberOfSections := 2;
        NtHead^.OptionalHeader.AddressOfEntryPoint := AddrOfEP + HEADSIZE +
          GetAlignedSize(IMPSIZE, 4); // Set EP

        BaseAddr := Pointer(ImagBase + SecHead^.VirtualAddress);
        // Set Golbal CODE BaseAddr
      end;
      //
    end;

    // Setting Head
    NtHead^.OptionalHeader.SizeOfCode := GetAlignedSize(IP, FILEALIGN);
    NtHead^.OptionalHeader.SizeOfHeaders := GetAlignedSize(HEADSIZE, FILEALIGN);
    NtHead^.OptionalHeader.Subsystem := FileMode;
    NtHead^.OptionalHeader.BaseOfCode := HEADSIZE;
    NtHead^.OptionalHeader.BaseOfData :=
      GetAlignedSize(DWORD(IP) + HEADSIZE + IMPSIZE, 4);
    NtHead^.OptionalHeader.SizeOfImage :=
      GetAlignedSize(DWORD(IP) + HEADSIZE + IMPSIZE, 4);
  end;

  procedure TXASM.AddImportTable(Imp: AnsiString);
  begin
    if FTmport = FALSE then
    begin
      FTmport := TRUE;
      IMPSIZE := 0;
      IMPNUM := 1;
      IMPTABLES := AllocMem(65535);
      SetLength(IMPSTRINGS, IMPNUM);
      IMPSTRINGS[IMPNUM - 1] := Imp;
    end
    else
    begin
      IMPNUM := IMPNUM + 1;
      SetLength(IMPSTRINGS, IMPNUM);
      IMPSTRINGS[IMPNUM - 1] := Imp;
    end;
  end;

  procedure TXASM.BuildImportTable;
  var
    PEImpDir: PImageImportDecriptor;
    pFuncName: PImageImportByName;
    DllName, pDllName: PAnsiChar;
    lDllName, lFuncName, FuncCount: Cardinal;
    pThunk: PDWORD;
    n, i, L, L2: Cardinal;
    FuncName: Array of PAnsiChar;
  begin
    IMPSIZE := Sizeof(TImageImportDecriptor) * (IMPNUM + 1);
    for n := 0 to High(IMPSTRINGS) do
    begin
      DllName := PAnsiChar(Split(IMPSTRINGS[n], ',', 1));
      i := 1;
      while Split(IMPSTRINGS[n], ',', i + 1) <> '' do
      begin
        SetLength(FuncName, i);
        FuncName[i - 1] := PAnsiChar(Split(IMPSTRINGS[n], ',', i + 1));
        i := i + 1;
      end;
      lDllName := Length(DllName) + 1;
      lFuncName := 0;
      FuncCount := High(FuncName) - Low(FuncName) + 1;
      for i := Low(FuncName) to High(FuncName) do
        Inc(lFuncName, Length(FuncName[i]) + 1);
      // Ìî³äµ¼Èë±í
      PEImpDir := Pointer(DWORD(IMPTABLES) + Sizeof(TImageImportDecriptor) * n);
      PEImpDir^.Union.OriginalFirstThunk := 0;
      PEImpDir^.TimeDateStamp := $0;
      PEImpDir^.ForwarderChain := $0;
      // Name, FirstThunkµÄÖµÊÇOffset,²»ÊÇRVA!
      PEImpDir^.Name := IMPSIZE + 4 * (FuncCount + 1);
      PEImpDir^.FirstThunk := IMPSIZE;
      pDllName := PtrAdd(IMPTABLES, PEImpDir^.Name);
      CopyMemory(pDllName, DllName, lDllName);
      pThunk := PtrAdd(IMPTABLES, PEImpDir^.FirstThunk);
      pFuncName := PtrAdd(pDllName, lDllName);
      L := IMPSIZE + 4 * (FuncCount + 1) + lDllName;
      for i := Low(FuncName) to High(FuncName) do
      begin
        pThunk^ := L;
        Inc(pThunk); // pThunkµÄÖµÊÇOffset,²»ÊÇRVA!
        pFuncName^.Hint := 0;
        CopyMemory(@pFuncName^.Name[0], FuncName[i], Length(FuncName[i]));
        L2 := Length(FuncName[i]) + Sizeof(TImageImportByName) - 1;
        pFuncName := PtrAdd(pFuncName, L2);
        Inc(L, L2);
      end;
      // ¼ÆËãµ¼Èë±í´óÐ¡
      IMPSIZE := IMPSIZE + lDllName + lFuncName + 2 * FuncCount + 4 *
        (FuncCount + 1);
    end;
  end;

  procedure TXASM.SaveExe2File(const Filename: AnsiString);
  var
    F: PStream;
  begin
    // Write To File
    F := NewWriteFileStream(Filename);
    F.Write(PEHEAD^, HEADSIZE);
    FreeMem(PEHEAD);
    if FTmport then
    begin
      F.Write(IMPTABLES^, GetAlignedSize(IMPSIZE, FILEALIGN));
      FreeMem(IMPTABLES);
    end;
    F.Write(Memory^, GetAlignedSize(IP, FILEALIGN));
    F.Free;
  end;

{ procedure TXASM.SetSrc(const NewSrcText: String; DoClearHints: Boolean);
  begin
  Src.Text:=NewSrcText;
  if DoClearHints then ClearHints;
  end;

  function TXASM.SrcText: String;
  begin
  Result:=Src.Text;
  end; }

initialization

InitUpper;
InitInstrTable;

finalization

FinalTables;

end.

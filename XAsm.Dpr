program XAsm;

{$APPTYPE CONSOLE}

uses Windows, XAsmUnit, Kol;

var
  Compler: TXASM;
  BinMode, CuiMode, TinyPe, DllMode: Boolean;
  InputFileName, OutputFileName: AnsiString;
  ReqImageBase: Integer;

function HexToInt(AHex: AnsiString): Cardinal;
var
  LI, LO: Byte;
  LM: Cardinal;
begin
  LM := 1;
  Result := 0;
  AHex := UpperCase(AHex);
  if (Length(AHex) > 2) and (AHex[2] = 'X') then
    AHex := Copy(AHex, 3, MaxInt);

  for LI := Length(AHex) downto 1 do
  begin
    if not((AHex[LI] in ['0' .. '9']) or (AHex[LI] in ['A' .. 'F'])) then
    begin
      Result := 0;
      Exit;
    end;
    if AHex[LI] in ['0' .. '9'] then
      LO := 48
    else
      LO := 55;
    LO := Ord(AHex[LI]) - LO;
    Result := Result + LO * LM;
    LM := LM shl 4;
  end;
end;

procedure About;
begin
  WriteLn;
  WriteLn('xAsm v0.03 - unknowall, sgfree@hotmail.com');
  WriteLn;
  WriteLn('Source: http://github.com/unknowall/xAsm');
  WriteLn;
end;

procedure Usage;
var
  LStr: AnsiString;
begin
  LStr := ExtractFileName(ParamStr(0));
  WriteLn('Usage: ', LStr,
    ' [-h] [-c] [-n] [-s] [-d] [-b:ImageBase] InputFile [-o OutputFile]');
  WriteLn('  -h             Show This');
  WriteLn('  -c             Compiler BIN Mode(.com)');
  WriteLn('  -n             Set SubSystem to CUI');
  WriteLn('  -d             Compiler DLL File');
  WriteLn('  -s             Tiny Pe File');
  WriteLn('  -o             Output File');
  WriteLn('  -b:ImageBase   image base in hexadecimal string');
  WriteLn;
  WriteLn('Examples:');
  WriteLn;
  WriteLn('1) ', LStr, ' Test.asm');
  WriteLn;
  WriteLn('2) ', LStr, ' -n Test.asm -o Test.exe');
  WriteLn;
  WriteLn('3) ', LStr, ' -b:1F000000 -n Test.asm -o Test.exe');
  WriteLn;
  WriteLn('4) ', LStr, ' -s Tiny.asm -o Tiny.exe');
  WriteLn;
  ExitProcess(0);
end;

function ProcessCmdLine: Boolean;
var
  LI: Integer;
  LPar, LUpArg: ansistring;
begin
  Result := False;
  ReqImageBase := $00400000;
  InputFileName := '';
  OutputFileName := '';

  if (ParamCount < 1) or (ParamCount > 5) then
    Exit;
  LI := 1;
  while LI <= ParamCount do
  begin
    LPar := ParamStr(LI);
    //LUpArg := UpperCase(LPar);
    LUpArg := LPar;
    Inc(LI);
    //WriteLn('Param: '+LUpArg);
    if LUpArg[1] = '-' then
    begin
      if Length(LUpArg) = 1 then
        Continue;
      case LUpArg[2] of
        'c','C':
          BinMode := True;
        'n','N':
          CuiMode := True;
        's','S':
          TinyPe := True;
        'd','D':
          DllMode := True;
        'b','B':
          begin
            if Length(LUpArg) < 4 then Continue;
            if LUpArg[3] <> ':' then Continue;
            if LUpArg[2] = 'B' then
            begin
              ReqImageBase := HexToInt(Copy(LUpArg, 4, MaxInt));
              if ReqImageBase = 0 then Continue;
            end
          end;
        'o', 'O':
          begin
            if Length(ParamStr(LI)) < 4 then Continue;
            OutputFileName := ParamStr(LI);
            Inc(LI);
          end;
      else
        Continue;
      end;
    end
    else
    begin
      InputFileName := LPar;
      Continue;
    end;
  end;

  if Length(OutputFileName) = 0 then
    if BinMode then
      OutputFileName := Copy(InputFileName, 1, Pos('.', InputFileName)) + 'com'
    else
      OutputFileName := Copy(InputFileName, 1, Pos('.', InputFileName)) + 'exe';
  //Result := (LI - 1 = ParamCount) and (Length(InputFileName) > 0);
  Result := (Length(OutputFileName) > 0) and (Length(InputFileName) > 0);
end;

begin

  About;
  if not ProcessCmdLine then Usage;

  // InputFileName:='test.asm';
  // OutputFileName:='test.exe';
  // ReqImageBase:=$00400000;

  WriteLn('-----------------------------------------------------------');
  WriteLn;
  WriteLn(InputFileName+' >> '+OutputFileName);
  WriteLn;
  var TimeLess: Integer;
  TimeLess := GetTickCount;

  Compler.Create;
  Compler.ImageBase := ReqImageBase;
  if CuiMode then
    Compler.PeMode := IMAGE_SUBSYSTEM_WINDOWS_CUI
  else
    Compler.PeMode := IMAGE_SUBSYSTEM_WINDOWS_GUI;
  Compler.TinyPe := TinyPe;
  Compler.CompileFromFile(InputFileName);

  if Compler.Size > 0 then
  begin
    if BinMode then
      Compler.SaveBin2File(OutputFileName)
    else
      Compler.SaveExe2File(OutputFileName);
  end;

  WriteLn(Compler.LineCount, ' Total Lines, ', Compler.Size, ' Bytes Code, ', Compler.DatSize, ' Bytes Data, ', Compler.Errs, ' Errors.');
  WriteLn;
  WriteLn('Compile time: ',GetTickCount - TimeLess, ' ms');
  WriteLn;
end.

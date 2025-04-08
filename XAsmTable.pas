unit XAsmTable;

interface

type
  TIdxBase = ( ibNone, ibEAX, ibEDX, ibECX, ibEBX, ibEBP, ibESP, ibESI, ibEDI );
  TScale   = ( mult1, mult2, mult4, mult8 );

  POperand = ^TOperand;
  TOperand = packed record
    AsStr: array[ 0..9 ] of AnsiChar;
    OpdType: Char;
    OpdSize: Byte;
    RegNum: Byte;
    Segment: array[ 0..1 ] of AnsiChar;
    IsOffset: Boolean;
    IdxBase1: TIdxBase;
    IdxBase2: TIdxBase;
    IdxMult2: TScale; // 1, 2, 4 or 8
    Offset: Integer;
    //JmpOffset: Integer;
  end;

  THintType = ( htNone, htCmd, htMacro );

  TListHint = packed Record
    HintTp: THintType;
    HintOpds: Byte;
    CmdIdx: Integer;
    Operands: array[ 1..3 ] of TOperand;
    OpdLens: array[ 1..3 ] of Integer;
  end;

const
 InstrDefs: AnsiString =
 'AAA -> 37;' +
 'AAD b -> D5 b;' +
 'AAD -> D5 0A;' +
 'AAM b -> D4 b;' +
 'AAM -> D4 0A;' +
 'AAS -> 3F;' +
 'DAA -> 27;' +
 'DAS -> 2F;' +

 'ADD AL,b -> 04 b;' +
 'ADD AX,w -> !66 05 w w>8;' +
 'ADD r4,b -> !83 C0+r b;' +
 'ADD EAX,d -> 05 d d>8 d>10 d>18;' +
 'ADD r1,b -> !80 C0+r b;' +
 'ADD r1,w -> !80 C0+r b;' +
 'ADD r1,d -> !80 C0+r b;' +
 'ADD r2,w -> !66 !81 C0+r w w>8;' +
 'ADD r2,d -> !66 !81 C0+r w w>8;' +
 'ADD r4,d -> !81 C0+r d d>8 d>10 d>18;' +
 'ADD r4,w -> !66 !83 C0+r w w>8;' +
 'ADD m1,b -> !80 ? m m>8 m>10 m>18 b;' +
 'ADD m1,w -> !80 ? m m>8 m>10 m>18 b;' +
 'ADD m1,d -> !80 ? m m>8 m>10 m>18 b;' +
 'ADD m2,b -> !66 !83 ? m m>8 m>10 m>18 b;' +
 'ADD m2,w -> !66 !81 ? m m>8 m>10 m>18 w w>8;' +
 'ADD m2,d -> !66 !81 ? m m>8 m>10 m>18 w w>8;' +
 'ADD m4,b -> !83 ? m m>8 m>10 m>18 b;' +
 'ADD m4,d -> !81 ? m m>8 m>10 m>18 d d>8 d>10 d>18;' +
 //'ADD m4,w -> !81 ? m m>8 m>10 m>18 d d>8 d>10 d>18;' +
 'ADD r1,R1 -> 00 C0+r+R<3;' +
 'ADD r2,R2 -> !66 01 C0+r+R<3;' +
 'ADD r4,R4 -> 01 C0+r+R<3;' +
 'ADD r1,m1 -> 02 ?+r<3 m m>8 m>10 m>18;' +
 'ADD r2,m2 -> !66 03 ?+r<3 m m>8 m>10 m>18;' +
 'ADD r4,m4 -> 03 ?+r<3 m m>8 m>10 m>18;' +
 'ADD m1,r1 -> 00 ?+r<3 m m>8 m>10 m>18;' +
 'ADD m2,r2 -> !66 01 ?+r<3 m m>8 m>10 m>18;' +
 'ADD m4,r4 -> 01 ?+r<3 m m>8 m>10 m>18;' +

 'OR *,* <- ADD 08;' +
 'ADC *,* <- ADD 10;' +
 'SBB *,* <- ADD 18;' +
 'AND *,* <- ADD 20;' +
 'SUB *,* <- ADD 28;' +

 'XOR r1,R1 -> 32 C0+r<3+R;' +
 'XOR r2,R2 -> !66 31 C0+r+R<3;' +
 'XOR r4,R4 -> 31 C0+r+R<3;' +

 'XOR *,* <- ADD 30;' +
 'CMP *,* <- ADD 38;' +

 'ANDPD x10,X10 -> !66 !0F 54 C0+x<3+X;' +
 'ANDPD x10,m10 -> !66 !0F 54 ?+x<3 m m>8 m>10 m>18;' +
 'ANDPS x10,X10 -> !0F 54 C0+x<3+X;' +
 'ANDPS x10,m10 -> !0F 54 ?+x<3 m m>8 m>10 m>18;' +

 'ANDNPD *,* <- ANDPD 55-54;' +
 'ANDNPS *,* <- ANDPS 55-54;' +

 'ADDPD *,* <- ANDPD 58-54;' +
 'ADDPS *,* <- ANDPS 58-54;' +
 'ADDSD x10,X10 -> !F2 !0F 58 C0+x<3+X;' +
 'ADDSD x10,m10 -> !F2 !0F 58 ?+x<3 m m>8 m>10 m>18;' +
 'ADDSS x10,X10 -> !F3 !0F 58 C0+x<3+X;' +
 'ADDSS x10,m4 -> !F3 !0F 58 ?+x<3 m m>8 m>10 m>18;' +

 'ORPD *,* <- ANDPD 56-54;' +
 'ORPS *,* <- ANDPS 56-54;' +

 'XORPD *,* <- ANDPD 57-54;' +
 'XORPS *,* <- ANDPS 57-54;' +

 'SQRTPD *,* <- ANDPD 51-54;' +
 'SQRTPS *,* <- ANDPS 51-54;' +
 'SQRTSD *,* <- ADDSD 51-58;' +
 'SQRTSS *,* <- ADDSS 51-58;' +

 'MULPD *,* <- ANDPD 59-54;' +
 'MULPS *,* <- ANDPS 59-54;' +
 'MULSD *,* <- ADDSD 59-58;' +
 'MULSS *,* <- ADDSS 59-58;' +

 'MULPD *,* <- ANDPD 5E-54;' +
 'MULPS *,* <- ANDPS 5E-54;' +
 'MULSD *,* <- ADDSD 5E-58;' +
 'MULSS *,* <- ADDSS 5E-58;' +

 'SUBPD *,* <- ANDPD 5C-54;' +
 'SUBPS *,* <- ANDPS 5C-54;' +
 'SUBSD *,* <- ADDSD 5C-58;' +
 'SUBSS *,* <- ADDSS 5C-58;' +

 'MINPD *,* <- ANDPD 5D-54;' +
 'MINPS *,* <- ANDPS 5D-54;' +
 'MINSD *,* <- ADDSD 5D-58;' +
 'MINSS *,* <- ADDSS 5D-58;' +

 'MAXPD *,* <- ANDPD 5F-54;' +
 'MAXPS *,* <- ANDPS 5F-54;' +
 'MAXSD *,* <- ADDSD 5F-58;' +
 'MAXSS *,* <- ADDSS 5F-58;' +

 'CMPPD x10,X10,b -> !66 !0F C2 C0+x<3+X b;' +
 'CMPPD x10,m10,b -> !66 !0F C2 ?+x<3 m m>8 m>10 m>18 b;' +
 'CMPPS x10,X10,b -> !0F C2 C0+x<3+X b;' +
 'CMPPS x10,m10,b -> !0F C2 ?+x<3 m m>8 m>10 m>18 b;' +

 'COMISD *,* <- ANDPD 2F-54;' +
 'UCOMISD *,* <- ANDPD 2E-54;' +

 'COMISS x10,X10 -> !0F 2F C0+x<3+X;' +
 'COMISS x10,m4 -> !0F 2F ?+x<3 m m>8 m>10 m>18;' +

 'UCOMISS *,* <- ANDPS 2E-54;' +

 'CVTDQ2PD x10,X10 -> !F3 !0F E6 C0+x<3+X;' +
 'CVTDQ2PD x10,m8 -> !F3 !0F E6 ?+x<3 m m>8 m>10 m>18;' +

 'CVTDQ2PS *,* <- ANDPS 5B-54;' +
 'CVTPD2DQ *,* <- ADDSD E6-58;' +

 'CVTPD2PI x8,X10 -> !66 !0F 2D C0+x<3+X;' +
 'CVTPD2PI x8,m10 -> !66 !0F 2D ?+x<3 m m>8 m>10 m>18;' +

 'CVTPD2PS *,* <- ANDPD 5A-54;' +

 'CVTPI2PD x10,X8 -> !66 !0F 2A C0+x<3+X;' +
 'CVTPI2PD x10,m8 -> !66 !0F 2A ?+x<3 m m>8 m>10 m>18;' +
 'CVTPI2PS x10,X8 -> !0F 2A C0+x<3+X;' +
 'CVTPI2PS x10,m8 -> !0F 2A ?+x<3 m m>8 m>10 m>18;' +

 'CVTPS2DQ *,* <- ANDPD 5B-54;' +
 'CVTPS2PD *,* <- ANDPS 5A-54;' +

 'CVTPS2PI x8,X10 -> !0F 2D C0+x<3+X;' +
 'CVTPS2PI x8,m8 -> !0F 2D ?+x<3 m m>8 m>10 m>18;' +

 'CVTSD2SI r4,x10 -> !F2 !0F 2D C0+r<3+x;' +
 'CVTSD2SI r4,m8 -> !F2 !0F 2D ?+r<3 m m>8 m>10 m>18;' +

 'CVTSI2SD x10,r4 -> !F2 !0F 2A C0+x<3+r;' +
 'CVTSI2SD x10,m4 -> !F2 !0F 2A ?+x<3 m m>8 m>10 m>18;' +

 'CVTSI2SS x10,r4 -> !F3 !0F 2A C0+x<3+r;' +
 'CVTSI2SS x10,m4 -> !F3 !0F 2A ?+x<3 m m>8 m>10 m>18;' +

 'CVTSS2SD *,* <- ADDSS 5A-58;' +

 'CVTTPD2PI x8,X10 -> !66 !0F 2C C0+x<3+X;' +
 'CVTTPD2PI x8,m10 -> !66 !0F 2C ?+x<3 m m>8 m>10 m>18;' +

 'CVTTPD2DQ *,* <- ANDPD E6-54;' +

 'CVTTPS2DQ x10,X10 -> !F3 !0F 5B C0+x<3+X;' +
 'CVTTPS2DQ x10,m10 -> !F3 !0F 5B ?+x<3 m m>8 m>10 m>18;' +

 'CVTTPS2PI x8,X10 -> !0F 2C C0+x<3+X;' +
 'CVTTPS2PI x8,m8 -> !0F 2C ?+x<3 m m>8 m>10 m>18;' +

 'CVTTSD2SI r4,x10 -> !F2 !0F 2C C0+r<3+x;' +
 'CVTTSD2SI r4,m8 -> !F2 !0F 2C ?+r<3 m m>8 m>10 m>18;' +

 'CVTTSS2SI r4,x10 -> !F3 !0F 2C C0+r<3+x;' +
 'CVTTSS2SI r4,m4 -> !F3 !0F 2C ?+r<3 m m>8 m>10 m>18;' +

 'MASKMOVDQU *,* <- ANDPD F7-54;' +
 'MASKMOVQ x8,X8 -> !0F F7 C0+x<3+X;' +

 'MOVAPD *,* <- ANDPD 28-54;' +
 'MOVAPD m10,x10 -> !66 !0F 28 ?+x<3 m m>8 m>10 m>18;' +
 'MOVAPS *,* <- ANDPS 28-54;' +
 'MOVAPS m10,x10 -> !66 !0F 29 ?+x<3 m m>8 m>10 m>18;' +
 'MOVD x8,r4 -> 0F 6E C0+x<3+r;' +
 'MOVD x8,m4 -> 0F 6E ?+x<3 m m>8 m>10 m>18;' +
 'MOVD r4,x8 -> 0F 7E C0+r+x<3;' +
 'MOVD m4,x8 -> 0F 7E ?+x<3 m m>8 m>10 m>18;' +
 'MOVD x10,r4 -> !66 0F 6E C0+x<3+r;' +
 'MOVD x10,m4 -> !66 0F 6E ?+x<3 m m>8 m>10 m>18;' +
 'MOVD r4,x10 -> !66 0F 7E C0+r+x<3;' +
 'MOVD m4,x10 -> !66 0F 7E ?+x<3 m m>8 m>10 m>18;' +
 'MOVDQA x10,X10 -> !66 0F 6F C0+x<3+X;' +
 'MOVDQA x10,m10 -> !66 0F 6F ?+x<3 m m>8 m>10 m>18;' +
 'MOVDQA m10,x10 -> !66 0F 7F ?+x<3 m m>8 m>10 m>18;' +
 'MOVDQU x10,X10 -> F3 0F 6F C0+x<3+X;' +
 'MOVDQU x10,m10 -> F3 0F 6F ?+x<3 m m>8 m>10 m>18;' +
 'MOVDQU m10,x10 -> F3 0F 7F ?+x<3 m m>8 m>10 m>18;' +
 'MOVDQ2Q x8,X10 -> F2 0F D6 C0+x<3+X;' +
 'MOVHLPS x10,X10 -> 0F 12 C0+x<3+X;' +
 'MOVHPD x10,m8 -> !66 0F 16 ?+x<3 m m>8 m>10 m>18;' +
 'MOVHPD m8,x10 -> !66 0F 17 ?+x<3 m m>8 m>10 m>18;' +
 'MOVHPS x10,m8 -> 0F 16 ?+x<3 m m>8 m>10 m>18;' +
 'MOVHPS m8,x10 -> 0F 17 ?+x<3 m m>8 m>10 m>18;' +
 'MOVLHPS x10,X10 -> 0F 16 C0+x<3+X;' +
 'MOVLPD x10,m8 -> !66 0F 12 ?+x<3 m m>8 m>10 m>18;' +
 'MOVLPD m8,x10 -> !66 0F 13 ?+x<3 m m>8 m>10 m>18;' +
 'MOVLPS x10,m8 -> 0F 12 ?+x<3 m m>8 m>10 m>18;' +
 'MOVLPS m8,x10 -> 0F 13 ?+x<3 m m>8 m>10 m>18;' +
 'MOVMSKPD r4,x10 -> !66 0F 50 C0+r<3+x;' +
 'MOVMSKPS r4,x10 -> 0F 50 C0+r<3+x;' +
 'MOVNTDQ m10,x10 -> !66 0F E7 ?+x<3 m m>8 m>10 m>18;' +
 'MOVNTI m4,r4 -> 0F C3 ?+r<3 m m>8 m>10 m>18;' +
 'MOVNTPD m10,x10 -> !66 0F 2B ?+x<3 m m>8 m>10 m>18;' +
 'MOVNTPS m10,x10 -> 0F 2B ?+x<3 m m>8 m>10 m>18;' +
 'MOVNTQ m8,x8 -> 0F E7 ?+x<3 m m>8 m>10 m>18;' +
 'MOVQ x8,X8 -> 0F 6F C0+x<3+X;' +
 'MOVQ x8,m8 -> 0F 6F ?+x<3 m m>8 m>10 m>18;' +
 'MOVQ m8,x8 -> 0F 7F ?+x<3 m m>8 m>10 m>18;' +
 'MOVQ x10,X10 -> F3 0F 7E C0+x<3+X;' +
 'MOVQ x10,m8 -> F3 0F 7E ?+x<3 m m>8 m>10 m>18;' +
 'MOVQ m8,x10 -> !66 0F D6 ?+x<3 m m>8 m>10 m>18;' +
 'MOVQ2DQ x10,X8 -> F3 0F D6 C0+x<3+X;' +
 'MOVSD x10,X10 -> F2 0F 10 C0+x<3+X;' +
 'MOVSD x10,m8 -> F2 0F 10 ?+x<3 m m>8 m>10 m>18;' +
 'MOVSD m8,x10 -> F2 0F 11 ?+x<3 m m>8 m>10 m>18;' +
 'MOVSS x10,X10 -> F3 0F 10 C0+x<3+X;' +
 'MOVSS x10,m4 -> F3 0F 10 ?+x<3 m m>8 m>10 m>18;' +
 'MOVSS m4,x10 -> F3 0F 11 ?+x<3 m m>8 m>10 m>18;' +
 'MOVUPD x10,X10 -> !66 0F 10 C0+x<3+X;' +
 'MOVUPD x10,m10 -> !66 0F 10 ?+x<3 m m>8 m>10 m>18;' +
 'MOVUPD m10,x10 -> !66 0F 11 ?+x<3 m m>8 m>10 m>18;' +
 'MOVUPS x10,X10 -> 0F 10 C0+x<3+X;' +
 'MOVUPS x10,m10 -> 0F 10 ?+x<3 m m>8 m>10 m>18;' +
 'MOVUPS m10,x10 -> 0F 11 ?+x<3 m m>8 m>10 m>18;' +

 'PACKSSWB x8,X8 -> 0F 63 C0+x<3+X;' +
 'PACKSSWB x8,m8 -> 0F 63 ?+x<3 m m>8 m>10 m>18;' +
 'PACKSSWB x10,X10 -> !66 0F 63 C0+x<3+X;' +
 'PACKSSWB x10,m10 -> !66 0F 63 ?+x<3 m m>8 m>10 m>18;' +

 'PACKSSDW x8,X8 -> 0F 6B C0+x<3+X;' +
 'PACKSSDW x8,m8 -> 0F 6B ?+x<3 m m>8 m>10 m>18;' +
 'PACKSSDW x10,X10 -> !66 0F 6B C0+x<3+X;' +
 'PACKSSDW x10,m10 -> !66 0F 6B ?+x<3 m m>8 m>10 m>18;' +

 'PACKUSWB x8,X8 -> 0F 67 C0+x<3+X;' +
 'PACKUSWB x8,m8 -> 0F 67 ?+x<3 m m>8 m>10 m>18;' +
 'PACKUSWB x10,X10 -> !66 0F 67 C0+x<3+X;' +
 'PACKUSWB x10,m10 -> !66 0F 67 ?+x<3 m m>8 m>10 m>18;' +

 'PUNPCKHBW ?8,?8 <- PACKSSWB 00 68-63;' +

 'PUNPCKHWD *,* <- PACKSSWB 00 69-63;' +
 'PUNPCKHDQ *,* <- PACKSSWB 00 6A-63;' +
 'PUNPCKLBW *,* <- PACKSSWB 00 60-63;' +
 'PUNPCKLWD *,* <- PACKSSWB 00 61-63;' +
 'PUNPCKLDQ *,* <- PACKSSWB 00 62-63;' +

 'UNPCKHPD x10,X10 -> !66 0F 15 C0+x<3+X;' +
 'UNPCKHPD x10,m10 -> !66 0F 15 ?+x<3 m m>8 m>10 m>18;' +
 'UNPCKLPD *,* <- UNPCKHPD 00 14-15;' +
 'UNPCKHPS x10,X10 -> 0F 15 C0+x<3+X;' +
 'UNPCKHPS x10,m10 -> 0F 15 ?+x<3 m m>8 m>10 m>18;' +
 'UNPCKLPS *,* <- UNPCKHPS 00 14-15;' +

 'PADDB x8,X8 -> 0F FC C0+x<3+X;' +
 'PADDB x8,m8 -> 0F FC ?+x<3 m m>8 m>10 m>18;' +
 'PADDB x10,X10 -> !66 0F FC C0+x<3+X;' +
 'PADDB x10,m10 -> !66 0F FC ?+x<3 m m>8 m>10 m>18;' +

 'PADDW *,* <- PADDB 00 01;' +
 'PADDD *,* <- PADDB 00 02;' +
 'PADDQ *,* <- PADDB 00 D4-FC;' +
 'PADDSB *,* <- PADDB 00 EC-FC;' +
 'PADDSW *,* <- PADDB 00 ED-FC;' +
 'PADDUSB *,* <- PADDB 00 DC-FC;' +
 'PADDUSW *,* <- PADDB 00 DD-FC;' +

 'PSUBB *,* <- PADDB 00 F8-FC;' +
 'PSUBW *,* <- PADDB 00 F9-FC;' +
 'PSUBD *,* <- PADDB 00 FA-FC;' +
 'PSUBQ *,* <- PADDB 00 FB-FC;' +
 'PSUBSB *,* <- PADDB 00 E8-FC;' +
 'PSUBSW *,* <- PADDB 00 E9-FC;' +
 'PSUBUSB *,* <- PADDB 00 D8-FC;' +
 'PSUBUSW *,* <- PADDB 00 D9-FC;' +

 'PAND *,* <- PADDB 00 DB-FC;' +
 'PANDN *,* <- PADDB 00 DF-FC;' +
 'POR *,* <- PADDB 00 EB-FC;' +
 'PXOR *,* <- PADDB 00 EF-FC;' +

 'PAVGB *,* <- PADDB 00 E0-FC;' +
 'PAVGW *,* <- PADDB 00 E3-FC;' +
 'PCMPEQB *,* <- PADDB 00 74-FC;' +
 'PCMPEQW *,* <- PADDB 00 75-FC;' +
 'PCMPEQD *,* <- PADDB 00 76-FC;' +
 'PCMPGTB *,* <- PADDB 00 64-FC;' +
 'PCMPGTW *,* <- PADDB 00 65-FC;' +
 'PCMPGTD *,* <- PADDB 00 66-FC;' +
 'PMADDWD *,* <- PADDB 00 F5-FC;' +
 'PMAXSW *,* <- PADDB 00 EE-FC;' +
 'PMAXUB *,* <- PADDB 00 DE-FC;' +
 'PMINSW *,* <- PADDB 00 EA-FC;' +
 'PMINUB *,* <- PADDB 00 DA-FC;' +
 'PMULHUW *,* <- PADDB 00 E4-FC;' +
 'PMULHW *,* <- PADDB 00 E5-FC;' +
 'PMULLW *,* <- PADDB 00 D5-FC;' +
 'PMULUDQ *,* <- PADDB 00 F4-FC;' +

 'PEXTRW r4,x8,b -> 0F C5 C0+r<3+x b;' +
 'PEXTRW r4,x10,b -> !66 0F C5 C0+r<3+x b;' +
 'PINSRW x8,r4,b -> 0F C4 C0+r+x<3 b;' +
 'PINSRW x8,m2,b -> 0F C4 ?+x<3 m m>8 m>10 m>18 b;' +
 'PINSRW x10,r4,b -> !66 0F C4 C0+r+x<3 b;' +
 'PINSRW x10,m2,b -> !66 0F C4 ?+x<3 m m>8 m>10 m>18 b;' +

 'PMOVMSKB r4,x8 -> 0F D7 C0+r<3+x;' +
 'PMOVMSKB r4,x10 -> !66 0F D7 C0+r<3+x;' +

 'PSADBW *,* <- PADDB 00 F6-FC;' +

 'PSHUFD x10,X10,b -> !66 0F 70 C0+x<3+X b;' +
 'PSHUFD x10,m10,b -> !66 0F 70 ?+x<3 m m>8 m>10 m>18 b;' +
 'SHUFPD *,* <- PSHUFD 00 C6-70;' +

 'PSHUFHW x10,X10,b -> F3 0F 70 C0+x<3+X b;' +
 'PSHUFHW x10,m10,b -> F3 0F 70 ?+x<3 m m>8 m>10 m>18 b;' +
 'PSHUFLW x10,X10,b -> F2 0F 70 C0+x<3+X b;' +
 'PSHUFLW x10,m10,b -> F2 0F 70 ?+x<3 m m>8 m>10 m>18 b;' +

 'PSHUFW x8,X8,b -> 0F 70 C0+x<3+X b;' +
 'PSHUFW x8,m8,b -> 0F 70 ?+x<3 m m>8 m>10 m>18 b;' +

 'SHUFPS x10,X10,b -> 0F C6 C0+x<3+X b;' +
 'SHUFPS x10,m10,b -> 0F C6 ?+x<3 m m>8 m>10 m>18 b;' +

 'PSLLDQ x10,b -> !66 0F 73 F8+x b;' +
 'PSRLDQ x10,b -> !66 0F 73 D8+x b;' +

 'PSLLW *,* <- PADDB 00 F1-FC;' +
 'PSLLD *,* <- PADDB 00 F2-FC;' +
 'PSLLQ *,* <- PADDB 00 F3-FC;' +

 'PSRAW *,* <- PADDB 00 E1-FC;' +
 'PSRAD *,* <- PADDB 00 E2-FC;' +

 'PSRLW *,* <- PADDB 00 D1-FC;' +
 'PSRLD *,* <- PADDB 00 D2-FC;' +
 'PSRLQ *,* <- PADDB 00 D3-FC;' +

 'PSLLW x8,b -> 0F 71 ?+F0+x b;' +
 'PSLLW x10,b -> !66 0F 71 ?+F0+x b;' +
 'PSLLD x8,b -> 0F 72 ?+F0+x b;' +
 'PSLLD x10,b -> !66 0F 72 ?+F0+x b;' +
 'PSLLQ x8,b -> 0F 73 ?+F0+x b;' +
 'PSLLQ x10,b -> !66 0F 73 ?+F0+x b;' +

 'PSRAW x8,b -> 0F 71 ?+E0+x b;' +
 'PSRAW x10,b -> !66 0F 71 ?+E0+x b;' +
 'PSRAD x8,b -> 0F 72 ?+E0+x b;' +
 'PSRAD x10,b -> !66 0F 72 ?+E0+x b;' +

 'PSRLW x8,b -> 0F 71 ?+D0+x b;' +
 'PSRLW x10,b -> !66 0F 71 ?+D0+x b;' +
 'PSRLD x8,b -> 0F 72 ?+D0+x b;' +
 'PSRLD x10,b -> !66 0F 72 ?+D0+x b;' +
 'PSRLQ x8,b -> 0F 73 ?+D0+x b;' +
 'PSRLQ x10,b -> !66 0F 73 ?+D0+x b;' +

 'RCPPS x10,X10 -> 0F 53 C0+x<3+X;' +
 'RCPPS x10,m10 -> 0F 53 ?+x<3 m m>8 m>10 m>18;' +
 'RCPSS x10,X10 -> !F3 0F 53 C0+x<3+X;' +
 'RCPSS x10,m10 -> !F3 0F 53 ?+x<3 m m>8 m>10 m>18;' +

 'RSQRTPS *,* <- RCPPS 00 52-53;' +
 'RSQRTSS *,* <- RCPSS 00 52-53;' +




 'ARPL r2,R2 -> 63 C0+r+R<3;' +
 'ARPL m2,R2 -> 63 ?+r<3 m m>8 m>10 m>18;' +
 'BOUND r2,m2 -> !66 62 ?+r<3 m m>8 m>10 m>18;' +
 'BOUND r4,m4 -> 62 ?+r<3 m m>8 m>10 m>18;' +
 'BSF r2,R2 -> !66 0F BC C0+r<3+R;' +
 'BSF r2,m2 -> !66 0F BC ?+r<3 m m>8 m>10 m>18;' +
 'BSF r4,R4 -> 0F BC C0+r<3+R;' +
 'BSF r4,m4 -> 0F BC ?+r<3 m m>8 m>10 m>18;' +
 'BSR *,* <- BSF 00 01;' +

 'BSWAP r4 -> 0F C8+r;' +

 'BT r2,R2 -> !66 !0F A3 C0+r+R<3;' +
 'BT m2,r2 -> !66 !0F A3 ?+r<3 m m>8 m>10 m>18;' +
 'BT r4,R4 -> !0F A3 C0+r+R<3;' +
 'BT m4,R4 -> !0F A3 ?+r<3 m m>8 m>10 m>18;' +
 'BT r2,b -> !66 !0F !BA E0+r b;' +
 'BT m2,b -> !66 !0F !BA ?+20 m m>8 m>10 m>18 b;' +
 'BT r4,b -> !0F !BA E0+r b;' +
 'BT m4,b -> !0F !BA ?+20 m m>8 m>10 m>18 b;' +

 'BTC *,* <- BT BB-A3;' +
 'BTR *,* <- BT B3-A3;' +
 'BTS *,* <- BT AB-A3;' +

 'CALL f4 -> E8 f f>8 f>10 f>18;' +
 'CALL r2 -> !66 FF D0+r;' +
 'CALL m2 -> !66 FF ?+10 m m>8 m>10 m>18;' +
 'CALL r4 -> FF D0+r;' +
 'CALL m4 -> FF ?+10 m m>8 m>10 m>18;' +
 //'CALL p2:2 -> !66 9A ? p p>8;' +
 //'CALL p2:4 -> 9A ? p p>8;' +
 //'CALL m2:2 -> !66 FF ?+D8 m m>8;' +
 //'CALL m2:4 -> FF ?+D8 m m>8;' +

 'CBW -> !66 98;' +
 'CWDE -> 98;' +
 'CWD -> !66 99;' +
 'CDQ -> 99;' +
 'CLC -> F8;' +
 'CLD -> FC;' +
 'CLFLUSH m1 -> !0F AE ?+38 m m>8 m>10 m>18;' +
 'CLI -> FA;' +
 'CLTS -> !0F 06;' +
 'CMC -> F5;' +
 'CPUID -> !0F A2;' +

 'CMOVB r2,R2 -> !66 !0F 42 C0+r<3+R;' +
 'CMOVB r2,m2 -> !66 !0F 42 ?+r<3 m m>8 m>10 m>18;' +
 'CMOVC *,* <- CMOVB;' +
 'CMOVAE *,* <- CMOVB 43-42;' +
 'CMOVNC *,* <- CMOVB 43-42;' +
 'CMOVE *,* <- CMOVB 44-42;' +
 'CMOVZ *,* <- CMOVB 44-42;' +
 'CMOVNE *,* <- CMOVB 45-42;' +
 'CMOVNZ *,* <- CMOVB 45-42;' +
 'CMOVBE *,* <- CMOVB 46-42;' +
 'CMOVNA *,* <- CMOVB 46-42;' +
 'CMOVA *,* <- CMOVB 47-42;' +
 'CMOVNBE *,* <- CMOVB 47-42;' +
 'CMOVS *,* <- CMOVB 48-42;' +
 'CMOVNS *,* <- CMOVB 49-42;' +
 'CMOVP *,* <- CMOVB 4A-42;' +
 'CMOVPE *,* <- CMOVB 4A-42;' +
 'CMOVNP *,* <- CMOVB 4B-42;' +
 'CMOVPO *,* <- CMOVB 4B-42;' +
 'CMOVL *,* <- CMOVB 4C-42;' +
 'CMOVNGE *,* <- CMOVB 4C-42;' +
 'CMOVGE *,* <- CMOVB 4D-42;' +
 'CMOVNL *,* <- CMOVB 4D-42;' +
 'CMOVLE *,* <- CMOVB 4E-42;' +
 'CMOVNG *,* <- CMOVB 4E-42;' +
 'CMOVG *,* <- CMOVB 4F-42;' +
 'CMOVNLE *,* <- CMOVB 4F-42;' +

 'CMPXCHG r1,AL -> !0F B0 C0+r;' +
 'CMPXCHG m1,AL -> !0F B0 ? m m>8 m>10 m>18;' +
 'CMPXCHG r2,AX -> !66 !0F B1 C0+r;' +
 'CMPXCHG m2,AX -> !66 !0F B1 ?+r<3 m m>8 m>10 m>18;' +
 'CMPXCHG r4,EAX -> !0F B1 C0+r;' +
 'CMPXCHG m4,EAX -> !0F B1 ?+r<3 m m>8 m>10 m>18;' +
 'CMPXCHG8B m8 -> !0F C7 ?+8 m m>8 m>10 m>18;' +

 'DEC r1 -> !FE C8+r;' +
 'DEC r2 -> !66 48+r;' +
 'DEC r4 -> 48+r;' +
 'DEC m1 -> !FE ?+08 m m>8 m>10 m>18;' +
 'DEC m2 -> !66 !FF ?+08 m m>8 m>10 m>18;' +
 'DEC m4 -> !FF ?+08 m m>8 m>10 m>18;' +

 'INC r? <- DEC C0-C8;' +
 'INC m? <- DEC 00-08;' +

 'DIV r1 -> F6 F0+r;' +
 'DIV r2 -> !66 F7 F0+r;' +
 'DIV r4 -> F7 F0+r;' +
 'DIV m1 -> F6 ?+30 m m>8 m>10 m>18;' +
 'DIV m2 -> !66 F7 ?+30 m m>8 m>10 m>18;' +
 'DIV m4 -> F7 ?+30 m m>8 m>10 m>18;' +

 'IDIV * <- DIV 00 3D-35;' +

 'IMUL r1 -> F6 E8+r;' +
 'IMUL r2 -> !66 F7 E8+r;' +
 'IMUL r4 -> F7 E8+r;' +
 'IMUL m1 -> F6 ?+28 m m>8 m>10 m>18;' +
 'IMUL m2 -> !66 F7 ?+28 m m>8 m>10 m>18;' +
 'IMUL m4 -> F7 ?+28 m m>8 m>10 m>18;' +
 'IMUL r2,R2 -> !66 0F AF C0+r<3+R;' +
 'IMUL r2,m2 -> !66 0F AF ?+r<3 m m>8 m>10 m>18;' +
 'IMUL r4,R4 -> 0F AF C0+r<3+R;' +
 'IMUL r4,m4 -> 0F AF ?+r<3 m m>8 m>10 m>18;' +
 'IMUL r2,R2,b -> !66 6B C0+r<3+R b;' +
 'IMUL r2,m2,b -> !66 6B ?+r<3 m m>8 m>10 m>18 b;' +
 'IMUL r4,R4,b -> 6B C0+r<3+R b;' +
 'IMUL r4,m4,b -> 6B ?+r<3 m m>8 m>10 m>18 b;' +
 'IMUL r2,R2,w -> !66 69 C0+r<3+R w w>8;' +
 'IMUL r2,m2,w -> !66 69 ?+r<3 m m>8 m>10 m>18 w w>8;' +
 'IMUL r4,R4,d -> 69 C0+r<3+R d d>8 d>10 d>18;' +
 'IMUL r4,m4,d -> 69 ?+r<3 m m>8 m>10 m>18 d d>8 d>10 d>18;' +
 'IMUL r2,w -> !66 69 C0+r<3+r w w>8;' +
 'IMUL r4,d -> 69 C0+r<3+r d d>8 d>10 d>18;' +

 'MUL * <- DIV 00 25-35;' +

 'EMMS -> 0F 77;' +
 'ENTER w,b -> C8 w w>8 b;' +

 'F2XM1 -> D9 F0;' +
 'FABS -> D9 E1;' +

 'FADD m4 -> D8 ? m m>8 m>10 m>18;' +
 'FADD m8 -> DC ? m m>8 m>10 m>18;' +
 'FADD ST(0),z -> D8 C0+Z;' +
 'FADD z,ST(0) -> DC C0+z;' +
 'FADDP z,ST(0) -> DE C0+z;' +
 'FADDP -> DE C1;' +
 'FIADD m4 -> DA ? m m>8 m>10 m>18;' +
 'FIADD m2 -> DE ? m m>8 m>10 m>18;' +

 'FSUB m? <- FADD 00 25-05;' +
 'FSUB ST(0),* <- FADD 00 E0-C0;' +
 'FSUB *,* <- FADD 00 E8-C0;' +
 'FSUBP *,* <- FADDP 00 E8-C0;' +
 'FSUBP <- FADDP 00 E9-C1;' +
 'FISUB * <- FIADD 00 25-05;' +

 'FSUBR m? <- FADD 00 2D-05;' +
 'FSUBR ST(0),* <- FADD 00 E8-C0;' +
 'FSUBR *,* <- FADD 00 E0-C0;' +
 'FSUBRP *,* <- FADDP 00 E0-C0;' +
 'FSUBRP <- FADDP 00 E1-C1;' +
 'FISUBR * <- FIADD 00 2D-05;' +

 'FBLD m0A -> DF ?+20 m m>8 m>10 m>18;' +
 'FBSTP m0A -> DF ?+30 m m>8 m>10 m>18;' +
 'FBSTP m0A -> DF ?+30 m m>8 m>10 m>18;' +
 'FCHS -> D9 E0;' +
 'FCLEX -> !9B DB E2;' +
 'FNCLEX -> DB E2;' +

 'FCMOVB ST(0),z -> DA C0+Z;' +
 'FCMOVE ST(0),z -> DA C8+Z;' +
 'FCMOVBE ST(0),z -> DA D0+Z;' +
 'FCMOVU ST(0),z -> DA D8+Z;' +
 'FCMOVNB ST(0),z -> DB C0+Z;' +
 'FCMOVNE ST(0),z -> DB C8+Z;' +
 'FCMOVNBE ST(0),z -> DB D0+Z;' +
 'FCMOVNU ST(0),z -> DB D8+Z;' +

 'FCOM m4 -> D8 ?+10 m m>8 m>10 m>18;' +
 'FCOM m8 -> DC ?+10 m m>8 m>10 m>18;' +
 'FCOM z -> D8 D0+z;' +
 'FCOM -> D8 D1;' +
 'FCOMP m4 -> D8 ?+18 m m>8 m>10 m>18;' +
 'FCOMP m8 -> DC ?+18 m m>8 m>10 m>18;' +
 'FCOMP z -> D8 D8+z;' +
 'FCOMP -> D8 D9;' +
 'FCOMPP -> DE D9;' +

 'FCOMI ST(0),z -> DB F0+Z;' +
 'FCOMIP ST(0),z -> DF F0+Z;' +
 'FUCOMI ST(0),z -> DB E8+Z;' +
 'FUCOMIP ST(0),z -> DF E8+Z;' +

 'FCOS -> D9 FF;' +
 'FDECSTP -> D9 F6;' +

 'FDIV m4 -> D8 ?+30 m m>8 m>10 m>18;' +
 'FDIV m8 -> DC ?+30 m m>8 m>10 m>18;' +
 'FDIV ST(0),z -> D8 F0+Z;' +
 'FDIV z,ST(0) -> DC F8+z;' +
 'FDIVP z,ST(0) -> DE F8+z;' +
 'FDIVP -> DE F9;' +
 'FIDIV m4 -> DA ?+30 m m>8 m>10 m>18;' +
 'FIDIV m2 -> DE ?+30 m m>8 m>10 m>18;' +

 'FDIVR m? <- FDIV 00 3D-35;' +

 'FDIVR ST(0),z -> D8 F8+Z;' +
 'FDIVR z,ST(0) -> DC F0+z;' +
 'FDIVRP z,ST(0) -> DE F0+z;' +
 'FDIVRP -> DE F1;' +

 'FIDIVR m? <- FIDIV 00 3D-35;' +

 'FFREE z -> DD C0+z;' +

 'FICOM m2 -> DE ?+10 m m>8 m>10 m>18;' +
 'FICOM m4 -> DA ?+10 m m>8 m>10 m>18;' +
 'FICOMP m? <- FICOM 00 1D-15;' +

 'FILD m2 -> DF ? m m>8 m>10 m>18;' +
 'FILD m4 -> DB ? m m>8 m>10 m>18;' +
 'FILD m8 -> DF ?+28 m m>8 m>10 m>18;' +

 'FINCSTP -> D9 F7;' +
 'FINIT -> 9B DB E3;' +
 'FNINIT -> DB E3;' +

 'FIST m2 -> DF ?+10 m m>8 m>10 m>18;' +
 'FIST m4 -> DB ?+10 m m>8 m>10 m>18;' +
 'FISTP m2 -> DF ?+18 m m>8 m>10 m>18;' +
 'FISTP m4 -> DB ?+18 m m>8 m>10 m>18;' +
 'FISTP m8 -> DF ?+38 m m>8 m>10 m>18;' +

 'FLD m4 -> D9 ? m m>8 m>10 m>18;' +
 'FLD m8 -> DD ? m m>8 m>10 m>18;' +
 'FLD m0A -> DB ?+28 m m>8 m>10 m>18;' +
 'FLD z -> D9 C0+z;' +
 'FLD1 -> D9 E8;' +
 'FLDL2T -> D9 E9;' +
 'FLDL2E -> D9 EA;' +
 'FLDPI -> D9 EB;' +
 'FLDLG2 -> D9 EC;' +
 'FLDLN2 -> D9 ED;' +
 'FLDZ -> D9 EE;' +

 'FLDCW m2 -> D9 ?+28 m m>8 m>10 m>18;' +
 'FLDENV m0E -> !66 D9 ?+20 m m>8 m>10 m>18;' +
 'FLDENV m1C -> D9 ?+20 m m>8 m>10 m>18;' +

 'FMUL m4 -> D8 ?+08 m m>8 m>10 m>18;' +
 'FMUL m8 -> DC ?+08 m m>8 m>10 m>18;' +
 'FMUL ST(0),z -> D8 C8+Z;' +
 'FMUL z,ST(0) -> DC C8+z;' +
 'FMULP z,ST(0) -> DE C8+z;' +
 'FMULP -> DE C9;' +
 'FIMUL m4 -> DA ?+08 m m>8 m>10 m>18;' +
 'FIMUL m2 -> DE ?+08 m m>8 m>10 m>18;' +

 'FNOP -> D9 D0;' +
 'FPATAN -> D9 F3;' +
 'FPREM -> D9 F8;' +
 'FPREM1 -> D9 F5;' +
 'FPTAN -> D9 F2;' +
 'FRNDINT -> D9 FC;' +
 'FRSTOR m -> DD ?+20 m m>8 m>10 m>18;' +
 'FSAVE m -> 9B DD ?+30 m m>8 m>10 m>18;' +
 'FNSAVE m -> DD ?+30 m m>8 m>10 m>18;' +
 'FSCALE -> D9 FD;' +
 'FSIN -> D9 FE;' +
 'FSINCOS -> D9 FB;' +
 'FSQRT -> D9 FA;' +

 'FST m4 -> D9 ?+10 m m>8 m>10 m>18;' +
 'FST m8 -> DD ?+10 m m>8 m>10 m>18;' +
 'FST z -> DD D0+z;' +
 'FSTP m4 -> D9 ?+18 m m>8 m>10 m>18;' +
 'FSTP m8 -> DD ?+18 m m>8 m>10 m>18;' +
 'FSTP m0A -> DB ?+38 m m>8 m>10 m>18;' +
 'FSTP z -> DD D8+z;' +
 'FSTCW m2 -> 9B D9 ?+38 m m>8 m>10 m>18;' +
 'FNSTCW m2 -> D9 ?+38 m m>8 m>10 m>18;' +
 'FSTENV m -> 9B D9 ?+30 m m>8 m>10 m>18;' +
 'FNSTENV m -> D9 ?+30 m m>8 m>10 m>18;' +
 'FSTSW m2 -> 9B DD ?+38 m m>8 m>10 m>18;' +
 'FSTSW AX -> 9B DF E0;' +
 'FNSTSW m2 -> DD ?+38 m m>8 m>10 m>18;' +
 'FNSTSW AX -> DF E0;' +

 'FTST -> D9 E4;' +
 'FXAM -> D9 E5;' +
 'FXCH z -> D9 C8+z;' +
 'FXCH -> D9 C9;' +
 'FXRSTOR m -> 0F AE ?+08 m m>8 m>10 m>18;' +
 'FXSAVE m -> 0F AE ? m m>8 m>10 m>18;' +
 'FXTRACT -> D9 F4;' +
 'FYL2X -> D9 F1;' +
 'FYL2XP1 -> D9 F9;' +

 'HLT -> F4;' +
 'IN AL,b -> E4 b;' +
 'IN AX,b -> !66 E5 b;' +
 'IN EAX,b -> E5 b;' +
 'IN AL,DX -> EC;' +
 'IN AX,DX -> !66 ED;' +
 'IN EAX,DX -> ED;' +
 'INSB -> 6C;' +
 'INSW -> !66 6D;' +
 'INSD -> 6D;' +
 'INT 3 -> CC;' +
 'INT b -> CD b;' +
 'INTO -> CE;' +
 'INVD -> 0F 08;' +
 'INVLPG m -> 0F 01 ?+38 m m>8 m>10 m>18;' +
 'IRET -> !66 CF;' +
 'IRETD -> CF;' +

 'JO f1 -> 70 f;' +
 'JNO f1 -> 71 f;' +
 'JB f1 -> 72 f;' +
 'JNAE f1 -> 72 f;' +
 'JC f1 -> 72 f;' +
 'JAE f1 -> 73 f;' +
 'JNB f1 -> 73 f;' +
 'JNC f1 -> 73 f;' +
 'JE f1 -> 74 f;' +
 'JZ f1 -> 74 f;' +
 'JNZ f1 -> 75 f;' +
 'JNE f1 -> 75 f;' +
 'JBE f1 -> 76 f;' +
 'JNA f1 -> 76 f;' +
 'JA f1 -> 77 f;' +
 'JNBE f1 -> 77 f;' +
 'JS f1 -> 78 f;' +
 'JNS f1 -> 79 f;' +
 'JP f1 -> 7A f;' +
 'JPE f1 -> 7A f;' +
 'JNP f1 -> 7B f;' +
 'JPO f1 -> 7B f;' +
 'JL f1 -> 7C f;' +
 'JNGE f1 -> 7C f;' +
 'JGE f1 -> 7D f;' +
 'JNL f1 -> 7D f;' +
 'JNG f1 -> 7E f;' +
 'JLE f1 -> 7E f;' +
 'JG f1 -> 7F f;' +
 'JNLE f1 -> 7F f;' +

 'JCXZ f1 -> !66 E3 f;' +
 'JECXZ f1 -> E3 f;' +

 'JO f4 -> 0F 80 f f>8 f>10 f>18;' +
 'JNO f4 -> 0F 81 f f>8 f>10 f>18;' +
 'JB f4 -> 0F 82 f f>8 f>10 f>18;' +
 'JC f4 -> 0F 82 f f>8 f>10 f>18;' +
 'JNAE f4 -> 0F 82 f f>8 f>10 f>18;' +
 'JAE f4 -> 0F 83 f f>8 f>10 f>18;' +
 'JNB f4 -> 0F 83 f f>8 f>10 f>18;' +
 'JNC f4 -> 0F 83 f f>8 f>10 f>18;' +
 'JE f4 -> 0F 84 f f>8 f>10 f>18;' +
 'JZ f4 -> 0F 84 f f>8 f>10 f>18;' +
 'JNE f4 -> 0F 85 f f>8 f>10 f>18;' +
 'JNZ f4 -> 0F 85 f f>8 f>10 f>18;' +
 'JBE f4 -> 0F 86 f f>8 f>10 f>18;' +
 'JNA f4 -> 0F 86 f f>8 f>10 f>18;' +
 'JA f4 -> 0F 87 f f>8 f>10 f>18;' +
 'JNBE f4 -> 0F 87 f f>8 f>10 f>18;' +
 'JS f4 -> 0F 88 f f>8 f>10 f>18;' +
 'JNS f4 -> 0F 89 f f>8 f>10 f>18;' +
 'JP f4 -> 0F 8A f f>8 f>10 f>18;' +
 'JPE f4 -> 0F 8A f f>8 f>10 f>18;' +
 'JNP f4 -> 0F 8B f f>8 f>10 f>18;' +
 'JPO f4 -> 0F 8B f f>8 f>10 f>18;' +
 'JL f4 -> 0F 8C f f>8 f>10 f>18;' +
 'JNGE f4 -> 0F 8C f f>8 f>10 f>18;' +
 'JGE f4 -> 0F 8D f f>8 f>10 f>18;' +
 'JNL f4 -> 0F 8D f f>8 f>10 f>18;' +
 'JLE f4 -> 0F 8E f f>8 f>10 f>18;' +
 'JNG f4 -> 0F 8E f f>8 f>10 f>18;' +
 'JG f4 -> 0F 8F f f>8 f>10 f>18;' +
 'JNLE f4 -> 0F 8F f f>8 f>10 f>18;' +

 'JMP f1 -> EB f;' +
 'JMP f4 -> E9 f f>8 f>10 f>18;' +
 'JMP r2 -> !66 FF E0+r;' +
 'JMP r4 -> FF E0+r;' +
 'JMP m2 -> !66 FF ?+20 m m>8 m>10 m>18;' +
 'JMP m4 -> FF ?+20 m m>8 m>10 m>18;' +
 //'JMP p2:2 -> ...' +
 //'JMP p2:4 -> ...' +
 //'JMP m2:2 -> ...' +
 //'JMP m2:4 -> ...' +

 'LAHF -> 9F;' +
 'LAR r2,R2 -> !66 0F 02 C0+r<3+R;' +
 'LAR r2,m2 -> !66 0F 02 ?+r<3 m m>8 m>10 m>18;' +
 'LAR r2,R2 -> 0F 02 C0+r<3+R;' +
 'LAR r2,m2 -> 0F 02 ?+r<3 m m>8 m>10 m>18;' +
 'LDMXCSR m4 -> 0F AE ?+10 m m>8 m>10 m>18;' +
 'STMXCSR m4 <- LDMXCSR 00 00 18-10;' +
 //'LDS ...'
 //'LES ...'
 //'LFS ...'
 //'LGS ...'

 'LEA r2,m -> !66 8D ?+r<3 m m>8 m>10 m>18;' +
 'LEA r4,m -> 8D ?+r<3 m m>8 m>10 m>18;' +

 'LEAVE -> C9;' +
 //'LFENCE -> 0F AE '
 //'MFENCE -> 0F AE /6' ????
 //'SFENCE -> 0F AE /7' ????
 'LGDT m -> 0F 01 ?+10 m m>8 m>10 m>18;' +
 'LIDT m -> 0F 01 ?+18 m m>8 m>10 m>18;' +
 'LLDT m -> 0F 00 ?+10 m m>8 m>10 m>18;' +

 'SGDT * <- LGDT 00-10;' +
 'SIDT * <- LIDT 08-18;' +
 'SLDT * <- LLDT 00-10;' +


 'LMSW r2 -> 0F 01 F0+r;' +
 'LMSW m2 -> 0F 01 ?+30 m m>8 m>10 m>18;' +
 'SMSW * <- LMSW 00 00 20-30;' +

 'LOCK -> F0;' +

 'LODSB -> AC;' +
 'LODSW -> !66 AD;' +
 'LODSD -> AD;' +

 'LOOP f1 -> E2 f;' +
 'LOOPE f1 -> E1 f;' +
 'LOOPZ f1 -> E1 f;' +
 'LOOPNE f1 -> E0 f;' +
 'LOOPNZ f1 -> E0 f;' +

 'LOOP f2 -> 49 !66 0F 85 f f>8;' +

 'LSL r2,R2 -> !66 0F 03 C0+r<3+R;' +
 'LSL r2,m2 -> !66 0F 03 ?+r<3 m m>8 m>10 m>18;' +
 'LSL r4,R4 -> 0F 03 C0+r<3+R;' + 
 'LSL r4,m4 -> 0F 03 ?+r<3 m m>8 m>10 m>18;' +

 'LTR r2 -> 0F 00 D8+r;' +
 'LTR m2 -> 0F 00 ?+18 m m>8 m>10 m>18;' +

 'MOV AL,u1 -> A0 u;' +
 'MOV AX,u2 -> !66 A1 u u>8;' +
 'MOV EAX,u4 -> A1 u u>8 u>10 u>18;' +
 'MOV u1,AL -> A2 u u>8 u>10 u>18;' +
 'MOV u2,AX -> !66 A3 u u>8 u>10 u>18;' +
 'MOV u4,EAX -> A3 u u>8 u>10 u>18;' +

 'MOV r1,R1 -> 88 C0+r+R<3;' +
 'MOV m1,R1 -> 88 ?+R<3 m m>8 m>10 m>18;' +
 'MOV r1,m1 -> 8A ?+r<3 m m>8 m>10 m>18;' +
 'MOV r2,R2 -> !66 89 C0+r+R<3;' +
 'MOV m2,R2 -> !66 89 ?+R<3 m m>8 m>10 m>18;' +
 'MOV r2,m2 -> !66 8B ?+r<3 m m>8 m>10 m>18;' +
 'MOV r4,R4 -> 89 C0+r+R<3;' +
 'MOV m4,R4 -> 89 ?+R<3 m m>8 m>10 m>18;' +
 'MOV r4,m4 -> 8B ?+R<3 m m>8 m>10 m>18;' +

 'MOV r2,s -> !66 8C C0+s<3+r;' +
 'MOV m2,s -> !66 8C ?+s<3 m m>8 m>10 m>18;' +
 'MOV s,r2 -> !66 8E C0+s<3+r;' +
 'MOV s,m2 -> !66 8E ?+s<3 m m>8 m>10 m>18;' +

 'MOV r1,b -> B0+r b;' +
 'MOV r1,w -> B0+r b;' +
 'MOV r1,d -> B0+r b;' +
 'MOV r2,b -> !66 B8+r w w>8;' +
 'MOV r2,w -> !66 B8+r w w>8;' +
 'MOV r2,d -> !66 B8+r w w>8;' +
 'MOV r4,d -> B8+r d d>8 d>10 d>18;' +
 'MOV m1,b -> C6 ? m m>8 m>10 m>18 b;' +
 'MOV m1,w -> C6 ? m m>8 m>10 m>18 b;' +
 'MOV m1,d -> C6 ? m m>8 m>10 m>18 b;' +
 'MOV m2,w -> !66 C7 ? m m>8 m>10 m>18 w w>8;' +
 'MOV m2,d -> !66 C7 ? m m>8 m>10 m>18 w w>8;' +
 'MOV m4,d -> C7 ? m m>8 m>10 m>18 d d>8 d>10 d>18;' +

 'MOV CR0,r4 -> 0F 22 C0+r;' +
 'MOV CR2,r4 -> 0F 22 D0+r;' +
 'MOV CR3,r4 -> 0F 22 D8+r;' +
 'MOV CR4,r4 -> 0F 22 E0+r;' +
 'MOV r4,CR0 -> 0F 20 C0+r;' +
 'MOV r4,CR2 -> 0F 20 D0+r;' +
 'MOV r4,CR3 -> 0F 20 D8+r;' +
 'MOV r4,CR4 -> 0F 20 E0+r;' +

 'MOV r4,DR0 -> 0F 21 C0+r;' +
 'MOV r4,DR1 -> 0F 21 C8+r;' +
 'MOV r4,DR2 -> 0F 21 D0+r;' +
 'MOV r4,DR3 -> 0F 21 D8+r;' +
 'MOV r4,DR4 -> 0F 21 E0+r;' +
 'MOV r4,DR5 -> 0F 21 E8+r;' +
 'MOV r4,DR6 -> 0F 21 F0+r;' +
 'MOV r4,DR7 -> 0F 21 F8+r;' +

 'MOV DR0,r4 -> 0F 23 C0+r;' +
 'MOV DR1,r4 -> 0F 23 C8+r;' +
 'MOV DR2,r4 -> 0F 23 D0+r;' +
 'MOV DR3,r4 -> 0F 23 D8+r;' +
 'MOV DR4,r4 -> 0F 23 E0+r;' +
 'MOV DR5,r4 -> 0F 23 E8+r;' +
 'MOV DR6,r4 -> 0F 23 F0+r;' +
 'MOV DR7,r4 -> 0F 23 F8+r;' +

 'MOVSB -> A4;' +
 'MOVSW -> !66 A5;' +
 'MOVSD -> A5;' +

 'MOVSX r2,R1 -> !66 0F BE C0+r<3+R;' +
 'MOVSX r2,m1 -> !66 0F BE ?+r<3 m m>8 m>10 m>18;' +
 'MOVSX r4,R1 -> 0F BE C0+r<3+R;' +
 'MOVSX r4,m1 -> 0F BE ?+r<3 m m>8 m>10 m>18;' +
 'MOVSX r4,R2 -> 0F BF C0+r<3+R;' +
 'MOVSX r4,m2 -> 0F BF ?+r<3 m m>8 m>10 m>18;' +

 'MOVZX *,* <- MOVSX 00 B6-BE;' +
 'NEG r1 -> F6 D8+r;' +
 'NEG m1 -> F6 ?+18 m m>8 m>10 m>18;' +
 'NEG r2 -> !66 F7 D8+r;' +
 'NEG m2 -> !66 F7 ?+18 m m>8 m>10 m>18;' +
 'NEG r4 -> F7 D8+r;' +
 'NEG m4 -> F7 ?+18 m m>8 m>10 m>18;' +

 'NOP -> 90;' +

 'NOT * <- NEG 00 10-18;' +
 'OUT b,AL -> E6 b;' +
 'OUT b,AX -> !66 E7 b;' +
 'OUT b,EAX -> E7 b;' +
 'OUT DX,AL -> EE;' +
 'OUT DX,AX -> !66 EF;' +
 'OUT DX,EAX -> EF;' +

 'OUTSB -> 6E;' +
 'OUTSW -> !66 6F;' +
 'OUTSD -> 6F;' +

 'PAUSE -> F3 90;' +

 'POP r2 -> !66 58+r;' +
 'POP m2 -> !66 8F ? m m>8 m>10 m>18;' +
 'POP r4 -> 58+r;' +
 'POP m4 -> 8F ? m m>8 m>10 m>18;' +
 'POP DS -> 1F;' +
 'POP ES -> 07;' +
 'POP SS -> 17;' +
 'POP FS -> 0F A1;' +
 'POP GS -> 0F A9;' +
 'POPA -> !66 61;' +
 'POPAD -> 61;' +
 'POPF -> !66 9D;' +
 'POPFD -> 9D;' +

 'PUSH r2 -> !66 50+r;' +
 'PUSH m2 -> !66 FF ?+30 m m>8 m>10 m>18;' +
 'PUSH r4 -> 50+r;' +
 'PUSH m4 -> FF ?+30 m m>8 m>10 m>18;' +
 'PUSH b -> 6A b;' +
 // there is a problem with this instruction! 'PUSH w -> !66 68 w w>8;' +
 'PUSH d -> 68 d d>8 d>10 d>18;' +
 'PUSH CS -> 0E;' +
 'PUSH DS -> 1E;' +
 'PUSH ES -> 06;' +
 'PUSH SS -> 16;' +
 'PUSH FS -> 0F A0;' +
 'PUSH GS -> 0F A8;' +
 'PUSHA -> !66 60;' +
 'PUSHAD -> 60;' +
 'PUSHF -> !66 9C;' +
 'PUSHFD -> 9C;' +

 'PREFETCHT0 m1 -> 0F 18 ?+8 m m>8 m>10 m>18;' +
 'PREFETCHT1 m1 -> 0F 18 ?+10 m m>8 m>10 m>18;' +
 'PREFETCHT2 m1 -> 0F 18 ?+18 m m>8 m>10 m>18;' +
 'PREFETCHNTA m1 -> 0F 18 ? m m>8 m>10 m>18;' +

 'RCL r1,1 -> D0 D0+r;' +
 'RCL m1,1 -> D0 ?+10 m m>8 m>10 m>18;' +
 'RCL r1,CL -> D2 D0+r;' +
 'RCL m1,CL -> D2 ?+10 m m>8 m>10 m>18;' +
 'RCL r1,b -> C0 D0+r b;' +
 'RCL r1,w -> C0 D0+r b;' +
 'RCL r1,d -> C0 D0+r b;' +
 'RCL m1,b -> C0 ?+10 m m>8 m>10 m>18 b;' +

 'RCL r2,1 -> !66 D1 D0+r;' +
 'RCL m2,1 -> !66 D1 ?+10 m m>8 m>10 m>18;' +
 'RCL r2,CL -> !66 D3 D0+r;' +
 'RCL m2,CL -> !66 D3 ?+10 m m>8 m>10 m>18;' +
 'RCL r2,b -> !66 C1 D0+r b;' +
 'RCL m2,b -> !66 C1 ?+10 m m>8 m>10 m>18 b;' +

 'RCL r4,1 -> D1 D0+r;' +
 'RCL m4,1 -> D1 ?+10 m m>8 m>10 m>18;' +
 'RCL r4,CL -> D3 D0+r;' +
 'RCL m4,CL -> D3 ?+10 m m>8 m>10 m>18;' +
 'RCL r4,b -> C1 D0+r b;' +
 'RCL m4,b -> C1 ?+10 m m>8 m>10 m>18 b;' +

 'RCR *,* <- RCL 00 08;' +
 'ROL *,* <- RCL 00 00-10;' +
 'ROR *,* <- RCL 00 08-10;' +

 'SAL *,* <- RCL 00 20-10;' +
 'SHL *,* <- RCL 00 20-10;' +
 'SHR *,* <- RCL 00 28-10;' +
 'SAR *,* <- RCL 00 38-10;' +

 'RDMSR -> 0F 32;' +
 'RDPMC -> 0F 33;' +
 'RDTSC -> 0F 31;' +

 'REP INSB -> F3 6C;' +
 'REP INSW -> F3 66 6D;' +
 'REP INSD -> F3 6D;' +
 'REP MOVSB -> F3 A4;' +
 'REP MOVSW -> F3 66 A5;' +
 'REP MOVSD -> F3 A5;' +
 'REP OUTSB -> F3 6E;' +
 'REP OUTSW -> F3 66 6F;' +
 'REP OUTSD -> F3 6F;' +
 'REP LODSB -> F3 AC;' +
 'REP LODSW -> F3 66 AD;' +
 'REP LODSD -> F3 AD;' +
 'REP STOSB -> F3 AA;' +
 'REP STOSW -> F3 66 AB;' +
 'REP STOSD -> F3 AB;' +
 'REPE CMPSB -> F3 A6;' +
 'REPE CMPSW -> F3 66 A7;' +
 'REPE CMPSD -> F3 A7;' +
 'REPZ CMPSB -> F3 A6;' +
 'REPZ CMPSW -> F3 66 A7;' +
 'REPZ CMPSD -> F3 A7;' +
 'REPE SCASB -> F3 AE;' +
 'REPE SCASW -> F3 66 AF;' +
 'REPE SCASD -> F3 AF;' +
 'REPZ SCASB -> F3 AE;' +
 'REPZ SCASW -> F3 66 AF;' +
 'REPZ SCASD -> F3 AF;' +
 'REPNE CMPSB -> F2 A6;' +
 'REPNE CMPSW -> F2 66 A7;' +
 'REPNE CMPSD -> F2 A7;' +
 'REPNZ CMPSB -> F2 A6;' +
 'REPNZ CMPSW -> F2 66 A7;' +
 'REPNZ CMPSD -> F2 A7;' +
 'REPNE SCASB -> F2 AE;' +
 'REPNE SCASW -> F2 66 AF;' +
 'REPNE SCASD -> F2 AF;' +
 'REPNZ SCASB -> F2 AE;' +
 'REPNZ SCASW -> F2 66 AF;' +
 'REPNZ SCASD -> F2 AF;' +

 'RET -> C3;' +
 'RETFAR -> CB;' +
 'RET w -> C2 w w>8;' +
 'RETFAR w -> CA w w>8;' +

 'RSM -> 0F AA;' +

 'SAHF -> 9E;' +
 'SCASB -> AE;' +
 'SCASW -> !66 AF;' +
 'SCASD -> AF;' +

 'SETB r1 -> !0F 92 C0+r;' +
 'SETB m1 -> !0F 92 ? m m>8 m>10 m>18;' +
 'SETC * <- SETB;' +
 'SETNAE * <- SETB;' +
 'SETO * <- SETB 90-92;' +
 'SETNO * <- SETB 91-92;' +
 'SETAE * <- SETB 93-92;' +
 'SETNB * <- SETB 93-92;' +
 'SETNC * <- SETB 93-92;' +
 'SETE * <- SETB 94-92;' +
 'SETZ * <- SETB 94-92;' +
 'SETNE * <- SETB 95-92;' +
 'SETNZ * <- SETB 95-92;' +
 'SETBE * <- SETB 96-92;' +
 'SETNA * <- SETB 96-92;' +
 'SETA * <- SETB 97-92;' +
 'SETNBE * <- SETB 97-92;' +
 'SETS * <- SETB 98-92;' +
 'SETNS * <- SETB 99-92;' +
 'SETP * <- SETB 9A-92;' +
 'SETPE * <- SETB 9A-92;' +
 'SETNP * <- SETB 9B-92;' +
 'SETPO * <- SETB 9B-92;' +
 'SETL * <- SETB 9C-92;' +
 'SETNGE * <- SETB 9C-92;' +
 'SETGE * <- SETB 9D-92;' +
 'SETNL * <- SETB 9D-92;' +
 'SETLE * <- SETB 9E-92;' +
 'SETNG * <- SETB 9E-92;' +
 'SETG * <- SETB 9F-92;' +
 'SETNLE * <- SETB 9F-92;' +

 'SHLD r2,R2,b -> !66 0F A4 C0+r+R<3 b;' +
 'SHLD m2,r2,b -> !66 0F A4 ?+r<3 m m>8 m>10 m>18 b;' +
 'SHLD r2,R2,CL -> !66 0F A5 C0+r+R<3;' +
 'SHLD m2,r2,CL -> !66 0F A5 ?+r<3 m m>8 m>10 m>18;' +

 'SHLD r4,R4,b -> 0F A4 C0+r+R<3 b;' +
 'SHLD m4,r4,b -> 0F A4 ?+r<3 m m>8 m>10 m>18 b;' +
 'SHLD r4,R4,CL -> 0F A5 C0+r+R<3;' +
 'SHLD m4,r4,CL -> 0F A5 ?+r<3 m m>8 m>10 m>18;' +

 'SHRD *,*,* <- SHLD 00 AC-A4;' +

 'STC -> F9;' +
 'STD -> FD;' +
 'STD -> FB;' +

 'STOSB -> AA;' +
 'STOSW -> !66 AB;' +
 'STOSD -> AB;' +

 'STR r2 -> 0F 00 C8+r;' +
 'STR m2 -> 0F 00 ?+8 m m>8 m>10 m>18;' +

 'SYSENTER -> 0F 34;' +
 'SYSEXIT -> 0F 35;' +

 'TEST AL,b -> A8 b;' +
 'TEST AX,w -> !66 A9 w w>8;' +
 'TEST EAX,d -> A9 d d>8 d>10 d>18;' +
 'TEST r1,b -> !F6 C0+r b;' +
 'TEST r1,w -> !F6 C0+r b;' +
 'TEST r1,d -> !F6 C0+r b;' +
 'TEST r2,w -> !66 !F7 C0+r w w>8;' +
 'TEST r4,d -> !F7 C0+r d d>8 d>10 d>18;' +
 'TEST m1,b -> !F6 ? m m>8 m>10 m>18 b;' +
 'TEST m2,w -> !66 !F7 ? m m>8 m>10 m>18 w w>8;' +
 'TEST m4,d -> !F7 ? m m>8 m>10 m>18 d d>8 d>10 d>18;' +
 'TEST r1,R1 -> 84 C0+r+R<3;' +
 'TEST r2,R2 -> !66 85 C0+r+R<3;' +
 'TEST r4,R4 -> 85 C0+r+R<3;' +
 'TEST m1,r1 -> 84 ?+r<3 m m>8 m>10 m>18;' +
 'TEST m2,r2 -> !66 85 ?+r<3 m m>8 m>10 m>18;' +
 'TEST m4,r4 -> 85 ?+r<3 m m>8 m>10 m>18;' +

 'UD2 -> 0F 0B;' +
 'VERR r2 -> !0F !00 E0+r;' +
 'VERR m2 -> !0F !00 ?+20 m m>8 m>10 m>18;' +
 'VERW * <- VERR 08;' +

 'WAIT -> 9B;' +
 'FWAIT -> 9B;' +
 'WBINVD -> 0F 09;' +
 'WRMSR -> 0F 30;' +

 'XADD r1,R1 -> 0F C0 C0+r+R<3;' +
 'XADD m1,r1 -> 0F C0 ?+r<3 m m>8 m>10 m>18;' +
 'XADD r2,R2 -> !66 0F C1 C0+r+R<3;' +
 'XADD m2,r2 -> !66 0F C1 ?+r<3 m m>8 m>10 m>18;' +
 'XADD r4,R4 -> 0F C1 C0+r+R<3;' +
 'XADD m4,r4 -> 0F C1 ?+r<3 m m>8 m>10 m>18;' +

 'XCHG AX,r2 -> !66 90+R;' +
 'XCHG r2,AX -> !66 90+r;' +
 'XCHG EAX,r4 -> 90+R;' +
 'XCHG r4,EAX -> 90+r;' +
 'XCHG r1,R1 -> 86 C0+r<3+R;' +
 'XCHG r1,m1 -> 86 ?+r<3 m m>8 m>10 m>18;' +
 'XCHG m1,r1 -> 86 ?+r<3 m m>8 m>10 m>18;' +
 'XCHG r2,R2 -> !66 87 C0+r<3+R;' +
 'XCHG r2,m2 -> !66 87 ?+r<3 m m>8 m>10 m>18;' +
 'XCHG m2,r2 -> !66 87 ?+r<3 m m>8 m>10 m>18;' +
 'XCHG r4,R4 -> 87 C0+r<3+R;' +
 'XCHG r4,m4 -> 87 ?+r<3 m m>8 m>10 m>18;' +
 'XCHG m4,r4 -> 87 ?+r<3 m m>8 m>10 m>18;' +

 'XLAT -> D7;' +

 '';

implementation

end.

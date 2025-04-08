## xASM a 32bit x86 ASM Compiler

这是一个32位X86汇编语言编译器，基本语法与BASM一致，可编译出实模式/保护模式的windows可执行文件 (.com/.exe)，或代码块

指令集位于 XAsmTable.pas ， 修改指令集可相对容易的实现 arm / risc / misc 汇编编译器。

可以编译出极小的可执行文件，如 HelloWorld.asm ，编译后的windows可执行文件仅为 444 字节。

## 示例代码：HelloWorld.asm
```asm
.FILEALIGN 4
.IMAGEBASE $400000

.IMPORT user32.dll,MessageBoxA

txt1&& DB 'Hello World!'

msgbox: MACRO handle=0,text=0,title=0,button=0
 push &button
 push &title
 push &text
 push &handle
 call A[MessageBoxA]
 END

Start:
 msgbox handle=0,text=txt1,title=txt1,button=0
 ret
```

## 示例代码：API.asm
```asm
.FILEALIGN 4

//注意，不同的DLL必须单独使用 .IMPORT
//在定义后 API 名称将成为 Label
//用 CALL A[API名称] 的方式使用API
//本文件编译后 516 Bytes

.IMPORT kernel32.dll,GetProcAddress,LoadLibraryA
.IMPORT user32.dll,MessageBoxA

txt1&& DB 'Hello World!'

msgbox: MACRO handle=0,text=0,title=0,button=0
 push &button
 push &title
 push &text
 push &handle
 call A[MessageBoxA]
 END

Start:
 msgbox handle=eax,text=txt1,title=txt1,button=0
 ret
 ```

## 示例代码：Option.asm
```asm
.FILEALIGN 4 //文件对齐
.IMAGEBASE $400000 //影象文件基址
.TINYPE //最小模式编译
//.DLLMODE //编译为DLL
.SUBSYSTEM 2 //设置子系统, GUI == 2, CONSOLE == 3

Start:
.BUILDMSG 编译到这里时产生信息
 ret
 ```

## 示例代码：m-s.asm
```asm
.FILEALIGN 4

//本文件编译后 320 Bytes

.ALIGN 2
struct1: STRUCT
FieldDB: DB $90 DIV $90
FieldDW: DW $9090 SHR 10
FieldDD: DD $90909090 / 2
FieldDQ: DQ $90909090 * 2
 END

.ALIGN 4
macro1: MACRO param1=0,param2=0
 mov eax,&param1
 mov ebx,&param2
 mov ecx,DWORD PTR [struct1.FieldDB]
 add ecx,eax
 add ecx,ebx
 mov DWORD PTR [struct1.FieldDW],ecx
 END

Start:
 macro1 param1=$100,param2=1
 ret
 ```

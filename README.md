# xASM a 32bit x86 ASM Compiler
# xASM - 32位 x86 汇编语言编译器

xASM 是一个轻量级的 32 位 X86 汇编语言编译器，语法与 BASM 高度兼容。它能够生成极小体积的 Windows 可执行文件（`.com` 或 `.exe`），并支持实模式和保护模式下的代码编译。
通过修改指令集表（位于 `XAsmTable.pas`），还可以轻松扩展支持其他架构（如 ARM、RISC 等）。

**特点：**
- 支持生成极小体积的可执行文件（例如，Hello World 示例仅 444 字节）。
- 提供灵活的宏定义和结构体支持。
- 易于扩展，适合学习底层汇编语言和编译器开发。

## 快速开始
1. 使用编译器编译示例代码
>./xasm HelloWorld.asm<br>

2. 运行生成的可执行文件
>./HelloWorld.exe<br>

## 示例代码：HelloWorld.asm
说明：
此示例展示了如何调用 Windows API (MessageBoxA) 显示一个消息框。编译后生成的 .exe 文件大小仅为 444 字节。
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
说明：
此示例展示了如何动态加载 DLL 并调用多个 API。编译后生成的 .exe 文件大小为 516 字节。
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
说明：
此示例展示了如何通过配置选项生成不同类型的可执行文件（如最小模式或 DLL）。
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
说明：
此示例展示了如何定义结构体和宏，并在代码中使用它们。
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

## 扩展与定制
xASM 的设计目标是灵活性和可扩展性。
您可以通过修改 XAsmTable.pas 文件中的指令集表，轻松实现对其他架构（如 ARM、RISC 等）的支持。
此外，xASM 的模块化设计也使其成为学习编译器开发的理想工具。

## 许可证
本项目采用 MIT 许可证 ，允许任何人自由使用、修改和分发代码。

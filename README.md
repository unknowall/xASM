# xASM a 32bit x86 ASM Compiler

xASM is a lightweight 32-bit X86 assembly language compiler that is highly compatible with BASM syntax. It is capable of generating extremely small Windows executable files (.com or .exe) and supports code compilation in both real mode and protected mode. By modifying the instruction set table (located in XAsmTable.pas), it can easily be extended to support other architectures (such as ARM, RISC, etc.).

Features:
- Supports the generation of extremely small executable files (for example, the Hello World example is only 444 bytes).
- Provides flexible macro definitions and structure support.
- Easy to extend, making it suitable for learning low-level assembly language and compiler development.
- Standalone Execution: A single-file compiler with no external dependencies (.NET/VC runtime not required)

# xASM - 32位 x86 汇编语言编译器

xASM 是一个轻量级的 32 位 X86 汇编语言编译器，语法与 BASM 高度兼容。它能够生成极小体积的 Windows 可执行文件（`.com` 或 `.exe`），并支持实模式和保护模式下的代码编译。
通过修改指令集表（位于 `XAsmTable.pas`），还可以轻松扩展支持其他架构（如 ARM、RISC 等）。

**特点：**
- 支持生成极小体积的可执行文件（例如，Hello World 示例仅 444 字节）。
- 提供灵活的宏定义和结构体支持。
- 易于扩展，适合学习底层汇编语言和编译器开发。
- 独立运行：单文件编译器，无任何外部依赖（无需.NET/VC运行库）

## 快速开始
1. 使用编译器编译示例代码
>./xasm HelloWorld.asm<br>

2. 运行生成的可执行文件
>./HelloWorld.exe<br>

## 示例代码：HelloWorld.asm
说明：
此示例展示了如何调用 Windows API (MessageBoxA) 显示一个消息框。编译后生成的 .exe 文件大小仅为 444 字节。<br>
This example demonstrates how to call the Windows API (MessageBoxA) to display a message box. The compiled .exe file is only 444 bytes in size.
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
此示例展示了如何动态加载 DLL 并调用多个 API。编译后生成的 .exe 文件大小为 516 字节。<br>
This example demonstrates how to dynamically load a DLL and call multiple APIs. The compiled .exe file is 516 bytes in size.
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
此示例展示了如何通过配置选项生成不同类型的可执行文件（如最小模式或 DLL）。<br>
This example demonstrates how to generate different types of executable files (such as minimal mode or DLL) by configuring options.
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
此示例展示了如何定义结构体和宏，并在代码中使用它们。<br>
This example demonstrates how to define structures and macros, and use them in the code.
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

## 技术亮点 (Technical Highlights)
- 编译器 ：完全使用 Pascal 编写，是学习编译器设计原理的理想工具。
- 可扩展架构 ：通过修改指令集表（XAsmTable.pas），可轻松扩展支持 ARM、RISC 等新架构。
- 极小体积可执行文件 ：生成的可执行文件最小仅 444 字节 ，适合底层编程爱好者和极简代码实践。


- Compiler: Written in Pascal, making it an excellent learning tool for understanding compiler design.
- Extensible Architecture: Modify the instruction set table (XAsmTable.pas) to support new architectures like ARM or RISC.
- Minimal Executables: Generate executables as small as 444 bytes , ideal for low-level programming enthusiasts.

## 许可证 (License)
本项目采用 MIT 许可证 ，允许任何人自由使用、修改和分发代码。

This project is licensed under the MIT License, allowing anyone to freely use, modify, and distribute the code.

## 下载
[Release](https://github.com/unknowall/xASM/releases/)

无需安装依赖，**可直接在以下环境运行**：
   - Windows XP ~ 11
   - WinPE/WinRE 维护系统
   - 其他精简版Windows环境

<br>

No dependencies required. Runs directly in:
   - Windows XP to 11
   - WinPE/WinRE maintenance systems
   - Other stripped-down Windows environments


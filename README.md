# xASM a 32bit x86 ASM Compiler
[![MIT License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT) [![Release Version](https://img.shields.io/github/v/release/unknowall/xASM)](https://github.com/unknowall/xASM/releases) [![Platform Support](https://img.shields.io/badge/Platform-Windows%20XP~11-blue)](https://learn.microsoft.com/windows)

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


**编译20423行代码仅需 78 ms (AMD Ryzen3 3550h):**
```asm
xAsm v0.03 - unknowall, sgfree@hotmail.com

Source: http://github.com/unknowall/xAsm

-----------------------------------------------------------

TestPC.asm >> TestPC.exe

20423 Total Lines, 102124 Bytes Code, 0 Bytes Data, 0 Errors.

Compile time: 78 ms
```

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

## 示例代码：const.asm
说明：
此示例展示了常量定义、条件编译和基本算术运算。 .REPEAT 与 .ENDREP 在编译时会将块内代码重复生成 CONST2($100) 次.

This example demonstrates constant definitions, conditional compilation, and basic arithmetic operations. 

The .REPEAT and .ENDREP directives generate the enclosed code block CONST2 ($100) times during compilation.
```asm
// --- 常量与数据定义 ---
// 本文件编译后 1,104 Bytes
.FILEALIGN 4        // 设置文件对齐方式为4字节
.ALIGN 4            // 代码段对齐4字节

@CONST1 VAR $1      // 定义常量1（数值型）
@CONST2 VAR $100    // 定义常量2（数值型）
@CONST3 VAR "This Is Text2" // 字符串常量（未被使用）
txt1&& DB 'Hello World!!'  // 字符串数据（未被使用）
var1&& DD $0        // 初始化双字变量为0

// --- 代码段 ---
showtxt:
 jmp SHORT end      // 跳过中间代码

Start:
 DB $90,$90         // 两个NOP空操作指令
 .IFDEF var1>=$100  // 条件编译检查（因var1=0实际不成立）
 jmp SHORT showtxt
 .ENDIF
 int 3              // 触发调试中断（用于调试）

end:
 mov eax, [var1]    // eax = 0
 mov ebx, @CONST1   // ebx = 1
 add eax, ebx       // eax = 1
 .REPEAT @CONST2    // 编译时展开$100次循环
 add eax, @CONST1   // 每次循环eax += 1
 .ENDREP
 mov [var1], eax    // 最终var1 = 1 + $100*1 = $101
 ret
 ```
##  .FOR 循环指令

**语法**
```asm
.FOR <变量名>=<起始值>,<结束值>[,<步长>]
    ; 循环体代码
.ENDFOR
```
**功能说明**
 - 编译时展开：在编译阶段直接生成展开后的重复代码块
 - 零运行时开销：不产生循环控制指令（DEC/JNZ等）
 - 嵌套支持：支持多层嵌套循环（需配合缩进使用）
 - 参数灵活：支持常量表达式作为参数值

示例 - 生成递增序列
```Asm
; Generate 0-3 with step 1
.FOR i=0,3
    DB &i  ; 展开为 DB 0, DB 1, DB 2, DB 3
.ENDFOR
```
示例 - 颜色渐变生成
```Asm
.FOR rgb=0,255,16
    DB &rgb, &rgb/2, 0     ; R分量渐变
    DD &rgb<<16 | &rgb<<8  ; ARGB格式颜色
.ENDFOR
```
示例 - 矩阵初始化
```Asm
.FOR Y=0,15
    .FOR X=0,15
        DB &Y*16 + &X  ; 生成16x16矩阵(0-255)
    .ENDFOR
.ENDFOR
```
**注意事项**
 - 代码膨胀:循环次数不宜超过100次（典型值），否则可能显著增加最终文件大小

 - 参数限制,  仅支持编译时可确定的常量值，不支持运行时变量
 
  - 特殊字符, 变量名避免使用寄存器名称（EAX/EBX等）和系统保留字

 - 变量作用域, 循环变量仅在当前循环体内有效：

```Asm
.FOR i=0,3
    MOV eax, &i
.ENDFOR
; 此处&i 已失效
```

**性能对比**
| 循环类型 | 10次循环代码量 | 执行周期 |
|----------|----------------|----------|
| .FOR     | 40字节         | N/A      |
| LOOP     | 5字节          | 82周期   |
| REP      | 3字节          | 28周期   |

## 支持的寄存器及编码表

**通用寄存器**
| 寄存器名称 | 编码值 | 位宽  | 用途说明                     |
|------------|--------|-------|------------------------------|
| AL         | 0      | 8-bit | 累加器低8位                  |
| AH         | 4      | 8-bit | 累加器高8位                  |
| AX         | 0      | 16-bit| 16位累加器                   |
| EAX        | 0      | 32-bit| 32位扩展累加器               |
| DL         | 2      | 8-bit | 数据低8位（常用于I/O操作）   |
| DH         | 6      | 8-bit | 数据高8位                    |
| DX         | 2      | 16-bit| 16位数据寄存器               |
| EDX        | 2      | 32-bit| 32位扩展数据寄存器           |
| CL         | 1      | 8-bit | 计数低8位（常用于移位操作）  |
| CH         | 5      | 8-bit | 计数高8位                    |
| CX         | 1      | 16-bit| 16位计数器                   |
| ECX        | 1      | 32-bit| 32位扩展计数器               |
| BL         | 3      | 8-bit | 基址低8位                    |
| BH         | 7      | 8-bit | 基址高8位                    |
| BX         | 3      | 16-bit| 16位基址寄存器               |
| EBX        | 3      | 32-bit| 32位扩展基址寄存器           |
| SI         | 6      | 16-bit| 源索引寄存器                |
| ESI        | 6      | 32-bit| 32位扩展源索引寄存器         |
| DI         | 7      | 16-bit| 目标索引寄存器              |
| EDI        | 7      | 32-bit| 32位扩展目标索引寄存器       |
| SP         | 4      | 16-bit| 堆栈指针寄存器              |
| ESP        | 4      | 32-bit| 32位扩展堆栈指针            |
| BP         | 5      | 16-bit| 基指针寄存器                |
| EBP        | 5      | 32-bit| 32位扩展基指针             |

**MMX 寄存器**
| 寄存器名称 | 编码值 | 位宽  | 用途说明                     |
|------------|--------|-------|------------------------------|
| MM0        | 0      | 64-bit| 多媒体扩展寄存器0           |
| MM1        | 1      | 64-bit| 多媒体扩展寄存器1           |
| MM2        | 2      | 64-bit| 多媒体扩展寄存器2           |
| MM3        | 3      | 64-bit| 多媒体扩展寄存器3           |
| MM4        | 4      | 64-bit| 多媒体扩展寄存器4           |
| MM5        | 5      | 64-bit| 多媒体扩展寄存器5           |
| MM6        | 6      | 64-bit| 多媒体扩展寄存器6           |
| MM7        | 7      | 64-bit| 多媒体扩展寄存器7           |

**SSE 寄存器**
| 寄存器名称 | 编码值 | 位宽   | 用途说明                     |
|------------|--------|--------|------------------------------|
| XMM0       | 0      | 128-bit| 流式SIMD扩展寄存器0         |
| XMM1       | 1      | 128-bit| 流式SIMD扩展寄存器1         |
| XMM2       | 2      | 128-bit| 流式SIMD扩展寄存器2         |
| XMM3       | 3      | 128-bit| 流式SIMD扩展寄存器3         |
| XMM4       | 4      | 128-bit| 流式SIMD扩展寄存器4         |
| XMM5       | 5      | 128-bit| 流式SIMD扩展寄存器5         |
| XMM6       | 6      | 128-bit| 流式SIMD扩展寄存器6         |
| XMM7       | 7      | 128-bit| 流式SIMD扩展寄存器7         |

**FPU 堆栈寄存器**
| 寄存器名称 | 编码值 | 位宽   | 用途说明                     |
|------------|--------|--------|------------------------------|
| ST(0)      | 0      | 80-bit | 浮点运算寄存器0             |
| ST(1)      | 1      | 80-bit | 浮点运算寄存器1             |
| ST(2)      | 2      | 80-bit | 浮点运算寄存器2             |
| ST(3)      | 3      | 80-bit | 浮点运算寄存器3             |
| ST(4)      | 4      | 80-bit | 浮点运算寄存器4             |
| ST(5)      | 5      | 80-bit | 浮点运算寄存器5             |
| ST(6)      | 6      | 80-bit | 浮点运算寄存器6             |
| ST(7)      | 7      | 80-bit | 浮点运算寄存器7             |

**段寄存器**
| 寄存器名称 | 编码值 | 位宽   | 用途说明                              |
|------------|--------|--------|---------------------------------------|
| ES         | 0      | 16-bit | 附加段寄存器       |
| CS         | 1      | 16-bit | 代码段寄存器                          |
| SS         | 2      | 16-bit | 堆栈段寄存器                          |
| DS         | 3      | 16-bit | 数据段寄存器                          |
| FS         | 4      | 16-bit | 附加段寄存器    |
| GS         | 5      | 16-bit | 附加段寄存器 |

**控制寄存器**
| 寄存器名称 | 编码值 | 位宽    | 用途说明                              |
|------------|--------|---------|---------------------------------------|
| CR0        | 0      | 32-bit  | 控制处理器基本功能     |
| CR1        | 1      | 32-bit  | 保留未使用                             |
| CR2        | 2      | 32-bit  | 页故障线性地址寄存器                   |
| CR3        | 3      | 32-bit  | 页目录基址寄存器                       |
| CR4        | 4      | 32-bit  | 控制处理器扩展功能    |
| CR5-CR7    | 5-7    | 32-bit  | 保留未使用    |

**调试寄存器**
| 寄存器名称 | 编码值 | 位宽    | 用途说明                              |
|------------|--------|---------|---------------------------------------|
| DR0        | 0      | 32-bit  | 调试地址寄存器0（断点地址）            |
| DR1        | 1      | 32-bit  | 调试地址寄存器1                        |
| DR2        | 2      | 32-bit  | 调试地址寄存器2                        |
| DR3        | 3      | 32-bit  | 调试地址寄存器3                        |
| DR4        | 4      | 32-bit  | 保留（与 DR6 重叠）                    |
| DR5        | 5      | 32-bit  | 保留（与 DR7 重叠）                    |
| DR6        | 6      | 32-bit  | 调试状态寄存器（断点命中状态）         |
| DR7        | 7      | 32-bit  | 调试控制寄存器（断点条件设置）         |

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


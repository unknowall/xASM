# xASM a 32bit x86 ASM Compiler
[![MIT License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT) [![Release Version](https://img.shields.io/github/v/release/unknowall/xASM)](https://github.com/unknowall/xASM/releases) [![Platform Support](https://img.shields.io/badge/Platform-Windows%20XP~11-blue)](https://learn.microsoft.com/windows)

<details>
<summary><h3> 🌐 English Version</h3></summary>
xASM is a lightweight 32-bit x86 assembly language compiler with high compatibility to BASM syntax. It generates compact Windows executables (`.com` or `.exe`) and supports both real mode and protected mode compilation. The architecture can be easily extended to support other platforms (e.g., ARM, RISC) by modifying the instruction set table (`XAsmTable.pas`).

## Features:
- **Ultra-Compact Executables**: The Hello World example compiles to just 444 bytes.
- **Macro and Structure Support**: Flexible macro definitions and structure implementation.
- **Extensible Architecture**: Easy to modify, making it ideal for learning low-level assembly and compiler development.
- **Zero Dependencies**: A single-file compiler with no runtime support libraries required.
- **Rapid Compilation**: On an AMD Ryzen3 3550h, 20,423 lines of code compile in just 78 milliseconds.
- **Pascal Implementation**: Fully written in Pascal, suitable for educational purposes in compiler design.
- **Debugging Support**: Detailed error reporting with line-specific diagnostic information.
- **Advanced Directives**:
   - `.REPEAT/.ENDREP`: Compile-time code expansion.
   - `.IFDEF`: Conditional compilation.
   - `.FOR`: Compile-time loops with zero runtime overhead.

## Quick Start
Compile sample code:
```BASH
   ./xasm HelloWorld.asm
```
Run generated executable:
```BASH
   ./HelloWorld.exe
```
   
## Example: HelloWorld.asm
This example demonstrates how to call the Windows API (MessageBoxA) to display a message box. The compiled .exe file is only 444 bytes in size.
```Asm
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

## Example: API.asm
This example demonstrates how to dynamically load a DLL and call multiple APIs. The compiled .exe file is 516 bytes in size.
```asm
.FILEALIGN 4

// Note: Different DLLs must use .IMPORT separately.
// After definition, the API name will become a Label.
// Use the API by calling CALL A[API name].
// This file is 516 bytes after compilation.

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

## Example: Option.asm
This example demonstrates how to generate different types of executable files (such as minimal mode or DLL) by configuring options.
```asm
.FILEALIGN 4          // File alignment
.IMAGEBASE $400000    // Image base address
.TINYPE               // Compile in minimal (tiny) mode
//.DLLMODE           // Compile as a DLL
.SUBSYSTEM 2          // Set subsystem, GUI == 2, CONSOLE == 3

Start:
.BUILDMSG A message is generated when compiling reaches this point
 ret
 ```

## Example: m-s.asm
This example demonstrates how to define structures and macros, and use them in the code.
```asm
.FILEALIGN 4          // Align file sections to a 4-byte boundary.
                       // This ensures efficient memory usage and alignment.

// After compilation, this file is 320 bytes in size.

.ALIGN 2              // Align the following data structure to a 2-byte boundary.
struct1: STRUCT       // Define a structure named `struct1`.
FieldDB: DB $90 DIV $90   // Define a byte field (8 bits), initialized to $90 divided by $90 (result: 1).
FieldDW: DW $9090 SHR 10  // Define a word field (16 bits), initialized to $9090 shifted right by 10 bits (result: 0x0090).
FieldDD: DD $90909090 / 2 // Define a double-word field (32 bits), initialized to $90909090 divided by 2 (result: 0x48484848).
FieldDQ: DQ $90909090 * 2 // Define a quad-word field (64 bits), initialized to $90909090 multiplied by 2 (result: 0x1212121212121212).
END                   // End of the structure definition.

.ALIGN 4              // Align the following macro definition to a 4-byte boundary.
macro1: MACRO param1=0, param2=0  // Define a macro named `macro1` with two optional parameters (`param1` and `param2`), defaulting to 0 if not provided.
 mov eax, &param1      // Move the value of `param1` into the EAX register. The `&` operator dereferences the parameter.
 mov ebx, &param2      // Move the value of `param2` into the EBX register.
 mov ecx, DWORD PTR [struct1.FieldDB]  // Load the value of `struct1.FieldDB` (byte) into the ECX register, treating it as a double-word.
 add ecx, eax          // Add the value of EAX (param1) to ECX.
 add ecx, ebx          // Add the value of EBX (param2) to ECX.
 mov DWORD PTR [struct1.FieldDW], ecx  // Store the result (ECX) into `struct1.FieldDW` (word), treating it as a double-word.
END                    // End of the macro definition.

Start:                // Entry point of the program.
 macro1 param1=$100, param2=1  // Invoke the `macro1` macro with `param1` set to $100 (hexadecimal 256) and `param2` set to 1.
 ret                   // Return from the program.
 ```

## Example: const.asm
This example demonstrates constant definitions, conditional compilation, and basic arithmetic operations. 

The .REPEAT and .ENDREP directives generate the enclosed code block CONST2 ($100) times during compilation.
```asm
// --- Constants and Data Definitions ---
// After compilation, this file is 1,104 bytes in size.
.FILEALIGN 4        // Set file alignment to 4 bytes for efficient memory usage.
.ALIGN 4            // Align the code section to a 4-byte boundary.

@CONST1 VAR $1      // Define constant @CONST1 with a numeric value of 1.
@CONST2 VAR $100    // Define constant @CONST2 with a numeric value of 256 (hexadecimal $100).
@CONST3 VAR "This Is Text2" // Define a string constant @CONST3 (not used in the code).
txt1&& DB 'Hello World!!'  // Define a string data block containing "Hello World!!" (not used in the code).
var1&& DD $0        // Initialize a double-word variable var1 with a value of 0.

// --- Code Section ---
showtxt:
 jmp SHORT end      // Jump to the label 'end', skipping intermediate code.

Start:
 DB $90,$90         // Insert two NOP (No Operation) instructions. These do nothing but take up space.
 .IFDEF var1>=$100  // Conditional compilation check: If var1 >= $100, include the following code.
                     // This condition is not true because var1 is initialized to 0.
 jmp SHORT showtxt  // Jump to the label 'showtxt'.
 .ENDIF
 int 3              // Trigger a debug interrupt (used for debugging purposes).

end:
 mov eax, [var1]    // Load the value of var1 (0) into the EAX register.
 mov ebx, @CONST1   // Load the value of @CONST1 (1) into the EBX register.
 add eax, ebx       // Add EBX (1) to EAX (0), resulting in EAX = 1.
 .REPEAT @CONST2    // Repeat the following block of code @CONST2 times (256 times, as @CONST2 = $100).
 add eax, @CONST1   // Add @CONST1 (1) to EAX during each iteration.
 .ENDREP
 mov [var1], eax    // Store the final value of EAX ($101, or 257 in decimal) back into var1.
 ret                // Return from the program.
 ```

## .FOR Loop Directive

**Syntax**
```asm
.FOR <variable_name>=<start_value>,<end_value>[,<step>]
    ; Loop body code
.ENDFOR
```

**Function Description**
 - **Compile-Time Expansion**: The loop is expanded into repeated code blocks during the compilation phase.
 - **Zero Runtime Overhead**: No loop control instructions (e.g., `DEC/JNZ`) are generated, resulting in no runtime overhead.
 - **Nested Support**: Supports multi-level nested loops (indentation is recommended for clarity).
 - **Flexible Parameters**: Accepts constant expressions as parameter values.

### Example - Generating an Incremental Sequence
```asm
; Generate 0-3 with step 1
.FOR i=0,3
    DB &i  ; Expands to DB 0, DB 1, DB 2, DB 3
.ENDFOR
```

### Example - Gradient Color Generation
```asm
.FOR rgb=0,255,16
    DB &rgb, &rgb/2, 0     ; Red component gradient
    DD &rgb<<16 | &rgb<<8  ; ARGB format color
.ENDFOR
```

### Example - Matrix Initialization
```asm
.FOR Y=0,15
    .FOR X=0,15
        DB &Y*16 + &X  ; Generates a 16x16 matrix (0-255)
    .ENDFOR
.ENDFOR
```

**Notes**
 - **Code Bloat**: The number of iterations should not exceed 100 (typical value), as it may significantly increase the final file size.
 - **Parameter Restrictions**: Only supports compile-time constant values. Runtime variables are not allowed.
 - **Special Characters**: Avoid using register names (e.g., `EAX`, `EBX`) and system reserved words as variable names.
 - **Variable Scope**: The loop variable is only valid within the current loop body:

```asm
.FOR i=0,3
    MOV eax, &i
.ENDFOR
; Here, &i is no longer valid
```

**Performance Comparison**
| Loop Type | Code Size for 10 Iterations | Execution Cycles |
|-----------|-----------------------------|------------------|
| .FOR      | 40 bytes                    | N/A              |
| LOOP      | 5 bytes                     | 82 cycles        |
| REP       | 3 bytes                     | 28 cycles        |

## Supported Registers and Encoding Table

**General-Purpose Registers**
| Register Name | Encoding Value | Bit Width | Description                     |
|---------------|----------------|-----------|---------------------------------|
| AL            | 0              | 8-bit     | Lower 8 bits of the accumulator |
| AH            | 4              | 8-bit     | Upper 8 bits of the accumulator |
| AX            | 0              | 16-bit    | 16-bit accumulator              |
| EAX           | 0              | 32-bit    | 32-bit extended accumulator     |
| DL            | 2              | 8-bit     | Lower 8 bits of data (commonly used for I/O operations) |
| DH            | 6              | 8-bit     | Upper 8 bits of data            |
| DX            | 2              | 16-bit    | 16-bit data register            |
| EDX           | 2              | 32-bit    | 32-bit extended data register   |
| CL            | 1              | 8-bit     | Lower 8 bits of the counter (commonly used for shift operations) |
| CH            | 5              | 8-bit     | Upper 8 bits of the counter     |
| CX            | 1              | 16-bit    | 16-bit counter                  |
| ECX           | 1              | 32-bit    | 32-bit extended counter         |
| BL            | 3              | 8-bit     | Lower 8 bits of the base        |
| BH            | 7              | 8-bit     | Upper 8 bits of the base        |
| BX            | 3              | 16-bit    | 16-bit base register            |
| EBX           | 3              | 32-bit    | 32-bit extended base register   |
| SI            | 6              | 16-bit    | Source index register           |
| ESI           | 6              | 32-bit    | 32-bit extended source index register |
| DI            | 7              | 16-bit    | Destination index register      |
| EDI           | 7              | 32-bit    | 32-bit extended destination index register |
| SP            | 4              | 16-bit    | Stack pointer register          |
| ESP           | 4              | 32-bit    | 32-bit extended stack pointer   |
| BP            | 5              | 16-bit    | Base pointer register           |
| EBP           | 5              | 32-bit    | 32-bit extended base pointer    |

**MMX Registers**
| Register Name | Encoding Value | Bit Width | Description                     |
|---------------|----------------|-----------|---------------------------------|
| MM0           | 0              | 64-bit    | Multimedia extension register 0|
| MM1           | 1              | 64-bit    | Multimedia extension register 1|
| MM2           | 2              | 64-bit    | Multimedia extension register 2|
| MM3           | 3              | 64-bit    | Multimedia extension register 3|
| MM4           | 4              | 64-bit    | Multimedia extension register 4|
| MM5           | 5              | 64-bit    | Multimedia extension register 5|
| MM6           | 6              | 64-bit    | Multimedia extension register 6|
| MM7           | 7              | 64-bit    | Multimedia extension register 7|

**SSE Registers**
| Register Name | Encoding Value | Bit Width  | Description                     |
|---------------|----------------|------------|---------------------------------|
| XMM0          | 0              | 128-bit    | Streaming SIMD extension register 0 |
| XMM1          | 1              | 128-bit    | Streaming SIMD extension register 1 |
| XMM2          | 2              | 128-bit    | Streaming SIMD extension register 2 |
| XMM3          | 3              | 128-bit    | Streaming SIMD extension register 3 |
| XMM4          | 4              | 128-bit    | Streaming SIMD extension register 4 |
| XMM5          | 5              | 128-bit    | Streaming SIMD extension register 5 |
| XMM6          | 6              | 128-bit    | Streaming SIMD extension register 6 |
| XMM7          | 7              | 128-bit    | Streaming SIMD extension register 7 |

**FPU Stack Registers**
| Register Name | Encoding Value | Bit Width  | Description                     |
|---------------|----------------|------------|---------------------------------|
| ST(0)         | 0              | 80-bit     | Floating-point register 0       |
| ST(1)         | 1              | 80-bit     | Floating-point register 1       |
| ST(2)         | 2              | 80-bit     | Floating-point register 2       |
| ST(3)         | 3              | 80-bit     | Floating-point register 3       |
| ST(4)         | 4              | 80-bit     | Floating-point register 4       |
| ST(5)         | 5              | 80-bit     | Floating-point register 5       |
| ST(6)         | 6              | 80-bit     | Floating-point register 6       |
| ST(7)         | 7              | 80-bit     | Floating-point register 7       |

**Segment Registers**
| Register Name | Encoding Value | Bit Width  | Description                     |
|---------------|----------------|------------|---------------------------------|
| ES            | 0              | 16-bit     | Extra segment register          |
| CS            | 1              | 16-bit     | Code segment register           |
| SS            | 2              | 16-bit     | Stack segment register          |
| DS            | 3              | 16-bit     | Data segment register           |
| FS            | 4              | 16-bit     | Extra segment register          |
| GS            | 5              | 16-bit     | Extra segment register          |

**Control Registers**
| Register Name | Encoding Value | Bit Width  | Description                     |
|---------------|----------------|------------|---------------------------------|
| CR0           | 0              | 32-bit     | Controls basic processor functions |
| CR1           | 1              | 32-bit     | Reserved (unused)               |
| CR2           | 2              | 32-bit     | Page fault linear address register |
| CR3           | 3              | 32-bit     | Page directory base register    |
| CR4           | 4              | 32-bit     | Controls extended processor functions |
| CR5-CR7       | 5-7            | 32-bit     | Reserved (unused)               |

**Debug Registers**
| Register Name | Encoding Value | Bit Width  | Description                     |
|---------------|----------------|------------|---------------------------------|
| DR0           | 0              | 32-bit     | Debug address register 0 (breakpoint address) |
| DR1           | 1              | 32-bit     | Debug address register 1         |
| DR2           | 2              | 32-bit     | Debug address register 2         |
| DR3           | 3              | 32-bit     | Debug address register 3         |
| DR4           | 4              | 32-bit     | Reserved (overlaps with DR6)     |
| DR5           | 5              | 32-bit     | Reserved (overlaps with DR7)     |
| DR6           | 6              | 32-bit     | Debug status register (breakpoint hit status) |
| DR7           | 7              | 32-bit     | Debug control register (breakpoint condition settings) |

## Release
[Release](https://github.com/unknowall/xASM/releases/)

No dependencies are required, **can run directly in the following environments**:
   - Windows XP ~ 11
   - WinPE/WinRE maintenance systems
   - Other lightweight Windows environments


</details>

# xASM - 32位 x86 汇编语言编译器

xASM 是一个轻量级的 32 位 X86 汇编语言编译器，语法与 BASM 高度兼容。它能够生成极小体积的 Windows 可执行文件（`.com` 或 `.exe`），并支持实模式和保护模式下的代码编译。
通过修改指令集表（位于 `XAsmTable.pas`），还可以轻松扩展支持其他架构（如 ARM、RISC 等）。

## 特点：
- 超紧凑可执行文件：Hello World 示例编译后仅 444 字节。
- 宏与结构体支持：灵活的宏定义和结构体实现。
- 可扩展架构：易于修改，适合学习底层汇编和编译器开发。
- 零依赖：单文件编译器，无需运行时支持库。
- 快速编译：在 AMD Ryzen3 3550h 上，20,423 行代码仅需 78 毫秒完成编译。
- Pascal 实现：完全用 Pascal 编写，适用于教育目的的编译器设计。
- 调试支持：详细的错误报告，带有针对特定行的诊断信息。
- 高级指令：
   - .REPEAT/.ENDREP：编译时代码展开。
   - .IFDEF：条件编译。
   - .FOR：编译时循环，无任何运行时开销。

**编译20423行代码仅需 78 ms (AMD Ryzen3 3550h):**
```asm
xAsm v0.03 - unknowall, sgfree@hotmail.com

Source: http://github.com/unknowall/xAsm

-----------------------------------------------------------

TestPC.asm >> TestPC.exe

20423 Total Lines, 102124 Bytes Code, 0 Bytes Data, 0 Errors.

Compile time: 78 ms
```
**详细的错误提示：**
```asm
xAsm 0.04

Sources: http://github.com/unknowall/xAsm

Maintainer: unknowall, sgfree@hotmail.com

-----------------------------------------------------------

Compiling:

   HelloWorlderr.asm >> HelloWorlderr.exe

Errors:

   Line 00007: Unterminated string
   Line 00011(18): Parameter title1 not found
   Line 00011(18): Operands are not matching to instruction op
   Line 00013(18): Parameter handle1 not found
   Line 00013(18): Operands are not matching to instruction op
   Line 00014(18): Waiting for ']'

Summary:

    Total Errors: 6

    Compile time: 0 ms
```

## 快速开始
1. 使用编译器编译示例代码
```BASH
./xasm HelloWorld.asm
```
2. 运行生成的可执行文件
```BASH
./HelloWorld.exe
```
## 示例代码：HelloWorld.asm
说明：
此示例展示了如何调用 Windows API (MessageBoxA) 显示一个消息框。编译后生成的 .exe 文件大小仅为 444 字节。<br>
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
```asm
.FILEALIGN 4

//不同 DLL 需分别用 .IMPORT 声明
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
```asm
.FILEALIGN 4          // 设置文件对齐方式为4字节，确保生成的文件在内存中按4字节对齐，提高加载效率。

// 本文件编译后 320 Bytes

.ALIGN 2              // 将结构体 `struct1` 的起始地址对齐到2字节边界。
struct1: STRUCT       // 定义一个名为 `struct1` 的结构体。
FieldDB: DB $90 DIV $90   // 定义一个字节字段 `FieldDB`，初始化为 `$90 DIV $90`，结果为1。
FieldDW: DW $9090 SHR 10  // 定义一个字字段 `FieldDW`，初始化为 `$9090 SHR 10`，右移10位，结果为0x0090。
FieldDD: DD $90909090 / 2 // 定义一个双字字段 `FieldDD`，初始化为 `$90909090 / 2`，结果为0x48484848。
FieldDQ: DQ $90909090 * 2 // 定义一个四字字段 `FieldDQ`，初始化为 `$90909090 * 2`，结果为0x1212121212121212。
END                   // 结束结构体定义。

.ALIGN 4              // 将宏 `macro1` 的起始地址对齐到4字节边界。
macro1: MACRO param1=0, param2=0  // 定义一个宏 `macro1`，带有两个可选参数 `param1` 和 `param2`，默认值均为0。
 mov eax, &param1      // 将参数 `param1` 的值加载到寄存器 `eax` 中。
 mov ebx, &param2      // 将参数 `param2` 的值加载到寄存器 `ebx` 中。
 mov ecx, DWORD PTR [struct1.FieldDB]  // 将结构体 `struct1` 的 `FieldDB` 字段值加载到寄存器 `ecx` 中，并将其视为双字。
 add ecx, eax          // 将寄存器 `eax` 的值（即 `param1`）加到寄存器 `ecx` 中。
 add ecx, ebx          // 将寄存器 `ebx` 的值（即 `param2`）加到寄存器 `ecx` 中。
 mov DWORD PTR [struct1.FieldDW], ecx  // 将寄存器 `ecx` 的值存储回结构体 `struct1` 的 `FieldDW` 字段中，并将其视为双字。
END                    // 结束宏定义。

Start:                // 程序入口点。
 macro1 param1=$100, param2=1  // 调用宏 `macro1`，传入参数 `param1` 为 `$100`（十六进制256），`param2` 为1。
 ret                   // 返回，结束程序。
 ```

## 示例代码：const.asm
说明：
此示例展示了常量定义、条件编译和基本算术运算。 .REPEAT 与 .ENDREP 在编译时会将块内代码重复生成 CONST2($100) 次.
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
 - 嵌套支持：支持多层嵌套循环（建议使用缩进以提高可读性）
 - 参数灵活：支持常量表达式作为参数值

示例 - 生成递增序列
```Asm
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
| 循环类型 | 10次循环代码量 | 执行所需 CPU 周期数 |
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

## 下载
[Release](https://github.com/unknowall/xASM/releases/)

无需安装依赖，**可直接在以下环境运行**：
   - Windows XP ~ 11
   - WinPE/WinRE 维护系统
   - 其他精简版Windows环境

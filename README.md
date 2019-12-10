# FES Compiler- Forth Entertainment System Compiler
Compile a Forth like programming language (+ some small additions) to 6502 Assembly (specifically for the NES (Nintendo Entertainment System).

EDIT:
Work in progress, not usable yet.
Because [Nim](https://nim-lang.org/) is not on version 1.0 yet, there are still breaking changes between
versions. Some changes made from Nim 0.18 to 0.20 breaks a lot of tests (methods do not support generics
any more for example). This will require a smaller rewrite.
Additionally certain language features (structs and lists) which are not part of Forth are also not fixed yet.

The [Nimes](https://github.com/def-/nimes) emulator is used for testing.
Check out 'tests/emu_tests.nim' to see some test cases.


Example:
The NES has an option to intensify the red, green, or blue color effectively
tinting the screen. We check if b, a, or start is pressed and tint the screen
accordingly.

```
begin true while
  read_inputs
    input1 b_pressed? set_intensify_reds
    input1 a_pressed? set_intensify_greens
    input1 start_pressed? set_intensify_blues
end
```

Generated 6502 assembly (nesasm):

```
; INES header setup

  .inesprg 1
  .ineschr 1
  .inesmir 1
  .inesmap 0

  .org $8000
  .bank 0

Start:
  LDA #$FF
  TAX
begin_while0:
  JSR true
  CLC
  ASL A
  BCC end_while0
  LDA $0200,X
  INX
begin_then_while0:
  JSR read_inputs
  DEX
  STA $0200,X
  LDA #$00
  DEX
  STA $0200,X
  LDA #$00
  JSR b_pressedis
  JSR set_intensify_reds
  DEX
  STA $0200,X
  LDA #$00
  DEX
  STA $0200,X
  LDA #$00
  JSR a_pressedis
  JSR set_intensify_greens
  DEX
  STA $0200,X
  LDA #$00
  DEX
  STA $0200,X
  LDA #$00
  JSR start_pressedis
  JSR set_intensify_blues
  JMP begin_while0
end_while0:
  LDA $0200,X
  INX
  JMP End
true:
  DEX
  STA $0200,X
  LDA #$FF
  RTS
swap:
  LDY $0200,X
  STA $0200,X
  TYA
  RTS
and:
  AND $0200,X
  INX
  RTS
or:
  ORA $0200,X
  INX
  RTS
store_var:
  STA $FF
  LDA $0200,X
  STA $FE
  INX
  LDA $0200,X
  LDY #$00
  STA [$FE],Y
  INX
  LDA $0200,X
  INX
  RTS
load_var:
  STA $FF
  LDA $0200,X
  STA $FE
  LDY #$00
  LDA [$FE],Y
  INX
  RTS
read_inputs:
  JSR read_inputs1
  JSR read_inputs2
  RTS
a_pressedis:
  JSR get_Input_ByteValue
  DEX
  STA $0200,X
  LDA #$80
  JSR bit_setis
  RTS
b_pressedis:
  JSR get_Input_ByteValue
  DEX
  STA $0200,X
  LDA #$40
  JSR bit_setis
  RTS
start_pressedis:
  JSR get_Input_ByteValue
  DEX
  STA $0200,X
  LDA #$10
  JSR bit_setis
  RTS
read_inputs1:
  DEX
  STA $0200,X
  LDA #$01
  STA $4016
  STA $FE
  LSR a
  STA $4016
read_inputs_loop:
  LDA $4016
  LSR a
  ROL $FE
  BCC read_inputs_loop
  LDA $FE
  DEX
  STA $0200,X
  LDA #$00
  DEX
  STA $0200,X
  LDA #$00
  JSR set_Input_ByteValue
  RTS
read_inputs2:
  DEX
  STA $0200,X
  LDA #$01
  STA $4017
  STA $FE
  LSR a
  STA $4017
read_inputs_loop2:
  LDA $4017
  LSR a
  ROL $FE
  BCC read_inputs_loop2
  LDA $FE
  DEX
  STA $0200,X
  LDA #$01
  DEX
  STA $0200,X
  LDA #$00
  JSR set_Input_ByteValue
  RTS
bit_setis:
  JSR swap
  STA $FD
  JSR swap
  BIT $FD
  BEQ bit_set_false
bit_set_true:
  LDA #$FF
  JMP bit_set_done
bit_set_false:
  LDA #$00
bit_set_done:
  INX
  RTS
set_intensify_blues:
begin_if0:
  CLC
  ASL A
  BCC begin_else0
begin_then0:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$03
  DEX
  STA $0200,X
  LDA #$00
  JSR load_var
  DEX
  STA $0200,X
  LDA #$80
  JSR or
  JMP end_if0
begin_else0:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$03
  DEX
  STA $0200,X
  LDA #$00
  JSR load_var
  DEX
  STA $0200,X
  LDA #$7F
  JSR and
end_if0:
  STA $2001
  DEX
  STA $0200,X
  LDA #$03
  DEX
  STA $0200,X
  LDA #$00
  JSR store_var
  RTS
set_intensify_greens:
begin_if1:
  CLC
  ASL A
  BCC begin_else1
begin_then1:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$03
  DEX
  STA $0200,X
  LDA #$00
  JSR load_var
  DEX
  STA $0200,X
  LDA #$40
  JSR or
  JMP end_if1
begin_else1:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$03
  DEX
  STA $0200,X
  LDA #$00
  JSR load_var
  DEX
  STA $0200,X
  LDA #$BF
  JSR and
end_if1:
  STA $2001
  DEX
  STA $0200,X
  LDA #$03
  DEX
  STA $0200,X
  LDA #$00
  JSR store_var
  RTS
set_intensify_reds:
begin_if2:
  CLC
  ASL A
  BCC begin_else2
begin_then2:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$03
  DEX
  STA $0200,X
  LDA #$00
  JSR load_var
  DEX
  STA $0200,X
  LDA #$20
  JSR or
  JMP end_if2
begin_else2:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$03
  DEX
  STA $0200,X
  LDA #$00
  JSR load_var
  DEX
  STA $0200,X
  LDA #$DF
  JSR and
end_if2:
  STA $2001
  DEX
  STA $0200,X
  LDA #$03
  DEX
  STA $0200,X
  LDA #$00
  JSR store_var
  RTS
get_Input_ByteValue:
  STA $FF
  LDA $0200,X
  STA $FE
  INX
  LDY #$00
  LDA [$FE],Y
  RTS
set_Input_ByteValue:
  STA $FF
  LDA $0200,X
  STA $FE
  INX
  LDA $0200,X
  INX
  LDY #$00
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
End:
  JMP End

  .bank 1
  .org $FFFA
  .dw 0
  .dw Start
  .dw 0

  .bank 2
  .org $0000
```



## Getting Started

### Prerequisites

### Installing

## Usage


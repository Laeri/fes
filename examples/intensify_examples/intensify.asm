; INES header setup

  .inesprg 1
  .ineschr 0
  .inesmir 1
  .inesmap 0

  .org $8000
  .bank 0

Start:
  LDA #$FF
  TAX
begin_while1:
  JSR true
  ASL A
  BCS no_jump_end_while10
  JMP end_while1
no_jump_end_while10:
  LDA $0200,X
  INX
begin_then_while1:
  DEX
  STA $0200,X
  LDA #$03
  JSR load_var
  DEX
  STA $0200,X
  LDA #$FF
  JSR equal
begin_if1:
  CLC
  ASL A
  BCC begin_else1
begin_then1:
  LDA $0200,X
  INX
  JSR true
  JSR set_intensify_reds
  JMP end_if1
begin_else1:
  LDA $0200,X
  INX
  JSR false
  JSR set_intensify_reds
end_if1:
  DEX
  STA $0200,X
  LDA #$02
  JSR load_var
  DEX
  STA $0200,X
  LDA #$01
  JSR add
  JSR dup
  DEX
  STA $0200,X
  LDA #$02
  JSR store_var
  DEX
  STA $0200,X
  LDA #$FF
  JSR equal
begin_if2:
  CLC
  ASL A
  BCC begin_else2
begin_then2:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$00
  DEX
  STA $0200,X
  LDA #$02
  JSR store_var
  DEX
  STA $0200,X
  LDA #$03
  JSR load_var
  DEX
  STA $0200,X
  LDA #$01
  JSR add
  DEX
  STA $0200,X
  LDA #$03
  JSR store_var
  JMP end_if2
begin_else2:
  LDA $0200,X
  INX
end_if2:
  JMP begin_while1
end_while1:
  LDA $0200,X
  INX
  JMP End
true:
  DEX
  STA $0200,X
  LDA #$FF
  RTS
false:
  DEX
  STA $0200,X
  LDA #$00
  RTS
dup:
  DEX
  STA $0200,X
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
  STA $FE
  LDA $0200,X
  STX $FD
  LDX $FE
  STA $00,X
  LDX $FE
  INX
  LDA $0200,X
  INX
  RTS
load_var:
  STX $FE
  TAX
  LDA $00,X
  LDX $FE
  RTS
add:
  CLC
  ADC $0200,X
  INX
  RTS
equal:
  CMP $0200,X
  BEQ equal_true
  LDA #$00
  JMP equal_done
equal_true:
  LDA #$FF
equal_done:
  INX
  RTS
set_intensify_reds:
begin_if3:
  CLC
  ASL A
  BCC begin_else3
begin_then3:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$01
  JSR load_var
  DEX
  STA $0200,X
  LDA #$20
  JSR or
  JMP end_if3
begin_else3:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$01
  JSR load_var
  DEX
  STA $0200,X
  LDA #$DF
  JSR and
end_if3:
  STA $2001
  DEX
  STA $0200,X
  LDA #$01
  JSR store_var
  RTS
End:
  JMP End

  .bank 1
  .org $FFFA
  .dw 0
  .dw Start
  .dw 0
  
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
  JSR true
  JSR set_intensify_greens
  JMP End
true:
  DEX
  STA $0200,X
  LDA #$FF
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
  TAY
  LDA $0200,X
  STA $00,Y
  INX
  LDA $0200,X
  INX
  RTS
load_var:
  TAY
  LDA $00,Y
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
  LDA #$01
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
  LDA #$01
  JSR load_var
  DEX
  STA $0200,X
  LDA #$BF
  JSR and
end_if1:
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
  
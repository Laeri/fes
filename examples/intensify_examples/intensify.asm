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
false:
  DEX
  STA $0200,X
  LDA #$00
  RTS
mul:
  LDY $0200,X
  LSR a
  STA $FC
  STY $FD
  LDA #$0
  LDY #$8
mul_loop:
  BCC mul_noadd
  CLC
  ADC $FD
mul_noadd:
  ROR a
  ROR $FC
  DEY
  BNE mul_loop
  LDA $FC
  INX
  RTS
  RTS
div:
  STA $FA
  LDA $0200,X
  INX
  LDY #$00
  SEC
div_one:
  SBC $FA
  BCC div_two
  INY
  BNE div_one
div_two:
  TYA
  RTS
mod:
  STA $FA
  LDA $0200,X
  INX
  LDY #$00
  SEC
mod_one:
  SBC $FA
  BCC mod_two
  INY
  BNE mod_one
mod_two:
  CLC
  ADC $FA
  RTS
dup:
  DEX
  STA $0200,X
  RTS
drop:
  LDA $0200,X
  INX
  RTS
nip:
  INX
  RTS
swap:
  LDY $0200,X
  STA $0200,X
  TYA
  RTS
rot:
  LDY $0200,X
  STA $0200,X
  INX
  TYA
  LDY $0200,X
  STA $0200,X
  DEX
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
xor:
  EOR $0200,X
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
add:
  CLC
  ADC $0200,X
  INX
  RTS
sub:
  SEC
  LDY $0200,X
  STA $0200,X
  TYA
  SBC $0200,X
  INX
  RTS
not:
  EOR #$FF
  RTS
negate:
  DEX
  STA $0200,X
  LDA #$00
  JSR swap
  JSR sub
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
smaller:
  CMP $0200,X
  BCS smaller_true
  LDA #$00
  JMP smaller_done
smaller_true:
  LDA #$FF
smaller_done:
  INX
  RTS
greater:
  CMP $0200,X
  BMI greater_true
  BEQ greater_true
greater_false:
  LDA #$00
  JMP greater_done
greater_true:
  LDA #$FF
greater_done:
  INX
  RTS
greater_or_equal:
  JSR smaller
  JSR not
  RTS
smaller_or_equal:
  JSR greater
  JSR not
  RTS
not_equal:
  JSR equal
  JSR not
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
  LDA #$80
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
  LDA #$7F
  JSR and
end_if1:
  STA $2001
  DEX
  STA $0200,X
  LDA #$01
  JSR store_var
  RTS
intensify_bluesis:
  DEX
  STA $0200,X
  LDA #$01
  JSR load_var
  DEX
  STA $0200,X
  LDA #$80
  JSR bit_setis
  RTS
set_intensify_greens:
begin_if2:
  CLC
  ASL A
  BCC begin_else2
begin_then2:
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
  JMP end_if2
begin_else2:
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
end_if2:
  STA $2001
  DEX
  STA $0200,X
  LDA #$01
  JSR store_var
  RTS
intensify_greensis:
  DEX
  STA $0200,X
  LDA #$01
  JSR load_var
  DEX
  STA $0200,X
  LDA #$40
  JSR bit_setis
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
intensify_redsis:
  DEX
  STA $0200,X
  LDA #$01
  JSR load_var
  DEX
  STA $0200,X
  LDA #$20
  JSR bit_setis
  RTS
get_PaletteData_bg0:
  STA $FE
  LDY #$00
  LDA [$FE],Y
  RTS
get_PaletteData_bg1:
  STA $FE
  LDY #$01
  LDA [$FE],Y
  RTS
get_PaletteData_bg2:
  STA $FE
  LDY #$02
  LDA [$FE],Y
  RTS
get_PaletteData_bg3:
  STA $FE
  LDY #$03
  LDA [$FE],Y
  RTS
get_PaletteData_s0:
  STA $FE
  LDY #$04
  LDA [$FE],Y
  RTS
get_PaletteData_s1:
  STA $FE
  LDY #$05
  LDA [$FE],Y
  RTS
get_PaletteData_s2:
  STA $FE
  LDY #$06
  LDA [$FE],Y
  RTS
get_PaletteData_s3:
  STA $FE
  LDY #$07
  LDA [$FE],Y
  RTS
get_Palette_col0:
  STA $FE
  LDY #$00
  LDA [$FE],Y
  RTS
get_Palette_col1:
  STA $FE
  LDY #$01
  LDA [$FE],Y
  RTS
get_Palette_col2:
  STA $FE
  LDY #$02
  LDA [$FE],Y
  RTS
set_PaletteData_bg0:
  STA $FE
  LDA $0200,X
  INX
  LDY #$00
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_PaletteData_bg1:
  STA $FE
  LDA $0200,X
  INX
  LDY #$01
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_PaletteData_bg2:
  STA $FE
  LDA $0200,X
  INX
  LDY #$02
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_PaletteData_bg3:
  STA $FE
  LDA $0200,X
  INX
  LDY #$03
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_PaletteData_s0:
  STA $FE
  LDA $0200,X
  INX
  LDY #$04
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_PaletteData_s1:
  STA $FE
  LDA $0200,X
  INX
  LDY #$05
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_PaletteData_s2:
  STA $FE
  LDA $0200,X
  INX
  LDY #$06
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_PaletteData_s3:
  STA $FE
  LDA $0200,X
  INX
  LDY #$07
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_Palette_col0:
  STA $FE
  LDA $0200,X
  INX
  LDY #$00
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_Palette_col1:
  STA $FE
  LDA $0200,X
  INX
  LDY #$01
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
set_Palette_col2:
  STA $FE
  LDA $0200,X
  INX
  LDY #$02
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
list_get:
  CLC
  ADC #$01
  TAY
  LDA $0200,X
  STA $FE
  LDA [$FE],Y
  RTS
list_set:
  CLC
  ADC #$01
  TAY
  INX
  LDA $0200,X
  STA $FE
  DEX
  LDA $0200,X
  STA [$FE],Y
  LDA $0200,X
  INX
  RTS
list_size:
  LDY #$00
  STA $FE
  LDA [$FE],Y
  RTS
End:
  JMP End

  .bank 1
  .org $FFFA
  .dw 0
  .dw Start
  .dw 0
  
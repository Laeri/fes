#[ hardware stack (used as the return stack), goes from $0100-$01FF
 custom data stack: $0200-$02FF but backwards!!! (top down)
( base address is $0200, but X is set to #$FF which makes the stack start at $02FF )
 X is the stack pointer and points always to second element of the stack
tos is accumulator
 ]#

const BASE_ADDR "$0200"
const TMP_0 "$FC"
const TMP_1 "$FD"
const TMP_2 "$FE"
const TMP_3 "$FF"

: true
[
dex
sta $0200,X
lda #$FF
]
;

: false
[
dex
sta $0200,X
lda #$00
]
;


#[ one factor in A, one in Y, from https://wiki.nesdev.com/w/index.php/8-bit_Multiply ]#

: *
[
ldy $0200,X
lsr a
sta $FC
sty $FD
lda #$0
ldy #$8
mul_loop:
bcc mul_noadd
clc
adc $FD
mul_noadd:
ror a
ror $FC
dey
bne mul_loop
lda $FC
inx
rts
]
;


#[ https://wiki.nesdev.com/w/index.php/8-bit_Divide divisor in $FA, quotient in y counter, remainder in A ]#

: /
[
sta $FA
lda $0200,X
inx
ldy #$00
sec
div_one:
sbc $FA
bcc div_two
iny
bne div_one
div_two:
tya
]
;

 #[ / modified to adc the divisor at the end if the result fell below 0 ]#
: mod
[
sta $FA
lda $0200,X
inx
ldy #$00
sec
mod_one:
sbc $FA
bcc mod_two
iny
bne mod_one
mod_two:
clc
adc $FA
]
;

: dup
[
dex
sta $0200,X
]
;

: drop
[
lda $0200,X
inx
]
;

: nip
[
inx
]
;

: swap
[
ldy $0200,X ; test
sta $0200,X
tya
]
;

#[ x1 x2 x3 -- x2 x3 x1 ]#
: rot
[
ldy $0200,X
sta $0200,X
inx
tya
ldy $0200,X
sta $0200,X
dex
tya
]
;

#[ x1 x2 -- x3 ]#
: and
[
and $0200,X
inx
]
;

#[ x1 x2 -- x3 ]#
: or
[
ora $0200,X
inx
]
;

#[ x1 x2 -- x3 ]#
: xor
[
eor $0200,X
inx
]
;


#[ x1 a-addr -- ]#
: !
[
tay
lda $0200,X
sta $00,Y
inx
lda $0200,X
inx
]
;

#[ use $FE and $FF for temporary indirect indexed storage ]#
: @
[
sta $FE
ldy #$00
lda [$FE],Y
]
;

: +
[
CLC
adc $0200,X
inx
]
;

: -
[
sec
ldy $0200,X
sta $0200,X
tya
sbc $0200,X
inx
]
;

: not
[
eor #$FF
]
;

: negate
0
swap
-
;

: =
[
cmp $0200,X
beq equal_true
lda #$00
jmp equal_done
equal_true:
lda #$FF
equal_done:
inx
]
;

: <
[
cmp $0200,X
bcs smaller_true
lda #$00
jmp smaller_done
smaller_true:
lda #$FF
smaller_done:
inx
]
;

: >
[
cmp $0200,X
bmi greater_true
beq greater_true
greater_false:
lda #$00
jmp greater_done
greater_true:
lda #$FF
greater_done:
inx
]
;

: >=
< not
;

: <=
> not
;


: !=
= not
;



























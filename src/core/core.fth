( hardware stack (used as the return stack), goes from $0100-$01FF
 custom data stack: $0200-$02FF but backwards!!! (top down)
( base address is $0200, but X is set to #$FF which makes the stack start at $02FF )
 X is the stack pointer and points always to second element of the stack
tos is accumulator
)

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

: swap
[
ldy $0200,X
sta $0200,X
tya
]
;

(x1 x2 x3 -- x2 x3 x1)
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

(x1 x2 -- x3)
: and
[
and $0200,X
inx
]
;

(x1 x2 -- x3)
: or
[
ora $0200,X
inx
]
;

(x1 x2 -- x3)
: xor
[
eor $0200,X
inx
]
;


(x1 a-addr --)
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

( use $FE and $FF for temporary indirect indexed storage )
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
bmi greater_false
beq greater_false
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


( not equal)
: !=
= not
;



























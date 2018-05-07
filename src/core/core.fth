( hardware stack (used as the return stack), goes from $0100-$01FF
 custom data stack: $0200-$02FF but backwards!!! (top down)
 X is the stack pointer and points always to second element of the stack
tos is accumulator
)

: true
[
dex
sta $02FF,X
lda #$FF
]
;

: false
[
dex
sta $02FF,X
lda #$00
]
;

: dup
[
dex
sta $02FF,X
]
;

: drop
[
lda $02FF,X
inx
]
;

: swap
[
ldy $02FF,X
sta $02FF,X
tya
]
;

(x1 x2 x3 -- x2 x3 x1)
: rot
[
ldy $02FF,X
sta $02FF,X
inx
tya
ldy $02FF,X
sta $02FF,X
dex
tya
]
;

(x1 x2 -- x3)
: and
[
and $02FF,X
inx
]
;

(x1 x2 -- x3)
: or
[
ora $02FF,X
inx
]
;

(x1 x2 -- x3)
: xor
[
eor $02FF,X
inx
]
;


(x1 a-addr --)
: !
[
tay
lda $02FF,X
sta $00,Y
inx
lda $02FF,X
inx
]
;

: +
[
CLC
adc $02FF,X
inx
]
;

: -
[
sec
ldy $02FF,X
sta $02FF,X
tya
sbc $02FF,X
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
cmp $02FF,X
inx
bne equal_false:
lda #$FF
jmp equal_done
equal_false:
lda #$00
equal_done:
]
;

: <
swap
[
cmp $02FF,X
inx
bpl smaller_false:
lda #$FF
jmp smaller_done
smaller_false:
lda #$00
smaller_done:
]
;

: >
swap
[
cmp $02FF,X
inx

greater_false:
greater_true:
greater_done:
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



























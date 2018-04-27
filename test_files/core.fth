( hardware stack (used as the return stack), goes from $0100-$01FF
 custom data stack: $0200-$02FF but backwards!!! (top down)
 X is the stack pointer and points always to last element in the stack
)

1
2
3
: dup
[
lda $02FF,X
dex
sta $02FF,X
]
;

: drop
[
inx
]
;

: swap
[
ldy $02FF,X
inx
lda $02FF,X
sty $02FF,X
dex
sta $02FF,X
]
;

(x1 x2 x3 -- x2 x3 x1)
: rot
[
lda $02FF,X 
pha
inx
lda $02FF,X
inx
ldy $02FF,X
sta $02FF,X
dex
pla
sta $02FF,X
dex
sty $02FF,X
]
;

(x1 x2 -- x3)
: and
[
lda $02FF,X
inx
and $02FF,X
sta $02FF,X
]
;

(x1 x2 -- x3)
: or
[
lda $02FF,X
inx
ora
sta $02FF,X
]
;

(x1 x2 -- x3)
: xor
[
lda $02FF,X
inx
eor
sta $02FF,X
]
;


(x1 a-addr --)
: !
[
ldy $02FF,X
inx
lda $02FF,X
sta $00,Y
]
;

: +
[
CLC
lda $02FF,X
inx
adc $02FF,X
sta $02FF,X
]
;

: -
[
SEC
inx
lda $02FF,X
dex
sbc
inx
sta $02FF,X
]
;




























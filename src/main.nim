import
  compiler, types, optimizer


var test_opt_str = """
[
  ADC $02FF,X
  JSR Loop
  RTS

Loop:
  AND $02FF,X
  LDA $02FF,X
RTS
]


"""


var parser = newParser()
parser.parse_string(test_opt_str)
parser.root.group_word_defs_last()
parser.root.add_start_label()
var asm_calls: seq[ASMAction] = @[]
parser.root.emit(asm_calls)
var asm_str = aasm_to_string(asm_calls)
echo asm_str

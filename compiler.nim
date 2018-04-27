import strutils, patty, sequtils, tables, typetraits, macros, os
type
  ASTNode = ref object of RootObj

  PushNumberNode = ref object of ASTNode
    number: int

  SequenceNode = ref object of ASTNode
    sequence: seq[ASTNode]

  DefineWordNode = ref object of ASTNode
    word_name: string
    definition: SequenceNode
  
  CallWordNode = ref object of ASTNode
    word_name: string

  ASMNode = ref object of ASTNode
    asm_calls: seq[ASMAction]

  ASMAction = ref object of RootObj

  ASMCall = ref object of ASMAction
    str: string
    op: OPCODE
    param: string
    mode: OP_MODE

  ASMLabel = ref object of ASMAction
    label_name: string

  OPCODE = enum
    ADC, AND, ASL, BIT, BPL, BMI, BVC, BVS, BCC, BCS, BNE, BEQ, BRK, CMP, CPX, CPY,
    DEC, EOR,
    CLC, SEC, CLI, SEI, CLV, CLD, SED,
    INC, JMP, JSR,
    LDA, LDX, LDY,
    LSR, NOP, ORA,
    TAX, TXA, DEX, INX, TAY, TYA, DEY, INY,
    ROL, ROR, RTI, RTS, SBC, STA,
    TXS, TSX, PHA, PLA, PHP, PLP,
    STX, STY
  
  OP_MODE = enum
    Immediate, Zero_Page, Zero_Page_X, Absolute, Absolute_X, Absolute_Y, Indirect_X, Indirect_Y, Accumulator, Relative, Implied

  ASMInfo = ref object of ASTNode
    mode: OP_MODE
    len: int
    time: int
   
  Scanner = ref object of RootObj
    src: string
    lines: seq[string]
    columns: seq[string]
    line: int
    column: int

  Parser = ref object of RootObj
    root: SequenceNode
    scanner: Scanner


proc `$`(call: ASMCall): string = 
  return $call[]

proc `$`(node: ASMNode): string =
  return $(node[])

proc `$`(label: ASMLabel): string =
  return $(label[])


proc isOPCODE(str: string): bool =
  try:
    discard parseEnum[OPCODE] str
  except ValueError:
     return false
  return true

proc isOP_MODE(str: string): bool =
  try:
    discard parseEnum[OP_MODE] str
  except ValueError:
     return false
  return true

proc newASMInfo(op_mode: OP_MODE, op_length: int, op_time: int): ASMInfo =
  return ASMInfo(mode: op_mode, len: op_length, time: op_time)

template asm_data(op_mode: OP_MODE, op_length: int, op_time: int): ASMInfo =
  ASMInfo(mode: op_mode, len: op_length,time: op_time)


var info_table = newTable[OPCODE, TableRef[OP_MODE, ASMInfo]]()

proc setup(info_table: TableRef[OPCODE, TableRef[OP_MODE, ASMInfo]], args: varargs[string, `$`]) =
  var opcode: OPCODE
  var mode: OP_MODE
  var op_len: int
  var op_time: int
  var read_all = false
  var i: int = 0
  while not(read_all):
    if (args[i]).isOPCODE:
      opcode = parseEnum[OPCODE] args[i]
      info_table[opcode] = newTable[OP_MODE, ASMInfo]()
      i = i + 1
    else:
      mode = parseEnum[OP_MODE] args[i]
      op_len = args[i+1].parseInt
      op_time = args[i+2].parseInt
      info_table[opcode].add(mode, newASMInfo(mode, op_len, op_time))
      i = i + 3
    if i >= args.len:
      read_all = true

info_table.setup(
  ADC,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  AND,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  ASL,
  Accumulator, 1, 2,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  BCC,
  Relative, 2, 2,
  BCS,
  Relative, 2, 2,
  BEQ,
  Relative, 2, 2,
  BIT,
  Zero_page, 2, 3,
  Absolute, 3, 4,
  BMI,
  Relative, 2, 2,
  BNE,
  Relative, 2, 2,
  BPL,
  Relative, 2, 2,
  BRK,
  Implied, 1, 7,
  BVC,
  Relative, 2, 2,
  BVS,
  Relative, 2, 2,
)


proc len(asm_call: ASMCall): int = 
  return info_table[asm_call.op][asm_call.mode].len


proc time(asm_call: ASM_Call): int =
  return info_table[asm_call.op][asm_call.mode].time


proc op(name: OPCODE, param: string): ASMCall = 
  return ASMCall(op: name, str: $name, param: param)


proc nonempty(lines: seq[string], index = 0): bool =
  for i in countup(index, lines.len - 1):
    if lines[i].len != 0:
      return true
  return false


proc read_string(scanner: Scanner, src: string) =
  scanner.src = src
  scanner.lines = splitLines(src)
  if scanner.lines.len != 0:
    scanner.columns = scanner.lines[0].splitWhitespace
  else:
    scanner.columns = @[]
  scanner.line = 0
  scanner.column = 0


proc skip_to_next_line(scanner: Scanner) =
  scanner.line += 1
  scanner.column = 0
  scanner.columns = scanner.lines[scanner.line].splitWhitespace

proc skip_empty_lines(scanner: Scanner) =
  while scanner.lines[scanner.line].len == 0:
    scanner.skip_to_next_line


proc advance(scanner: Scanner) =
  scanner.column += 1
  if scanner.column >= scanner.columns.len:
    scanner.column = 0
    scanner.line += 1
    scanner.columns = scanner.lines[scanner.line].splitWhitespace
  while scanner.lines[scanner.line].len == 0:
    scanner.advance 


proc has_next(scanner: Scanner): bool = 
  return (scanner.column < scanner.columns.len - 1) or (nonempty(scanner.lines, scanner.line + 1))


proc next(scanner: Scanner): string = 
  var token = scanner.columns[scanner.column]
  scanner.advance
  return token

proc upto_next_line(scanner: Scanner): seq[string] =  
  var line_tokens = scanner.columns[scanner.column .. (scanner.columns.len - 1)]
  scanner.skip_to_next_line()
  scanner.skip_empty_lines()
  return line_tokens

proc newSequenceNode(): SequenceNode =
  var node = SequenceNode()
  node.sequence = @[]
  return node


proc newASMNode(): ASMNode =
  var node = ASMNode()
  node.asm_calls = @[]
  return node


proc newDefineWordNode(): DefineWordNode =
  var node = DefineWordNode()
  node.definition = newSequenceNode()
  return node


proc add(node: SequenceNode, other: ASTNode) = 
  node.sequence.add(other)


proc add(node: DefineWordNode, other: ASTNode) =
  node.definition.add(other)


proc add(node: ASMNode, asm_action: ASMAction) = 
  node.asm_calls.add(asm_action)


proc isInteger(str: string): bool =
  try:
    let f = parseInt str
  except ValueError:
     return false
  return true



proc parse_asm_block(parser: Parser, asm_node: ASMNode) = 
  var tokens: seq[string] = parser.scanner.upto_next_line()
  var end_block = false
  while not(end_block):
    for token in tokens:
      if token == "]":
        end_block = true
      elif tokens.len == 1:
        if tokens[0].contains(":"):
          asm_node.add(ASMLabel(label_name: tokens[0]))
        else:
          asm_node.add(ASMCall(op: parseEnum[OPCODE] tokens[0]))
      elif tokens.len == 2:
        asm_node.add(ASMCall(op: parseEnum[OPCODE] tokens[0]))
    if not(end_block):
      tokens = parser.scanner.upto_next_line()

proc parse_word_definition(parser: Parser, def_node: DefineWordNode) =
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token == ";":
      return
    elif token == "[":
      var node = newASMNode()
      def_node.add(node)
      parser.parse_asm_block(node)
    elif token.isInteger:
      var node = PushNumberNode()
      node.number = token.parseInt
      def_node.add(node)
    else:
      var node = CallWordNode()
      node.word_name = token
      def_node.add(node)

proc parse_comment(parser: Parser) =
  echo "parse_comment"
  while parser.scanner.has_next:
    var token = parser.scanner.next
    echo token
    if token.contains(")"):
      echo "finish_parse_comment"
      return
    elif token.contains("("):
      parser.parse_comment

proc parse_string(parser: Parser, src: string) = 
  parser.scanner.read_string(src)
  var root = newSequenceNode()
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token == ":":
      var def_node = newDefineWordNode()
      token = parser.scanner.next
      def_node.word_name = token
      parser.parse_word_definition(def_node)
      root.add(def_node)
    elif token == "[":
      var asm_node = newASMNode()
      parser.parse_asm_block(asm_node)
      root.add(asm_node)
    elif token == "(":
      parser.parse_comment()
    elif token.isInteger:
      var node = PushNumberNode()
      node.number = token.parseInt
      root.add(node)
    else:
      var node = CallWordNode(word_name: token)
      root.add(node)
  parser.root = root

proc parse_file(parser: Parser, name: string) =
  var src: string = readFile(name)
  parser.parse_string(src)


proc newParser(): Parser = 
  var parser = Parser()
  parser.scanner = Scanner()
  return parser


proc is_def(node: ASTNode): bool =
  return (node of DefineWordNode)

proc partition[T](sequence: seq[T], pred: proc): tuple[selected: seq[T],rejected: seq[T]] =
  var selected: seq[T] = @[]
  var rejected: seq[T] = @[]
  for el in sequence:
    if el.pred:
      selected.add(el)
    else:
      rejected.add(el)
  return (selected, rejected)

proc group_word_defs_last(root: SequenceNode) = 
  var partition = root.sequence.partition(is_def)
  root.sequence = partition.rejected & partition.selected


method print(node: ASTNode) =
  echo node[]


method print(node: SequenceNode) = 
  for child in node.sequence:
    child.print


method print(node: ASMNode) =
  echo node


method print(node: PushNumberNode) =
  echo node[]


method print(node: DefineWordNode) =
  echo "define_node: " & node.word_name
  node.definition.print
  echo "end_define"


method print(node: CallWordNode) =
  echo "call: "
  echo node[]

method emit(node: ASTNode, asm_code: var seq[ASMCall]) =
  echo "error, node without code to emit"
  discard
method emit(node: SequenceNode, asm_code: var seq[ASMCall]) = 
  for node in node.sequence:
    node.emit(asm_code)
method emit(node: CallWordNode, asm_code: var seq[ASMCall]) =
  asm_code.add(ASMCall(str: ("  JSR " & node.word_name & "\n")))

method emit(node: DefineWordNode, asm_code: var seq[ASMCall]) =
  asm_code.add(ASMCall(str: (node.word_name & ":\n")))
  node.definition.emit(asm_code)
  asm_code.add(ASMCall(str: ("  RTS\n")))

method emit(node: PushNumberNode, asm_code: var seq[ASMCall]) =
  asm_code.add(ASMCall(str: "  PEA " & intToStr(node.number) & "\n"))

method emit(node: ASMNode, asm_code: var seq[ASMCall]) =
  echo "string should not contain yet asm calls"
  discard
    

proc digit_to_hex(number: int): string =
  var hex = @["A", "B", "C", "D", "E", "F"]
  if number < 10:
    return number.intToStr
  else:
    return hex[number - 10]

proc num_to_hex(number: int) =
  var hex: string = ""
  var n = number
  if n == 0:
    hex = "0"
  while (n / 16 > 0):
    var val = n / 16
    var rem = n mod 16
    hex = rem.digit_to_hex & hex
    n = int(val)
  hex = "$" & hex

proc pad_to_even(hex: var string) = 
  var str: string = "" & hex[2 .. hex.len]
  if ((str.len - 1) mod 2) == 1:
    hex = "0x0" & str

var test_src = """
1 2 3
: name1
4 5 6
;
: name2
7 8 name1
;
9 10 11
""" 
var parser = newParser()
parser.parse_file("test_files/core.fth")
#parser.parse_string(test_src)
parser.root.print
#parser.root.group_word_defs_last()
#parser.root.print
#var asm_calls: seq[ASMCall] = @[]
#parser.root.emit(asm_calls)

#var output_str: string = ""
#for c in asm_calls:
#  output_str = output_str & c.str

#echo output_str

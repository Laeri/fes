import strutils, patty, sequtils, tables, typetraits, macros, os, streams, osproc
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
    with_arg: bool

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
    Immediate, Zero_Page, Zero_Page_X, Zero_Page_Y Absolute, Absolute_X, Absolute_Y, Indirect, Indirect_X, Indirect_Y, Accumulator, Relative, Implied

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
  CLC,
  Implied, 1, 2,
  CLD,
  Implied, 1, 2,
  CLI,
  Implied, 1, 2,
  CLV,
  Implied, 1, 2,
  CMP,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  CPX,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Absolute, 3, 4,
  CPY,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Absolute, 3, 4,
  DEC,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 3,
  Absolute_X, 3, 7,
  DEX,
  Implied, 1, 2,
  DEY,
  Implied, 1, 2,
  EOR,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  INC,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  INX,
  Implied, 1, 2,
  INY,
  Implied, 1, 2,
  JMP,
  Absolute, 3, 3,
  Indirect, 3, 5,
  JSR,
  Absolute, 3, 6,
  LDA,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  LDX,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_Y, 2, 4,
  Absolute, 3, 4,
  Absolute_Y, 3, 4,
  LDY,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  LSR,
  Accumulator, 1, 2,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  NOP,
  Implied, 1, 2,
  ORA,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  PHA,
  Implied, 1, 3,
  PHP,
  Implied, 1, 3,
  PLA,
  Implied, 1, 4,
  PLP, 
  Implied, 1, 4,
  ROL,
  Accumulator, 1, 2,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  ROR,
  Accumulator, 1, 2,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  RTI,
  Implied, 1, 6,
  RTS,
  Implied, 1, 6,
  SBC,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  SEC,
  Implied, 1, 2,
  SED,
  Implied, 1, 2,
  SEI,
  Implied, 1, 2,
  STA,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 5,
  Absolute_Y, 3, 5,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 6,
  STX,
  Zero_Page, 2, 3,
  Zero_Page_Y, 2, 4,
  Absolute, 3, 4,
  STY,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  TAX,
  Implied, 1, 2,
  TAY,
  Implied, 1, 2,
  TSX,
  Implied, 1, 2,
  TXS,
  Implied, 1, 2,
  TYA,
  Implied, 1, 2
)

var nes_transl_table: Table[string, string] =
  {
    "+": "add",
    "-": "sub",
    "*": "mul",
    "/": "div",
    "!": "store"
  }.toTable

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
          asm_node.add(ASMCall(op: parseEnum[OPCODE] tokens[0], with_arg: false))
      elif tokens.len == 2:
        var arg_string = tokens[1]
        asm_node.add(ASMCall(op: parseEnum[OPCODE] tokens[0], param: arg_string, with_arg: true))
    if not(end_block):
      tokens = parser.scanner.upto_next_line()

proc translate_name(name: string): string =
  if nes_transl_table.contains(name):
    return nes_transl_table[name]
  else:
    return name

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
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.contains(")"):
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
      def_node.word_name = token.translate_name
      parser.parse_word_definition(def_node)
      root.add(def_node)
    elif token == "[":
      var asm_node = newASMNode()
      parser.parse_asm_block(asm_node)
      root.add(asm_node)
    elif token.contains("("):
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

proc add_start_label(root: SequenceNode) =
  var asm_node = newASMNode()
  asm_node.add(ASMLabel(label_name: "Start:"))
  var tmp_seq: seq[ASTNode] = @[]
  tmp_seq.add(asm_node)
  root.sequence = tmp_seq & root.sequence


method string_rep(node: ASTNode, prefix = ""): string =
  echo "error: node with no print function!!!"
  return prefix & $node[]

method string_rep(node: SequenceNode, prefix = ""): string =
  var str: string = prefix & "SequenceNode:\n" 
  for child in node.sequence:
    str &= child.string_rep(prefix & "  ") & "\n"
  return str

method string_rep(action: ASMAction, prefix = ""): string =
  echo "UNSPECIFIED ASM ACTION"
  return "!!!!!"

method string_rep(call: ASMCall, prefix = ""): string =
  var arg = "  "
  if (call.with_arg):
    arg &= call.param
  result = prefix & "ASMCall: " & $call.op & arg
  return result

method string_rep(label: ASMLabel, prefix = ""): string =
  result = prefix & "ASMLabel: " & label.label_name
  return result

method string_rep(node: ASMNode, prefix = ""): string =
  var str: string = prefix & "ASMNode:\n"
  for action in node.asm_calls:
    str &= prefix & action.string_rep(prefix & "  ") & "\n"
  return str

method string_rep(node: PushNumberNode, prefix = ""): string =
  return prefix & "PushNumberNode: " & $node.number

method string_rep(node: DefineWordNode, prefix = ""): string =
  var define_str = prefix & "DefineWordNode: " & node.word_name & "\n"
  define_str &= node.definition.string_rep(prefix & "  ")
  return define_str

method string_rep(node: CallWordNode, prefix = ""): string =
  return prefix & "CallWordNode: " & node.word_name


proc digit_to_hex(number: int): string =
  var hex = @["A", "B", "C", "D", "E", "F"]
  var result = ""
  if number < 10:
    result = number.intToStr
  else:
    result = hex[number - 10]
  return result

proc num_to_hex(number: int): string =
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
  return hex

proc pad_to_even(hex: var string): string = 
  var str: string = "" & hex[2 .. hex.len]
  if ((str.len - 1) mod 2) == 1:
    hex = "0x0" & str
  return hex


method emit(node: ASTNode, asm_code: var seq[ASMAction]) =
  echo "error, node without code to emit"
  discard

method emit(node: SequenceNode, asm_code: var seq[ASMAction]) = 
  for node in node.sequence:
    node.emit(asm_code)

method emit(node: CallWordNode, asm_code: var seq[ASMAction]) =
  asm_code.add(ASMCall(op: JSR, param: node.word_name & "\n"))

method emit(node: DefineWordNode, asm_code: var seq[ASMAction]) =
  asm_code.add(ASMLabel(label_name: (node.word_name & ":")))
  node.definition.emit(asm_code)
  asm_code.add(ASMCall(op: RTS, param: "", with_arg:true))

method emit(node: PushNumberNode, asm_code: var seq[ASMAction]) =
  var param = node.number.num_to_hex
  param = param.pad_to_even
  var call = ASMCall(op: LDA, param: param, with_arg: true)
  asm_code.add(call)

method emit(node: ASMNode, asm_code: var seq[ASMAction]) =
  for call in node.asm_calls:
    asm_code.add(call)
    

proc aasm_to_string(asm_actions: seq[ASMAction]): string =
  var result = ""
  for asm_code in asm_actions:
    if asm_code of ASMCall:
      var call = cast[ASMCall](asm_code)
      var arg = ""
      if call.with_arg:
        arg = " " & call.param
      result &= "  " & $call.op & arg & "\n"
    elif asm_code of ASMLabel:
      var label = cast[ASMLabel](asm_code)
      result &= cast[ASMLabel](asm_code).label_name & "\n"
  return result

proc generate_nes_str(asm_code: seq[ASMAction]): string =
  var num_16k_prg_banks = 1
  var num_8k_chr_banks = 0
  var VRM_mirroring = 1
  var nes_mapper = 0
  
  var program_start = "$8000"

  var result = "; INES header setup\n\n"
  result &= "  .inesprg " & $num_16k_prg_banks & "\n"
  result &= "  .ineschr " & $num_8k_chr_banks & "\n"
  result &= "  .inesmir " & $VRM_mirroring & "\n"
  result &= "  .inesmap " & $nes_mapper & "\n"
  result &= "\n"
  result &= "  .org " & program_start & "\n"
  result &= "  .bank 0\n\n"
  result &= aasm_to_string(asm_code)
  result &= "\n"
  result &= """
  .bank 1
  .org $FFFA
  .dw 0
  .dw Start
  .dw 0
  """
  return result

proc generate_and_store(asm_code: seq[ASMAction], file_name: string) =
  var fs = newFileStream(file_name, fmWrite)
  var nes_str = generate_nes_str(asm_code)
  fs.write(nes_str)
  fs.close

proc generate_and_assemble(asm_code: seq[ASMAction], asm_file_name: string) =
  generate_and_store(asm_code, asm_file_name)
  var nes_name = asm_file_name.replace(r"\..*$", ".nes")
  echo asm_file_name
  echo nes_name
  var exit_code = execCmd "nesasm " & asm_file_name
  var (output, exitCoe2) = execCmdEx "nesasm " & asm_file_name
  #var exit_code3 = execCmd "fceux " & nes_name
  #var (output2, exitCoe4) = execCmdEx "fceux " & nes_name


var parser = newParser()
parser.parse_file("test_files/core.fth")
parser.root.group_word_defs_last()
parser.root.add_start_label()
var asm_calls: seq[ASMAction] = @[]
parser.root.emit(asm_calls)
var asm_str = aasm_to_string(asm_calls)
#generate_and_store(asm_calls, "TEST.asm")
generate_and_assemble(asm_calls, "TEST.asm")








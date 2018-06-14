import
  types, utils, strutils, tables, sequtils


proc newASMInfo*(op_mode: OP_MODE, op_length: int, op_time: int): ASMInfo =
  return ASMInfo(mode: op_mode, len: op_length, time: op_time)

template asm_data*(op_mode: OP_MODE, op_length: int, op_time: int): ASMInfo =
  ASMInfo(mode: op_mode, len: op_length,time: op_time)

proc newASMCall*(op: OPCODE, param: string = nil): ASMCall =
  result = ASMCall(op: op, param: param)

var info_table* = newTable[OPCODE, TableRef[OP_MODE, ASMInfo]]()

proc setup*(info_table: TableRef[OPCODE, TableRef[OP_MODE, ASMInfo]], args: varargs[string, `$`]) =
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

var branches*: seq[OPCODE] = @[BEQ, BNE, BCC, BCS, BVC, BVS, BMI, BPL]


proc inverse_branch*(op: OPCODE): OPCODE =
  if not(branches.contains(op)):
    echo "inverse_branch function a non branch opcode supplied"
  result = case op:
    of BEQ:
      BNE
    of BNE:
      BEQ
    of BCC:
      BCS
    of BCS:
      BCC
    of BVC:
      BVS
    of BMI:
      BPL
    of BPL:
      BMI
    else:
      INVALID_OPCODE
  

method asm_str*(action: ASMAction): string {.base.} =
  discard

method asm_str*(call: ASMCall): string =
  result = $call.op
  if call.with_arg:
    result &= " " & call.param

method asm_str*(label: ASMLabel): string =
  result = label.label_name & ":"

method asm_str*(comment: ASMComment): string =
  result = comment.comment


proc is_branch*(call: ASMCall): bool =
  if not(call.with_arg):
    result = false
  else:
    result = branches.contains(call.op) # branches is a variable defined in asm_t.nim

proc addressing_mode(param: string): OP_MODE =
  if param.contains("[") and param.contains("X"):
    return Indirect_X
  elif param.contains("[") and param.contains("Y"):
    return Indirect_Y
  elif param.contains(","):
    var splitted = param.split(",")
    var first = splitted[0]
    var second = splitted[1]
    if first.len == 5 and second == "X":
      return Absolute_X
    elif first.len == 3 and second == "X":
      return Zero_Page_X
    elif first.len == 5 and second == "Y":
      return Absolute_Y
    elif first.len == 3 and second == "Y":
      return Zero_Page_Y
  elif param.contains("#"):
    return Immediate
  elif param.contains("$"):
    if param.len == 5: # $ABCD
      return Absolute
    elif param.len == 3: # $AB
      return Zero_Page
  elif param.len > 0: # jump address
    if param.contains("["): # indirect jump
      return Indirect
    else:
      return Absolute

proc parse_call_to_addressing_mode*(call: ASMCall): OP_MODE =
  if not(call.with_arg):
    return Implied
  if call.is_branch():
    return Relative
  var param = call.param
  return param.addressing_mode

method len*(asm_action: ASMAction): int {.base.} =
  echo "ASMAction len should not be called"
  return 0


method len*(asm_comment: ASMComment): int =
  return 0

method len*(asm_call: ASMCall): int = 
  result = 1 # 1 byte for the opcode ?
  var addr_mode = parse_call_to_addressing_mode(asm_call)
  result += info_table[asm_call.op][addr_mode].len

method len*(asm_label: ASMLabel): int =
  return 0

proc op*(name: OPCODE, param: string): ASMCall = 
  return ASMCall(op: name, str: $name, param: param)


    
    
























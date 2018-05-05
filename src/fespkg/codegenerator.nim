import
  types, strutils

proc newCodeGenerator*(): CodeGenerator =
  result = CodeGenerator()
  result.code = @[]

proc newASMCall*(op: OPCODE, param: string = nil): ASMCall =
  result = ASMCall(op: op, param: param)

proc digit_to_hex(number: int): string =
  var hex = @["A", "B", "C", "D", "E", "F"]
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
  if (hex.len mod 2) == 1:
    hex = "0" & hex
  return "$" & hex

proc num_to_im_hex(number: int): string =
  return "#" & num_to_hex(number)

method `==`*(c1: ASMAction, c2: ASMAction): bool {.base.} =
  return false

method `==`*(c1, c2: ASMCall): bool =
  return (c1.op == c2.op) and (c1.param == c2.param)


method emit*(generator: CodeGenerator, node: ASTNode) {.base.} =
  echo "error, node without code to emit"
  discard

method emit*(generator: CodeGenerator, node: SequenceNode) = 
  for node in node.sequence:
    generator.emit(node)

method emit*(generator: CodeGenerator, node: CallWordNode) =
  generator.code.add(ASMCall(op: JSR, param: node.word_name))

method emit*(generator: CodeGenerator, node: DefineWordNode) =
  generator.code.add(ASMLabel(label_name: (node.word_name & ":")))
  generator.emit(node.definition)
  generator.code.add(ASMCall(op: RTS))

method emit*(generator: CodeGenerator, node: PushNumberNode) =
  var param = node.number.num_to_im_hex
  generator.code.add(ASMCall(op: DEX))
  generator.code.add(ASMCall(op: STA, param: "$02FF,X"))
  generator.code.add(ASMCall(op: LDA, param: param))

method emit*(generator: CodeGenerator, node: ASMNode) =
  for call in node.asm_calls:
    generator.code.add(call)

method emit*(generator: CodeGenerator, node: IfElseNode) =
  var then_block = node.then_block
  var else_block = node.else_block
  generator.code.add(ASMLabel(label_name: "begin_if" & $generator.current_ifelse & ":"))
  

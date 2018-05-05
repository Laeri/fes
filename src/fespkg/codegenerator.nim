import
  types, strutils

proc newCodeGenerator*(): CodeGenerator =
  result = CodeGenerator()
  result.code = @[]


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
  hex = "$" & hex
  return hex

proc pad_to_even(hex: var string): string = 
  var str: string = "" & hex[2 .. hex.len]
  if ((str.len - 1) mod 2) == 1:
    hex = "0x0" & str
  return hex
    

method emit*(generator: CodeGenerator, node: ASTNode) {.base.} =
  echo "error, node without code to emit"
  discard

method emit*(generator: CodeGenerator, node: SequenceNode) = 
  for node in node.sequence:
    generator.emit(node)

method emit*(generator: CodeGenerator, node: CallWordNode) =
  generator.code.add(ASMCall(op: JSR, param: node.word_name & "\n"))

method emit*(generator: CodeGenerator, node: DefineWordNode) =
  generator.code.add(ASMLabel(label_name: (node.word_name & ":")))
  generator.emit(node.definition)
  generator.code.add(ASMCall(op: RTS))

method emit*(generator: CodeGenerator, node: PushNumberNode) =
  var param = node.number.num_to_hex
  param = param.pad_to_even
  var call = ASMCall(op: LDA, param: param)
  generator.code.add(call)

method emit*(generator: CodeGenerator, node: ASMNode) =
  for call in node.asm_calls:
    generator.code.add(call)

method emit*(generator: CodeGenerator, node: IfElseNode) =
  var then_block = node.then_block
  var else_block = node.else_block
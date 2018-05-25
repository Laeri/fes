import
  types, strutils, tables

proc newCodeGenerator*(): CodeGenerator =
  result = CodeGenerator()
  result.code = @[]
  result.current_ifelse = 0
  result.current_while = 0
  result.current_address = 0
  result.variables = newTable[string, VariableNode]()

proc newASMCall*(op: OPCODE, param: string = nil): ASMCall =
  result = ASMCall(op: op, param: param)

proc digit_to_hex(number: int): string =
  var hex = @["A", "B", "C", "D", "E", "F"]
  if number < 10:
    result = number.intToStr
  else:
    result = hex[number - 10]
  return result

proc next_ifelse(generator: CodeGenerator) =
  generator.current_ifelse += 1

proc next_while(generator: CodeGenerator) =
  generator.current_while += 1

proc next_address(generator: CodeGenerator) =
  generator.current_address += 1

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

# it is assumed that variable definitions are grouped first
method emit*(generator: CodeGenerator, node: VariableNode) =
  node.address = generator.current_address
  generator.next_address
  var param = node.address.num_to_im_hex
  generator.code.add(ASMCall(op: DEX))
  generator.code.add(ASMCall(op: STA, param: "$0200,X"))
  generator.code.add(ASMCall(op: LDA, param: param))
  generator.variables[node.name] = node

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
  generator.code.add(ASMCall(op: STA, param: "$0200,X"))
  generator.code.add(ASMCall(op: LDA, param: param))

method emit*(generator: CodeGenerator, node: ASMNode) =
  for call in node.asm_calls:
    generator.code.add(call)

proc begin_if_label_name(generator: CodeGenerator): string =
  return "begin_if" & $generator.current_ifelse

proc begin_then_label_name(generator: CodeGenerator): string =
  return "begin_then" & $generator.current_ifelse

proc begin_else_label_name(generator: CodeGenerator): string =
  return "begin_else" & $generator.current_ifelse

proc end_if_label_name(generator: CodeGenerator): string =
  return "end_if" & $generator.current_ifelse



proc begin_if_label(generator: CodeGenerator): ASMLabel =
  return ASMLabel(label_name: generator.begin_if_label_name() & ":")

proc begin_then_label(generator: CodeGenerator): ASMLabel =
  return ASMLabel(label_name: generator.begin_then_label_name() & ":")

proc begin_else_label(generator: CodeGenerator): ASMLabel =
  return ASMLabel(label_name: generator.begin_else_label_name() & ":")

proc end_if_label(generator: CodeGenerator): ASMLabel =
  return ASMLabel(label_name: generator.end_if_label_name() & ":")


method emit*(generator: CodeGenerator, node: IfElseNode) =
  generator.next_ifelse()
  var then_block = node.then_block
  var else_block = node.else_block
  generator.code.add(generator.begin_if_label())
  generator.code.add(ASMCall(op: CLC))
  generator.code.add(ASMCall(op: ASL))
  generator.code.add(ASMCall(op: BCC, param: generator.begin_else_label_name()))
  generator.code.add(generator.begin_then_label())
  generator.emit(then_block)
  generator.code.add(ASMCall(op: JMP, param: generator.end_if_label_name()))
  generator.code.add(generator.begin_else_label())
  generator.emit(else_block)
  generator.code.add(generator.end_if_label())

proc begin_while_name(generator: CodeGenerator): string =
  return "begin_while" & $generator.current_while
proc end_while_name(generator: CodeGenerator): string =
  return "end_while" & $generator.current_while
proc then_while_name(generator: CodeGenerator): string =
  return "begin_then_while" & $generator.current_while
proc begin_while_label(generator: CodeGenerator): ASMLabel =
  return ASMLabel(label_name: generator.begin_while_name & ":")
proc end_while_label(generator: CodeGenerator): ASMLabel =
  return ASMLabel(label_name: generator.end_while_name & ":")
proc then_while_label(generator: CodeGenerator): ASMLabel =
  return ASMLabel(label_name: generator.then_while_name & ":")

method emit*(generator: CodeGenerator, node: WhileNode) =
  generator.next_while()
  var condition_block = node.condition_block
  var then_block = node.then_block
  generator.code.add(generator.begin_while_label())
  generator.emit(condition_block)
  generator.code.add(ASMCall(op: ASL))
  generator.code.add(ASMCall(op: BCC, param: generator.end_while_name()))
  generator.code.add(generator.then_while_label())
  generator.emit(then_block)
  generator.code.add(generator.end_while_label())

proc gen*(generator: CodeGenerator, node: ASTNode) =
  generator.code.add(ASMCall(op: LDA, param: "#$FF")) # set X to #$FF in order to set stack start address to $02FF
  generator.code.add(ASMCall(op: TAX))
  generator.emit(node)

proc aasm_to_string*(asm_actions: seq[ASMAction]): string =
  result = ""
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


proc code_as_string*(generator: CodeGenerator): string =
  return aasm_to_string(generator.code)
  
  

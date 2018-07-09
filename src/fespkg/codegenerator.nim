import
  types, utils, strutils, tables, ast, asm_t, sequtils


proc push_asm_node(num: int): ASMNode = 
  result = newASMNode()
  result.add(ASMCall(op: DEX))
  result.add(ASMCall(op: STA, param: "$0200,X"))
  result.add(ASMCall(op: LDA, param: num_to_im_hex(num)))

proc push_addr_asm_node(num: int): ASMNode =
  result = newASMNode()
  result.add(DEX)
  result.add(STA, "$0200,X")
  result.add(LDA, num_to_im_hex_lower_byte(num))
  result.add(DEX)
  result.add(STA, "$0200,X")
  result.add(LDA, num_to_im_hex_higher_byte(num))

proc newCodeGenerator*(): CodeGenerator =
  result = CodeGenerator()
  result.code = @[]
  result.current_ifelse = 0
  result.current_while = 0
  result.current_address = 0



proc next_ifelse(generator: CodeGenerator) =
  generator.current_ifelse += 1

proc next_while(generator: CodeGenerator) =
  generator.current_while += 1

proc next_address(generator: CodeGenerator) =
  generator.current_address += 1

method `==`*(c1: ASMAction, c2: ASMAction): bool {.base.} =
  return false

method `==`*(c1, c2: ASMCall): bool =
  return (c1.op == c2.op) and (c1.param == c2.param)

proc translate_to_label_name(name: string): string = 
  replace(name, "-", "_")

method emit*(generator: CodeGenerator, node: ASTNode) {.base.} =
  if not((node of ConstNode) or (node of StructNode)):
    echo "error, node: " & node.str & " without code to emit"
  discard

proc var_base_addr(node: VariableNode): int =
  return node.address

method emit*(generator: CodeGenerator, node: VariableNode) =
 discard

method emit*(generator: CodeGenerator, node: SequenceNode) = 
  for node in node.sequence:
    generator.emit(node)

method emit*(generator: CodeGenerator, node: CallWordNode) =
  generator.code.add(ASMCall(op: JSR, param: translate_to_label_name(node.word_name)))

method emit*(generator: CodeGenerator, node: DefineWordNode) =
  generator.code.add(ASMLabel(label_name: (translate_to_label_name(node.word_name))))
  generator.emit(node.definition)
  if node.word_name == "on_nmi":
    generator.code.add(ASMCall(op: RTI)) # on_nmi is an interrupt hook, so neads return from interrupt (RTI)
  else:
    generator.code.add(ASMCall(op: RTS))

method emit*(generator: CodeGenerator, node: PushNumberNode) =
  generator.emit(push_asm_node(node.number))

method emit*(generator: CodeGenerator, node: ASMNode) =
  for call in node.asm_calls:
    generator.code.add(call)

proc begin_if_label_name(generator: CodeGenerator, index: int): string =
  return "begin_if" & $index

proc begin_then_label_name(generator: CodeGenerator, index: int): string =
  return "begin_then" & $index

proc begin_else_label_name(generator: CodeGenerator, index: int): string =
  return "begin_else" & $index

proc end_if_label_name(generator: CodeGenerator, index: int): string =
  return "end_if" & $index



proc begin_if_label(generator: CodeGenerator, index: int): ASMLabel =
  return ASMLabel(label_name: generator.begin_if_label_name(index))

proc begin_then_label(generator: CodeGenerator, index: int): ASMLabel =
  return ASMLabel(label_name: generator.begin_then_label_name(index))

proc begin_else_label(generator: CodeGenerator, index: int): ASMLabel =
  return ASMLabel(label_name: generator.begin_else_label_name(index))

proc end_if_label(generator: CodeGenerator, index: int): ASMLabel =
  return ASMLabel(label_name: generator.end_if_label_name(index))


method emit*(generator: CodeGenerator, node: IfElseNode) =
  var current_ifelse_index = generator.current_ifelse
  generator.next_ifelse()
  var then_block = node.then_block
  var else_block = node.else_block
  generator.code.add(generator.begin_if_label(current_ifelse_index))
  generator.code.add(CLC)
  generator.code.add(ASL, "A")
  generator.code.add(BCC, generator.begin_else_label_name(current_ifelse_index))
  generator.code.add(generator.begin_then_label(current_ifelse_index))
  generator.code.add(LDA, "$0200,X") # pop condition
  generator.code.add(INX)
  generator.emit(then_block)
  generator.code.add(JMP, generator.end_if_label_name(current_ifelse_index))
  generator.code.add(generator.begin_else_label(current_ifelse_index))
  generator.code.add(LDA, "$0200,X") # pop condition
  generator.code.add(INX)
  generator.emit(else_block)
  generator.code.add(generator.end_if_label(current_ifelse_index))

proc begin_while_name(generator: CodeGenerator, index: int): string =
  return "begin_while" & $index
proc end_while_name(generator: CodeGenerator, index: int): string =
  return "end_while" & $index
proc then_while_name(generator: CodeGenerator, index: int): string =
  return "begin_then_while" & $index
proc begin_while_label(generator: CodeGenerator, index: int): ASMLabel =
  return ASMLabel(label_name: generator.begin_while_name(index))
proc end_while_label(generator: CodeGenerator, index: int): ASMLabel =
  return ASMLabel(label_name: generator.end_while_name(index))
proc then_while_label(generator: CodeGenerator, index: int): ASMLabel =
  return ASMLabel(label_name: generator.then_while_name(index))

method emit*(generator: CodeGenerator, node: WhileNode) =
  var current_while_index = generator.current_while
  generator.next_while()
  var condition_block = node.condition_block
  var then_block = node.then_block
  generator.code.add(generator.begin_while_label(current_while_index))
  generator.emit(condition_block)
  generator.code.add(CLC)
  generator.code.add(ASL, "A")
  generator.code.add(BCC, generator.end_while_name(current_while_index))
  generator.code.add(LDA, "$0200,X") # pop computed flag of the stack
  generator.code.add(INX)
  generator.code.add(generator.then_while_label(current_while_index))
  generator.emit(then_block)
  generator.code.add(JMP, generator.begin_while_name(current_while_index))
  generator.code.add(generator.end_while_label(current_while_index))
  generator.code.add(LDA, "$0200,X") # pop computed flag of the stack
  generator.code.add(INX)

var base_address = "$0200"



method emit*(generator: CodeGenerator, node: LoadVariableNode) =
  echo node.name & " addr: " & $node.var_node.address
  generator.code.add(DEX)
  generator.code.add(STA, base_address & ",X")
  generator.code.add(LDA, num_to_im_hex_lower_byte(node.var_node.address))
  generator.code.add(DEX)
  generator.code.add(STA, base_address & ",X")
  generator.code.add(LDA, num_to_im_hex_higher_byte(node.var_node.address))

method emit*(generator: CodeGenerator, node: LoadConstantNode) =
  var val_str = node.const_node.value
  var val = val_str.parseInt
  generator.emit(push_addr_asm_node(val)) # we should need to distinguish between addresses and simple numbers in constants!
  

proc gen*(generator: CodeGenerator, node: ASTNode) =
  generator.emit(node)


proc aasm_to_string*(asm_actions: seq[ASMAction]): string =
  result = ""
  for asm_code in asm_actions:
    if asm_code of ASMCall:
      var call = cast[ASMCall](asm_code)
      result &= "  " & call.asm_str & "\n"
    elif asm_code of ASMLabel:
      var label = cast[ASMLabel](asm_code)
      result &= label.asm_str & "\n"
  return result


proc generate_nes_str*(generator: CodeGenerator, asm_code: seq[ASMAction], root: ASTNode, on_nmi_defined: bool): string =
  var num_16k_prg_banks = 1
  var num_8k_chr_banks = 1
  var VRM_mirroring = 1
  var nes_mapper = 0
  
  var on_nmi = "0"
  if on_nmi_defined:
    on_nmi = "on_nmi"
  
  var program_start = "$8000"

  result = "; INES header setup\n\n"
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
  .dw """ & on_nmi & "\n" & """
  .dw Start
  .dw 0

  .bank 2
  .org $0000
  """

  # add .incbin sprite.chr
  # for every LoadSpriteNode we do this
  var nodes = (cast[SequenceNode](root)).sequence
  var load_sprite_nodes = nodes.filter(proc (node: ASTNode): bool =
    node of LoadSpriteNode).map(proc (node: ASTNode): LoadSpriteNode =
      cast[LoadSpriteNode](node))
  for lds in load_sprite_nodes:
    result &= ".incbin " & lds.path & "\n  "
  return result



proc code_as_string*(generator: CodeGenerator): string =
  return aasm_to_string(generator.code)
  
  

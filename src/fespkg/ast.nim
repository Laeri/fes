import
  types


proc newSequenceNode*(): SequenceNode =
  var node = SequenceNode()
  node.sequence = @[]
  return node

proc newIfElseNode*(): IfElseNode =
  result = IfElseNode()
  result.then_block = newSequenceNode()
  result.else_block = newSequenceNode()

proc newWhileNode*(): WhileNode =
  result = WhileNode()
  result.condition_block = newSequenceNode()
  result.then_block = newSequenceNode()

proc newASMNode*(): ASMNode =
  var node = ASMNode()
  node.asm_calls = @[]
  return node

proc newTypeData*(): TypeData =
  result = TypeData()
  result.name = "No TypeData Name"
  result.fes_type = Number

proc newASMNode*(calls: seq[ASMAction]): ASMNode =
  result = newASMNode()
  result.asm_calls = calls

proc newASMCall*(): ASMCall =
  result = ASMCall()

proc newInitStructValuesNode*(): InitStructValuesNode =
  result = InitStructValuesNode()
  result.names = @[]
  result.str_values = @[]

proc newInitListValuesNode*(): InitListValuesNode =
  result = InitListValuesNode()
  result.str_values = @[]

proc newStructNode*(): StructNode =
  result = StructNode()
  result.members = @[]

proc newListNode*(): ListNode =
  result = ListNode()
  result.element_type_data = newTypeData()


proc newStructMember*(): StructMember =
  result = StructMember()
  result.has_default = false
  result.type_data = newTypeData()
  result.type_data.fes_type = Untyped

proc set_default*(struct_member: StructMember, val: string) =
  struct_member.has_default = true
  struct_member.default_str_val = val

proc newConstNode*(): ConstNode =
  result = ConstNode()


proc newDefineWordNode*(): DefineWordNode =
  var node = DefineWordNode()
  node.definition = newSequenceNode()
  return node


proc find_index*[T](lst: seq[T], pred: (proc(el: T): bool)): int =
  for i in 0..(lst.len - 1):
    if pred(lst[i]):
      return i
  return -1



method add*(node: ASTNode, other: ASTNode) {.base.} =
  echo "base add in ASTNode should not be called"

method add*(node: SequenceNode, other: ASTNode) = 
  node.sequence.add(other)

method add*(node: DefineWordNode, other: ASTNode) =
  node.definition.add(other)

method add*(node: ASMNode, asm_action: ASMAction) {.base.} = 
  node.asm_calls.add(asm_action)

proc add*(asm_node: ASMNode, op_code: OPCODE, param_str: string = nil) =
  asm_node.add(ASMCall(op: op_code, param: param_str))

proc is_def*(node: ASTNode): bool =
  return (node of DefineWordNode)

proc is_var*(node: ASTNode): bool =
  return (node of VariableNode)

proc is_word_call*(node: ASTNode): bool =
  return (node of CallWordNode)

method str*(node: ASTNode, prefix = ""): string {.base.} =
  echo "error: node with no print function!!!"
  return prefix & $node[]

method str*(node: ListNode, prefix = ""): string = 
  return prefix & "ListNode:\n" & prefix & "   " & "size: " & $node.size

method str*(node: StructNode, prefix = ""): string = 
  var str: string = prefix & "StructNode: " & node.name & " {\n"
  for member in node.members:
    str &= prefix & "  " & member.name
    if member.has_default:
      str &= " = " & member.default_str_val
    str &= "\n"
  str &= prefix & "}"
  return str

method str*(node: SequenceNode, prefix = ""): string =
  var str: string = prefix & "SequenceNode:\n" 
  for child in node.sequence:
    str &= child.str(prefix & "  ") & "\n"
  return str

method str*(node: WhileNode, prefix = ""): string =
  var str: string = prefix & "WhileNode:\n"
  str &= "condition:\n" & node.condition_block.str(prefix & "  ")
  str &= "then:\n" & node.then_block.str(prefix & "  ")
  return str

method str*(node: IfElseNode, prefix = ""): string =
  var str: string = prefix & "IfElseNode:\n"
  str &= prefix & "  " & "then:\n" & node.then_block.str(prefix & "  " & "  ")
  str &= prefix & "  " & "else:\n" & node.else_block.str(prefix & "  " & "  ")
  return str

method str*(node: VariableNode, prefix = ""): string =
  var str: string = prefix & "VariableNode:\n"
  str &= prefix & "   " & "name: " & node.name & "\n"
  str &= prefix & "   " & "size: " & $node.size & "\n"
  str &= prefix & "   " & "addr: " & $node.address & "\n"
  str &= prefix & "   " & "type: " & $node.var_type & "\n"
  return str

method str*(node: LoadConstantNode, prefix = ""): string =
  var str: string = prefix & "LoadConstantNode: " & node.name & "\n"
  return str

method str*(node: LoadVariableNode, prefix = ""): string = 
  var str: string = prefix & "LoadVariableNode: " & node.name & "\n"
  return str

method str*(action: ASMAction, prefix = ""): string =
  echo "UNSPECIFIED ASM ACTION"
  echo $(action of ASMLabel)
  echo $(action of ASMCall)
  return "!!!!!"

method str*(node: InitStructValuesNode, prefix = ""): string =
  result = prefix & "InitStructValuesNode: " & "\n"
  for i in 0..(node.names.len - 1):
    result &= prefix & "member: " & node.names[i] & " default: " & node.str_values[i] & "\n"

method str*(node: OtherNode, prefix = ""): string =
  return prefix & "OtherNode: " & node.name & "\n"

method str*(node: ASMComment, prefix = ""): string =
  return prefix & "ASMComment: " & node.comment & "\n"

method str*(call: ASMCall, prefix = ""): string =
  var arg = "  "
  if (call.with_arg):
    arg &= call.param
  result = prefix & "ASMCall: " & $call.op & arg & "\n"
  return result

method str*(label: ASMLabel, prefix = ""): string =
  result = prefix & "ASMLabel: " & label.label_name & "\n"
  return result

method str*(node: ASMNode, prefix = ""): string =
  var str: string = prefix & "ASMNode:\n"
  for action in node.asm_calls:
    str &= prefix & action.str(prefix & "  ") & "\n"
  return str

method str*(node: PushNumberNode, prefix = ""): string =
  return prefix & "PushNumberNode: " & $node.number

method str*(node: DefineWordNode, prefix = ""): string =
  var define_str = prefix & "DefineWordNode: " & node.word_name & "\n"
  define_str &= node.definition.str(prefix & "  ")
  return define_str

method str*(node: CallWordNode, prefix = ""): string =
  return prefix & "CallWordNode: " & node.word_name

method str*(node: ConstNode, prefix = ""): string =
  result = prefix & "ConstNode:\n"
  result &= prefix & "  name: " & node.name & "\n"
  result &= prefix & "  value: " & node.value

method str*(node: LoadSpriteNode, prefix = ""): string =
  result = prefix & "LoadSpriteNode:\n"
  result &= prefix & "  name: " & node.name & "\n"
  result &= prefix & "  path: " & node.path & "\n"

method transform_node*(node: ASTNode, transform: proc(node: ASTNode)) {.base.} =
  transform(node)

method transform_node*(node: SequenceNode, transform: proc(node: ASTNode)) = 
  transform(node)
  for node in node.sequence:
    transform_node(node, transform)

method transform_node*(node: IfElseNode, transform: proc(node: ASTNode)) =
  transform(node)
  transform_node(node.then_block, transform)
  transform_node(node.else_block, transform)

method transform_node*(node: WhileNode, transform: proc(node: ASTNode)) = 
  transform(node)
  transform_node(node.condition_block, transform)
  transform_node(node.then_block, transform)

method transform_node*(node: DefineWordNode, transform: proc(node: ASTNode)) = 
  transform(node)
  transform_node(node.definition, transform)


method any_true*(node: ASTNode, pred: proc(node: ASTNode): bool): bool {.base.} =
  return pred(node)

method any_true*(node: SequenceNode, pred: proc(node: ASTNode): bool): bool = 
  if pred(node):
    return true
  else:
    for node in node.sequence:
      if any_true(node, pred):
        return true
  return false

method any_true*(node: IfElseNode, pred: proc(node: ASTNode): bool): bool =
  return pred(node) or any_true(node.then_block, pred) or any_true(node.else_block, pred)

method any_true*(node: WhileNode, pred: proc(node: ASTNode): bool): bool = 
  return pred(node) or any_true(node.condition_block, pred) or any_true(node.then_block, pred)

method any_true*(node: DefineWordNode, pred: proc(node: ASTNode): bool): bool = 
  return pred(node) or any_true(node.definition, pred)

proc size*(node: StructNode): int =
  return node.members.len


proc `[]`*(node: SequenceNode, index: int): ASTNode =
  result = node.sequence[index]


proc len*(node: SequenceNode): int = 
  result = 0
  for n in node.sequence:
    result += 1

# length of a definition is just all the statement/calls it has
proc len*(node: DefineWordNode): int = 
  return node.definition.len













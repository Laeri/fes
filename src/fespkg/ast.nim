import
  types


proc newIfElseNode*(): IfElseNode =
  result = IfElseNode()

proc newSequenceNode*(): SequenceNode =
  var node = SequenceNode()
  node.sequence = @[]
  return node


proc newASMNode*(): ASMNode =
  var node = ASMNode()
  node.asm_calls = @[]
  return node


proc newDefineWordNode*(): DefineWordNode =
  var node = DefineWordNode()
  node.definition = newSequenceNode()
  return node

proc len*(node: SequenceNode): int =
  return node.sequence.len

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


proc is_def*(node: ASTNode): bool =
  return (node of DefineWordNode)

proc is_var*(node: ASTNode): bool =
  return (node of VariableNode)

proc is_word_call*(node: ASTNode): bool =
  return (node of CallWordNode)


method str*(node: ASTNode, prefix = ""): string {.base.} =
  echo "error: node with no print function!!!"
  return prefix & $node[]

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
  str &= "then:\n" & node.then_block.str(prefix & "  ")
  str &= "else:\n" & node.else_block.str(prefix & "  ")
  return str

method str*(node: VariableNode, prefix = ""): string =
  var str: string = prefix & "VariableNode: " & node.name & " " & $node.address
  return str

method str*(node: LoadVariableNode, prefix = ""): string = 
  var str: string = prefix & "LoadVariableNode: " & node.name & "\n"
  return str

method str*(action: ASMAction, prefix = ""): string {.base.} =
  echo "UNSPECIFIED ASM ACTION"
  return "!!!!!"

method str*(call: ASMCall, prefix = ""): string =
  var arg = "  "
  if (call.with_arg):
    arg &= call.param
  result = prefix & "ASMCall: " & $call.op & arg
  return result

method str*(label: ASMLabel, prefix = ""): string =
  result = prefix & "ASMLabel: " & label.label_name
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


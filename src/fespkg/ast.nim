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


method string_rep*(node: ASTNode, prefix = ""): string {.base.} =
  echo "error: node with no print function!!!"
  return prefix & $node[]

method string_rep*(node: SequenceNode, prefix = ""): string =
  var str: string = prefix & "SequenceNode:\n" 
  for child in node.sequence:
    str &= child.string_rep(prefix & "  ") & "\n"
  return str

method string_rep*(action: ASMAction, prefix = ""): string {.base.} =
  echo "UNSPECIFIED ASM ACTION"
  return "!!!!!"

method string_rep*(call: ASMCall, prefix = ""): string =
  var arg = "  "
  if (call.with_arg):
    arg &= call.param
  result = prefix & "ASMCall: " & $call.op & arg
  return result

method string_rep*(label: ASMLabel, prefix = ""): string =
  result = prefix & "ASMLabel: " & label.label_name
  return result

method string_rep*(node: ASMNode, prefix = ""): string =
  var str: string = prefix & "ASMNode:\n"
  for action in node.asm_calls:
    str &= prefix & action.string_rep(prefix & "  ") & "\n"
  return str

method string_rep*(node: PushNumberNode, prefix = ""): string =
  return prefix & "PushNumberNode: " & $node.number

method string_rep*(node: DefineWordNode, prefix = ""): string =
  var define_str = prefix & "DefineWordNode: " & node.word_name & "\n"
  define_str &= node.definition.string_rep(prefix & "  ")
  return define_str

method string_rep*(node: CallWordNode, prefix = ""): string =
  return prefix & "CallWordNode: " & node.word_name


import
  types


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


method add*(node: ASTNode, other: ASTNode) =
  echo "base add in ASTNode should not be called"

method add*(node: SequenceNode, other: ASTNode) = 
  node.sequence.add(other)

method add*(node: DefineWordNode, other: ASTNode) =
  node.definition.add(other)

method add*(node: ASMNode, asm_action: ASMAction) = 
  node.asm_calls.add(asm_action)


proc is_def*(node: ASTNode): bool =
  return (node of DefineWordNode)

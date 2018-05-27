import
  types, ast, sets, msgs, typetraits, tables


proc newPassRunner*(): PassRunner =
  result = PassRunner()

proc newPassRunner*(handler: ErrorHandler, var_table: TableRef[string, VariableNode]): PassRunner =
  result = newPassRunner()
  result.handler = handler
  result.var_table = var_table

proc partition[T](sequence: seq[T], pred: proc): tuple[selected: seq[T],rejected: seq[T]] =
  var selected: seq[T] = @[]
  var rejected: seq[T] = @[]
  for el in sequence:
    if el.pred:
      selected.add(el)
    else:
      rejected.add(el)
  return (selected, rejected)


method visit(visitor: ASTVisitor, node: ASTNode) {.base.} =
  return

method accept(node: ASTNode, visitor: ASTVisitor) {.base.} =
  visitor.visit(node)

method accept(def_node: DefineWordNode, visitor: ASTVisitor) =
  visitor.visit(def_node)
  def_node.definition.accept(visitor)

method accept(ifelse_node: IfElseNode, visitor: ASTVisitor)  =
  visitor.visit(ifelse_node)
  ifelse_node.then_block.accept(visitor)
  ifelse_node.else_block.accept(visitor)

method accept(while_node: WhileNode, visitor: ASTVisitor) =
  visitor.visit(while_node)
  while_node.condition_block.accept(visitor)
  while_node.then_block.accept(visitor)

method accept[T](node: ASTNode, visitor: CollectVisitor[T]) =
  visitor.visit(node)

method accept(seq_node: SequenceNode, visitor: ASTVisitor) =
  visitor.visit(seq_node)
  for n in seq_node.sequence:
    n.accept(visitor)

method visit[T](collect_visitor: CollectVisitor[T], node: ASTNode) =
  if collect_visitor.pred(node):
    collect_visitor.collected.add(cast[T](node))
  return


proc newCollectVisitor[T](pred: proc(node:ASTNode): bool = nil): CollectVisitor[T] =
  result = CollectVisitor[T](pred: pred)
  result.collected = @[]



proc collect_defs(node: ASTNode): seq[DefineWordNode] =
  var visitor: CollectVisitor[DefineWordNode] = newCollectVisitor[DefineWordNode](is_def)
  node.accept(visitor)
  return visitor.collected

proc count[T](t_seq: seq[T], t_el: T): int =
  result = 0
  for seq_el in t_seq:
    if seq_el == t_el:
      inc(result)

proc pass_check_multiple_defs*(pass_runner: PassRunner, node: ASTNode) =
  var defs = collect_defs(cast[SequenceNode](node))
  var names: seq[string] = @[]
  for def in defs:
    names.add(def.word_name)
  var names_set = names.toSet
  if names.len != names_set.len:
    for set_name in names_set:
      if names.count(set_name) > 1:
        discard #pass_runner.handler.report(node, errWordAlreadyDefined, set_name)

proc pass_group_word_defs_last*(pass_runner: PassRunner, root: SequenceNode) = 
  var partition = root.sequence.partition(is_def)
  root.sequence = partition.rejected & partition.selected

proc pass_group_vars_first*(pass_runner: PassRunner, root: SequenceNode) =
  var partition = root.sequence.partition(is_var)
  root.sequence = partition.selected  & partition.rejected

proc pass_add_start_label*(pass_runner: PassRunner, root: SequenceNode) =
  var asm_node = newASMNode()
  asm_node.add(ASMLabel(label_name: "Start:"))
  var tmp_seq: seq[ASTNode] = @[]
  tmp_seq.add(asm_node)
  root.sequence = tmp_seq & root.sequence


method replace_n(node: ASTNode, pred: (proc(el: ASTNode): bool), rep: (proc(el: ASTNode): ASTNode)) {.base.} = 
  discard

method replace_n(node: SequenceNode, pred: (proc(el: ASTNode): bool),rep: (proc(el: ASTNode): ASTNode)) = 
  var i = 0
  while i < node.sequence.len:
    if pred(node.sequence[i]):
      var replace_node = rep(node.sequence[i])
      node.sequence.delete(i)
      node.sequence.insert(replace_node, i - 1)
    else:
      i += 1

method replace_n(node: IfElseNode, pred: (proc(el: ASTNode): bool), rep: (proc(el: ASTNode): ASTNode)) = 
  node.then_block.replace_n(pred, rep)
  node.else_block.replace_n(pred, rep)

method replace_n(node: WhileNode, pred: (proc(el: ASTNode): bool), rep: (proc(el: ASTNode): ASTNode)) = 
  node.condition_block.replace_n(pred, rep)

method replace_n(node: DefineWordNode,pred: (proc(el: ASTNode): bool), rep: (proc(el: ASTNode): ASTNode)) = 
  node.definition.replace_n(pred, rep)


proc pass_add_end_label*(pass_runner: PassRunner, root: SequenceNode) =
  var end_node = newASMNode()
  end_node.add(ASMLabel(label_name: "End:"))
  end_node.add(ASMCall(op: JMP, param: "End")) # endless cycle
  root.sequence.add(end_node)
  var first_def_index = find_index(root.sequence, is_def)
  var jmp_node = newASMNode()
  jmp_node.add(ASMCall(op: JMP, param: "End"))
  root.sequence.insert(jmp_node, first_def_index)


proc pass_word_to_var_calls*(pass_runner: PassRunner, node: ASTNode) = 
  var var_table = pass_runner.var_table
  var is_call_var = (proc (node: ASTNode): bool = 
    if node of CallWordNode:
      var call = cast[CallWordNode](node)
      if var_table.contains(call.word_name):
        return true
    return false)
  var call_to_var = (proc(node: ASTNode): ASTNode =
    var load_node = LoadVariableNode()
    load_node.name = (cast[CallWordNode](node)).word_name
    load_node.var_node = var_table[load_node.name]
    return load_node)
  node.replace_n(is_call_var, call_to_var)
  


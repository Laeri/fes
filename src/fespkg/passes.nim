import
  types, ast, sets, msgs, compiler, parser



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

proc newCollectVisitor[T](pred: proc(node:ASTNode): bool = nil): CollectVisitor[T] =
  result = CollectVisitor[T](pred: pred)
  result.collected = @[]

method visit(collect_visitor: CollectVisitor, node: ASTNode)  =
  if collect_visitor.pred(node):
    collect_visitor.collected.add(node)
  return

method visit(collect_visitor: CollectVisitor, node: DefineWordNode) =
  node.definition.accept(collect_visitor)
  return

method visit(collect_visitor: CollectVisitor, node: SequenceNode)  =
  for n in node.sequence:
    n.accept(collect_visitor)

method visit(collect_visitor: CollectVisitor, node: IfElseNode) =
  node.then_block.accept(collect_visitor)
  node.else_block.accept(collect_visitor)

method visit(collect_visitor: CollectVisitor, node: WhileNode) =
  node.condition_block.accept(collect_visitor)
  node.then_block.accept(collect_visitor)

proc collect_defs(node: ASTNode): seq[DefineWordNode] =
  var visitor: CollectVisitor[DefineWordNode] = newCollectVisitor[DefineWordNode](is_def)
  node.accept(visitor)
  return visitor.collected

proc count[T](t_seq: seq[T], t_el: T): int =
  result = 0
  for seq_el in t_seq:
    if seq_el == t_el:
      inc(result)

proc pass_check_multiple_defs*(compiler: FESCompiler, node: ASTNode) =
  var defs = collect_defs(cast[SequenceNode](node))
  var names: seq[string] = @[]
  for def in defs:
    names.add(def.word_name)
  var names_set = names.toSet
  if names.len != names_set.len:
    for set_name in names_set:
      if names.count(set_name) > 1:
        compiler.parser.report(node, errWordAlreadyDefined, set_name)

proc pass_group_word_defs_last*(root: SequenceNode) = 
  var partition = root.sequence.partition(is_def)
  root.sequence = partition.rejected & partition.selected

proc pass_group_vars_first*(root: SequenceNode) =
  var partition = root.sequence.partition(is_var)
  root.sequence = partition.selected  & partition.rejected

proc pass_add_start_label*(root: SequenceNode) =
  var asm_node = newASMNode()
  asm_node.add(ASMLabel(label_name: "Start:"))
  var tmp_seq: seq[ASTNode] = @[]
  tmp_seq.add(asm_node)
  root.sequence = tmp_seq & root.sequence

proc pass_word_to_var_calls*(compiler: FESCompiler, node: ASTNode) = 
  var visitor: CollectVisitor[CallWordNode] = newCollectVisitor[CallWordNode](is_word_call)
  node.accept(visitor)
  


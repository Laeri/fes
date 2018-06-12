import
  types, msgs, strutils, sets, sequtils

type
  CallGraph* = ref object of RootObj
    nodes*: seq[DefineWordNode]
    call_sites*: seq[CallSite]
  CallSite* = ref object of RootObj
    call_from*: ASTNode
    call_node*: CallWordNode
    call_to*: DefineWordNode

method collect_top_level_calls(node: ASTNode): seq[CallWordNode] {.base.} =
  return @[]

method collect_top_level_calls(node: SequenceNode): seq[CallWordNode] =
  result = @[]
  for n in node.sequence:
    result = concat(result, n.collect_top_level_calls)


method collect_top_level_calls(node: CallWordNode): seq[CallWordNode] =
  result = newSeq[CallWordNode]()
  result.add(node)

method collect_top_level_calls(node: IfElseNode): seq[CallWordNode] =
  result = concat(node.then_block.collect_top_level_calls, node.else_block.collect_top_level_calls)

method collect_top_level_calls(node: WhileNode): seq[CallWordNode] =
  result = concat(node.condition_block.collect_top_level_calls, node.then_block.collect_top_level_calls)



proc newCallGraph(): CallGraph =
  result = CallGraph()
  result.nodes = @[]
  result.call_sites = @[]


proc build_call_graph*(root: SequenceNode): CallGraph =
  var current_calls = root.collect_top_level_calls()
  var defs_used: seq[DefineWordNode] = @[]
  var graph = newCallGraph()
  while current_calls.len > 0:
    var call = current_calls[0]
    current_calls.delete(0)
    var call_site = CallSite()
    call_site.call_node = call
    graph.call_sites.add(call_site)
    if not(defs_used.contains(call.word_def)):
      defs_used.add(call.word_def)
      current_calls = concat(current_calls, call.word_def.definition.collect_top_level_calls())
    
  graph.nodes = defs_used
  return graph


method remove_n(node: ASTNode, pred: (proc(el: ASTNode): bool)) {.base.} = 
  discard

method remove_n(node: SequenceNode, pred: (proc(el: ASTNode): bool)) = 
  var i = 0
  while i < node.sequence.len:
    if pred(node.sequence[i]):
      node.sequence.delete(i)
    else:
      remove_n(node.sequence[i], pred)
      i += 1

method remove_n(node: IfElseNode, pred: (proc(el: ASTNode): bool)) = 
  node.then_block.remove_n(pred)
  node.else_block.remove_n(pred)

method remove_n(node: WhileNode, pred: (proc(el: ASTNode): bool)) = 
  node.condition_block.remove_n(pred)
  node.then_block.remove_n(pred)

method remove_n(node: DefineWordNode,pred: (proc(el: ASTNode): bool)) = 
  node.definition.remove_n(pred)


proc remove_unused_defs*(root: SequenceNode, call_graph: CallGraph) =
  var used_defs = call_graph.nodes
  root.remove_n(proc (node: ASTNode): bool =
    if node of DefineWordNode:
      var def_node = cast[DefineWordNode](node)
      if used_defs.contains(def_node):
        return false
      else:
        return true
    return false)


















      
      
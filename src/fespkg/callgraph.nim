import
  types, msgs, strutils, sets, sequtils, tables, ast, codegenerator, asm_t

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
        if def_node.word_name == "on_nmi":
          return false # on_nmi is not called from the program but from the nes! (and needs rti instead of rts)
        return true
    return false)




method size*(node: ASTNode): int {.base.} =
  echo "ERROR"
  discard

method size*(node: DefineWordNode): int =
  result = node.definition.size + 1 # rts

method size*(node: SequenceNode): int =
  result = 0
  for n in node.sequence:
    result += n.size

# size(IfElseNode) = size(then_block) + size(else_block) + size(asm_statements_to_realize_compare_and_jump) 
method size*(node: IfElseNode): int =
  # create a dummy ifelsenode and a dummy generator
  # ifelsenode has empty then, else statement
  # generate code for dummy node, the length of this code is the overhead to 
  # realize an if-else-statement
  var dummy_if_else = newIfElseNode()
  var generator = newCodeGenerator()
  generator.emit(dummy_if_else)
  var asm_node = newASMNode()
  asm_node.asm_calls = generator.code
  return node.then_block.size + node.else_block.size + asm_node.size

method size*(node: WhileNode): int =
  # same idea with dummy whilenode and codegenerator
  var dummy_while = newWhileNode()
  var generator = newCodeGenerator()
  generator.emit(dummy_while)
  var asm_node = newASMNode()
  asm_node.asm_calls = generator.code
  return node.condition_block.size + node.then_block.size + asm_node.size

method size*(node: ASMNode): int =
  result = 0
  for c in node.asm_calls:
    result += c.len

method size*(node: LoadVariableNode): int =
  var gen = newCodeGenerator()
  gen.emit(node)
  var asm_node = newASMNode(gen.code)
  return asm_node.size

method size*(node: PushNumberNode): int =
  var gen = newCodeGenerator()
  gen.emit(node)
  var asm_node = newASMNode(gen.code)
  return asm_node.size

method size*(node: CallWordNode): int =
 var gen = newCodeGenerator()
 gen.emit(node)
 var asm_node = newASMNode(gen.code)
 return asm_node.size

method size*(node: LoadConstantNode): int =
  var gen = newCodeGenerator()
  gen.emit(node)
  var asm_node = newASMNode(gen.code)
  return asm_node.size

proc inline*(root: SequenceNode, call_graph: CallGraph) =
  # for the moment no bank switching:
  let MAX_PROGRAM_BYTE_SIZE = 16 * 1024 # 16 KB bank 1 KB = 1025 byte

  var rebate_ratio: TableRef[string, float] = newTable[string, float]()
  var size: TableRef[string, int] = newTable[string, int]()

  # Two possibilities:
  # 1. Calculate size of all nodes (add size of additionally generated asm statements)
  # 2. Collapse IfElseNode, WhileNode into SequenceNode and ASMBlocks and then calculate size from that
  # use method 1 for the moment, it could be helpful to collapse nodes but we will see

  for def_node in call_graph.nodes:
    size[def_node.word_name] = def_node.size
    #echo "name: " & def_node.word_name
    #echo "size: " & $def_node.size 
  


















      
      
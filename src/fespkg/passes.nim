import
  types, utils, ast, sets, msgs, typetraits, tables, parser, codegenerator, algorithm


proc newPassRunner*(): PassRunner =
  result = PassRunner()

proc newPassRunner*(parser: Parser): PassRunner =
  result = newPassRunner()
  result.error_handler = parser.error_handler
  result.var_table = parser.var_table
  result.definitions = parser.definitions
  result.calls = parser.calls
  result.structs = parser.structs
  result.var_index = parser.var_index

proc partition[T](sequence: seq[T], pred: proc): tuple[selected: seq[T],rejected: seq[T]] =
  var selected: seq[T] = @[]
  var rejected: seq[T] = @[]
  for el in sequence:
    if el.pred:
      selected.add(el)
    else:
      rejected.add(el)
  return (selected, rejected)


proc report(pass_runner: PassRunner,  node: ASTNode, msg: MsgKind, msg_args: varargs[string]) =
  pass_runner.error_handler.handle(gen_error(node, msg, msg_args))

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

method replace_n(node: ASTNode, pred: (proc(el: ASTNode): bool), rep: (proc(el: ASTNode): ASTNode)) {.base.} = 
  discard

method replace_n(node: SequenceNode, pred: (proc(el: ASTNode): bool),rep: (proc(el: ASTNode): ASTNode)) = 
  var i = 0
  while i < node.sequence.len:
    if pred(node.sequence[i]):
      var replace_node = rep(node.sequence[i])
      node.sequence.delete(i)
      node.sequence.insert(replace_node, i)
    else:
      replace_n(node.sequence[i], pred, rep)
      i += 1

method replace_n(node: IfElseNode, pred: (proc(el: ASTNode): bool), rep: (proc(el: ASTNode): ASTNode)) = 
  node.then_block.replace_n(pred, rep)
  node.else_block.replace_n(pred, rep)

method replace_n(node: WhileNode, pred: (proc(el: ASTNode): bool), rep: (proc(el: ASTNode): ASTNode)) = 
  node.condition_block.replace_n(pred, rep)

method replace_n(node: DefineWordNode,pred: (proc(el: ASTNode): bool), rep: (proc(el: ASTNode): ASTNode)) = 
  node.definition.replace_n(pred, rep)

proc collect_defs(node: ASTNode): seq[DefineWordNode] =
  var visitor: CollectVisitor[DefineWordNode] = newCollectVisitor[DefineWordNode](is_def)
  node.accept(visitor)
  return visitor.collected

proc count[T](t_seq: seq[T], t_el: T): int =
  result = 0
  for seq_el in t_seq:
    if seq_el == t_el:
      inc(result)


# Pass No.1
proc pass_group_word_defs_last*(pass_runner: PassRunner, root: SequenceNode) = 
  var partition = root.sequence.partition(is_def)
  root.sequence = partition.rejected & partition.selected

# Pass No.2
proc pass_group_vars_first*(pass_runner: PassRunner, root: SequenceNode) =
  var partition = root.sequence.partition(is_var)
  root.sequence = partition.selected  & partition.rejected

# Pass No.3
proc pass_add_start_label*(pass_runner: PassRunner, root: SequenceNode) =
  var asm_node = newASMNode()
  asm_node.add(ASMLabel(label_name: "Start:"))
  var tmp_seq: seq[ASTNode] = @[]
  tmp_seq.add(asm_node)
  root.sequence = tmp_seq & root.sequence

# Pass No.4
proc pass_check_multiple_defs*(pass_runner: PassRunner, node: ASTNode) =
  var defs = collect_defs(cast[SequenceNode](node))
  var names: seq[string] = @[]
  for def in defs:
    names.add(def.word_name)
  var names_set = names.toSet
  if names.len != names_set.len:
    for set_name in names_set:
      if names.count(set_name) > 1:
        pass_runner.error_handler.handle(gen_error(node, errWordAlreadyDefined, set_name))

# Pass No.5
proc pass_set_variable_loads*(pass_runner: PassRunner, node: ASTNode) = 
  var var_table = pass_runner.var_table
  var is_var = (proc (node: ASTNode): bool = 
    if node of OtherNode:
      var other_node = cast[OtherNode](node)
      if var_table.contains(other_node.name):
        return true
    return false)
  var other_to_load = (proc(node: ASTNode): ASTNode =
    var load_node = LoadVariableNode()
    load_node.name = (cast[OtherNode](node)).name
    load_node.var_node = var_table[load_node.name]
    return load_node)
  node.replace_n(is_var, other_to_load)

# Pass No.6
proc pass_set_word_calls*(pass_runner: PassRunner, root: SequenceNode) =
  var def_table = pass_runner.definitions
  var is_call = (proc (node: ASTNode): bool =
    if node of OtherNode:
      var other_node = cast[OtherNode](node)
      if def_table.contains(other_node.name):
        return true
    return false)
  var other_to_call = (proc(node: ASTNode): ASTNode =
    var call_node = CallWordNode()
    call_node.word_name = (cast[OtherNode](node)).name
    call_node.word_def = def_table[call_node.word_name]
    return call_node)
  root.replace_n(is_call, other_to_call)


# Pass No.7
proc pass_set_struct_var_type*(pass_runner: PassRunner, root: SequenceNode) =
  var transform_var_struct = (proc (node: ASTNode) = 
    if node of SequenceNode:
      var seq_node = cast[SequenceNode](node)
      var last_var_node = false
      var i = 0
      while i < seq_node.sequence.len:
        var seq_el = seq_node.sequence[i]
        if (seq_el of OtherNode) and last_var_node:
          var other_node = cast[OtherNode](seq_node.sequence[i])
          if (other_node.name in pass_runner.structs):
            var struct_node = pass_runner.structs[other_node.name]
            var var_node = cast[VariableNode](seq_node.sequence[i - 1])
            var_node.var_type = Struct
            var_node.type_node = struct_node
            seq_node.sequence.delete(i)
            last_var_node = false
          else:
            last_var_node = false
            i += 1
        elif (seq_el of VariableNode):
          last_var_node = true
          i += 1
        else:
          last_var_node = false
          i += 1)
  transform_node(root, transform_var_struct)

# Pass No.8
proc pass_set_variable_addresses*(pass_runner: PassRunner, root: SequenceNode) =
# each variable node has an index already set in the parser by the order in which they are encountered
  var sorted_vars: seq[VariableNode] = @[]
  for var_node in pass_runner.var_table.values:
    sorted_vars.add(var_node)
  sorted_vars.sort(proc (x, y: VariableNode): int =
    result = cmp(x.var_index, y.var_index))
  for var_node in sorted_vars:
    if var_node.var_type == Struct:
      var struct_node = cast[StructNode](var_node.type_node)
      var_node.address = pass_runner.var_index
      var_node.size = struct_node.size
      pass_runner.var_index += var_node.size
    elif var_node.var_type == Number:
      var_node.address = pass_runner.var_index
      pass_runner.var_index += 1
      var_node.size = 1
    else:
      echo "implement new variable and set its address"



var base_addr_addr = "$FF"
# Pass No.9
# syntax: <player_variable> get-Player-<member_name>
proc add_struct_getters(pass_runner: PassRunner, root: SequenceNode, struct_node: StructNode) =
  # assumes base address is on the stack
  # removes base address and puts value of the member variable onto the stack
  var get_prefix = "get-" & struct_node.name & "-"
  for i in 0..(struct_node.members.len - 1):
    var member = struct_node.members[i]
    var get_define = newDefineWordNode()
    var asm_node = newASMNode()
    # use indirect indexed address fetching with y register
    # for example "lda ($01), Y" loads value at address $01 (the base address of the struct) and
    # then applies the offset Y (to each member variable in the struct
    # the base value is assumed to be TOS (in register A) and has to be stored at a memory location
    # to perform this magic
    # temporarily use location $FF!

    asm_node.add(ASMCall(op: STA, param: base_addr_addr)) # store base address for indirect indexing
    asm_node.add(ASMCall(op: LDY, param: num_to_im_hex(i))) # load struct member offset
    asm_node.add(ASMCall(op: LDA, param: "[" & base_addr_addr & "],Y")) # access base + member_offset
    get_define.word_name = get_prefix & member
    get_define.definition.add(asm_node)
    pass_runner.definitions[get_define.word_name] = get_define
    root.add(get_define) 
proc pass_gen_getters*(pass_runner: PassRunner, root: SequenceNode) =
  for struct in pass_runner.structs.values:
    pass_runner.add_struct_getters(root, struct)

proc second_stack_item_addr_str(): string = 
  return "$0200,X"
# Pass No.10
# syntax: <variable> <player_variable> set-Player-<member_name>
# assumes stack: (var player_var - player)
# ! pushes the player base address pointer again to the stack
proc add_struct_setters(pass_runner: PassRunner, root: SequenceNode, struct_node: StructNode) = 
  var set_prefix = "set-" & struct_node.name & "-"
  for i in 0..(struct_node.members.len - 1):
    var member = struct_node.members[i]
    var set_define = newDefineWordNode()
    var asm_node = newASMNode()
    # same magic as for gen_getters
    asm_node.add(ASMCall(op: STA, param: base_addr_addr))
    asm_node.add(ASMCall(op: LDA, param: second_stack_item_addr_str()))
    asm_node.add(ASMCall(op: LDY, param: num_to_im_hex(i))) # load struct member offset))
    asm_node.add(ASMCall(op: STA, param: "[" & base_addr_addr & "],Y"))
    set_define.word_name = set_prefix & member
    set_define.definition.add(asm_node)
    pass_runner.definitions[set_define.word_name] = set_define
    root.add(set_define)
proc pass_gen_setters*(pass_runner: PassRunner, root: SequenceNode) =
  for struct in pass_runner.structs.values:
    pass_runner.add_struct_setters(root, struct)

# Pass No.11
proc pass_set_list_var_type*(pass_runner: PassRunner, root: SequenceNode) =
  var transform_var_list = (proc (node: ASTNode) = 
    if node of SequenceNode:
      var seq_node = cast[SequenceNode](node)
      var last_var_node = false
      var i = 0
      while i < seq_node.sequence.len:
        var seq_el = seq_node.sequence[i]
        if (seq_el of ListNode) and last_var_node:
          var list_node = cast[ListNode](seq_node.sequence[i])
          var var_node = cast[VariableNode](seq_node.sequence[i - 1])
          var_node.var_type = List
          var_node.type_node = list_node
          seq_node.sequence.delete(i)
          last_var_node = false
        elif (seq_el of VariableNode):
          last_var_node = true
          i += 1
        else:
          last_var_node = false
          i += 1)
  transform_node(root, transform_var_list)


# Pass No.12
proc pass_gen_list_methods*(pass_runner: PassRunner, root: SequenceNode) =
  # assumed it is called in this form: <var> <index> list-get
  # replaces everything with ... var_base item]
  # which means stack is: ... var_base index] where index is in register A
  # we can use some indirect addressing mode as for structure member variable access
  var list_get = newDefineWordNode()
  list_get.word_name = "list-get"
  var get_asm = newASMNode()
  get_asm.add(ASMCall(op: CLC))
  get_asm.add(ASMCall(op: ADC, param: "#$01"))
  get_asm.add(ASMCall(op: TAY)) # offset is already TOS in A, but we have to add one to it because first element
  # at base address holds the lists length
  get_asm.add(ASMCall(op: LDA, param: second_stack_item_addr_str())) # put base address TOS
  get_asm.add(ASMCall(op: STA, param: base_addr_addr)) # store base_addr for indirect addressing
  get_asm.add(ASMCall(op: LDA, param: "[" & base_addr_addr & "],Y")) # do indirect addressing with offset in Y
  list_get.definition.add(get_asm)
  pass_runner.definitions[list_get.word_name] = list_get
  root.add(list_get)

  # <list> <value> <index> list-set
  var list_set = newDefineWordNode()
  list_set.word_name = "list-set"
  var set_asm = newASMNode()
  set_asm.add(ASMCall(op: CLC))
  set_asm.add(ASMCall(op: ADC, param: "#$01"))
  set_asm.add(ASMCall(op: TAY)) # move index to Y, but first add 1 because first byte specifies the size
  # then put base address onto tos (onto A)
  # to do this decrease (increase in this case) the stack pointer X
  set_asm.add(ASMCall(op: INX))
  set_asm.add(ASMCall(op: LDA, param: second_stack_item_addr_str())) # base address is now in A
  set_asm.add(ASMCall(op: STA, param: base_addr_addr)) # same trick as with struct
  set_asm.add(ASMCall(op: DEX)) # move stack pointer up again so it SOS onto value
  set_asm.add(ASMCall(op: LDA, param: second_stack_item_addr_str())) # load the vlaue onto A
  set_asm.add(ASMCall(op: STA, param: "[" & base_addr_addr & "],Y")) # do indirect addressing
  set_asm.add(ASMCall(op: LDA, param: second_stack_item_addr_str())) # now move base address onto the stack again
  set_asm.add(ASMCall(op: INX))
  list_set.definition.add(set_asm)
  pass_runner.definitions[list_set.word_name] = list_set
  root.add(list_set)

  # <var_name> list-size
  # tos (A) holds the base address, which contains the size directly
  # assumed first byte of list holds its size
  var list_size = newDefineWordNode()
  list_size.word_name = "list-size"
  var size_asm = newASMNode()
  size_asm.add(ASMCall(op: LDY, param: "#$00")) # set Y to 0 because indirect addressing is used with no offset
  size_asm.add(ASMCall(op: STA, param: base_addr_addr)) # store base address for indirect addressing
  size_asm.add(ASMCall(op: LDA, param: "[" & base_addr_addr & "],Y")) # replace tos with value (length) at first byte
  list_size.definition.add(size_asm)
  pass_runner.definitions[list_size.word_name] = list_size
  root.add(list_size)

  

# Pass No.13
proc pass_add_end_label*(pass_runner: PassRunner, root: SequenceNode) =
  var end_node = newASMNode()
  end_node.add(ASMLabel(label_name: "End:"))
  end_node.add(ASMCall(op: JMP, param: "End")) # endless cycle
  root.sequence.add(end_node)
  var first_def_index = find_index(root.sequence, is_def)
  var jmp_node = newASMNode()
  jmp_node.add(ASMCall(op: JMP, param: "End"))
  root.sequence.insert(jmp_node, first_def_index)
###

proc pass_calls_to_def_check*(pass_runner: PassRunner) = 
  for call in pass_runner.calls.values:
    var defs = pass_runner.definitions
    if not(call.word_name in defs):
      pass_runner.report(call, errWordCallWithoutDefinition, call.word_name)




  



    
    
    
      
  


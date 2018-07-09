import
  types, asm_t, utils, ast, sets, msgs, typetraits, tables, strutils, parser, codegenerator, algorithm, sequtils

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
  result.const_table = parser.const_table

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
  node.then_block.replace_n(pred, rep)

method replace_n(node: DefineWordNode,pred: (proc(el: ASTNode): bool), rep: (proc(el: ASTNode): ASTNode)) = 
  node.definition.replace_n(pred, rep)

proc collect_defs(node: ASTNode): seq[DefineWordNode] =
  var visitor: CollectVisitor[DefineWordNode] = newCollectVisitor[DefineWordNode](is_def)
  node.accept(visitor)
  return visitor.collected

proc collect_other_nodes(node: ASTNode, name: string): seq[OtherNode] =
  var has_name = (proc (node: ASTNode): bool =
    return (node of OtherNode) and ((cast[OtherNode](node)).name == name))
  var visitor: CollectVisitor[OtherNode] = newCollectVisitor[OtherNode](has_name)
  node.accept(visitor)
  return visitor.collected

proc find_parent_of(root: ASTNode, child: ASTNode): ASTNode =
  var is_parent = (proc (node: ASTNode): bool =
    return node.has_child(child))
  var visitor: CollectVisitor[ASTNode] = newCollectVisitor[ASTNode](is_parent)
  root.accept(visitor)
  return visitor.collected[0]

proc count[T](t_seq: seq[T], t_el: T): int =
  result = 0
  for seq_el in t_seq:
    if seq_el == t_el:
      inc(result)

proc second_stack_item_addr_str(): string = 
  return "$0200,X"
var base_addr_addr = "$FE"
var base_addr_addr_high_byte = "$FF"

# Pass
proc pass_group_word_defs_last*(pass_runner: PassRunner, root: SequenceNode) = 
  var partition = root.sequence.partition(is_def)
  root.sequence = partition.rejected & partition.selected

# Pass
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

proc exists_with_name(structs: seq[StructNode], name: string): bool =
  for struct in structs:
    if struct.name == name:
      return true
  return false

proc get_with_name(structs: seq[StructNode], name: string): StructNode =
  for struct in structs:
    if struct.name == name:
      return struct

# Pass
proc pass_set_member_ptr_types*(pass_runner: PassRunner, node: ASTNode) =
  var structs = toSeq(pass_runner.structs.values) # values is an iterator, toSeq transforms any iterator to a sequence
  for struct in structs:
    for member in struct.members:
      if member.type_data.fes_type == Untyped_ptr:
        if structs.exists_with_name(member.type_data.name):
          member.type_data.fes_type = Struct_ptr
        else: # if not a struct it has to be a pointer to a list
          member.type_data.fes_type = List_ptr

# Pass 
proc pass_setup_sprites*(pass_runner: PassRunner, node: ASTNode) =
  # setup sprite with tile index
  var load_sprite_nodes = (cast[SequenceNode](node)).sequence.filter((proc (node: ASTNode): bool =
    node of LoadSpriteNode)).map((proc (node: ASTNode): LoadSpriteNode =
      cast[LoadSpriteNode](node)))
  var tile_index = 0
  for new_sprite in load_sprite_nodes:
    var setup_sprite = newSequenceNode()
    var push_tile_index = PushNumberNode(number: tile_index)
    var name_node = OtherNode(name: new_sprite.name)
    var set_call = OtherNode(name: "set-Sprite-tile_number")
    setup_sprite.add(push_tile_index)
    setup_sprite.add(name_node)
    setup_sprite.add(set_call)
    (cast[SequenceNode](node)).sequence.insert(setup_sprite, 0)
    tile_index += 1


# Pass
proc pass_set_constants*(pass_runner: PassRunner, root: SequenceNode) =
  var const_table = pass_runner.const_table
  var is_constant = (proc (node: ASTNode): bool = 
    if node of OtherNode:
      var other_node = cast[OtherNode](node)
      if const_table.contains(other_node.name):
        return true
    return false)
  var other_to_const = (proc(node: ASTNode): ASTNode =
    var load_node = LoadConstantNode()
    load_node.name = (cast[OtherNode](node)).name
    load_node.const_node = const_table[load_node.name]
    return load_node)
  root.replace_n(is_constant, other_to_const)


# Pass
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

proc setter_name*(struct_node: StructNode, member: StructMember): string =
  result = "set-" & struct_node.name & "-" & member.name

proc getter_name*(struct_node: StructNode, member: StructMember): string =
  result = "get-" & struct_node.name & "-" & member.name

# Pass
# syntax: <player_variable> get-Player-<member_name>
# low_byte high_byte
proc add_struct_getters(pass_runner: PassRunner, root: SequenceNode, struct_node: StructNode) =
  # assumes base address is on the stack
  # removes base address and puts value of the member variable onto the stack
  var relative_address = 0
  for i in 0..(struct_node.members.len - 1):
    var member = struct_node.members[i]
    var get_define = newDefineWordNode()
    var asm_node = newASMNode()
    if member.type_data.fes_type == Number:
      asm_node.add(STA, base_addr_addr_high_byte)
      asm_node.add(LDA, "$0200,X")
      asm_node.add(STA, base_addr_addr)
      asm_node.add(INX)
      asm_node.add(LDY, num_to_im_hex(relative_address))
      asm_node.add(LDA, "[" & base_addr_addr & "],Y")
      relative_address += 1
    elif (member.type_data.fes_type == Struct_ptr) or (member.type_data.fes_type == List_ptr):
      asm_node.add(STA, base_addr_addr_high_byte)
      asm_node.add(LDA, "$0200,X")
      asm_node.add(STA, base_addr_addr)
      asm_node.add(LDY, num_to_im_hex(relative_address))
      asm_node.add(LDA, "[" & base_addr_addr & "],Y") # loaded low_byte of ptr_value
      asm_node.add(STA, "$0200,X") # store low_byte on stack and make room for high_byte
      asm_node.add(LDY, num_to_im_hex(relative_address+1)) # high byte is one cell further (low_byte high_byte)
      asm_node.add(LDA, "[" & base_addr_addr & "],Y") # we end up with low_byte, high_byte on the stack
      relative_address += 2 
    else:
      echo "no getter for type: " & $member.type_data.fes_type

 
    get_define.word_name = getter_name(struct_node, member)
    get_define.definition.add(asm_node)
    pass_runner.definitions[get_define.word_name] = get_define
    root.add(get_define)
proc pass_gen_getters*(pass_runner: PassRunner, root: SequenceNode) =
  for struct in pass_runner.structs.values:
    pass_runner.add_struct_getters(root, struct)


# Pass
# syntax: <variable> <player_variable> set-Player-<member_name>
# assumes stack: (var player_var - player)
# ! pushes the player base address pointer again to the stack
proc add_struct_setters(pass_runner: PassRunner, root: SequenceNode, struct_node: StructNode) = 
  var relative_address = 0
  for i in 0..(struct_node.members.len - 1):
    var member = struct_node.members[i]
    var set_define = newDefineWordNode()
    var asm_node = newASMNode()
    # same magic as for gen_getters
    if member.type_data.fes_type == Number:
      asm_node.add(STA, base_addr_addr_high_byte)
      asm_node.add(LDA, "$0200,X") # base_addr_addr is addressed indirectly as 2 byte value! store #$00 to $FF
      asm_node.add(STA, base_addr_addr)
      asm_node.add(INX)
      asm_node.add(LDA, "$0200,X")
      asm_node.add(INX)
      asm_node.add(LDY, num_to_im_hex(relative_address)) # load struct member offset))
      asm_node.add(STA, "[" & base_addr_addr & "],Y")
      asm_node.add(LDA, "$0200,X") # drop value from the stack after storing in struct member
      asm_node.add(INX)
      relative_address += 1
    elif (member.type_data.fes_type == Struct_ptr) or (member.type_data.fes_type == List_ptr):
      asm_node.add(STA, base_addr_addr_high_byte)
      asm_node.add(LDA, "$0200,X")
      asm_node.add(STA, base_addr_addr)
      asm_node.add(INX)
      asm_node.add(LDA, "$0200,X")
      asm_node.add(INX)
      asm_node.add(LDY, num_to_im_hex(relative_address + 1)) # high byte is first in stack and comes second in struct
      asm_node.add(STA, "[" & base_addr_addr & "],Y")
      asm_node.add(LDA, "$0200,X")
      asm_node.add(INX)
      asm_node.add(LDY, num_to_im_hex(relative_address)) # low byte is second ins tack and comes first in struct
      asm_node.add(STA, "[" & base_addr_addr & "],Y")
      asm_node.add(LDA, "$0200,X")
      asm_node.add(INX)
      relative_address += 2
    else:
      echo "Implement setter for other type " & $member.type_data.fes_type
    
    set_define.word_name = setter_name(struct_node, member)
    set_define.definition.add(asm_node)
    pass_runner.definitions[set_define.word_name] = set_define
    root.add(set_define)
proc pass_gen_setters*(pass_runner: PassRunner, root: SequenceNode) =
  for struct in pass_runner.structs.values:
    pass_runner.add_struct_setters(root, struct)


# Pass
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
          # also set element type of list_node which is still only a string in the name field
          # ...
          var var_node = cast[VariableNode](seq_node.sequence[i - 1])
          var_node.var_type = List
          var_node.size = list_node.size
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


# Pass
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


# Pass
proc pass_set_variable_addresses*(pass_runner: PassRunner, root: SequenceNode) =
# each variable node has an index already set in the parser by the order in which they are encountered
  var struct_addr = 0x0300 # temporary address for structs
  var sorted_vars: seq[VariableNode] = @[]
  for var_node in pass_runner.var_table.values:
    sorted_vars.add(var_node)
  sorted_vars.sort(proc (x, y: VariableNode): int =
    result = cmp(x.var_index, y.var_index))
  for var_node in sorted_vars:
    if var_node.var_type == Struct:
      var struct_node = cast[StructNode](var_node.type_node)
      if struct_node.name == "Sprite": # put sprites on 0x0300, not on zero page
        var_node.address = struct_addr
        struct_addr += struct_node.size
      else:
        var_node.address = pass_runner.var_index # temporary struct address
        pass_runner.var_index += struct_node.size
      var_node.size = struct_node.size
    elif var_node.var_type == Number:
      var_node.address = pass_runner.var_index
      pass_runner.var_index += 1
      var_node.size = 1
    elif var_node.var_type == List:
      var_node.address = pass_runner.var_index
      var element_size = 1
      var list_node = cast[ListNode](var_node.type_node)
      if list_node.element_type_data.fes_type != Number:
        element_size = 2
      pass_runner.var_index += var_node.size + 1 # one more because size takes one field at the front
    else:
      echo "implement new variable and set its address"

# Pass
proc pass_static_list_get_set_polymorphism*(pass_runner: PassRunner, root: ASTNode) =
  var list_getters = collect_other_nodes(root, "List-get")
  var list_setters = collect_other_nodes(root, "List-set")
  for list_get in list_getters:
    var parent = cast[SequenceNode](root.find_parent_of(list_get))
    var node_seq = parent.sequence
    var index = node_seq.find(list_get)
    var prev_node = cast[LoadVariableNode](node_seq[index - 1]).var_node
    var list = cast[ListNode](prev_node.type_node)
    if list.element_type_data.fes_type == Number:
      list_get.name = "List-get_8"
    else:
      list_get.name = "List-get_16"
    
  for list_set in list_setters:
    var parent = cast[SequenceNode](root.find_parent_of(list_set))
    var node_seq = parent.sequence
    var index = node_seq.find(list_set)
    var prev_node = cast[LoadVariableNode](node_seq[index - 1]).var_node
    var list = cast[ListNode](prev_node.type_node)
    if list.element_type_data.fes_type == Number:
      list_set.name = "List-set_8"
    else:
      list_set.name = "List-set_16"



# Pass
proc pass_init_struct_variable_values*(pass_runner: PassRunner, root: ASTNode) =
  var root_seq = (cast[SequenceNode](root)).sequence
  var init_seqs: seq[ASTNode] = @[]
  for j in 0..(root_seq.len - 1):
    if root_seq[j] of InitStructValuesNode:
      var init_node = cast[InitStructValuesNode](root_seq[j])
      var var_node = cast[VariableNode](root_seq[j - 1]) # assumes AST now hast the form "VariableNode InitStructVariableNode"
      for i in 0..(init_node.names.len - 1):
        var current_init = newSequenceNode()
        if init_node.str_values[i].is_valid_number_str:
          var push_val = PushNumberNode()
          push_val.number = init_node.str_values[i].parse_to_integer
          current_init.add(push_val)
        else:
          var load_param_addr = LoadVariableNode()
          load_param_addr.name = init_node.str_values[i]
          load_param_addr.var_node = pass_runner.var_table[load_param_addr.name]
          current_init.add(load_param_addr)
        var load_node = LoadVariableNode()
        load_node.name = var_node.name
        load_node.var_node = pass_runner.var_table[load_node.name]
        current_init.add(load_node)
        var setter = OtherNode()
        setter.name = "set-" & (cast[StructNode]((cast[VariableNode](root_seq[j - 1])).type_node)).name & "-" & init_node.names[i]
        current_init.add(setter)
        init_seqs.add(current_init)

  for tmp in init_seqs:
    (cast[SequenceNode](root)).sequence.insert(tmp, 0)

# Pass
proc pass_init_struct_default_values*(pass_runner: PassRunner, root: ASTNode) =
  for struct_node in pass_runner.structs.values:
    var struct_variables: seq[VariableNode] = @[]
    for var_node in pass_runner.var_table.values:
      if (var_node.var_type == Struct) and (var_node.type_node == struct_node):
        struct_variables.add(var_node)
    for member in struct_node.members:
      if member.has_default:
        for struct_var in struct_variables:
          var init_seq = newSequenceNode()
          if member.default_str_val.is_valid_number_str: # 0xXY, #$ABCD should also be parsed
            var push_val = PushNumberNode()
            push_val.number = member.default_str_val.parse_to_integer
            init_seq.add(push_val)
          else: # it is an address?
            var corresponding_variables: seq[VariableNode] =  @[]
            for tmp in pass_runner.var_table.values:
              if tmp.name == member.default_str_val:
                corresponding_variables.add(tmp)
            if corresponding_variables.len == 1: # we have found a corresponding variable and it should only be one variable with the given name in the var_table
              var load_var_addr = LoadVariableNode()
              load_var_addr.name = corresponding_variables[0].name
              load_var_addr.var_node = corresponding_variables[0]
              init_seq.add(load_var_addr)
            else:
              echo "Error in pass pass_init_struct_default_values"
          var push_struct_var_addr = LoadVariableNode(name: struct_var.name, var_node: struct_var)
          var call_setter = OtherNode(name: setter_name(struct_node, member)) # OtherNode -> CallWordNode is done by pass: pass_set_word_calls

          init_seq.add(push_struct_var_addr)
          init_seq.add(call_setter)
          var root_seq = cast[SequenceNode](root)
          root_seq.sequence.insert(init_seq, 0)


# Pass
proc pass_init_list_values*(pass_runner: PassRunner, root: ASTNode) =
  var root_seq = (cast[SequenceNode](root)).sequence
  var init_seqs: seq[ASTNode] = @[]
  for j in 0..(root_seq.len - 1):
    if root_seq[j] of InitListValuesNode:
      var index_in_list = 1 # first byte stores size
      var init_node = cast[InitListValuesNode](root_seq[j])
      var var_node = cast[VariableNode](root_seq[j - 1]) # assumes AST now hast the form "VariableNode InitListValuesNode"
      for i in 0..(init_node.str_values.len - 1):
        var current_init = newSequenceNode()
        var load_node = LoadVariableNode() # list addr is currently before the params, might be changed in later iteration, then this needs to be moved after the value and index
        load_node.name = var_node.name
        load_node.var_node = pass_runner.var_table[load_node.name]
        current_init.add(load_node)
        var size_increase_of_index: int

        if init_node.str_values[i].is_valid_number_str:
          var push_val = PushNumberNode()
          push_val.number = init_node.str_values[i].parse_to_integer
          current_init.add(push_val)
          size_increase_of_index = 1 # number is 1 byte long
        else:
          var load_param_addr = LoadVariableNode()
          load_param_addr.name = init_node.str_values[i]
          load_param_addr.var_node = pass_runner.var_table[load_param_addr.name]
          current_init.add(load_param_addr)
          size_increase_of_index = 2 # addr is 2 bytes long
        # value is on the stack, now index parameter has to be moved onto the stack
        var push_index = PushNumberNode()
        push_index.number = index_in_list    
        var setter = OtherNode()
        setter.name = "List-set"
        current_init.add(setter)
        init_seqs.add(current_init) 


# Pass
proc pass_group_vars_first*(pass_runner: PassRunner, root: SequenceNode) =
  var partition = root.sequence.partition(is_var)
  root.sequence = partition.selected  & partition.rejected


# Pass: init list size asm node
proc pass_init_list_sizes*(pass_runner: PassRunner, root: SequenceNode) =
  for variable in pass_runner.var_table.values:
    if variable.var_type == List:
      var asm_node = newASMNode()
      asm_node.add(DEX)
      asm_node.add(STA, "$0200,X")
      asm_node.add(LDA, num_to_im_hex(variable.size))
      asm_node.add(STA, index_to_addr_str(variable.address))
      asm_node.add(LDA, "$0200,X")
      asm_node.add(INX)
      root.sequence.insert(asm_node, 0) # insert after start label

proc indirect_with_y(addrs: string): string =
  result = "[" & addrs & "],Y"


proc gen_list_set(pass_runner: PassRunner, root: SequenceNode, el_size: int) =
  # <list> <value> <index> List-set
  # <index> <element> <list_low> <list_high>
  # <index> <element_low> <element_high> <list_low> <list_high>
  var list_set = newDefineWordNode()
  if el_size == 1:
    list_set.word_name = "List-set_8"
  else:
    list_set.word_name = "List-set_16"
  var set_asm = newASMNode()
  set_asm.add(STA, base_addr_addr_high_byte)
  set_asm.add(LDA, "$0200,X")
  set_asm.add(STA, base_addr_addr)
  if el_size == 2:
    set_asm.add(INX)
    set_asm.add(INX)
    set_asm.add(INX)
    set_asm.add(LDA, "$0200,X") # index in tos
    set_asm.add(CLC)
    set_asm.add(ADC, "$0200,X") # if element size is 2 we have to double the index
    set_asm.add(SEC)
    set_asm.add(SBC, "#$01")
    set_asm.add(TAY)
  else:
    set_asm.add(INX)
    set_asm.add(INX)
    set_asm.add(LDA, "$0200,X")
    set_asm.add(TAY)
  if el_size == 2:
    set_asm.add(DEX) # point to low byte of element
    set_asm.add(LDA, "$0200,X")
    set_asm.add(STA, indirect_with_y(base_addr_addr))
    set_asm.add(DEX)
    set_asm.add(TYA)
    set_asm.add(CLC)
    set_asm.add(ADC, "#$01")
    set_asm.add(TYA)
    set_asm.add(LDA, "$0200,X")
    set_asm.add(STA, indirect_with_y(base_addr_addr))
    set_asm.add(INX)
    set_asm.add(INX)
    set_asm.add(INX)
    set_asm.add(LDA) # repopulate tos
    set_asm.add(INX)
  else:
    set_asm.add(DEX) # point to element
    set_asm.add(LDA, "$0200,X")
    set_asm.add(STA, indirect_with_y(base_addr_addr))
    set_asm.add(INX)
    set_asm.add(INX)
    set_asm.add(LDA, "$0200,X") # repopulate tos
    set_asm.add(INX)
  list_set.definition.add(set_asm)
  pass_runner.definitions[list_set.word_name] = list_set
  root.add(list_set)


proc gen_list_get(pass_runner: PassRunner, root: SequenceNode, el_size: int) =
  # assumed it is called in this form: <var> <index> List-get
  # replaces everything with ... var_base item]
  # which means stack is: ... var_base index] where index is in register A
  # we can use some indirect addressing mode as for structure member variable access
  var list_get = newDefineWordNode()
  if el_size == 1:
    list_get.word_name = "List-get_8"
  else:
    list_get.word_name = "List-get_16"
  var get_asm = newASMNode()
  # <index> <list_low> <list_high>
  get_asm.add(STA, base_addr_addr_high_byte)
  get_asm.add(LDA, "$0200,X")
  get_asm.add(STA, base_addr_addr)
  get_asm.add(INX)
  get_asm.add(LDA, "$0200,X")
  if el_size == 2:
    get_asm.add(CLC)
    get_asm.add(ADC, "$0200,X")
    get_asm.add(INX)
    get_asm.add(SEC)
    get_asm.add(SBC, "#$01")
    get_asm.add(TAY)
    get_asm.add(LDA, indirect_with_y(base_addr_addr))
    get_asm.add(STA, "$0200,X")
    get_asm.add(TYA)
    get_asm.add(CLC)
    get_asm.add(ADC, "#$01")
    get_asm.add(TAY)
    get_asm.add(LDA, indirect_with_y(base_addr_addr))
  else:
    get_asm.add(TAY)
    get_asm.add(LDA, indirect_with_y(base_addr_addr))
    get_asm.add(INX)
  list_get.definition.add(get_asm)
  pass_runner.definitions[list_get.word_name] = list_get
  root.add(list_get)

proc gen_list_size(pass_runner: PassRunner, root: SequenceNode) =
  # ptr_low ptr_high List-size
  # tos (A) holds the base address, which contains the size directly
  # assumed first byte of list holds its size
  var list_size = newDefineWordNode()
  list_size.word_name = "List-size"
  var size_asm = newASMNode()
  size_asm.add(STA, base_addr_addr_high_byte) # store base address for indirect addressing
  size_asm.add(LDA, "$0200,X")
  size_asm.add(STA, base_addr_addr)
  size_asm.add(LDY, "#$00") # set Y to 0 because indirect addressing is used with no offset
  size_asm.add(LDA, "[" & base_addr_addr & "],Y") # replace tos with value (length) at first byte
  list_size.definition.add(size_asm)
  pass_runner.definitions[list_size.word_name] = list_size
  root.add(list_size)

# Pass
proc pass_gen_list_methods*(pass_runner: PassRunner, root: SequenceNode, el_size: int) =
  gen_list_get(pass_runner, root, el_size)
  gen_list_set(pass_runner, root, el_size)

proc pass_gen_list_methods*(pass_runner: PassRunner, root: SequenceNode) =
  pass_runner.gen_list_size(root)
  pass_runner.pass_gen_list_methods(root, 1)
  pass_runner.pass_gen_list_methods(root, 2)



# Pass
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


# Pass
proc pass_add_start_label*(pass_runner: PassRunner, root: SequenceNode) =
  var asm_node = newASMNode()
  asm_node.add(ASMLabel(label_name: "Start"))
  asm_node.add(LDA, "#$FF")
  asm_node.add(TAX) # setup stack
  root.sequence.insert(asm_node, 0)

# Pass
proc pass_add_end_label*(pass_runner: PassRunner, root: SequenceNode) =
  var end_node = newASMNode()
  end_node.add(ASMLabel(label_name: "End"))
  end_node.add(JMP, "End") # endless cycle
  root.sequence.add(end_node)
  var first_def_index = find_index(root.sequence, is_def)
  var jmp_node = newASMNode()
  jmp_node.add(JMP, "End")
  root.sequence.insert(jmp_node, first_def_index)

# Pass - Check no OtherNode's present
proc pass_check_no_OtherNodes*(pass_runner: PassRunner, root: SequenceNode) =
  var visitor = newCollectVisitor[OtherNode](proc (node: ASTNode): bool =
    result = node of OtherNode)
  root.accept(visitor)
  for node in visitor.collected:
    pass_runner.report(node, errNoWordDefForName, node.name)



proc pass_calls_to_def_check*(pass_runner: PassRunner) = 
  for call in pass_runner.calls.values:
    var defs = pass_runner.definitions
    if not(call.word_name in defs):
      pass_runner.report(call, errWordCallWithoutDefinition, call.word_name)


proc get_asm_labels(code: seq[ASMAction]): seq[string] =
  var labels: seq[string] = @[]
  for c in code:
    if c of ASMLabel:
      var label = cast[ASMLabel](c)
      if not(labels.contains(label.label_name)):
        labels.add(label.label_name)
  return labels

proc find_label_index(code: seq[ASMAction], label_name: string): int =
  for i in 0..(code.len - 1):
    if (code[i] of ASMLabel):
      var label = cast[ASMLabel](code[i])
      if label.label_name == label_name:
        return i
  return -1



proc byte_distance_from_branch_to_addr(code: seq[ASMAction], branch_index: int): int =
  var branch = cast[ASMCall](code[branch_index])
  var label_name = branch.param
  var label_index = find_label_index(code, label_name)
  var start: int
  # ? from where is the maximal offset calculated?  from the address directly after
  # the relative offset in the branch instruction or from the branch instruction itself?
  # otherwise the distance from the branch to the label will be off by one or two bytes!
  if branch_index > label_index:
    start = branch_index - 1
  else:
    start = branch_index + 1

  if start < 0:
    start = 0
  
  var byte_len = 0
  for i in start..label_index:
    var asm_line = code[i]
    byte_len += asm_line.len ### !!! to calculate len, addressing mode has to be set in every call
    # param has to be parsed to correct mode!
  return byte_len


proc is_label_name_available(name: string, code: seq[ASMAction]): bool =
  var labels = code.filter(proc (action: ASMAction): bool =
    result = action of ASMLabel)
  var label_names: seq[string] = @[]
  for label_action in labels:
    var label = cast[ASMLabel](label_action)
    label_names.add(label.label_name)
  return not(label_names.contains(name))


# transforms for example :
# <branch> <too_far_addr>
# to:
# <inv_branch> no_jump
# JMP <too_far_addr>
# no_jump: 
proc fixup_branch_code(code: var seq[ASMAction], branch_index: int) =
  var branch = cast[ASMCall](code[branch_index])
  var label_num = 0
  var no_jump_label_name = "no_jump_" & branch.param & $label_num # count up until label is available
  while not(no_jump_label_name.is_label_name_available(code)):
    label_num += 1
    no_jump_label_name = no_jump_label_name[0..(no_jump_label_name.len - 2)] & $label_num
  var inv_branch_call = newASMCall(branch.op.inverse_branch, no_jump_label_name)
  var jump_to_real_addr = newASMCall(JMP, branch.param)
  code.delete(branch_index)
  code.insert(inv_branch_call, branch_index)
  code.insert(jump_to_real_addr, branch_index + 1)
  var no_jump_label = ASMLabel(label_name: no_jump_label_name)
  code.insert(no_jump_label, branch_index + 2)

proc asm_pass_fix_branch_addr_too_far*(code: var seq[ASMAction]) =
  var MAX_DIST_POS = 120 # actually it is -127 - 128 but in the documentation it wasnt clear if op and param are included or not, so to be safe make the max range a bit smaller
  var MAX_DIST_NEG = -120
  var found_branches = code.filter(proc (action: ASMAction): bool =
    if action of ASMCall:
      var call = cast[ASMCall](action)
      if call.is_branch:
        return true
    return false)

  for branch in found_branches:
    var branch_index = code.find(branch)
    var dist = byte_distance_from_branch_to_addr(code, branch_index)
    if (dist > MAX_DIST_POS) or (dist < MAX_DIST_NEG):
      echo "fix branch: " & code[branch_index].asm_str
      fixup_branch_code(code, branch_index)




  



    
    
    
      
  


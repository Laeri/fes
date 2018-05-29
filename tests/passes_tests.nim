import 
  unittest, types, compiler, msgs, passes, parser, tables, ast

suite "Passes Suite":

  setup:
    var handler = newErrorHandler()
    handler.set_silent
    var compiler = newFESCompiler()
    var src: string
    var parser = newParser(handler)
    var pass_runner = newPassRunner(parser)

  teardown:
    compiler = nil
    handler = nil
    src = nil
    parser = nil

  test "load variable instead of calling a word name":
    src = " variable test_var test_var"
    parser.parse_string(src)
    pass_runner.pass_set_variable_loads(parser.root)
    #check(parser.root.sequence[1] of LoadVariableNode)


  test "Pass: Transform OtherNode to WordCallNode if corresponding DefineWordNode exists":
    src = ": name ; name"
    parser.parse_string(src)
    var nodes = parser.root.sequence
    check(nodes.len == 2)
    check(nodes[0] of DefineWordNode)
    check(nodes[1] of OtherNode)
    var other_node = cast[OtherNode](nodes[1])
    check(other_node.name == "name")
    pass_runner.pass_set_word_calls(parser.root)
    var call_node = cast[CallWordNode](nodes[1])
    check(call_node.word_name == "name")

  test "Pass: Transform OtherNode to LoadVariableNode if corresponding VariableNode exists":
    src = "variable player player"
    parser.parse_string(src)
    var nodes = parser.root.sequence
    check(nodes.len == 2)
    check(nodes[0] of VariableNode)
    check(nodes[1] of OtherNode)
    var other_node = cast[OtherNode](nodes[1])
    check(other_node.name == "player")
    pass_runner.pass_set_variable_loads(parser.root)
    var var_node = cast[LoadVariableNode](nodes[1])
    check(var_node.name == "player")

  test "OtherNode->CallWordNode conversion should also happen in DefineWordNode's definition":
    src = ": name1 ; : name2 name1 ;"
    parser.parse_string(src)
    var is_other = (proc (node: ASTNode): bool =
      return node of OtherNode)
    pass_runner.pass_set_word_calls(parser.root)
    check(any_true(parser.root, is_other) == false)

  test "variable <name> <Type> should input its type into VariableNode":
    src = "struct Player {x y z} variable player Player"
    parser.parse_string(src)
    pass_runner.pass_set_struct_var_type(parser.root)
    var seq_node = parser.root.sequence
    check(seq_node.len == 2)
    check(seq_node[0] of StructNode)
    check(seq_node[1] of VariableNode)
    var var_node = cast[VariableNode](seq_node[1])
    check(var_node.var_type == Struct)

  test "size after pass_set_variable_addresses(compiler.parser.root)":
    src = "variable name struct Player {x y z} variable player Player"
    parser.parse_string(src)
    pass_runner.pass_set_struct_var_type(parser.root)
    pass_runner.pass_set_variable_addresses(parser.root)
    var seq_node = parser.root.sequence
    check(seq_node[0] of VariableNode)
    check(seq_node[1] of StructNode)
    check(seq_node[2] of VariableNode)
    var normal_var = cast[VariableNode](seq_node[0])
    var struct_var = cast[VariableNode](seq_node[2])
    check(normal_var.size == 1)
    check(struct_var.size == 3)

  test "address after pass_set_variable_addresses(compiler.parser.root)":
    src = "struct Player {x y z} variable player Player variable name"
    parser.parse_string(src)
    pass_runner.pass_set_struct_var_type(parser.root)
    pass_runner.pass_set_variable_addresses(parser.root)
    var seq_node = parser.root.sequence
    check(seq_node[0] of StructNode)
    check(seq_node[1] of VariableNode)
    check(seq_node[2] of VariableNode)
    var normal_var = cast[VariableNode](seq_node[2])
    var struct_var = cast[VariableNode](seq_node[1])
    check(normal_var.address == 3)
    check(struct_var.address == 0)

  test "struct getter test":
    src = "struct Player { x y }"
    parser.parse_string(src)
    pass_runner.pass_gen_getters(parser.root)
    var seq_node = parser.root
    check(seq_node.len == 3)
    var get_x = cast[DefineWordNode](seq_node.sequence[1])
    var get_y = cast[DefineWordNode](seq_node.sequence[2])
    check(get_x.word_name == "get-Player-x")
    check(get_y.word_name == "get-Player-y")

  test "struct setter test":
    src = "struct Player { x y }"
    parser.parse_string(src)
    pass_runner.pass_gen_setters(parser.root)
    var seq_node = parser.root
    check(seq_node.len == 3)
    var get_x = cast[DefineWordNode](seq_node.sequence[1])
    var get_y = cast[DefineWordNode](seq_node.sequence[2])
    check(get_x.word_name == "set-Player-x")
    check(get_y.word_name == "set-Player-y")

  test "input List type into variable":
    src = "variable items list-5"
    parser.parse_string(src)
    pass_runner.pass_set_list_var_type(parser.root)
    check(parser.root.len == 1)
    check(parser.root[0] of VariableNode)
    var var_node = cast[VariableNode](parser.root[0])
    check(var_node.var_type == List)
    check(var_node.name == "items")






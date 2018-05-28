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

  test "Input struct type into VariableNode":
    src = "struct Player { x y } variable player Player"
    parser.parse_string(src)
    pass_runner.pass_set_struct_var_type(parser.root)
    echo parser.root.str

    

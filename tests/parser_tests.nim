import
  unittest, types, parser, msgs, ast, tables

suite  "Parser Suite":
  
  setup:
    var handler = newErrorHandler()
    handler.set_silent
    var parser = newParser(handler)
    var src: string

  teardown:
    parser = nil
    handler = nil
    src = nil

  test "parse word call before passes is OtherNode":
    src = ": name ; name"
    parser.parse_string(src)
    var node_seq = parser.root.sequence
    check(node_seq.len == 2)
    check(node_seq[0] of DefineWordNode == true)
    check(node_seq[1] of OtherNode == true)
    var other_n = cast[OtherNode](node_seq[1])
    check(other_n.name == "name")

  test "struct reference before passes is OtherNode":
    src = "struct Player { x y } variable player Player"
    parser.parse_string(src)
    var node_seq = parser.root.sequence
    check(node_seq.len == 3) # StructNode, VariableNode, OtherNode
    check(node_seq[0] of StructNode)
    check(node_seq[1] of VariableNode)
    check(node_seq[2] of OtherNode)

  test "struct with closing brackets directly at members":
    src = "struct Player {x y} z"
    parser.parse_string(src)
    var node_seq = parser.root.sequence
    check(node_seq.len == 2)
    check(node_seq[0] of StructNode)
    var struct_node = cast[StructNode](node_seq[0])
    check(struct_node.members.len == 2)
    check(struct_node.members[0] == "x")
    check(struct_node.members[1] == "y")

  test "errNestedWordDef: defining a word twice should be reported":
    src = ": name : name2 ;"
    parser.parse_string(src)
    check(handler.has_error_type(errNestedWordDef) == true)

  test "errMissingWordEnding: defining a word without ending \";\" should be reported":
    src = ": name"
    parser.parse_string(src)
    check(handler.has_error_type(errMissingWordEnding) == true)

  test "errInvalidDefinitionWordName: a word definition name cannot be a number and should be reported":
    src = ": 1 ;"
    parser.parse_string(src)
    check(handler.has_error_type(errInvalidDefinitionWordName) == true)

  test "errInvalidDefinitionWordName: a word definition name cannot be \":\", \";\" and should be reported":
    src = ": : ;"
    parser.parse_string(src)
    check(handler.has_error_type(errInvalidDefinitionWordName) == true)
    src = ": ; ;"
    parser.parse_string(src)
    check(handler.has_error_type(errInvalidDefinitionWordName) == true)

  test "errMissingWordDefName: a word definition with no given name should be reported":
    src = ":"
    parser.parse_string(src)
    check(handler.has_error_type(errMissingWordDefName) == true)

  test "errMissingASMEnding: an asm block without closing \']\' should be reported":
    src = "["
    parser.parse_string(src)
    check(handler.has_error_type(errMissingASMEnding) == true)


  test "errInvalidASMInstruction: invalid asm instruction should be reported":
    src = "[ NNN ]"
    parser.parse_string(src)
    check(handler.has_error_type(errInvalidASMInstruction) == true)

  test "warnMissingASMBody: asm body inside \'[]\' is empty and should be reported":
    src = "[ ]"
    parser.parse_string(src)
    check(handler.has_error_type(warnMissingASMBody) == true)
    src = ":name [ ] ;"
    parser.parse_string(src)
    check(handler.has_error_type(warnMissingASMBody) == true)
  
  test "warnMissingWordDefBody: word definition body is empty and should be reported":
    src = ": name ;"
    parser.parse_string(src)
    check(handler.has_error_type(warnMissingWordDefBody) == true)

  test "warnMissingThenBody: if else block without \'then\' body should be reported":
    src = "if then"
    parser.parse_string(src)
    check(handler.has_error_type(warnMissingThenBody) == true)

  test "warnMissingElseBody: if else block without \'else\' body should be reported":
    src = "if 1 else then"
    parser.parse_string(src)
    check(handler.has_error_type(warnMissingElseBody) == true)
    
  test "errMissingIfElseEnding: if block has no closing \'then\'":
    src = "if"
    parser.parse_string(src)
    check(handler.has_error_type(errMissingIfElseEnding) == true)

  test "errMissingIfElseEnding: if else block has no closing \'then\'": 
    src = "if else"
    parser.parse_string(src)
    check(handler.has_error_type(errMissingIfElseEnding) == true)

  test "warnMissingWhileConditionBody: while statement has no condition":
    src = "begin while repeat"
    parser.parse_string(src)
    check(handler.has_error_type(warnMissingWhileConditionBody) == true)

  test "warnMissingWhileThenBody: while statement has no body":
    src = "begin while repeat"
    parser.parse_string(src)
    check(handler.has_error_type(warnMissingWhileThenBody) == true)

  test "parser should be able to parse only one space":
    src = " "
    parser.parse_string(src)
    check(handler.has_errors == false)

  test "parser should be able to parse only new lines":
    src = """


"""
    parser.parse_string(src)
    check(handler.has_errors == false)

  test "parser should be able to parse the empty string":
    src = ""
    parser.parse_string(src)
    check(handler.has_errors == false)  

  test "errWordAlreadyDefined, word name cannot be defined twice":
    src = ": name 1 ; : name 1 ;"
    parser.parse_string(src)
    #check(handler.has_error_type(errWordAlreadyDefined) == true)

  test "errInvalidVariableName: a number is not a valid variable name":
    src = "variable 1"
    parser.parse_string(src)
    check(handler.has_error_type(errInvalidVariableName) == true)
 
  test "missingVariableName: variable name should be supplied":
    src = "variable"
    parser.parse_string(src)
    check(handler.has_error_type(errMissingVariableName))

  test "parse variable":
    src = "variable date"
    parser.parse_string(src)

  test "parse two src strings":
    var src1 = "1 2"
    var src2 = "3 4"
    parser.parse_string(src1, "SRC1")
    parser.parse_additional_src(src2, "SRC2")

  test "parse struct":
    src = "struct test_name { a b c }"
    parser.parse_string(src)
    check(parser.root.sequence.len == 1)
    check(parser.root.sequence[0] of StructNode)
    var node: StructNode = cast[StructNode](parser.root.sequence[0])
    check(node.members.len == 3)
    check(node.members[0] == "a")
    check(node.members[1] == "b")
    check(node.members[2] == "c")

    src = "struct test_name {a b c }"
    parser.parse_string(src)
    check(parser.root.sequence.len == 1)
    check(parser.root.sequence[0] of StructNode)
    node = cast[StructNode](parser.root.sequence[0])
    check(node.members.len == 3)
    check(node.members[0] == "a")
    check(node.members[1] == "b")
    check(node.members[2] == "c")

    src = "struct test_name { a b c}"
    parser.parse_string(src)
    check(parser.root.sequence.len == 1)
    check(parser.root.sequence[0] of StructNode)
    node = cast[StructNode](parser.root.sequence[0])
    check(node.members.len == 3)
    check(node.members[0] == "a")
    check(node.members[1] == "b")
    check(node.members[2] == "c")

  test "warnMissingStructBody: empty struct body should be reported":
    src = "struct test_name { }"
    parser.parse_string(src)
    check(handler.has_error_type(warnMissingStructBody))

  test "errMissingStructEnding: struct should be closed with \'}\'":
    src = "struct test_name {"
    parser.parse_string(src)
    check(handler.has_error_type(errMissingStructEnding))

  test "parse list":
    src = "list-3"
    parser.parse_string(src)
    check(parser.root.sequence.len == 1)
    check(parser.root.sequence[0] of ListNode)
    var list_node = cast[ListNode](parser.root.sequence[0])
    check(list_node.size == 3)

  test "parse if else inside word definition":
    src = ": name if 3 then ;"
    parser.parse_string(src)
    check(handler.has_errors == false)

  test "parse while inside word definition":
    src = ": name begin true while 3 repeat ; "
    parser.parse_string(src)
    check(handler.has_errors == false)

  test "skip # line comment":
    src = """
# name is a word
: name
# def description
1 2 3
;
"""
    parser.parse_string(src)
    check(handler.has_errors == false)
    check(parser.root.sequence.len == 1)
    check(parser.root[0] of DefineWordNode)

  test "parse constant":
    src = "const name $2000"
    parser.parse_string(src)
    echo parser.root.str



  




    

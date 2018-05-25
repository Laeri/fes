import
  unittest, types, parser, msgs

suite "Parser Suite":

  setup:
    var handler = newErrorHandler()
    handler.set_silent
    var parser = newParser(handler)
    var src: string

  teardown:
    parser = nil
    handler = nil
    src = nil
  
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

  test "errTooManyASMOperands: an asm instruction can at most have one operand, two should be reported":
    src = "[ JSR $00 $00 ]"
    parser.parse_string(src)
    check(handler.has_error_type(errTooManyASMOperands) == true)
    src = "[ JSR $00 $00"
    parser.parse_string(src)
    check(handler.has_error_type(errTooManyASMOperands) == true)

  test "errTooManyASMOperands: an asm instruction can at most have one operands, three should be reported":
    src = "[ JSR $00 $00 $00"
    parser.parse_string(src)
    check(handler.has_error_type(errTooManyASMOperands) == true)

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
    
  test "errMissingIfElseEnding: if else block has no closing \'then\'":
    src = "if"
    parser.parse_string(src)
    check(handler.has_error_type(errMissingIfElseEnding) == true)
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

  test "parse constant":
    src = "variable date"
    parser.parse_string(src)
    echo parser.root.repr

  




    

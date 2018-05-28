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
    pass_runner.pass_word_to_var_calls(parser.root)
    echo parser.root.str
    #check(parser.root.sequence[1] of LoadVariableNode)

  test "call to word without definition should be reported":
    src = "no_def_call"
    parser.parse_string(src)
    pass_runner.pass_calls_to_def_check()
    check(handler.has_error_type(errWordCallWithoutDefinition) == true)
import 
  unittest, types, compiler, msgs, parser, tables

suite "Passes Suite":

  setup:
    var handler = newErrorHandler()
    handler.set_silent
    var compiler = newFESCompiler()
    var src: string
    var parser = newParser(handler)

  teardown:
    compiler = nil
    handler = nil
    src = nil
    parser = nil

  test "load variable instead of calling a word name":
    src = " variable test_var test_var"
    parser.parse_string(src)
    compiler.pass_word_to_var_calls(parser.root)
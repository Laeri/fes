import
  random, sets, unittest, strutils, sequtils, scanner, types, codegenerator



suite "CodeGenerator Suite":

  setup:
    var generator = newCodeGenerator()
    var src: string
  teardown:
    discard
  
  test "executing a word should call subroutine with JSR":
    var node = CallWordNode()
    node.word_name = "Test"
    generator.emit(node)
    check(generator.code.len == 1)
    check(generator.code[0] == newASMCall(JSR, "Test"))
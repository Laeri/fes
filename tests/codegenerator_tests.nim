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

  test "pushing a number onto the stack should do LDA and STA":
    var node = PushNumberNode()
    node.number = 1
    generator.emit(node)
    check(generator.code.len == 2)
    check(generator.code[0] == newASMCall(LDA, "#$01"))
    check(generator.code[1] == newASMCall(STA, "$02FF,X"))
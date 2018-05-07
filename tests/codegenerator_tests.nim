import
  random, sets, unittest, strutils, sequtils, scanner, types, codegenerator, parser



suite "CodeGenerator Suite":

  setup:
    var generator = newCodeGenerator()
    var src: string
    var parser = newParser()
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
    check(generator.code.len == 3)
    check(generator.code[0] == newASMCall(DEX))
    check(generator.code[1] == newASMCall(STA, "$02FF,X"))
    check(generator.code[2] == newASMCall(LDA, "#$01"))


  test "sequence of push numbers and call words":
    src = "1 name1 2 name2"
    parser.parse_string(src)
    generator.emit(parser.root)
    check(generator.code.len == 8)
    check(generator.code[0] == newASMCall(DEX))
    check(generator.code[1] == newASMCall(STA, "$02FF,X"))
    check(generator.code[2] == newASMCall(LDA, "#$01"))
    check(generator.code[3] == newASMCall(JSR, "name1"))
    check(generator.code[4] == newASMCall(DEX))
    check(generator.code[5] == newASMCall(STA, "$02FF,X"))
    check(generator.code[6] == newASMCall(LDA, "#$02"))
    check(generator.code[7] == newASMCall(JSR, "name2"))

   

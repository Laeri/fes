import
  random, sets, unittest, strutils, sequtils, scanner, types, codegenerator, parser, passes, asm_t



suite "CodeGenerator Suite":

  setup:
    var generator = newCodeGenerator()
    var src: string
    var parser = newParser()
    var pass_runner = newPassRunner(parser)

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
    check(generator.code[1] == newASMCall(STA, "$0200,X"))
    check(generator.code[2] == newASMCall(LDA, "#$01"))

#[
  test "loading a variable should push its address onto the stack":
    var load_node = LoadVariableNode()
    var variable_node = VariableNode()
    variable_node.name = "test_var"
    variable_node.address = 5
    load_node.var_node = variable_node
    generator.emit(load_node)
    check(generator.code.len == 3)
    check(generator.code[0] == newASMCall(DEX))
    check(generator.code[1] == newASMCall(STA, "$0200,X"))
    check(generator.code[2] == newASMCall(LDA, "#$05"))
]#
#[
  test "sequence of push numbers and call words":
    src = ": name 1; : name2 ; 1 name1 2 name2"
    parser.parse_string(src)
    pass_runner.pass_set_word_calls(parser.root)
    generator.emit(parser.root)
    check(generator.code.len == 8)
    check(generator.code[0] == newASMCall(DEX))
    check(generator.code[1] == newASMCall(STA, "$0200,X"))
    check(generator.code[2] == newASMCall(LDA, "#$01"))
    check(generator.code[3] == newASMCall(JSR, "name1"))
    check(generator.code[4] == newASMCall(DEX))
    check(generator.code[5] == newASMCall(STA, "$0200,X"))
    check(generator.code[6] == newASMCall(LDA, "#$02"))
    check(generator.code[7] == newASMCall(JSR, "name2"))
]#

  test "asm call without argument in block should be generated":
    src = "[ inx ]"
    parser.parse_string(src)
    generator.emit(parser.root)
    var code_str = generator.code_as_string
    check(code_str == "  INX\n")

  test "asm call with two parameters (indirect address mode) in block should be generated":
    src = "[ sta $0200,X ]"
    parser.parse_string(src)
    generator.emit(parser.root)
    var code_str = generator.code_as_string
    check(code_str == "  STA $0200,X\n")

  test "asm call without args in block should be generated":
    src = "[ jmp label_name ]"
    parser.parse_string(src)
    generator.emit(parser.root)
    var code_str = generator.code_as_string
    check(code_str == "  JMP label_name\n")

  test "asm label in block should be generated":
    src = "[ label_name: ]"
    parser.parse_string(src)
    generator.emit(parser.root)
    var code_str = generator.code_as_string
    check(code_str == "label_name:\n")

  test "asm block should be generated independent if \'[\' and  \']\' are on a new line or not":
    src = """[
INX
]"""
    parser.parse_string(src)
    generator.emit(parser.root)
    var code_str = generator.code_as_string
    check(code_str == "  INX\n")

    

  test "nested if's should have distinct label names!":
    src = "if 5 else if 3 else 4 if 0 else 1 then then then if 6 else 7 then"
    parser.parse_string(src)
    generator.emit(parser.root)
    var code = generator.code
    var labels = code.filter(proc (action: ASMAction): bool =
      action of ASMLabel)
    var label_names: seq[string] = @[]
    for l in labels:
      var label = cast[ASMLabel](l)
      label_names.add(label.label_name)
    var label_set = label_names.toSet
    check(label_set.len == label_names.len) # otherwise a label was in there more than once


  test "nested while's should have distinc label names!":
    src = "begin 255 while begin 0 while begin 255 while 0 end end end"
    parser.parse_string(src)
    generator.emit(parser.root)
    var code = generator.code
    var labels = code.filter(proc (action: ASMAction): bool =
      action of ASMLabel)
    var label_names: seq[string] = @[]
    for l in labels:
      var label = cast[ASMLabel](l)
      label_names.add(label.label_name)
    var label_set = label_names.toSet
    check(label_set.len == label_names.len) # otherwise a label was in there more than once






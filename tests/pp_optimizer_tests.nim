import
  unittest, ../src/fespkg/types, ../src/fespkg/optimizer, ../src/fespkg/compiler, ../src/fespkg/parser

template do_rule_test(): untyped =
  parser.parse_string(asm_src)
  parser.root.emit(asm_calls)
  pp_optimizer.optimize_rule_str(rule_src, asm_calls)
  parser.parse_string(result_src)
  parser.root.emit(asm_result)
  check(asm_result.aasm_to_string == asm_calls.aasm_to_string)


suite "JSR_RTS":

  setup:
    var parser = newParser()
    var asm_calls: seq[ASMAction] = @[]
    var pp_optimizer: NESPPOptimizer = newNESPPOptimizer()
    var asm_src: string
    var rule_src: string
    var result_src: string
    var asm_result: seq[ASMAction] = @[]

  teardown:
    discard
  
  test "JSR_RTS":
    asm_src = """
      [
        JSR Loop
        RTS
      ]
    """
    rule_src = """
     Name: JSR_RTS
     ID: 1
     Descr:
     If we JSR to another subroutine last in a given subroutine we 
     can jump directly
     ---------------
     JSR _1_
     RTS
     ===============
     JMP _1_
     ---------------   
    """
    result_src = """
    [
    JMP Loop
    ]
    """

    #do_rule_test




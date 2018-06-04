import
  types, msgs, compiler, utils, ast, unittest, strutils, nimes_integration, ../lib/nimes/src/nes, ../lib/nimes/src/nes/mem, utils

template check_memory(mem_addr: int, check_val: int): untyped =
  var addr_uint16 = cast[uint16](mem_addr)
  var val_uint8 = cast[uint8](check_val)
  check(nes.cpu.mem[addr_uint16] == val_uint8)

template print_memory(from_addr: int, to_addr: int): untyped =
  for i in from_addr .. to_addr:
    var addr_uint16 = cast[uint16](i)
    echo "addr: " & $addr_uint16 & " val: " & $nes.cpu.mem[addr_uint16]

template check_tos(check_val: uint8): untyped =
  check(tos(nes) == check_val)

template compile_and_run(src: string, seconds: float = 0.2): untyped {.dirty.} =
  compiler.compile_test_str(src)
  nes = newNES(tmp_nes_path)
  nes.run(seconds)

template check_sos(check_val: uint8): untyped {.dirty.} =
  var sos: uint8 = nes.cpu.mem[second_of_stack_base_addr() + nes.cpu.x]
  check(sos == check_val)

template print_tos(): untyped {.dirty.} =
  nes.print_tos()



suite "Emulation Suite":

  setup:
    var compiler: FESCompiler = newFESCompiler()
    compiler.load_core_words = true
    # compile to temporary directory /tests/tmp
    # the output will be used as input into the nes emulator
    var tmp_src_path = "tests/tmp/emu_test.asm"
    var tmp_nes_path = "tests/tmp/emu_test.nes"
    compiler.out_asm_folder = tmp_src_path
    compiler.name = "FES: Emu Test"
    compiler.version = "Emu Test Version" 
    
    var nes: NES
    var src: string
  teardown:
    nes = nil
  
  test "variable should be stored at location $00":
    compile_and_run("variable name 1 name !")
    nes = newNES(tmp_nes_path)
    nes.run(1)
    #print_memory(0, 15)
    check_memory(0, 1)

  test "two variables should be stored at location $00 and $01":
    compile_and_run("""
variable name1
variable name2
variable name3
5 name1 !
10 name2 !
15 name3 !""")
    check_memory(0x00, 5)
    check_memory(0x01, 10)
    check_memory(0x02, 15)

  test "pushed number should turn up in register A":
    compile_and_run("1")
    check_tos(1)

  test "pushing two numbers should end up in register A and memory location 0x0200 offset by register X ([$0200,X])":
    compile_and_run("1 2")
    check_tos(2)
    check_sos(1)

  test "struct access":
    compile_and_run("""
struct Coord { x y }
variable coords Coord
3 coords set-Coord-x
""")
    print_memory(0, 15)
    check_memory(0, 3)

  test "struct setter test of x,y":
    compile_and_run("""
struct Player { x y }
variable player Player
3 player set-Player-y
4 player set-Player-x
""")
    check_memory(0x01, 3)
    check_memory(0x00, 4)

  test "struct getter test of y":
    compile_and_run("""
struct Player { x y }
variable player Player
3 player set-Player-y
player get-Player-y
""")
    check_tos(3)
    
  test "struct getter test of x":
    compile_and_run("""
struct Player { x y }
variable player Player
3 player set-Player-x
player get-Player-x
""")
    check_tos(3)

  test "+ positive":
    compile_and_run("1 2 +")
    check_tos(3)

  test "+ negative":
    compile_and_run("-10")
    nes.print_tos()

  test "-":
    compile_and_run("5 3 -")
    check_tos(2)

  test "swap":
    compile_and_run("1 2 swap")
    check_tos(1)
    check_sos(2)

  test "drop":
    compile_and_run("1 2 3 4 5 drop")
    check_tos(4)
    check_sos(3)

  test "rot":
    compile_and_run("1 2 3 rot")
    check_tos(1)
    check_sos(3)

  test "dup":
    compile_and_run("10 dup")
    check_tos(10)
    check_sos(10)

  test "@: load variable content":
    compile_and_run("variable player 3 player ! player @ ")
    check_tos(3)

  test "true":
    compile_and_run("true")
    check_tos(uint8_true())

  test "false":
    compile_and_run("false")
    check_tos(uint8_false())

  test "not false":
    compile_and_run("false not")
    check_tos(uint8_true())
  
  test "not true":
    compile_and_run("true not")
    check_tos(uint8_false())

  test "true and false":
    compile_and_run("true false and")
    check_tos(uint8_false())

  test "false and true":
    compile_and_run("false true and")
    check_tos(uint8_false())

  test "true and true":
    compile_and_run("true true and")
    check_tos(uint8_true())

  test "false and false":
    compile_and_run("false false and")
    check_tos(uint8_false())

  test "true or false":
    compile_and_run("true false or")
    check_tos(uint8_true())

  test "false or true":
    compile_and_run("false true or")
    check_tos(uint8_true())

  test "true or true":
    compile_and_run("true true or")
    check_tos(uint8_true())

  test "false or false":
    compile_and_run("false false or")
    check_tos(uint8_false())

  test "true xor false":
    compile_and_run("true false xor")
    check_tos(uint8_true())

  test "false xor true":
    compile_and_run("false true xor")
    check_tos(uint8_true())

  test "false xor false":
    compile_and_run("false false xor")
    check_tos(uint8_false())

  test "true xor true":
    compile_and_run("true true xor")
    check_tos(uint8_false())

  test "=: true":
    compile_and_run("1 1 =")
    check_tos(uint8_true())

  test "=: false":
    compile_and_run("1 2 =")
    check_tos(uint8_false())

  test "!=: true":
    compile_and_run("1 2 !=")
    check_tos(uint8_true())

  test "!=: false":
    compile_and_run("1 1 !=")
    check_tos(uint8_false())

  test "<: true":
    compile_and_run("3 4 <")
    print_tos()
    check_tos(uint8_true())
  
  test "<: false":
    compile_and_run("10 1 <")
    print_tos()
    check_tos(uint8_false())

  test ">: true":
    compile_and_run("4 3 >")
    check_tos(uint8_true())

  test ">: false":
    compile_and_run("1 10 >")
    check_tos(uint8_false())

  test ">=: true":
    compile_and_run("2 1 >=")
    check_tos(uint8_true())

  test ">=: false":
    compile_and_run("1 2 >=")
    check_tos(uint8_false())

  test "<=: true":
    compile_and_run("1 2 <=")
    check_tos(uint8_true())

  test "<=: false":
    compile_and_run("2 1 <=")
    check_tos(uint8_false())






















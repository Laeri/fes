import
  types, msgs, compiler, utils, ast, unittest, strutils, nimes_integration, ../lib/nimes/src/nes, ../lib/nimes/src/nes/mem, utils

template check_memory(mem_addr: int, check_val: int): untyped =
  var addr_uint16 = cast[uint16](mem_addr)
  var val_uint8 = cast[uint8](check_val)
  check(nes.cpu.mem[addr_uint16] == val_uint8)

template print_memory(from_addr: int, to_addr: int = from_addr): untyped =
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

template check_stack(stack_index: int, check_val: uint8): untyped =
  # stack index for tos = 0, for sos = -1, -2,-3....
  if stack_index == 0:
    check_tos(check_val)
  var mem_index: uint16 = cast[uint16](0x0200 + cast[int](nes.cpu.x) - stack_index - 1) # tos is in A
  check(nes.cpu.mem[mem_index] == check_val)



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
    print_memory(0, 15)
    #check_memory(0, 1)

  test "three variables should be stored at location $00 and $01, $02":
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

  test "second variable should be loaded on stack":
    compile_and_run("""
variable name1
variable name2
5 name1 !
10 name2 !
name2 @""")
    check_memory(0x00, 5)
    check_memory(0x01, 10)
    print_tos()

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
    check_memory(0x0000, 3)

  test "struct setter test of x,y":
    compile_and_run("""
struct Player { x y }
variable player Player
3 player set-Player-y
4 player set-Player-x
""")
    check_memory(0x0001, 3)
    check_memory(0x0000, 4)

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

  test "struct after var":
    compile_and_run("""
variable test_var
struct TestPlayer { x y }
variable player TestPlayer
10 player set-TestPlayer-x
player get-TestPlayer-x""")
    check_tos(10)

  test "struct settting, getting multiple times":
    compile_and_run("""
struct Input { ByteValue }
variable input1 Input
128 input1 set-Input-ByteValue
10 input1 set-Input-ByteValue
135 input1 set-Input-ByteValue
input1 get-Input-ByteValue""")
    check_tos(135)

  test "several structs":
    compile_and_run("""
struct Coords { x y }
struct Input { ByteValue }
variable coords1 Coords
variable input_t Input
variable coords2 Coords
variable input_t2 Input
128 input_t set-Input-ByteValue
5 coords1 set-Coords-x
10 coords1 set-Coords-y
125 input_t2 set-Input-ByteValue
input_t get-Input-ByteValue""")
    print_memory(0x0300, 0x0310)
    check_tos(128)

  test "struct accessing with overwritten memory":
    compiler.compile_test_str("struct Input { ByteValue } variable input Input 3 input set-Input-ByteValue input get-Input-ByteValue")
    nes = newNES(tmp_nes_path)
    for i in 0..0x02FF:
      nes.cpu.mem[cast[uint16](i)] = cast[uint8](0xFF) # overwrite all memory locations
    nes.run(1)
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

  test "nip":
    compile_and_run("1 2 3 nip")
    check_sos(1)
    check_tos(3)

  test "tuck":
    compile_and_run("1 2 3 tuck")
    check_tos(3)
    check_sos(2)
    check_stack(-2, 3)
    

  test "drop":
    compile_and_run("1 2 3 4 5 drop")
    check_tos(4)
    check_sos(3)

  test "rot":
    compile_and_run("1 2 3 rot")
    check_tos(1)
    check_sos(3)

  test "rot with more numbers on stack":
    compile_and_run(" 1 3 4 5 rot ")
    check_tos(3)
    check_sos(5)

  test "rot twice":
    compile_and_run("1 2 3 rot rot")
    check_tos(2)
    check_sos(1)

  test "over":
    compile_and_run("1 2 3 over")
    check_tos(2)
    check_sos(3)

  test "dup":
    compile_and_run("10 dup")
    check_tos(10)
    check_sos(10)

  test "2dup":
    compile_and_run("1 2 3 2dup")
    check_tos(3)
    check_sos(2)
    print_memory(0x0200, 0x02FF)

  test "2swap":
    compile_and_run("1 2 3 4 2swap")
    check_tos(2)
    check_sos(1)

  test "2over":
    compile_and_run("1 2 3 4 2over")
    check_tos(2)
    check_sos(1)

  test "inv_rot":
    compile_and_run("1 2 3 inv_rot")
    check_tos(2)
    check_sos(1)

  test "pull_fourth_up":
    compile_and_run("1 2 3 4 pull_fourth_up")
    check_tos(1)
    check_sos(4)

  test "pull_fifth_up":
    compile_and_run("1 2 3 4 5 copy_fifth_up")
    check_tos(1)
    check_sos(5)


  test "@: load variable content":
    compile_and_run("variable player 3 player ! player @")
    check_tos(3)
    print_tos()

  test "@: correct data stack pointer (X) after load. Bug was present which only popped high_byte of address":
    compile_and_run("0 0 @")
    check(nes.cpu.x == 0xFE)

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

  test "list: set one value":
    compile_and_run("""
variable lst list-5
lst 3 0 list-set""")
    check_memory(0x01, 3) # first element of a list holds its size
    check_memory(0x00, 5)
    

  test "list: set multiple values":
    compile_and_run("""
variable lst list-5
lst 3 0 list-set
lst 4 1 list-set
lst 5 2 list-set
lst 6 3 list-set
lst 7 4 list-set""")
    check_memory(0x01, 3) # first element of a list holds its size
    check_memory(0x02, 4)
    check_memory(0x03, 5)
    check_memory(0x04, 6)
    check_memory(0x05, 7)
    check_memory(0x00, 5) # check list size

  test "list: size test":
    compile_and_run("""
variable lst list-1
variable lst2 list-2
variable lst3 list-3
variable lst4 list-4""")
    check_memory(0x00, 1)
    check_memory(0x02, 2)
    check_memory(0x05, 3)
    check_memory(0x09, 4)

  test "list: get one value":
    compile_and_run("""
variable lst list-1
lst 10 0 list-set
lst 0 list-get
""")
    check_tos(10)

  test "mul: 2 * 3":
    compile_and_run("2 3 *")
    check_tos(6)

  test "mul: 10 * 15":
    compile_and_run("10 15 *")
    check_tos(150)

  test "mul: 4 * 4":
    compile_and_run("4 dup *")
    check_tos(16)

  test "8 / 2":
    compile_and_run("8 2 /")
    print_memory(0xFA, 0xFD)
    check_tos(4)

  test "16 / 4":
    compile_and_run("16 4 /")
    print_memory(0xFA, 0xFD)
    check_tos(4)

  test "7 / 3":
    compile_and_run("7 3 /")
    check_tos(2)

  test "16 mod 2":
     compile_and_run("16 2 mod")
     check_tos(0)

  test "3 mod 2":
     compile_and_run("3 2 mod")
     check_tos(1)

  test "17 mod 4":
     compile_and_run("17 4 mod")
     check_tos(1)

  test "if: true no else":
    compile_and_run("true if 1 then")
    check_tos(1)

  test "if: true with else":
    compile_and_run("true if 1 else 2 then")
    check_tos(1)
 
  test "if: false with else":
    compile_and_run("false if 1 else 2 then")
    check_tos(2)

  test "if: false no else":
    compile_and_run("5 false if 2 then")
    check_tos(5)

  test "if: true should remove condition bool from stack":
    compile_and_run("false true if 1 else 2 then drop")
    check_tos(uint8_false())

  test "if: false should remove condition bool from stack":
    compile_and_run("true false if 1 else 2 then drop")
    check_tos(uint8_true())
    print_memory(0x0200, 0x02FF)

  test "while: countdown":
    compile_and_run("10 begin dup 1 != while 1 - end")
    check_tos(1)

  test "while: no entry":
    compile_and_run("5 begin false while 1 end")
    check_tos(5)

  test "push binary number #%":
    compile_and_run("#%1011")
    check_tos(0b1011)

  test "push binary number 0b":
    compile_and_run("0b1011")
    check_tos(0b1011)

  test "push hex number #$2001":
    compile_and_run("#$11")
    check_tos(0x11)

  test "push hex number 0x2001":
    compile_and_run("0x11")
    check_tos(0x11)



















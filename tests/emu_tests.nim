import
  types, msgs, nimes_integration, compiler, utils, ast, unittest, strutils, nimes_integration, ../lib/nimes/src/nes, ../lib/nimes/src/nes/mem, utils


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
struct Coord {
  x Number
  y Number
}
variable coords Coord
3 coords set-Coord-x
""")
    check_memory(0x0000, 3)

  test "struct setter test of x,y":
    compile_and_run("""
struct Player {
  x Number
  y Number
}
variable player Player
3 player set-Player-y
4 player set-Player-x
""")
    check_memory(0x0001, 3)
    check_memory(0x0000, 4)

  test "struct getter test of y":
    compile_and_run("""
struct Player {
  x Number
  y Number
}
variable player Player
3 player set-Player-y
player get-Player-y
""")
    check_tos(3)
    
  test "struct getter test of x":
    compile_and_run("""
struct Player {
  x Number
  y Number
}
variable player Player
3 player set-Player-x
player get-Player-x
""")
    check_tos(3)

  test "struct after var":
    compile_and_run("""
variable test_var
struct TestPlayer {
  x Number
  y Number
}
variable player TestPlayer
10 player set-TestPlayer-x
player get-TestPlayer-x""")
    check_tos(10)

  test "struct settting, getting multiple times":
    compile_and_run("""
struct Input {
  ByteValue Number
}
variable input1 Input
128 input1 set-Input-ByteValue
10 input1 set-Input-ByteValue
135 input1 set-Input-ByteValue
input1 get-Input-ByteValue""")
    check_tos(135)

  test "several structs":
    compile_and_run("""
struct Coords {
  x Number
  y Number
}
struct Input {
  ByteValue Number
}
variable coords1 Coords
variable input_t Input
variable coords2 Coords
variable input_t2 Input
128 input_t set-Input-ByteValue
5 coords1 set-Coords-x
10 coords1 set-Coords-y
125 input_t2 set-Input-ByteValue
input_t get-Input-ByteValue """)
    check_tos(128)

  test "struct accessing with overwritten memory":
    compiler.compile_test_str("""struct Input {
  ByteValue Number
} variable input Input 3 input set-Input-ByteValue input get-Input-ByteValue """)
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
    compile_and_run("10 1 2 3 4 pull_fourth_up")
    check_tos(1)
    check_sos(4)

  test "pull_fifth_up":
    compile_and_run("10 1 2 3 4 5 copy_fifth_up")
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
    check_tos(4)

  test "16 / 4":
    compile_and_run("16 4 /")
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

  test "-1":
    compile_and_run("-1")
    check_tos(0xFF)

  test "-5":
    compile_and_run("-5")
    check_tos(0xFB)

  test "1 + -1":
    compile_and_run("1 -1 +")
    check_tos(0)

  test "-5 + 5":
    compile_and_run("-5 5 +")
    check_tos(0)

  test "1 - (-1)":
    compile_and_run("1 -1 -")
    check_tos(2)

  test "0 1 -":
    compile_and_run("0 1 -")
    check_tos(0xFF)

  test "0 -10 + ":
    compile_and_run("0 -10 +")
    check_tos(0xF6)

  test "default struct values of numbers":
    compile_and_run("""struct TestStruct {
  a Number = 10
  b Number = 0xB
}
variable tmp TestStruct
tmp get-TestStruct-a
tmp get-TestStruct-b""")
    check_tos(11)
    check_sos(10)

# ptr to numbers is going to be added later
#[
  test "default struct values of addresses":
    compile_and_run("""
variable tmp_var
3 tmp_var !
struct TestStruct {
  tmp = tmp_var
  tmp_other = 2
}
variable test_struct TestStruct
test_struct get-TestStruct-tmp @ @
""")
    check_tos(3)
]#

  test "struct init list":
    compile_and_run("""
struct TestStruct {
  a Number
  b Number
  c Number
}
variable tmp TestStruct {
  a = 10
  b = 11
}
tmp get-TestStruct-a
tmp get-TestStruct-b
""")
    check_tos(11)
    check_sos(10)


  test "struct_ptr getter":
    compile_and_run("""
      variable t
      struct AStruct {
        a Number = 10
      }
      struct BStruct {
        b AStruct
      }
      variable a_struct AStruct
      variable b_struct BStruct
      a_struct b_struct set-BStruct-b
      b_struct get-BStruct-b get-AStruct-a
    """)

    echo compiler.parser.root.str
    print_tos()
    nes.print_sos()
    print_memory(0x00, 0x10)

  test "struct_ptr setter":
    compile_and_run("""
      struct OneStruct {
        a Number = 10 
      }
      variable one_struct OneStruct
      11 one_struct set-OneStruct-a
      variable other_struct OneStruct
      struct TestStruct {
        a_struct OneStruct
      }
      variable test_struct TestStruct
      one_struct test_struct set-TestStruct-a_struct
      other_struct test_struct set-TestStruct-a_struct
      test_struct get-TestStruct-a_struct get-OneStruct-a
      """)
    check_tos(10)
    echo compiler.parser.root.str
        
    
    












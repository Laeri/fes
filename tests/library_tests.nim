import
  types, msgs, compiler, utils, ast, unittest, strutils, nimes_integration, ../lib/nimes/src/nes/types as nimes_types, ../lib/nimes/src/nes, ../lib/nimes/src/nes/mem, utils

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



suite "Engine Library Suite":

  setup:
    var compiler: FESCompiler = newFESCompiler()
    compiler.load_core_words = true
    compiler.load_library = true
    # compile to temporary directory /tests/tmp
    # the output will be used as input into the nes emulator
    var tmp_src_path = "tests/tmp/lib.asm"
    var tmp_nes_path = "tests/tmp/lib.nes"
    compiler.out_asm_folder = tmp_src_path
    compiler.name = "FES: Library Test"
    compiler.version = "Library Test Version" 
    
    var nes: NES
    var src: string
  teardown:
    nes = nil
  
  test "check intensify_blues set: false":
    compile_and_run("false set_intensify_blues intensify_blues?")
    check_tos(uint8_false())

  test "check intensify_blues set: true":
    compile_and_run("true set_intensify_blues intensify_blues?")
    check_tos(uint8_true())

  test "bit set: true":
    compile_and_run("0b1000 0b1000 bit_set?")
    check_tos(uint8_true())

  test "bit set false":
    compile_and_run("0b1000 0b0001 bit_set?")
    check_tos(uint8_false())

  test "read player1 input":
    compiler.compile_test_str("read_inputs input1 get-Input-ByteValue")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([true, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(0x80)

  test "read player2 input":
    compiler.compile_test_str("read_inputs input2 get-Input-ByteValue")
    nes = newNES(tmp_nes_path)
    nes.controllers[1].setButtons([true, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(0x80)

  test "input: A pressed? true":
    compiler.compile_test_str("read_inputs input1 a_pressed?")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([true, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(uint8_true())

  test "input: B pressed? true":
    compiler.compile_test_str("read_inputs input1 b_pressed?")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([false, true, false, false, false, false, false, false])
    nes.run(1)
    check_tos(uint8_true())

  test "input: A pressed? false":
    compiler.compile_test_str("read_inputs input1 a_pressed?")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([false, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(uint8_false())

  test "input: B pressed? false":
    compiler.compile_test_str("read_inputs input1 b_pressed?")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([false, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(uint8_false())

  test "sprite: set_colour_palette":
  # sprites are indexed from 0-3 (four sprites)
    compile_and_run("""
variable player Sprite
3 player set_colour_palette
player get_colour_palette
""")
    check_tos(3)

  test "sprite: set_priority":
  # priority can either be 0 or 1
    compile_and_run("""
variable player Sprite
1 player set_priority
player get_priority
""")
    print_memory(0x00, 0x10)
    check_tos(1)

  test "sprite: attributes of two sprites":
    compile_and_run("""
variable player1 Sprite
variable player2 Sprite
1 player1 set_priority
2 player1 set-Sprite-x
3 player1 set-Sprite-y
1 player2 set_priority
10 player2 set-Sprite-x
11 player2 set-Sprite-y
player1 get_priority""")
    print_memory(0x00, 0x10)
    check_tos(1)

  test "sprite: set_flip_horizontally":
    compile_and_run("""
variable player Sprite
true player set_flip_horizontally
player flip_horizontally?
""")
    check_tos(uint8_true())

  test "sprite: set_flip_vertically":
    compile_and_run("""
variable player Sprite
true player set_flip_vertically
player flip_vertically?""")
    print_memory(0x00, 0x10)
    check_tos(uint8_true())

  test "sprite: move x-Direction":
    compile_and_run("""
variable player Sprite
0 player set-Sprite-x
0 player set-Sprite-y
10 player move_sprite_by_x
player get-Sprite-x
""")
    check_tos(10)

  test "sprite: move x-Direction":
    compile_and_run("""
variable player Sprite
0 player set-Sprite-x
0 player set-Sprite-y
11 player move_sprite_by_x
player get-Sprite-x
""")
    check_tos(11)

  test "sprite: move x-Direction":
    compile_and_run("""
variable player Sprite
0 player set-Sprite-x
0 player set-Sprite-y
10 11 player move_sprite_by_xy
player get-Sprite-x
player get-Sprite-y
""")
    check_tos(11)
    check_sos(10)

  test "load sprite":
    compile_and_run("""
load_sprite mario "mario.chr"
""")

  test "load and use sprite":
    compile_and_run("""
load_sprite mario "mario.chr"
load_sprite luigi "mario.chr"
1 mario set_priority
10 mario set-Sprite-x
5 luigi set-Sprite-y
mario get-Sprite-x
luigi get-Sprite-y""")
    print_memory(0x00, 0x10)
    check_tos(5)
    check_sos(10)











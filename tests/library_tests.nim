import
  types, msgs, compiler, utils, ast, unittest, strutils, nimes_integration, ../lib/nimes/src/nes/types as nimes_types, ../lib/nimes/src/nes, ../lib/nimes/src/nes/mem, utils


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
    compile_and_run("1 false set_intensify_blues intensify_blues?")
    check_tos(uint8_false())
    check_sos(1)

  test "check intensify_blues set: true":
    compile_and_run("1 true set_intensify_blues intensify_blues?")
    check_tos(uint8_true())
    check_sos(1)

  test "bit set: true":
    compile_and_run("1 0b1000 0b1000 bit_set?")
    check_tos(uint8_true())
    check_sos(1)

  test "bit set false":
    compile_and_run("1 0b1000 0b0001 bit_set?")
    check_tos(uint8_false())
    check_sos(1)


  test "read player1 input":
    compiler.compile_test_str("1 read_inputs input1 get-Input-ByteValue")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([true, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(0x80)
    check_sos(1)

  test "read player2 input":
    compiler.compile_test_str("1 read_inputs input2 get-Input-ByteValue")
    nes = newNES(tmp_nes_path)
    nes.controllers[1].setButtons([true, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(0x80)
    check_sos(1)

  test "input: A pressed? true":
    compiler.compile_test_str("1 read_inputs input1 a_pressed?")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([true, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(uint8_true())
    check_sos(1)

  test "input: B pressed? true":
    compiler.compile_test_str("1 read_inputs input1 b_pressed?")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([false, true, false, false, false, false, false, false])
    nes.run(1)
    check_tos(uint8_true())
    check_sos(1)

  test "input: A pressed? false":
    compiler.compile_test_str("1 read_inputs input1 a_pressed?")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([false, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(uint8_false())
    check_sos(1)

  test "input: B pressed? false":
    compiler.compile_test_str("1 read_inputs input1 b_pressed?")
    nes = newNES(tmp_nes_path)
    nes.controllers[0].setButtons([false, false, false, false, false, false, false, false])
    nes.run(1)
    check_tos(uint8_false())
    check_sos(1)

  test "sprite: set_colour_palette":
  # sprites are indexed from 0-3 (four sprites)
    compile_and_run("""
variable player Sprite
3 player set_colour_palette
1 player get_colour_palette
""")
    check_tos(3)
    check_sos(1)

  test "sprite: set_priority":
  # priority can either be 0 or 1
    compile_and_run("""
variable player Sprite
1 player set_priority
2 player get_priority
""")
    check_tos(1)
    check_sos(2)

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
2 player1 get_priority""")
    print_memory(0x00, 0x10)
    check_tos(1)
    check_sos(2)

  test "sprite: set_flip_horizontally":
    compile_and_run("""
variable player Sprite
true player set_flip_horizontally
1 player flip_horizontally?
""")
    check_tos(uint8_true())
    check_sos(1)

  test "sprite: set_flip_vertically":
    compile_and_run("""
variable player Sprite
true player set_flip_vertically
1 player flip_vertically?""")
    print_memory(0x00, 0x10)
    check_tos(uint8_true())
    check_sos(1)

  test "sprite: move negative x-Direction":
    compile_and_run("""
variable player Sprite
8 player set-Sprite-x
0 player set-Sprite-y
-3 player move_sprite_by_x
1 player get-Sprite-x
""")
    check_tos(5)
    check_sos(1)

  test "sprite: move x-Direction":
    compile_and_run("""
variable player Sprite
0 player set-Sprite-x
0 player set-Sprite-y
15
11 player move_sprite_by_x
1 player get-Sprite-x
""")
    check_tos(11)
    check_sos(1)
    check_stack(-2, 15)

  test "sprite: move xy-Direction":
    compile_and_run("""
variable player Sprite
0 player set-Sprite-x
0 player set-Sprite-y
10 11 player move_sprite_by_xy
1
player get-Sprite-x
player get-Sprite-y
""")
    check_tos(11)
    check_sos(10)
    print_stack(20)

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

  test "tmp":
    compile_and_run("""
load_sprite mario "mario.chr"
1 mario set_priority
10 mario set-Sprite-x
11 mario set-Sprite-y
2 mario set-Sprite-tile_number
1 mario get-Sprite-tile_number""")
    check_tos(2)
    check_sos(1)

  test "store and load ppucntrl buffers":
    compile_and_run("""
0xFE ppu_control_reg_2_buffer !
1 2 3
ppu_control_reg_2_buffer @""")
    check_tos(0xFE)
    check_sos(3)

  test "store and load ppumask buffers":
    compile_and_run("""
0xFE ppu_control_reg_1_buffer !
1 2 3
ppu_control_reg_1_buffer @""")
    check_tos(0xFE)
    check_sos(3)

  test "palette colour access 0":
    compile_and_run("""
variable sp_palette0 Palette { col0 = 0x0F col1 = 0x31 col2 = 0x32 col3 = 0x33 }
1
sp_palette0 get-Palette-col0
""")
    check_tos(0x0F)
    check_sos(1)


  test "palette colour access 1":
    compile_and_run("""
variable sp_palette0 Palette { col0 = 0x0F col1 = 0x31 col2 = 0x32 col3 = 0x33 }
1
sp_palette0 get-Palette-col1
""")
    check_tos(0x31)
    check_sos(1)

  test "palette loading":
    compile_and_run("""
variable sp_palette0 Palette { col0 = 0x0F col1 = 0x31 col2 = 0x32 col3 = 0x33 }
variable sp_palette1 Palette { col0 = 0x0F col1 = 0x35 col2 = 0x36 col3 = 0x37 } 
variable sp_palette2 Palette { col0 = 0x0F col1 = 0x39 col2 = 0x3A col3 = 0x3B }
variable sp_palette3 Palette { col0 = 0x0F col1 = 0x3D col2 = 0x3E col3 = 0x0F }

variable bg_palette0 Palette { col0 = 0x0F col1 = 0x1C col2 = 0x15 col3 = 0x14 }
variable bg_palette1 Palette { col0 = 0x0F col1 = 0x02 col2 = 0x38 col3 = 0x3C } 
variable bg_palette2 Palette { col0 = 0x0F col1 = 0x1C col2 = 0x15 col3 = 0x14 }
variable bg_palette3 Palette { col0 = 0x0F col1 = 0x02 col2 = 0x38 col3 = 0x3C }

variable palette_data PaletteData {
  bg0 = bg_palette0
  bg1 = bg_palette1
  bg2 = bg_palette2
  bg3 = bg_palette3
  sp0 = sp_palette0
  sp1 = sp_palette1
  sp2 = sp_palette2
  sp3 = sp_palette3
}
10
palette_data get-PaletteData-sp0 get-Palette-col2
palette_data get-PaletteData-bg3 get-Palette-col3
""")
    check_tos(0x3C)
    check_sos(0x32)
    check_stack(-2, 10)





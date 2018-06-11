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

  test "check intensify_blues buffer":
    compile_and_run("true set_intensify_blues ppu_control_reg_2_buffer @")
    print_tos()
    print_memory(0x2001, 0x2001)
    print_memory(0x00, 0x08)

  test "test intensify_blues from asm code":
    compile_and_run("""
[
JSR true_
JSR set_intensify_blues_
JMP End
true_:
  DEX
  STA $0200,X
  LDA #$FF
  RTS
set_intensify_blues_:
begin_if1_:
  CLC
  ASL A
  BCC begin_else1_
begin_then1_:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$01
  JSR load_var
  DEX
  STA $0200,X
  LDA #$80
  JSR or
  JMP end_if1_
begin_else1_:
  LDA $0200,X
  INX
  DEX
  STA $0200,X
  LDA #$01
  JSR load_var
  DEX
  STA $0200,X
  LDA #$7F
  JSR and
end_if1_:
  STA $2001
  DEX
  STA $0200,X
  LDA #$01
  JSR store_var
  LDA #$10
  LDA $01
  STA $2001
  RTS
]""")
    print_memory(0x2001, 0x2001)
    print_memory(0x00, 0x10)
    print_tos()
    nes.print_sos()


  test "bit set: true":
    compile_and_run("0b1000 0b1000 bit_set?")
    check_tos(uint8_true())

  test "bit set_ false":
    compile_and_run("0b1000 0b0001 bit_set?")
    print_tos()
    check_tos(uint8_false())







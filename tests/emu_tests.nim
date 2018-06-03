import
  types, msgs, compiler, ast, unittest, strutils, ../lib/nimes/src/nes, ../lib/nimes/src/nes/mem, utils

template check_memory(mem_addr: int, check_val: int): untyped =
  var addr_uint16 = cast[uint16](mem_addr)
  var val_uint8 = cast[uint8](check_val)
  check(nes.cpu.mem[addr_uint16] == val_uint8)

template print_memory(from_addr: int, to_addr: int): untyped =
  for i in from_addr .. to_addr:
    var addr_uint16 = cast[uint16](i)
    echo "addr: " & $addr_uint16 & " val: " & $nes.cpu.mem[addr_uint16]

proc create_nes_file(fes_src: string) =
  discard

suite "Emulation Suite":

  setup:
    var compiler = newFESCompiler()
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
    compiler.load_core_words = true
    compiler.compile_test_str("variable name 1 name !")
    echo compiler.parser.root.str
    nes = newNES(tmp_nes_path)
    nes.run(1)
    print_memory(0, 15)
    check_memory(0, 1)

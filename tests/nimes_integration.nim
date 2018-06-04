import ../lib/nimes/src/nes, ../lib/nimes/src/nes/mem


proc tos*(nes: NES): uint8 = 
  result = nes.cpu.a

proc sos*(nes: NES): uint8 =
  var addr_uint16 = cast[uint16](0x0200) + cast[uint16](nes.cpu.x)
  result = nes.cpu.mem[addr_uint16]

proc print_sos_addr*(nes: NES) =
  echo $(0x0200 + cast[int](nes.cpu.x))

proc print_tos*(nes: NES) =
  echo "tos: " & $(nes.tos)

proc print_sos*(nes: NES) =
  echo "sos: " & $(nes.sos)
  
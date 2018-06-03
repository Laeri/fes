import ../lib/nimes/src/nes


proc tos*(nes: NES): uint8 = 
  result = nes.cpu.a

  
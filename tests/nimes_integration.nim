import ../lib/nimes/src/nes, ../lib/nimes/src/nes/mem, sequtils


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


template check_memory*(mem_addr: int, check_val: int): untyped =
  var addr_uint16 = cast[uint16](mem_addr)
  var val_uint8 = cast[uint8](check_val)
  check(nes.cpu.mem[addr_uint16] == val_uint8)

template print_memory*(from_addr: int, to_addr: int = from_addr): untyped =
  for i in from_addr .. to_addr:
    var addr_uint16 = cast[uint16](i)
    echo "addr: " & $addr_uint16 & " val: " & $nes.cpu.mem[addr_uint16]

template print_memory_hex*(from_addr: int, to_addr: int = from_addr): untyped =
  for i in from_addr .. to_addr:
    var addr_uint16 = cast[uint16](i)
    var num = cast[int](nes.cpu.mem[addr_uint16])
    echo "addr: " & num_to_hex(cast[int](addr_uint16)) & " val: " & num_to_hex(num)

template check_tos*(check_val: uint8): untyped =
  check(tos(nes) == check_val)

template compile_and_run*(src: string, seconds: float = 0.2): untyped {.dirty.} =
  compiler.compile_test_str(src)
  nes = newNES(tmp_nes_path)
  nes.run(seconds)

var STACK_BASE = 0x0200

template check_sos*(check_val: uint8): untyped {.dirty.} =
  var sos: uint8 = nes.cpu.mem[second_of_stack_base_addr() + nes.cpu.x]
  check(sos == check_val)

template print_tos*(): untyped {.dirty.} =
  nes.print_tos()

template print_sos*(): untyped {.dirty.} =
  nes.print_sos()

template print_sos_addr*(): untyped {.dirty.} =
  nes.print_sos_addr()

template print_x*(): untyped {.dirty.} =
  echo "reg x: " & $nes.cpu.x

template print_y*(): untyped {.dirty.} =
  echo "reg y: " & $nes.cpu.y

template print_a*(): untyped {.dirty.} =
  echo "reg a: " & $nes.cpu.a

template print_sp*(): untyped {.dirty.} =
  echo "reg sp: " & $nes.cpu.sp



template check_stack*(stack_index: int, check_val: uint8): untyped =
  # stack index for tos = 0, for sos = -1, -2,-3....
  if stack_index == 0:
    check_tos(check_val)
  var mem_index: uint16 = cast[uint16](STACK_BASE + cast[int](nes.cpu.x) - stack_index - 1) # tos is in A
  check(nes.cpu.mem[mem_index] == check_val)


template stack_has_form*(stack_elements: varargs[int]): untyped =
  var index = 0
  for el in stack_elements:
    check_stack(index, cast[uint8](el))
    index -= 1

template print_stack*(num_elements: int) : untyped =
  var stack_str = "stack: ["
  for i in 0..(num_elements - 2):
    var mem_index: uint16 = cast[uint16](STACK_BASE + cast[int](nes.cpu.x) + (num_elements-2 - i))
    stack_str &= num_to_hex(cast[int](nes.cpu.mem[mem_index])) & " ,"
  stack_str &= num_to_hex(cast[int](nes.cpu.a))
  stack_str &= "]"
  echo stack_str




import
  strutils, sequtils, math



proc digit_to_hex*(number: int): string =
  var hex = @["A", "B", "C", "D", "E", "F"]
  if number < 10:
    result = number.intToStr
  else:
    result = hex[number - 10]
  return result

proc padded_addr_str*(str: string): string = 
  if str.len < 6:
    result = "$"
    for i in 1..(5 - str.len):
      result &= "0"
    result &= str[1 .. str.len - 1]

proc num_to_hex*(number: int): string =
  var hex: string = ""
  var n = number
  if n == 0:
    hex = "0"
  while (n / 16 > 0):
    var val = n / 16
    var rem = n mod 16
    hex = rem.digit_to_hex & hex
    n = int(val)
  if (hex.len mod 2) == 1:
    hex = "0" & hex
  return "$" & hex

proc twos_complement_num*(num: int): int =
  result = 2^8 - abs(num)

proc num_to_im_hex*(number: int): string =
  var num = number
  if number < 0:
    num = twos_complement_num(number)
  return "#" & num_to_hex(num)


proc num_to_im_hex_lower_byte*(number: int): string =
  # $ABCD
  result = "#$" & padded_addr_str(num_to_hex(number))[3..4]

proc num_to_im_hex_higher_byte*(number: int): string =
  result = "#$" & padded_addr_str(num_to_hex(number))[1..2]

proc index_to_addr_str*(index: int): string =
  return num_to_hex(index).padded_addr_str

proc second_of_stack_base_addr*(): uint16 =
  result = 0x0200

proc uint8_true*(): uint8 =
  return 255

proc uint8_false*(): uint8 =
  return 0

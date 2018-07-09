import
  math, sequtils, strutils, tables


var nes_transl_table*: Table[string, string] =
  {
    "+": "add",
    "-": "sub",
    "*": "mul",
    "/": "div",
    "!": "store",
    "<": "smaller",
    ">": "greater",
    "<=": "smaller_or_equal",
    ">=": "greater_or_equal",
    "=": "equal",
    "!=": "not_equal",
    "!": "store_var",
    "@": "load_var"
  }.toTable

proc translate_name*(name: string): string =
  result = name
  if nes_transl_table.contains(name):
    result = nes_transl_table[name]
  result = result.replace("?", "is")
  var digits_to_str = @["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
  if result[0] in Digits:
    result = digits_to_str[($result[0]).parseInt] & "_" & result[1..(result.len - 1)]


proc isInteger*(str: string): bool =
  try:
    let f = parseInt str
  except ValueError:
     return false
  return true

proc twos_complement_8bit*(num: int): int =
  if num >= 0:
    result = num
  else:
    result = (2^8) - abs(num)

proc is_binary_str*(str: string): bool =
  if str.len <= 2: 
    return false
  if (str[0..1] == "#%") or (str[0..1] == "0b"):
    for ch in str[2..(str.len - 1)]:
      if not(ch in Digits):
        return false
    return true
  else:
    return false

proc is_hex_str*(str: string): bool =
  if str.len <= 2:
    return false
  if (str[0..1] == "#$") or (str[0..1] == "0x"):
    for ch in str[2..(str.len - 1)]:
      if not(ch in HexDigits):
        return false
    return true
  else:
    return false

proc is_valid_number_str*(str: string): bool =
  if str.isInteger:
    return true
  return is_binary_str(str) or is_hex_str(str)

proc parse_binary_str_to_int*(str: string): int =
  var bin_str = str[2..(str.len - 1)]
  result = 0
  var pow = 0
  for i in 0..(bin_str.len - 1):
    var digit = ($bin_str[(bin_str.len - 1) - i]).parseInt
    result += digit shl pow
    pow += 1

proc parse_hex_str_to_int*(str: string): int =
  return str[2..(str.len - 1)].parseHexInt
  
proc parse_to_integer*(str: string): int =
   if str.isInteger:
     return str.parseInt
   elif is_binary_str(str):
     return parse_binary_str_to_int(str)
   elif is_hex_str(str):
     return parse_hex_str_to_int(str)

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

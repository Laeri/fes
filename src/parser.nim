import
  types, scanner, strutils, ast, tables, msgs

var nes_transl_table: Table[string, string] =
  {
    "+": "add",
    "-": "sub",
    "*": "mul",
    "/": "div",
    "!": "store"
  }.toTable

proc isInteger(str: string): bool =
  try:
    let f = parseInt str
  except ValueError:
     return false
  return true

proc parse_asm_line*(tokens: seq[string]): ASMAction =
  if tokens.len == 1:
      if tokens[0].contains(":"):
        return ASMLabel(label_name: tokens[0])
      else:
        return ASMCall(op: parseEnum[OPCODE] tokens[0], with_arg: false)
  elif tokens.len == 2:
    var arg_string = tokens[1]
    return ASMCall(op: parseEnum[OPCODE] tokens[0], param: arg_string, with_arg: true)

proc parse_asm_block(parser: Parser, asm_node: ASMNode) = 
  var tokens: seq[string] = parser.scanner.upto_next_line()
  var end_block = false
  while not(end_block):
    if tokens[0] == "]":
      end_block = true
    elif tokens.len == 1:
      if tokens[0].contains(":"):
        asm_node.add(ASMLabel(label_name: tokens[0]))
      else:
        asm_node.add(ASMCall(op: parseEnum[OPCODE] tokens[0], with_arg: false))
    elif tokens.len == 2:
      var arg_string = tokens[1]
      asm_node.add(ASMCall(op: parseEnum[OPCODE] tokens[0], param: arg_string, with_arg: true))
    if not(end_block):
      tokens = parser.scanner.upto_next_line()

proc translate_name(name: string): string =
  if nes_transl_table.contains(name):
    return nes_transl_table[name]
  else:
    return name

proc parse_word_definition(parser: Parser, def_node: DefineWordNode) =
  while parser.scanner.has_next:
    var token = parser.scanner.next
    echo "parse_word " & token
    if token == ";":
      return
    elif token == "[":
      var node = newASMNode()
      def_node.add(node)
      parser.parse_asm_block(node)
    elif token.isInteger:
      var node = PushNumberNode()
      node.number = token.parseInt
      def_node.add(node)
    elif token == ":":
      echo "DEF"
      report(errWordDefInsideOtherWord, def_node.word_name)
    else:
      var node = CallWordNode()
      node.word_name = token
      def_node.add(node)
  echo "No more tokens"
  report(errMissingWordEnding, def_node.word_name)

proc parse_comment(parser: Parser) =
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.contains(")"):
      return
    elif token.contains("("):
      parser.parse_comment

proc is_valid_name*(name: string): bool = 
  if name.isInteger:
    return false
  else:
    return true

proc parse_string*(parser: Parser, src: string) = 
  parser.scanner.read_string(src)
  var root = newSequenceNode()
 
  while parser.scanner.has_next:
    var token = parser.scanner.next
    echo "parse_string: " & token
    if token == ":":
      var def_node = newDefineWordNode()
      token = parser.scanner.next
      if not(is_valid_name(token)):
        report(errInvalidDefinitionWordName, token)
      def_node.word_name = token.translate_name
      parser.parse_word_definition(def_node)
      root.add(def_node)
    elif token == "[":
      var asm_node = newASMNode()
      parser.parse_asm_block(asm_node)
      root.add(asm_node)
    elif token.contains("("):
      parser.parse_comment()
    elif token.isInteger:
      var node = PushNumberNode()
      node.number = token.parseInt
      root.add(node)
    else:
      if not(is_valid_name(token)):
        report(errInvalidCallWordName, token)
      var node = CallWordNode(word_name: token)
      root.add(node)
  parser.root = root

proc parse_files*(parser: Parser, files: varargs[string]) =
  var src: string = ""
  for file in files:
    src &= readFile(file)
  parser.parse_string(src)


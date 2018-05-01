import
  types, scanner, strutils, ast, tables, msgs, sequtils

proc newParser*(): Parser = 
  result = Parser()
  result.scanner = Scanner()

proc newParser*(handler: ErrorHandler): Parser = 
  result = newParser()
  result.error_handler = handler

var nes_transl_table: Table[string, string] =
  {
    "+": "add",
    "-": "sub",
    "*": "mul",
    "/": "div",
    "!": "store"
  }.toTable


proc report(parser: Parser, msg: MsgKind, msg_args: varargs[string]) =
  var args: seq[string] = @[]
  for ar in msg_args:
    args.add(ar)
  parser.error_handler.handle(msg, args)


proc parse_asm_line*(tokens: seq[Token]): ASMAction =
  if tokens.len == 1:
      if tokens[0].str_val.contains(":"):
        return ASMLabel(label_name: tokens[0].str_val)
      else:
        return ASMCall(op: parseEnum[OPCODE] tokens[0].str_val, with_arg: false)
  elif tokens.len == 2:
    var arg_string = tokens[1].str_val
    return ASMCall(op: parseEnum[OPCODE] tokens[0].str_val, param: arg_string, with_arg: true)

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
    if token.str_val == ";":
      return
    elif token.str_val == "[":
      var node = newASMNode()
      def_node.add(node)
      parser.parse_asm_block(node)
    elif token.str_val.isInteger:
      var node = PushNumberNode()
      node.number = token.str_val.parseInt
      def_node.add(node)
    elif token.str_val == ":":
      parser.report(errWordDefInsideOtherWord, def_node.word_name)
    else:
      var node = CallWordNode()
      node.word_name = token.str_val
      def_node.add(node)
  parser.report(errMissingWordEnding, def_node.word_name)

proc parse_comment(parser: Parser) =
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.str_val.contains(")"):
      return
    elif token.str_val.contains("("):
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
    if token.str_val == ":":
      var def_node = newDefineWordNode()
      token = parser.scanner.next
      echo token.str_val
      if not(is_valid_name(token.str_val)):
        parser.report(errInvalidDefinitionWordName, token.str_val)
      def_node.word_name = token.str_val.translate_name
      parser.parse_word_definition(def_node)
      root.add(def_node)
    elif token.str_val == "[":
      var asm_node = newASMNode()
      parser.parse_asm_block(asm_node)
      root.add(asm_node)
    elif token.str_val.contains("("):
      parser.parse_comment()
    elif token.str_val.isInteger:
      var node = PushNumberNode()
      node.number = token.str_val.parseInt
      root.add(node)
    else:
      if not(is_valid_name(token.str_val)):
        parser.report(errInvalidCallWordName, token.str_val)
      var node = CallWordNode(word_name: token.str_val)
      root.add(node)
  parser.root = root

proc parse_files*(parser: Parser, files: varargs[string]) =
  var src: string = ""
  for file in files:
    src &= readFile(file)
  parser.parse_string(src)


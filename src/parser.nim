import
  types, scanner, strutils, ast, tables, msgs, sequtils, typetraits

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

const
  invalid_names = @[":", ";", "[", "]"]

proc is_valid_name*(name: string): bool = 
  if name.isInteger or (name in invalid_names):
    return false
  else:
    return true

proc report(parser: Parser, msg: MsgKind, msg_args: varargs[string]) =
  var args: seq[string] = @[]
  for ar in msg_args:
    args.add(ar)
  parser.error_handler.handle(msg, args)

proc create_asm_call(parser: Parser, op: string, param: string = nil): ASMCall =
  if not(op.is_OPCODE):
    parser.report(errInvalidASMInstruction, op)
    return ASMCall(op: INVALID_OPCODE, param: param)
  else:
    return ASMCall(op: parseEnum[OPCODE](op), param: param)

proc parse_asm_line*(parser: Parser, tokens: seq[Token]): ASMAction =
  var str_val = tokens[0].str_val
  if tokens.len == 1:
      if str_val[str_val.len - 1] == ':':
        return ASMLabel(label_name: tokens[0].str_val)
      else:
        return parser.create_asm_call(str_val)
  elif tokens.len == 2:
    var arg_string = tokens[1].str_val
    return parser.create_asm_call(str_val, arg_string)


proc parse_asm_block(parser: Parser, asm_node: ASMNode) = 
  var tokens: seq[string] = parser.scanner.upto_next_line()
  var end_block = false
  while not(end_block):
    if tokens.len == 1:
      if tokens[0] == "]":
        return
      else:
        asm_node.add(parser.create_asm_call(tokens[0]))
    elif tokens.len == 2:
      if tokens[1] == "]":
        asm_node.add(parser.create_asm_call(tokens[0]))
        return
    elif tokens.len == 3:
      if tokens[2] == "]":
        asm_node.add(parser.create_asm_call(tokens[0], tokens[1]))
        return
      else:
        parser.report(errTooManyASMOperands, tokens[1..(tokens.len - 1)])
    elif tokens.len >= 4:
      parser.report(errTooManyASMOperands, tokens[1..(tokens.len - 1)])
      return
    if parser.scanner.has_next:
      tokens = parser.scanner.upto_next_line()
    else:
      parser.report(errMissingASMEnding)
      return


proc translate_name(name: string): string =
  if nes_transl_table.contains(name):
    return nes_transl_table[name]
  else:
    return name

proc is_empty(node: ASMNode): bool = 
  return node.asm_calls.len == 0

proc parse_word_definition(parser: Parser, def_node: DefineWordNode) =
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.str_val == ";":
      return
    elif token.str_val == "[":
      var node = newASMNode()
      def_node.add(node)
      parser.parse_asm_block(node)
      if node.is_empty:
        parser.report(warnMissingASMBody)
    elif token.str_val.isInteger:
      var node = PushNumberNode()
      node.number = token.str_val.parseInt
      def_node.add(node)
    elif token.str_val == ":":
      parser.report(errNestedWordDef, def_node.word_name)
    else:
      var node = CallWordNode()
      node.word_name = token.str_val
      if not(node.word_name.is_valid_name):
        parser.report(errInvalidCallWordName, token.str_val)
      else:
        def_node.add(node)
  parser.report(errMissingWordEnding, def_node.word_name)

proc parse_comment(parser: Parser) =
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.str_val.contains(")"):
      return
    elif token.str_val.contains("("):
      parser.parse_comment





proc parse_string*(parser: Parser, src: string) = 
  parser.scanner.read_string(src)
  var root = newSequenceNode()
 
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.str_val == ":":
      var def_node = newDefineWordNode()
      if not(parser.scanner.has_next()):
        parser.report(errMissingWordDefName)
      else:
        token = parser.scanner.next
        if not(is_valid_name(token.str_val)):
          parser.report(errInvalidDefinitionWordName, token.str_val)
        def_node.word_name = token.str_val.translate_name
      parser.parse_word_definition(def_node)
      root.add(def_node)
    elif token.str_val == "[":
      var asm_node = newASMNode()
      parser.parse_asm_block(asm_node)
      root.add(asm_node)
      if asm_node.is_empty:
        parser.report(warnMissingASMBody)
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


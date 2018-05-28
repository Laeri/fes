import
  types, scanner, strutils, ast, tables, msgs, sequtils, typetraits

proc newParser*(): Parser = 
  result = Parser()
  result.scanner = newScanner()
  result.error_handler = newErrorHandler()
  result.error_handler.scanner = result.scanner
  result.var_table = newTable[string, VariableNode]()
  result.var_index = 0
  result.definitions = newTable[string, DefineWordNode]()
  result.calls = newTable[string, CallWordNode]()
  result.structs = newTable[string, StructNode]()

proc newParser*(handler: ErrorHandler): Parser = 
  result = newParser()
  result.error_handler = handler
  handler.scanner = result.scanner
  result.var_table = newTable[string, VariableNode]() 

var nes_transl_table: Table[string, string] =
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
    "!=": "not_equal"
  }.toTable

const
  invalid_names = @[":", ";", "[", "]"]

proc is_valid_name*(name: string): bool = 
  if name.isInteger or (name in invalid_names):
    return false
  else:
    return true

proc set_begin_info(parser: Parser, node: ASTNode, backtrack: bool = true) =
  node.file_name = parser.scanner.src_name
  node.line_range = LineRange()
  var backtracked = backtrack and (parser.scanner.column != 0)
  if backtracked:
    parser.scanner.backtrack(1)
  node.line_range.low = parser.scanner.current_line_pos
  node.column_range = parser.scanner.current_word_range
  if backtracked:
    parser.scanner.advance()

proc set_end_info(parser: Parser, node: ASTNode, backtrack: bool = true) =
  var backtracked = backtrack and (parser.scanner.column != 0)
  if backtracked:
    parser.scanner.backtrack(1)
  node.line_range.high = parser.scanner.current_line_pos
  if backtracked:
    parser.scanner.advance

proc set_info(parser: Parser, node: ASTNode) =
  parser.set_begin_info(node)
  parser.set_end_info(node)


proc report(parser: Parser, error: FError) =
  parser.error_handler.handle(error)



proc report*(parser: Parser, node: ASTNode, msg: MsgKind, msg_args: varargs[string]) =
  parser.set_end_info(node)
  parser.report(gen_error(node, msg, msg_args))

proc create_asm_call(parser: Parser, op: string, param: string = nil): ASMCall =
  if not(op.is_OPCODE):
    var debug_node = ASTNode()
    parser.set_begin_info(debug_node)
    parser.report(debug_node, errInvalidASMInstruction, op)
    return ASMCall(op: INVALID_OPCODE, param: param)
  else:
    return ASMCall(op: parseEnum[OPCODE](op), param: param)

proc create_asm_label(parser: Parser, label_name: string): ASMLabel =
  return ASMLabel(label_name: label_name)

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


proc is_label(str: string): bool =
  return (str[str.len - 1] == ':')


proc parse_asm_block(parser: Parser, asm_node: ASMNode) = 
  var tokens: seq[Token] = parser.scanner.upto_next_line()
  var end_block = false
  while not(end_block):
    if tokens[tokens.len - 1].str_val == "]":
      end_block = true
      tokens.delete(tokens.len - 1)
      if tokens.len >= 3:
        parser.report(asm_node, errTooManyASMOperands)
      elif tokens.len > 0:
        asm_node.add(parser.parse_asm_line(tokens))
    else:
      if tokens.len >= 3:
        parser.report(asm_node, errTooManyASMOperands)
      asm_node.add(parser.parse_asm_line(tokens))
    if not(end_block):
      if parser.scanner.has_next:
        tokens = parser.scanner.upto_next_line()
      else:
        parser.report(asm_node, errMissingASMEnding)
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
      parser.set_begin_info(node)
      def_node.add(node)
      parser.parse_asm_block(node)
      if node.is_empty:
        parser.report(node, warnMissingASMBody)
    elif token.str_val.isInteger:
      var node = PushNumberNode()
      node.number = token.str_val.parseInt
      def_node.add(node)
    elif token.str_val == ":":
      parser.report(def_node, errNestedWordDef, def_node.word_name)
    else:
      var node = OtherNode()
      parser.set_begin_info(node)
      parser.set_end_info(node)
      node.name = token.str_val 
      def_node.add(node)
  parser.set_end_info(def_node)
  parser.report(def_node, errMissingWordEnding, def_node.word_name)

proc parse_comment(parser: Parser) =
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.str_val.contains(")"):
      return
    elif token.str_val.contains("("):
      parser.parse_comment    

var MAX_VAR_NUMBER = 512
proc parse_variable(parser: Parser): VariableNode =
  result = VariableNode()
  result.address = parser.var_index
  if parser.var_index >= MAX_VAR_NUMBER:
    parser.report(result, errTooManyVariablesDefined)
  parser.var_index += 1
  parser.set_begin_info(result)
  if parser.scanner.has_next:
    result.name = parser.scanner.next.str_val
    parser.set_begin_info(result)
    if not(result.name.is_valid_name):
      parser.report(result, errInvalidVariableName, result.name)
  else:
    parser.report(result, errMissingVariableName)
  parser.var_table[result.name] = result
  parser.set_end_info(result)

method is_empty(node: ASTNode): bool {.base.}=
  return true

method is_empty(node: DefineWordNode): bool = 
  return node.definition.len == 0

method is_empty(node: SequenceNode): bool =
  return node.sequence.len == 0

proc parse_ifelse*(parser: Parser): IfElseNode
proc parse_while*(parser: Parser): WhileNode

proc check_var_overflow(var_index: int) = 
  discard

proc finish_struct(parser: Parser, node: StructNode): StructNode =
  result = node
  if result.members.len == 0:
    parser.report(result, warnMissingStructBody, result.name)
  parser.set_end_info(result)
  parser.structs[result.name] = result


proc parse_struct(parser: Parser): StructNode =
  result = newStructNode()
  parser.set_begin_infO(result)
  var first = false

  if parser.scanner.has_next:
    result.name = parser.scanner.next.str_val
    parser.report(result, errMissingStructName)
  else:
    parser.report(result, errMalformedStruct)
  if parser.scanner.has_next: # skip opening {
    var token = parser.scanner.next.str_val
    if token[0] == '{' and token.len > 1:
      token = token[1 .. token.len - 1]
      result.members.add(token)
    elif token != "{":
      parser.report(result, errMalformedStruct)
  else:
    parser.report(result, errMalformedStruct)

  while parser.scanner.has_next:
    var token = parser.scanner.next.str_val
    if token == "}":
      return parser.finish_struct(result)
    elif token[token.len - 1] == '}':
      token = token[0 .. token.len - 2]
      echo token
      result.members.add(token)
      return parser.finish_struct(result)
    else:
      result.members.add(token)
  parser.report(result, errMissingStructEnding, result.name)
  

proc parse_sequence(parser: Parser): SequenceNode = 
  var root = newSequenceNode()
  parser.set_begin_info(root, false)
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.str_val == ":":
      var def_node = newDefineWordNode()
      if not(parser.scanner.has_next()):
        parser.set_begin_info(def_node)
        parser.report(def_node, errMissingWordDefName)
        return
      else:
        token = parser.scanner.next
        parser.set_begin_info(def_node)
        def_node.word_name = token.str_val
        if not(is_valid_name(token.str_val)):
          parser.report(def_node, errInvalidDefinitionWordName, token.str_val)
        def_node.word_name = token.str_val.translate_name
      parser.definitions[def_node.word_name] = def_node
      parser.parse_word_definition(def_node)
      root.add(def_node)
      if def_node.is_empty:
        parser.report(def_node, warnMissingWordDefBody, def_node.word_name)
    elif token.str_val == "[":
      var asm_node = newASMNode()
      parser.set_begin_info(asm_node)
      parser.parse_asm_block(asm_node)
      root.add(asm_node)
      if asm_node.is_empty:
        parser.report(asm_node, warnMissingASMBody)
    elif token.str_val == "if":
      var ifelse_node = parser.parse_ifelse()
      root.add(ifelse_node)
    elif token.str_val == "struct":
      var struct_node = parser.parse_struct()
      root.add(struct_node)
    elif token.str_val == "begin":
      var while_node = parser.parse_while()
      parser.set_begin_info(while_node)
      root.add(while_node)
    elif token.str_val == "variable":
      var var_node = parser.parse_variable()
      root.add(var_node)
    elif token.str_val == "then":
      break;
    elif token.str_val == "end":
      break;
    elif token.str_val == "else":
      break;
    elif token.str_val == "while":
      break;
    elif token.str_val == "repeat":
      break;
    elif token.str_val.contains("("):
      parser.parse_comment()
    elif token.str_val.isInteger:
      var node = PushNumberNode()
      parser.set_begin_info(node)
      node.number = token.str_val.parseInt
      root.add(node)
    else:
      var node = OtherNode(name: token.str_val)
      parser.set_begin_info(node)
      parser.set_end_info(node)
      root.add(node)
  parser.set_end_info(root)
  return root

proc parse_while*(parser: Parser): WhileNode =
  result = WhileNode()
  parser.set_begin_info(result)
  result.condition_block = parser.parse_sequence()
  if result.condition_block.is_empty:
    parser.report(result.condition_block, warnMissingWhileConditionBody)
  result.then_block = parser.parse_sequence()
  if result.then_block.is_empty:
    parser.report(result.then_block, warnMissingWhileThenBody)
  parser.set_end_info(result) 


proc parse_ifelse*(parser: Parser): IfElseNode =
  var ifelse_node = newIfElseNode()
  parser.set_begin_info(ifelse_node)
  var then_block = parser.parse_sequence()
  ifelse_node.then_block = then_block
  parser.set_begin_info(then_block)
  if then_block.is_empty:
    parser.report(then_block, warnMissingThenBody)
  parser.scanner.backtrack(1)
  var last_token = parser.scanner.next
  if last_token.str_val == "then":
    ifelse_node.else_block = newSequenceNode()
    parser.set_begin_info(ifelse_node)
    return ifelse_node
  elif last_token.str_val == "else":
    var else_block = parser.parse_sequence()
    ifelse_node.else_block = else_block
    if else_block.is_empty:
      parser.report(else_block, warnMissingElseBody)
    parser.scanner.backtrack(1)
    last_token = parser.scanner.next
    if last_token.str_val == "then":
      return ifelse_node
    else:
      parser.report(ifelse_node, errMissingIfElseEnding)
  else:
    parser.report(ifelse_node, errMissingIfElseEnding)
  parser.set_end_info(ifelse_node)
  return ifelse_node

proc parse_string*(parser: Parser, src: string, name: string) = 
  parser.scanner.read_string(src, name)
  var root = parser.parse_sequence
  parser.root = root

proc parse_string*(parser: Parser, src: string) =
  var t = "TEST_NAME"
  (parser.scanner).read_string(src, t)
  var root = parser.parse_sequence
  parser.root = root

proc parse_additional_src*(parser: Parser, src: string, name: string) =
  parser.scanner.read_string(src, name)
  var node = parser.parse_sequence
  parser.root.sequence.add(node.sequence)

proc parse_sources*(parser: Parser, sources: varargs[tuple[name: string, src: string]]) =
  var src = ""
  parser.parse_string(sources[0].src, sources[0].name)
  for i in 1..(sources.len - 1):
    parser.parse_additional_src(sources[i].src, sources[i].name)

proc parse_files*(parser: Parser, files: varargs[string]) =
  var sources: seq[tuple[name: string, src: string]] = @[]
  for file in files:
    sources.add((name: file.string, src: readFile(file)))
  parser.parse_sources(sources)


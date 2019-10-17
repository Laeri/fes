import
  types, scanner, strutils, ast, tables, msgs, sequtils, typetraits, utils

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
  result.const_table = newTable[string, ConstNode]()

proc newParser*(handler: ErrorHandler): Parser = 
  result = newParser()
  result.error_handler = handler
  handler.scanner = result.scanner
  result.var_table = newTable[string, VariableNode]()


const
  invalid_names = @[":", ";", "[", "]"]

const
  fes_comment_token_str = "#"

const
  asm_comment_token_str = ";"

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

proc create_asm_call(parser: Parser, op: string, param: string = ""): ASMCall =
  if not(op.is_OPCODE):
    var debug_node = ASTNode()
    parser.set_begin_info(debug_node)
    parser.report(debug_node, errInvalidASMInstruction, op)
    return ASMCall(op: INVALID_OPCODE, param: param)
  else:
    return ASMCall(op: parseEnum[OPCODE](op), param: param)

proc create_asm_label(parser: Parser, label_name: string): ASMLabel =
  return ASMLabel(label_name: label_name)



proc is_label(str: string): bool =
  return (str[str.len - 1] == ':')


proc trim_spaces(str: string): string =
  result = str
  if result.len == 0:
    return
  while result[0] == ' ':
    result = result[1..(result.len - 1)]
  while result[result.len - 1] == ' ':
    result = result[0..(result.len - 2)]

proc parse_asm_block(parser: Parser, asm_node: ASMNode) =
  if not(parser.scanner.has_next):
    parser.report(asm_node, errMissingASMEnding)
    return
  var line_str = parser.scanner.upto_next_line_str()
  var end_block = false
  var tokens_str: string
  var comment: ASMComment
  var comment_found = false
  while not(end_block):
    if line_str.contains(";"):
      comment_found = true
      var pos = find(line_str, ";")
      comment = newASMComment()
      if pos == 0:
        comment.on_own_line = true
      else:
        comment.on_own_line = false
      comment.comment = line_str[pos..(line_str.len - 1)]
      tokens_str = line_str[0..(pos - 1)]
    else:
      tokens_str = line_str
      comment_found = false

    if comment_found and (comment.on_own_line):
      asm_node.add(comment)

    if tokens_str.contains("]"):
      var pos = tokens_str.find("]")
      var len = tokens_str.trim_spaces.len
      var end_asm = true
      if (pos != 0) and (pos != len) and not(tokens_str[pos - 1] in Whitespace):
        end_asm = false
      if end_asm:
        end_block = true
        var end_pos = tokens_str.find("]")
        tokens_str = tokens_str[0..(end_pos - 1)]
        if tokens_str[end_pos..(tokens_str.len - 1)].splitWhitespace.len > 0:
          echo "Error: token after ] in asm block!"

    tokens_str = tokens_str.trim_spaces
    if tokens_str.splitWhitespace.len > 0:
      var operator = tokens_str.splitWhitespace[0].trim_spaces
      var operands: string
      if tokens_str.splitWhitespace.len == 1:
        operands = ""
      else:
        operands = tokens_str
        operands.removePrefix(operator)
        operands = operands.trim_spaces
      if operands.contains(Letters) or operands.contains(Digits):
        var call = parser.create_asm_call(operator, operands)
        asm_node.add(call)
      else:
        if operator[operator.len - 1] == ':':
          var label = parser.create_asm_label(operator[0..operator.len - 2]) # cutoff : at end  
          asm_node.add(label)
        else:
          var call = parser.create_asm_call(operator)
          asm_node.add(call)
    if comment_found and not(comment.on_own_line):
      asm_node.add(comment)

    if not(end_block):
      parser.scanner.skip_empty_lines()
      if parser.scanner.has_next:
        line_str = parser.scanner.upto_next_line_str()
      else:
        parser.report(asm_node, errMissingASMEnding)
        return


  



proc is_empty(node: ASMNode): bool = 
  return node.asm_calls.len == 0

proc parse_ifelse*(parser: Parser): IfElseNode
proc parse_while*(parser: Parser): WhileNode


proc parse_word_definition(parser: Parser, def_node: DefineWordNode) =
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.str_val == ";":
      return
    if token.str_val == "if":
      var ifelse_node = parser.parse_ifelse()
      def_node.add(ifelse_node)
    elif token.str_val == "[":
      var node = newASMNode()
      parser.set_begin_info(node)
      def_node.add(node)
      parser.parse_asm_block(node)
      if node.is_empty:
        parser.report(node, warnMissingASMBody)
    elif token.str_val == "#":
      parser.scanner.skip_to_next_line()
    elif token.str_val == "begin":
      var while_node = parser.parse_while()
      parser.set_begin_info(while_node)
      def_node.add(while_node)
    elif token.str_val.is_valid_number_str:
      var node = PushNumberNode()
      parser.set_begin_info(node)
      node.number = token.str_val.parse_to_integer
      def_node.add(node)
    elif token.str_val == ":":
      parser.report(def_node, errNestedWordDef, def_node.word_name)
    else:
      var node = OtherNode()
      parser.set_begin_info(node)
      parser.set_end_info(node)
      node.name = token.str_val.translate_name
      def_node.add(node)
  parser.set_end_info(def_node)
  parser.report(def_node, errMissingWordEnding, def_node.word_name)

proc parse_comment(parser: Parser) =
  var balance = 1
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token.str_val.contains("]#"):
      balance -= 1
    if token.str_val.contains("#["):
      balance += 1
    if balance == 0:
      break    


proc parse_variable(parser: Parser): VariableNode =
  result = VariableNode()
  result.var_type = Number
  result.size = 1
  result.var_index = parser.var_index
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
  discard

method is_empty(node: DefineWordNode): bool = 
  return node.definition.sequence.len == 0

method is_empty(node: SequenceNode): bool =
  return node.sequence.len == 0



proc check_var_overflow(var_index: int) = 
  discard

proc finish_struct(parser: Parser, node: StructNode): StructNode =
  result = node
  if result.members.len == 0:
    parser.report(result, warnMissingStructBody, result.name)
  parser.set_end_info(result)
  parser.structs[result.name] = result

#[
struct Palette {
  col0 0x0F
  col1 0xAB
  col2 0xBE
}

variable tmp_lst {1 2 3 4}

]#
proc parse_struct(parser: Parser): StructNode =
  result = newStructNode()
  parser.set_begin_infO(result)
  var first = false
  var struct_finished = false
  if parser.scanner.has_next:
    result.name = parser.scanner.next.str_val
  else:
    parser.report(result, errMalformedStruct)
  while parser.scanner.has_next:
    if struct_finished:
      return parser.finish_struct(result)
    var token = parser.scanner.next.str_val
    if token == "}":
      return parser.finish_struct(result)
    elif token.contains("}"):
      if not(token[token.len - 1] == '}'):
        parser.report(result,errMalformedStruct)
      token = token.replace("}", "")
      struct_finished = true
    elif token.contains("{"):
      if not(token[0] == '{'):
        parser.report(result, errMalformedStruct)
      token = token.replace("{", "")
    else:
      discard
    if token.len > 0:
      var struct_member = newStructMember()
      struct_member.name = token
      if parser.scanner.has_next_on_same_line():
        var next = parser.scanner.next.str_val
        if next == "=":
          var default_str_val = parser.scanner.next().str_val
          struct_member.set_default(default_str_val) 
        else:
          if next == $FESType.Number: # No List type added yet, only Number and Struct
            struct_member.type_data.fes_type = Number
          else: 
            # If the token is not a Number, it is a Struct, which kind of Struct is not defined here, just a struct
            # maybe store also struct name in member and then in a pass add the corresponding struct type info to each struct member
            struct_member.type_data.fes_type = Untyped_ptr
            struct_member.type_data.name = next
          if parser.scanner.has_next_on_same_line() and parser.scanner.next.str_val == "=":
            var default_str_val = parser.scanner.next().str_val
            struct_member.set_default(default_str_val)
      result.members.add(struct_member)
  parser.report(result, errMissingStructEnding)
 

proc parse_load_sprite(parser: Parser): LoadSpriteNode =
  result = LoadSpriteNode()
  parser.set_begin_info(result)
  result.name = parser.scanner.next.str_val
  result.path = parser.scanner.next.str_val
  parser.set_end_info(result)

proc parse_const(parser: Parser): ConstNode =
  result = newConstNode()
  parser.set_begin_info(result)
  if parser.scanner.has_next:
    result.name = parser.scanner.next.str_val
  if parser.scanner.has_next:
    result.value = parser.scanner.next.str_val
  parser.set_end_info(result)
  parser.const_table.add(result.name, result)

proc parse_init_struct_values(parser: Parser): InitStructValuesNode =
  result = newInitStructValuesNode()
  parser.set_begin_info(result)
  while parser.scanner.has_next: # no checks, malformed InitList should be reported!
    var name = parser.scanner.next.str_val
    if name == "}":
      return
    var eq = parser.scanner.next.str_val
    var default_val = parser.scanner.next.str_val
    result.names.add(name)
    result.str_values.add(default_val)

proc parse_init_list_values(parser: Parser): InitListValuesNode =
  result = newInitListValuesNode()
  parser.set_begin_info(result)
  while parser.scanner.has_next:
    var next = parser.scanner.next.str_val
    if next == "}":
      return
    result.str_values.add(next)

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
        def_node.word_name = token.str_val.translate_name
        if not(is_valid_name(token.str_val)):
          parser.report(def_node, errInvalidDefinitionWordName, token.str_val)
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
    elif token.str_val.len >= 6 and token.str_val[0..4] == "List-" and not(token.str_val.contains("List-get")) and not(token.str_val.contains("List-set")) and not(token.str_val.contains("List-size")):
      var type_and_size = token.str_val[5..(token.str_val.len - 1)].split("-")
      var el_type_str = type_and_size[0]
      var size_str: string = type_and_size[1]
      var list_node = newListNode()
      list_node.element_type_data.name = el_type_str
      list_node.size = size_str.parseInt
      if el_type_str == "Number":
        list_node.element_type_data.fes_type = Number
      else:
        list_node.element_type_data.fes_type = Untyped_ptr
      root.add(list_node)
      if parser.scanner.has_next and parser.scanner.peek.str_val == "{":
        discard parser.scanner.next # discard opening {
        var init_list_node = parser.parse_init_list_values()
        parser.set_end_info(init_list_node)
        root.add(init_list_node)
    elif token.str_val == "if":
      var ifelse_node = parser.parse_ifelse()
      root.add(ifelse_node)
    elif token.str_val == "#":
      parser.scanner.skip_to_next_line()
    elif token.str_val == "load_sprite": # every sprite gets a corresponding Sprite struct variable "variable <name> Sprite" 
      var load_sprite_node = parser.parse_load_sprite()
      var var_node = VariableNode()
      var_node.size = 1
      var_node.var_index = parser.var_index
      parser.var_index += 1
      var_node.name = load_sprite_node.name
      var other_node = OtherNode()
      other_node.name = "Sprite"
      parser.set_info(other_node)
      parser.var_table[var_node.name] = var_node
      root.add(load_sprite_node)
      root.add(var_node)
      root.add(other_node)
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
    elif token.str_val == "const":
      var const_node = parser.parse_const()
      root.add(const_node)
    elif token.str_val.contains("#["):
      parser.parse_comment()
    elif token.str_val == "{":
      var init_struct_val_node = parser.parse_init_struct_values()
      root.add(init_struct_val_node)
    elif token.str_val.is_valid_number_str:
      var node = PushNumberNode()
      parser.set_begin_info(node)
      node.number = token.str_val.parse_to_integer
      root.add(node)
    else:
      var node = OtherNode(name: translate_name(token.str_val))
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


import strutils
type
  ASTNode = ref object of RootObj

  PushNumberNode = ref object of ASTNode
    number: int

  SequenceNode = ref object of ASTNode
    sequence: seq[ASTNode]

  DefineWordNode = ref object of ASTNode
    word_name: string
    definition: SequenceNode
  
  CallWordNode = ref object of ASTNode
    word_name: string

  ASMNode = ref object of ASTNode
    asm_calls: seq[string]

  ASMCall = ref object of RootObj
    name: string
    argument: int
    cycles: int

  Scanner = ref object of RootObj
    src: string
    lines: seq[string]
    columns: seq[string]
    line: int
    column: int

  Parser = ref object of RootObj
    root: SequenceNode
    scanner: Scanner


proc nonempty(lines: seq[string], index = 0): bool =
  for i in countup(index, lines.len - 1):
    if lines[i].len != 0:
      return true
  return false


proc read_string(scanner: Scanner, src: string) =
  scanner.src = src
  scanner.lines = splitLines(src)
  echo scanner.lines
  scanner.columns = scanner.lines[0].splitWhitespace
  scanner.line = 0
  scanner.column = 0


proc has_next(scanner: Scanner): bool = 
  return (scanner.column < scanner.columns.len - 1) or (nonempty(scanner.lines, scanner.line + 1))


proc next(scanner: Scanner): string = 
  if scanner.column >= scanner.columns.len:
    scanner.column = 0
    scanner.line += 1
    scanner.columns = scanner.lines[scanner.line].splitWhitespace
  var token = scanner.columns[scanner.column]
  scanner.column += 1
  return token


proc newSequenceNode(): SequenceNode =
  var node = SequenceNode()
  node.sequence = @[]
  return node


proc newASMNode(): ASMNode =
  var node = ASMNode()
  node.asm_calls = @[]
  return node


proc newDefineWordNode(): DefineWordNode =
  var node = DefineWordNode()
  node.definition = newSequenceNode()
  return node


proc add(node: SequenceNode, other: ASTNode) = 
  node.sequence.add(other)


proc add(node: DefineWordNode, other: ASTNode) =
  node.definition.add(other)


proc add(node: ASMNode, asm_call: string) = 
  node.asm_calls.add(asm_call)


proc isInteger(str: string): bool =
  try:
    let f = parseInt str
  except ValueError:
     return false
  return true


proc parse_asm_block(parser: Parser, asm_node: ASMNode) = 
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token == "]":
      return
    else:
      asm_node.add(token)


proc parse_word_definition(parser: Parser, def_node: DefineWordNode) =
  while parser.scanner.has_next:
    var token = parser.scanner.next
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
    else:
      var node = CallWordNode()
      node.word_name = token
      def_node.add(node)


proc parse_string(parser: Parser, src: string) = 
  parser.scanner.read_string(src)
  var root = newSequenceNode()
  while parser.scanner.has_next:
    var token = parser.scanner.next
    if token == ":":
      var def_node = newDefineWordNode()
      token = parser.scanner.next
      def_node.word_name = token
      parser.parse_word_definition(def_node)
      root.add(def_node)
    elif token == "[":
      var asm_node = newASMNode()
      parser.parse_asm_block(asm_node)
      root.add(asm_node)
    elif token.isInteger:
      var node = PushNumberNode()
      node.number = token.parseInt
      root.add(node)
    else:
      var node = CallWordNode(word_name: token)
      root.add(node)
  parser.root = root


proc newParser(): Parser = 
  var parser = Parser()
  parser.scanner = Scanner()
  return parser


proc is_def(node: ASTNode): bool =
  return (node of DefineWordNode)

proc partition[T](sequence: seq[T], pred: proc): tuple[selected: seq[T],rejected: seq[T]] =
  var selected: seq[T] = @[]
  var rejected: seq[T] = @[]
  for el in sequence:
    if el.pred:
      selected.add(el)
    else:
      rejected.add(el)
  return (selected, rejected)

proc group_word_defs_last(root: SequenceNode) = 
  var partition = root.sequence.partition(is_def)
  root.sequence = partition.rejected & partition.selected


method print(node: ASTNode) =
  echo node[]


method print(node: SequenceNode) = 
  for child in node.sequence:
    child.print


method print(node: ASMNode) =
  for call in node.asm_calls:
    echo call


method print(node: PushNumberNode) =
  echo node[]


method print(node: DefineWordNode) =
  echo "define_node: " & node.word_name
  node.definition.print
  echo "end_define"


method print(node: CallWordNode) =
  echo "call: "
  echo node[]


var test_src = """
1 2 3
: name1
4 5 6
;
: name2
7 8 name1
;
9 10 11
""" 
var parser = newParser()
parser.parse_string(test_src)
#parser.root.print
parser.root.group_word_defs_last()
parser.root.print








    
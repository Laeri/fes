import
  types, strutils

type
  TokenKind = enum
    BEGIN_WORD
    END_WORD
    IF
    ELSE
    THEN
    BEGIN_ASM
    END_ASM
    OTHER
    NUMBER
    
  Token* = ref object of RootObj
    kind*: TokenKind
    line*: int
    column*: int
    line_str*: string
    str_val*: string
    

proc newScanner*(): Scanner =
  result = Scanner()
  result.sources = @[]
  result.source_names = @[]
  result.src_index = 0

proc newToken(): Token =
  result = Token()

proc current_line_str*(scanner: Scanner): string =
  result = scanner.lines[scanner.line]

proc line_str_at*(scanner: Scanner, pos: int): string =
  result = scanner.lines[pos]

proc token_str_vals*(tokens: seq[Token]): seq[string] =
  result = @[]
  for token in tokens:
    result.add(token.str_val)

proc isInteger*(str: string): bool =
  try:
    let f = parseInt str
  except ValueError:
     return false
  return true

proc column_position*(scanner: Scanner): int =
  return scanner.column_accurate

proc line_position*(scanner: Scanner): int =
  return scanner.line


proc has_next*(scanner: Scanner): bool = 
  if (scanner.line >= scanner.lines.len):
    return false
  return (scanner.column < scanner.columns.len)

proc set_accurate_count(scanner: Scanner) =
  if not(scanner.has_next):
    return
  var char_count = -1
  var word_count = -1
  var in_space = scanner.current_line_str[0] in Whitespace
  if not(in_space):
    word_count += 1
  for ch in scanner.lines[scanner.line]:
    char_count += 1
    if (ch in Whitespace):
      in_space = true
    elif in_space:
      word_count += 1
      in_space = false
    if word_count == scanner.column:
      scanner.column_accurate = char_count
      return


proc advance*(scanner: Scanner) =
  scanner.column += 1
  if scanner.column >= scanner.columns.len:
    scanner.column = 0
    scanner.line += 1
    if scanner.line < scanner.lines.len:
      scanner.columns = scanner.lines[scanner.line].splitWhitespace
      if(scanner.columns.len == 0):
        scanner.advance
  scanner.set_accurate_count()

proc current_word_range*(scanner: Scanner): ColumnRange =
  result = ColumnRange(low: scanner.column_accurate)
  if scanner.column >= scanner.columns.len:
    result.high = result.low
  else:
    result.high = result.low + scanner.columns[scanner.column].len - 1
  
proc current_line_pos*(scanner: Scanner): int =
  return scanner.line

proc current_column_pos*(scanner: Scanner): int =
  return scanner.column_accurate

proc current_src_file*(scanner: Scanner): string = 
  return scanner.src_name


proc read_string*(scanner: Scanner, src: string, name: string) =
  scanner.src_name = name
  scanner.lines = splitLines(src)
  if scanner.lines.len != 0:
    scanner.columns = scanner.lines[0].splitWhitespace
  else:
    scanner.columns = @[]
  scanner.line = 0
  scanner.column = -1
  scanner.column_accurate = 0
  scanner.advance

proc read_string*(scanner: Scanner, src: string) =
  var name = "TEST_NAME"
  scanner.read_string(src, name)

proc skip_to_next_line*(scanner: Scanner) =
  scanner.line += 1
  scanner.column = 0
  if scanner.has_next:
    scanner.columns = scanner.lines[scanner.line].splitWhitespace
    scanner.column_accurate = 0


proc skip_empty_lines*(scanner: Scanner) =
  if scanner.has_next:
    while scanner.lines[scanner.line].len == 0:
      scanner.skip_to_next_line
  scanner.set_accurate_count()

proc skip_to_next_nonempty_line*(scanner: Scanner) =
  while scanner.has_next:
    scanner.line += 1
    scanner.column = 0
    scanner.columns = scanner.lines[scanner.line].splitWhitespace
    scanner.column_accurate = 0
    if scanner.lines[scanner.line].len != 0:
      break

proc parse_to_token*(scanner: Scanner, str_val: string): Token =
  var token = newToken()
  token.str_val = str_val
  var kind: TokenKind
  case token.str_val:
  of ":":
    kind = BEGIN_WORD
  of ";":
    kind = END_WORD
  of "[":
    kind = BEGIN_ASM
  of "]":
    kind = END_ASM
  of "if":
    kind = IF
  of "IF":
    kind = IF
  of "else":
    kind = ELSE
  of "ELSE":
    kind = ELSE
  of "then":
    kind = THEN
  of "THEN":
    kind = THEN

  if token.str_val.isInteger():
    kind = NUMBER
  else:
    kind = OTHER

  token.kind = kind
  return token

proc current_token(scanner: Scanner): Token =
  var str_val = scanner.columns[scanner.column] 
  var token = scanner.parse_to_token(str_val)
  token.column = scanner.column
  token.line = scanner.line
  return token

proc peek*(scanner: Scanner): Token = 
  return scanner.current_token



proc next*(scanner: Scanner): Token =
  var token = scanner.currentToken()
  scanner.advance
  return token


proc backtrack*(scanner: Scanner, times = 1) =
  var back = times
  while back > 0:
    if scanner.column > 0:
      scanner.column -= 1
    else:
      scanner.line -= 1
      scanner.columns = scanner.lines[scanner.line].splitWhitespace
      while(scanner.columns.len == 0):
        scanner.line -= 1
        scanner.columns = scanner.lines[scanner.line].splitWhitespace
      scanner.column = scanner.columns.len - 1
    back -= 1
  scanner.set_accurate_count()


proc upto_next_line*(scanner: Scanner): seq[Token] =  
  var line_tokens = scanner.columns[scanner.column .. (scanner.columns.len - 1)]
  scanner.skip_to_next_line()
  scanner.skip_empty_lines()
  scanner.set_accurate_count()
  var tokens: seq[Token] = @[]
  for token_str in line_tokens:
    tokens.add(scanner.parse_to_token(token_str))
  return tokens

proc upto_next_line_str*(scanner: Scanner): string =
  var current_line = scanner.current_line_str()
  result = current_line[scanner.column_accurate..(current_line.len - 1)]
  scanner.skip_to_next_line()
  scanner.skip_empty_lines()

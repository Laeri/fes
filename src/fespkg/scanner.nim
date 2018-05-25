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
    
proc newToken(): Token =
  result = Token()

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
  var word_count = 0
  var in_space = false
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


proc read_string*(scanner: Scanner, src: string) =
  scanner.src = src
  scanner.lines = splitLines(src)
  if scanner.lines.len != 0:
    scanner.columns = scanner.lines[0].splitWhitespace
  else:
    scanner.columns = @[]
  scanner.line = 0
  scanner.column = -1
  scanner.column_accurate = 0
  scanner.advance

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
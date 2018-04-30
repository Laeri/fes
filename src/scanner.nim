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
  discard
  if scanner.has_next:
    var split_by_token = scanner.lines[scanner.line].split(scanner.columns[scanner.column])
    if split_by_token.len == 0:
      scanner.column_accurate = 0
    else:
      scanner.column_accurate = split_by_token[0].len

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

proc nonempty(lines: seq[string], index = 0): bool =
  for i in countup(index, lines.len - 1):
    if lines[i].splitWhitespace.len != 0:
      return true
  return false


proc skip_to_next_line*(scanner: Scanner) =
  scanner.line += 1
  scanner.column = 0
  scanner.columns = scanner.lines[scanner.line].splitWhitespace
  scanner.column_accurate = 0


proc skip_empty_lines*(scanner: Scanner) =
  if scanner.has_next:
    while scanner.lines[scanner.line].len == 0:
      scanner.skip_to_next_line
  scanner.set_accurate_count()

proc current_token(scanner: Scanner) : Token = 
  var token = newToken()
  token.column = scanner.column
  token.line = scanner.line
  token.str_val = scanner.columns[scanner.column]
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


proc upto_next_line*(scanner: Scanner): seq[string] =  
  var line_tokens = scanner.columns[scanner.column .. (scanner.columns.len - 1)]
  scanner.skip_to_next_line()
  scanner.skip_empty_lines()
  scanner.set_accurate_count()
  return line_tokens
import
  types, strutils



proc nonempty(lines: seq[string], index = 0): bool =
  for i in countup(index, lines.len - 1):
    if lines[i].len != 0:
      return true
  return false


proc read_string*(scanner: Scanner, src: string) =
  scanner.src = src
  scanner.lines = splitLines(src)
  if scanner.lines.len != 0:
    scanner.columns = scanner.lines[0].splitWhitespace
  else:
    scanner.columns = @[]
  scanner.line = 0
  scanner.column = 0

proc has_next*(scanner: Scanner): bool = 
  return (scanner.column < scanner.columns.len - 1) or (nonempty(scanner.lines, scanner.line + 1))


proc skip_to_next_line*(scanner: Scanner) =
  scanner.line += 1
  scanner.column = 0
  scanner.columns = scanner.lines[scanner.line].splitWhitespace


proc skip_empty_lines*(scanner: Scanner) =
  if scanner.has_next:
    while scanner.lines[scanner.line].len == 0:
      scanner.skip_to_next_line

proc backtrack*(scanner: Scanner, times = 1) =
  var back = times
  while back > 0:
    if scanner.column > 0:
      scanner.column -= 1
      back -= 1
    else:
      scanner.column = 0
      scanner.line -= 1
      scanner.columns = scanner.lines[scanner.line].splitWhitespace

proc advance*(scanner: Scanner) =
  scanner.column += 1
  if scanner.column >= scanner.columns.len:
    scanner.column = 0
    scanner.line += 1
    scanner.columns = scanner.lines[scanner.line].splitWhitespace
  while scanner.lines[scanner.line].len == 0:
    scanner.advance 



proc next*(scanner: Scanner): string = 
  var token = scanner.columns[scanner.column]
  scanner.advance
  return token

proc upto_next_line*(scanner: Scanner): seq[string] =  
  var line_tokens = scanner.columns[scanner.column .. (scanner.columns.len - 1)]
  scanner.skip_to_next_line()
  scanner.skip_empty_lines()
  return line_tokens
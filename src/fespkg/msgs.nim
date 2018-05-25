import
  strutils, os, tables, terminal, types, sequtils, typeinfo, scanner


const
  min_err = BEGIN_ERRORS
  max_err = END_ERRORS
  min_hint = BEGIN_HINTS
  max_hint = END_HINTS
  min_warn = BEGIN_WARNINGS
  max_warn = END_WARNINGS
  min_res = BEGIN_RESULTS
  max_res = END_RESULTS

const
  ErrorTitle = "Error: "
  ErrorColor = fgRed
  WarningTitle = "Warning: "
  WarningColor = fgYellow
  HintTitle = "Hint: "
  HintColor = fgBlue
  ResultTitle = "Result: "
  ResultColor = fgGreen

proc newFError*(msg: MsgKind, msg_args: seq[string]): FError = 
  result = FError()
  result.indications = @[]
  result.msg = msg
  result.msg_args = msg_args

proc newErrorIndication*(line: int, column_range: ColumnRange, msg:string = "", args: seq[string]  = @[]): ErrorIndication =
  result = ErrorIndication(line: line, column_range: column_range, msg: msg, args: args)

proc newErrorHandler*(): ErrorHandler =
  result = ErrorHandler()
  result.errors = @[]
  result.silent = false

proc set_silent*(handler: ErrorHandler) = 
  handler.silent = true

proc set_silent*(handler: ErrorHandler, silent: bool) =
  handler.silent = silent

proc has_errors*(handler: ErrorHandler): bool =
  return handler.errors.len > 0

proc report(handler: ErrorHandler, error: FError)
proc printMessage*(msg_k: MsgKind, params: varargs[string])

proc has_error_type*(handler: ErrorHandler, msg_kind: MsgKind): bool =
  for comp_err in handler.errors:
    if comp_err.msg == msg_kind:
      return true
  return false

proc handle*(handler: ErrorHandler, error: FError) =
  if not(handler.silent):
    handler.report(error)
  handler.errors.add(error)

proc handle*(handler: ErrorHandler, msg: MsgKind, msg_args: seq[string]) =
  var error = newFError(msg, msg_args)
  if not(handler.silent):
      printMessage(msg, msg_args)
  handler.errors.add(error)

proc handle*(handler: ErrorHandler, msg: MsgKind, msg_args: seq[string], line_info: LineInfo) =
  var error_info = newFError(msg, msg_args)
  if not(handler.silent):
    printMessage(msg, msg_args)
  handler.errors.add(error_info)
  

proc line_indicator(line: int): string =
  return $line & "| "

proc to_string(str: seq[char]): string =
  result = newStringOfCap(len(str))
  for ch in str:
    result.add(ch)

proc low(slice: Slice): int =
  result = slice.a

proc high(slice: Slice): int =
  result = slice.b

proc print_error_indicator(handler: ErrorHandler, ind: ErrorIndication) =
  var range = ind.column_range
  range.clamp_min(0)
  var line: seq[char] = @[]
  if range.low != 0:
    for i in 0..(range.low - 1):
      stdout.write(" ")
  stdout.setForeGroundColor(ErrorColor)
  for i in range.low..(range.high):
    stdout.write("^")
  stdout.write("\n")
  stdout.resetAttributes

proc repeat_str(str: string, num: int): string =
  result = ""
  for i in 0..(num - 1):
    result &= str

proc line_indent(num: int): string =
  return $num & "| "


proc remove_overlap(r1: CustomRange, r2: CustomRange) =
  if r1.high >= r2.low:
    r1.high = r2.low - 1

proc to_s(r1: CustomRange): seq[int] =
  result = @[]
  for i in r1.low..r1.high:
    result.add(i)

proc pprint_line(handler: ErrorHandler, error: FError, line_pos: int) =
  var min_indent = "  "
  var line_ind = min_indent & line_indent(line_pos + 1)
  var indent = repeat_str(" ", line_ind.len)
  if line_pos == error.start_line:
    echo line_ind & handler.scanner.line_str_at(0)
    stdout.write(indent)
    handler.print_error_indicator(error.indications[0])
  else:
    echo line_ind & handler.scanner.line_str_at(line_pos)

proc prettyPrintError(handler: ErrorHandler, error: FError) =
  var range_at_start = LineRange(low: -1, high: 3)
  var range_at_end = LineRange(low: -1, high: 3)
  range_at_start.shift_to(error.start_line)
  range_at_end.shift_to(error.line_range.high)
  range_at_start.clamp(0, handler.scanner.lines.len - 1)
  range_at_end.clamp(0, handler.scanner.lines.len - 1)
  remove_overlap(range_at_start, range_at_end)
  var msg = $error.msg
  if error.msg_args.len > 0:
    msg = msg % error.msg_args
  setForeGroundColor(HintColor)
  echo "==========================================="
  setForeGroundColor(ErrorColor)
  stdout.write(ErrorTitle)
  stdout.resetAttributes
  stdout.writeln(msg)
  stdout.flushFile
  echo "  " & error.file_name & ":" & $error.start_line & ":" & $error.start_column
  for line_pos in range_at_start.to_s():
    pprint_line(handler, error, line_pos)
  #echo ""
  echo "  \u00B7\u00B7\u00B7"
  #echo ""
  for line_pos in range_at_end.to_s:
    pprint_line(handler, error, line_pos)
  setForeGroundColor(HintColor)
  echo "==========================================="
  stdout.resetAttributes

proc printError(msg_k: MsgKind, params: varargs[string]) =
  var msg = $msg_k % params
  setForeGroundColor(ErrorColor)
  stdout.write(ErrorTitle)
  stdout.resetAttributes
  stdout.writeln(msg)
  stdout.flushFile


proc printWarning(msg_k: MsgKind, params: varargs[string]) =
  var msg = $msg_k % params
  setForeGroundColor(WarningColor)
  stdout.write(WarningTitle)
  stdout.resetAttributes
  stdout.writeln(msg)
  stdout.flushFile


proc printHint(msg_k: MsgKind, params: varargs[string]) =
  var msg = $msg_k % params
  setForeGroundColor(HintColor)
  stdout.write(HintTitle)
  stdout.resetAttributes
  stdout.writeln(msg)
  stdout.flushFile


proc printResult(msg_k: MsgKind, params: varargs[string]) =
  var msg = $msg_k % params
  setForeGroundColor(ResultColor)
  stdout.write(ResultTitle)
  stdout.resetAttributes
  stdout.writeln(msg)
  stdout.flushFile

proc printMessage*(msg_k: MsgKind, params: varargs[string]) =
  if msg_k in min_err..max_err:
    printError(msg_k, params)
  elif msg_k in min_warn..max_warn:
    printWarning(msg_k, params)
  elif msg_k in min_hint..max_hint:
    printHint(msg_k, params)
  elif msg_k in min_res..max_res:
    printResult(msg_k, params)

proc report(handler: ErrorHandler, error: FError) =
  handler.prettyPrintError(error)

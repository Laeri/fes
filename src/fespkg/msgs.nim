import
  strutils, os, tables, terminal, types, sequtils, typeinfo


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

proc newErrorInfo*(msg: MsgKind, msg_args: seq[string], line_info: LineInfo): ErrorInfo = 
  result = ErrorInfo()
  result.msg = msg
  result.msg_args = msg_args
  result.line_info = line_info

proc newErrorHandler*(): ErrorHandler =
  result = ErrorHandler()
  result.errors = @[]
  result.silent = false

proc set_silent*(handler: ErrorHandler) = 
  handler.silent = true

proc has_errors*(handler: ErrorHandler): bool =
  return handler.errors.len > 0

proc report(error_info: ErrorInfo)

proc has_error_type*(handler: ErrorHandler, msg_kind: MsgKind): bool =
  for comp_err in handler.errors:
    if comp_err.msg == msg_kind:
      return true
  return false


proc handle*(handler: ErrorHandler, msg: MsgKind, msg_args: seq[string]) =
  var error_info =  ErrorInfo(msg: msg, msg_args: msg_args)
  if not(handler.silent):
    report(error_info)
  handler.errors.add(error_info)

proc handle*(handler: ErrorHandler, msg: MsgKind, msg_args: seq[string], line_info: LineInfo) =
  var error_info = newErrorInfo(msg, msg_args, line_info)
  if not(handler.silent):
    report(error_info)
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

proc print_error_indicator(range: ColumnRange) =
  range.clamp_min(0)
  var line: seq[char] = @[]
  if range.low != 0:
    for i in 0..range.low:
      stdout.write(" ")
  stdout.setForeGroundColor(ErrorColor)
  for i in range.low..(range.high - 1):
    stdout.write("^")
  stdout.write("\n")
  stdout.resetAttributes

print_error_indicator((0..5).to_ColumnRange)

proc prettyPrintError(msg_k: MsgKind, params: varargs[string], line_info: LineInfo) =
  var range_at_start = LineRange(low: -1, high: 3)
  var range_at_end = LineRange(low: -1, high: 3)
  var msg = $msg_k % params
  setForeGroundColor(ErrorColor)
  stdout.write(ErrorTitle)
  stdout.resetAttributes
  stdout.writeln(msg)
  stdout.flushFile
  echo "file name: " & line_info.file_name & ": " & $line_info.line & ": " & $line_info.column
  

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

proc report(error_info: ErrorInfo) =
  printMessage(error_info.msg, error_info.msg_args)

proc report(msg: MsgKind, args: varargs[string]) =
  printMessage(msg, args)

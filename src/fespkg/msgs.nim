import
  strutils, os, tables, terminal, types


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

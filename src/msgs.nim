import
  strutils, os, tables, terminal

type
  LineInfo = tuple[line: int, column: int, line_str: string, file_name: string]
  CError* = ref object of RootObj
    msg_kind: MsgKind
    line_info: LineInfo
  MsgKind* = enum
    BEGIN_ERRORS
    errWordAlreadyDefined = "word \'$1\' already exists"
    errMissingWordEnding = "word \'$1\' has no definition ending \";\""
    errWordDefInsideOtherWord = "word \'$1\' has another definition inside it"
    errInvalidDefinitionWordName = "wordname \'$1\' in definition is not a valid name"
    errInvalidCallWordName = "wordname \'$1\' for a call not a valid name"
    END_ERRORS

    BEGIN_WARNINGS
    END_WARNINGS

    BEGIN_HINTS
    END_HINTS

    BEGIN_RESULTS
    END_RESULTS


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

proc report*(msg: MsgKind, args: varargs[string]) =
  printMessage(msg, args)

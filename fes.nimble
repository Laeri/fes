# Package

version       = "0.0.1"
author        = "Laeri"
description   = "A compiler for a forth like programming language to the NES (Nintendo Entertainment System)"
license       = "MIT"
srcDir        = "src"
bin           = @["fes"]

# Dependencies

requires "nim >= 0.18.0"
requires "docopt"

var silent = " --hints:off --warnings:off"


task run, "Run a file in the src/fespkg folder and generate binaries in bin/":
  if paramCount() < 2:
    quit(QuitFailure)
  else:
    var src_name = paramStr(2)
    exec "nim c " & silent & " -o=bin/" & src_name & " -r src/fespkg/" & src_name

task comp, "Compile a file in the src/fespkg folder and generate binares in bin/":
  if paramCount() < 2:
    quit(QuitFailure)
  else:
    var src_name = paramStr(2)
    exec "nim c" & silent & " -o=bin/" & src_name & " src/fespkg/" & src_name

task tests, "Run all tests in tests/ folder":
  exec "nim c -r " & silent & " -o=bin/runtests tests/runtests"

task test, "Run specified test in tests/ folder":
  if paramCount() < 2:
    quit(QuitFailure)
  else:
    var src_name = paramStr(2)
    exec "nim c -r " & silent & " -o=bin/" & src_name & " -r tests/" & src_name & " NIMTEST_OUTPUT_LVL=PRINT_FAILURES"

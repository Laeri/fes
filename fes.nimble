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

task run, "Run a file in the src/fespkg folder and generate binaries in bin/":
  if paramCount() < 2:
    quit(QuitFailure)
  else:
    var src_name = paramStr(2)
    exec "nim c -o=bin/" & src_name & " -r src/fespkg/" & src_name

task tests, "Run all tests in tests/ folder":
  exec "nim c -r -o=bin/runtests tests/runtests"



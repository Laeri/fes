import
  os, osproc, strutils, types, msgs

var compiled: int
var errors = false
var error_tests: seq[string] = @[]

for file in walkDir("tests/"):
  var (dir, name, ext) = splitFile(file.path)
  if (ext == ".nim") and (name != "runtests"):
    compiled = execCmd("nim c -r --verbosity:0 --hints:off --warnings:off -o=bin/" & name & " " & file.path )
    if compiled != 0:
      errors = true
      error_tests.add(name)

if errors:
  var handler = newErrorHandler()
  for error_t in error_tests:
    handler.handle(errTestError, @[error_t])
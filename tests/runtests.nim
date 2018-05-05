import
  os, osproc, strutils

var compiled: int
for file in walkDir("tests/"):
  var (dir, name, ext) = splitFile(file.path)
  if (ext == ".nim") and (name != "runtests"):
    compiled = execCmd("nim c -r --verbosity:0 --hints:off --warnings:off -o=bin/" & name & " " & file.path)
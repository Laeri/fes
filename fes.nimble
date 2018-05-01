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

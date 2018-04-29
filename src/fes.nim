import
  docopt, strutils, os, types, compiler

let version = "0.0.1"
let name = "fes"

let doc = name & 
  """.

Usage:
  fes (c | compile) <file_name> [-r | --run]
  fes (c | compile) <file_name> [--out=<out_path>] [--pass_info=<pass_path>] [--no_optimize]
  fes (-h | --help)
  fes --version

Options:
  -h --help                 Show this screen.
  --version                 Show version.
  --out:<out_path>          Generate binary output file at given path.
  --pass_info:<pass_path>   Generate pass info at given path.
  --no_optimize             Turn all optimizations of the compiler off.
"""


let args = docopt(doc, version = (name & " " & version))
var fes = newFESCompiler()
if args.contains("<out_path>"):
  fes.out_asm_folder = $args["<out_path>"]
else:
  fes.out_asm_folder = "TETSTST.asm"
if args.contains("<pass_path>"):
  fes.out_passes_folder = $args["<pass_path>"]
fes.optimize = not(args["--no_optimize"].to_bool)
fes.file_name = $args["<file_name>"]
fes.run = args["--run"].to_bool or args["-r"].to_bool

fes.compile()
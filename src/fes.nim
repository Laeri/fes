import
  docopt, strutils, os, fespkg/types, fespkg/compiler

let version = "0.0.1"
let name = "fes"

let doc = name & 
  """.

Usage:
  fes (c | compile) <file_name>
  fes (c | compile) <file_name> [options]
  fes (-h | --help)
  fes --version

Options:
  -h --help                 Show this screen.
  --version                 Show version.
  --out=<out_path>          Generate binary output file at given path.
  --pass_info=<pass_path>   Generate pass info at given path.
  --no_optimize             Turn all optimizations of the compiler off.
  -r --run                  Compile and run the resulting file in emulator.
  -s --silent               No compiler warnings or hints on stdout.
  --no_core_words           Don't load the core words, used for debugging purposes.
  --show_asm_log            Shows the output of the nes assembler.
  --no_library              Don't load library words for graphics and audio control.
"""


let args = docopt(doc, version = (name & " " & version))
var fes = newFESCompiler()
fes.name = name
fes.version = version

fes.file_path = $args["<file_name>"]
if args.contains("--out"):
  fes.out_asm_folder = $args["--out"]
if args.contains("<pass_path>"):
  fes.out_passes_folder = $args["<pass_path>"]
fes.optimize = not(args["--no_optimize"].to_bool)
fes.run = args["--run"].to_bool
fes.silent = args["--silent"]
fes.load_core_words = args["--no_core_words"].not
fes.load_library = args["--no_library"].not
fes.show_asm_log = args["--show_asm_log"].to_bool
fes.compile()

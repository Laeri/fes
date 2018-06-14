import 
  strutils, asm_t, sequtils, tables, typetraits, macros, os,
  streams, osproc, types, optimizer, callgraph, scanner, msgs, typeinfo, sequtils, parser, ast, sets, codegenerator, times, passes


proc newFESCompiler*(): FESCompiler =
  result = FESCompiler()
  result.error_handler = newErrorHandler()
  result.parser = newParser(result.error_handler)
  result.generator = newCodeGenerator()
  result.pass_runner = newPassRunner(result.parser)


proc report(compiler: FESCompiler, msg: MsgKind, msg_args: varargs[string]) =
  var args: seq[string] = @[]
  for ar in msg_args:
    args.add(ar)
  compiler.error_handler.handle(msg, args)




proc time(asm_call: ASM_Call): int =
  return info_table[asm_call.op][asm_call.mode].time



proc generate_nes_str(asm_code: seq[ASMAction]): string =
  var num_16k_prg_banks = 1
  var num_8k_chr_banks = 0
  var VRM_mirroring = 1
  var nes_mapper = 0
  
  var program_start = "$8000"

  result = "; INES header setup\n\n"
  result &= "  .inesprg " & $num_16k_prg_banks & "\n"
  result &= "  .ineschr " & $num_8k_chr_banks & "\n"
  result &= "  .inesmir " & $VRM_mirroring & "\n"
  result &= "  .inesmap " & $nes_mapper & "\n"
  result &= "\n"
  result &= "  .org " & program_start & "\n"
  result &= "  .bank 0\n\n"
  result &= aasm_to_string(asm_code)
  result &= "\n"
  result &= """
  .bank 1
  .org $FFFA
  .dw 0
  .dw Start
  .dw 0
  """
  return result

proc extract_file_name(file_name: string): string =
  var splitted = file_name.split(r"/")
  return splitted[splitted.len - 1]

proc file_ending(file_name: string, new_ending: string): string =
  return file_name.replace("\\..*$", new_ending)

proc generate_and_store(compiler: FESCompiler, asm_code: seq[ASMAction], file_path: string) =
  var fs = newFileStream(file_path, fmWrite)
  var nes_str = generate_nes_str(asm_code)
  #echo compiler.parser.root.str
  fs.write(nes_str)
  fs.close
  compiler.report(reportGeneratedASMFile, file_path)

proc run_in_emu(file_path: string) =
  var emulator = "fceux" 
  var exit_code = execCmd emulator & file_path
  var (output, exitCoe2) = execCmdEx emulator & file_path

proc generate_and_assemble(compiler: FESCompiler, asm_code: seq[ASMAction], file_path: string) =
  compiler.generate_and_store(asm_code, file_path)
  let (outp, error_code) = execCmdEx "nesasm " & file_path
  if  error_code != 0:
    compiler.report(errAssemblyError, $error_code, outp) 
  if outp.contains("error") or compiler.show_asm_log:
    compiler.report(errASMSourceError, outp)

proc do_passes(compiler: FESCompiler) =
  var pass_runner = compiler.pass_runner
  pass_runner.pass_group_word_defs_last(compiler.parser.root)
  pass_runner.pass_check_multiple_defs(compiler.parser.root)
  pass_runner.pass_set_constants(compiler.parser.root)
  pass_runner.pass_set_struct_var_type(compiler.parser.root)
  pass_runner.pass_gen_getters(compiler.parser.root)
  pass_runner.pass_gen_setters(compiler.parser.root)
  pass_runner.pass_set_list_var_type(compiler.parser.root)
  pass_runner.pass_set_variable_loads(compiler.parser.root)
  pass_runner.pass_set_variable_addresses(compiler.parser.root)
  pass_runner.pass_group_vars_first(compiler.parser.root)
  pass_runner.pass_init_list_sizes(compiler.parser.root)
  pass_runner.pass_gen_list_methods(compiler.parser.root)
  pass_runner.pass_set_word_calls(compiler.parser.root)
  pass_runner.pass_add_start_label(compiler.parser.root)
  pass_runner.pass_add_end_label(compiler.parser.root)
  pass_runner.pass_check_no_OtherNodes(compiler.parser.root)

proc do_asm_passes(compiler: FESCompiler, code: var seq[ASMAction]) =
  asm_pass_fix_branch_addr_too_far(code)


const core = readFile("src/core/core.fes")
const engine_lib = readFile("src/engine_lib/engine_lib.fes")
const ppopt_src = readFile("src/ppopt/peephole_6502.txt")
  

proc pp_optimize(compiler: FESCompiler, asm_code: var seq[ASMAction]) =
  var pp_optimizer = newNESPPOptimizer()
  pp_optimizer.optimize(ppopt_src, asm_code)

proc do_optimizations(compiler: FESCompiler) =
  var graph = build_call_graph(compiler.parser.root)
  remove_unused_defs(compiler.parser.root, graph)


proc compile*(compiler: FESCompiler) =
  let time = cpuTime()
  compiler.report(reportCompilerVersion, compiler.name, compiler.version)
  compiler.report(reportBeginCompilation, compiler.file_path)
  var src = readFile(compiler.file_path)
  if compiler.load_core_words:
    compiler.parser.parse_string(core, "core")
    if compiler.load_library:
      compiler.parser.parse_additional_src(engine_lib, "engine_lib")
    compiler.parser.parse_additional_src(src, compiler.file_path)
  else:
    compiler.parser.parse_string(src, compiler.file_path)
    if compiler.load_library:
      compiler.parser.parse_additional_src(engine_lib, "engine_lib")


  compiler.do_passes()
  compiler.do_optimizations()
  #echo compiler.parser.root.str
  compiler.generator.gen(compiler.parser.root)
  compiler.do_asm_passes(compiler.generator.code)
  var asm_calls = compiler.generator.code
  if compiler.optimize:
    compiler.pp_optimize(asm_calls)
  var asm_str = aasm_to_string(asm_calls)
  compiler.generate_and_assemble(asm_calls, compiler.out_asm_folder.file_ending(".asm"))
  compiler.report(reportFinishedCompilation)
  compiler.report(reportCompilationTime, $(cpuTime() - time))
  var num_warnings = compiler.error_handler.num_warnings
  var num_errors = compiler.error_handler.num_errors
  compiler.report(reportWarningCount, $num_warnings)
  compiler.report(reportErrorCount, $num_errors)
  if compiler.run:
    discard  #compiler.run_in_emu()

proc compile_test_str*(compiler: FESCompiler, input_src: string) =
  var src = input_src
  if compiler.load_core_words:
    compiler.parser.parse_string(core, "core")
    if compiler.load_library:
      compiler.parser.parse_additional_src(engine_lib, "engine_lib")
    compiler.parser.parse_additional_src(src, compiler.file_path)
  else:
    compiler.parser.parse_string(src, compiler.file_path)
    if compiler.load_library:
      compiler.parser.parse_additional_src(engine_lib, "engine_lib")

  compiler.do_passes()
  compiler.do_optimizations()
  compiler.generator.gen(compiler.parser.root)
  compiler.do_asm_passes(compiler.generator.code)
  var asm_calls = compiler.generator.code
  if compiler.optimize:
    compiler.pp_optimize(asm_calls)
  var asm_str = aasm_to_string(asm_calls)
  compiler.generate_and_assemble(asm_calls, compiler.out_asm_folder.file_ending(".asm"))
  var num_warnings = compiler.error_handler.num_warnings
  var num_errors = compiler.error_handler.num_errors
  compiler.report(reportWarningCount, $num_warnings)
  compiler.report(reportErrorCount, $num_errors)
    








import 
  strutils, sequtils, tables, typetraits, macros, os,
  streams, osproc, types, optimizer, scanner, msgs, typeinfo, sequtils, parser, ast, sets, codegenerator, times


proc newFESCompiler*(): FESCompiler =
  result = FESCompiler()
  result.error_handler = newErrorHandler()
  result.parser = newParser(result.error_handler)
  result.generator = newCodeGenerator()


proc report(compiler: FESCompiler, msg: MsgKind, msg_args: varargs[string]) =
  var args: seq[string] = @[]
  for ar in msg_args:
    args.add(ar)
  compiler.error_handler.handle(msg, args)


proc newASMInfo(op_mode: OP_MODE, op_length: int, op_time: int): ASMInfo =
  return ASMInfo(mode: op_mode, len: op_length, time: op_time)

template asm_data(op_mode: OP_MODE, op_length: int, op_time: int): ASMInfo =
  ASMInfo(mode: op_mode, len: op_length,time: op_time)


var info_table = newTable[OPCODE, TableRef[OP_MODE, ASMInfo]]()

proc setup(info_table: TableRef[OPCODE, TableRef[OP_MODE, ASMInfo]], args: varargs[string, `$`]) =
  var opcode: OPCODE
  var mode: OP_MODE
  var op_len: int
  var op_time: int
  var read_all = false
  var i: int = 0
  while not(read_all):
    if (args[i]).isOPCODE:
      opcode = parseEnum[OPCODE] args[i]
      info_table[opcode] = newTable[OP_MODE, ASMInfo]()
      i = i + 1
    else:
      mode = parseEnum[OP_MODE] args[i]
      op_len = args[i+1].parseInt
      op_time = args[i+2].parseInt
      info_table[opcode].add(mode, newASMInfo(mode, op_len, op_time))
      i = i + 3
    if i >= args.len:
      read_all = true

info_table.setup(
  ADC,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  AND,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  ASL,
  Accumulator, 1, 2,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  BCC,
  Relative, 2, 2,
  BCS,
  Relative, 2, 2,
  BEQ,
  Relative, 2, 2,
  BIT,
  Zero_page, 2, 3,
  Absolute, 3, 4,
  BMI,
  Relative, 2, 2,
  BNE,
  Relative, 2, 2,
  BPL,
  Relative, 2, 2,
  BRK,
  Implied, 1, 7,
  BVC,
  Relative, 2, 2,
  BVS,
  Relative, 2, 2,
  CLC,
  Implied, 1, 2,
  CLD,
  Implied, 1, 2,
  CLI,
  Implied, 1, 2,
  CLV,
  Implied, 1, 2,
  CMP,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  CPX,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Absolute, 3, 4,
  CPY,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Absolute, 3, 4,
  DEC,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 3,
  Absolute_X, 3, 7,
  DEX,
  Implied, 1, 2,
  DEY,
  Implied, 1, 2,
  EOR,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  INC,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  INX,
  Implied, 1, 2,
  INY,
  Implied, 1, 2,
  JMP,
  Absolute, 3, 3,
  Indirect, 3, 5,
  JSR,
  Absolute, 3, 6,
  LDA,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  LDX,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_Y, 2, 4,
  Absolute, 3, 4,
  Absolute_Y, 3, 4,
  LDY,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  LSR,
  Accumulator, 1, 2,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  NOP,
  Implied, 1, 2,
  ORA,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  PHA,
  Implied, 1, 3,
  PHP,
  Implied, 1, 3,
  PLA,
  Implied, 1, 4,
  PLP, 
  Implied, 1, 4,
  ROL,
  Accumulator, 1, 2,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  ROR,
  Accumulator, 1, 2,
  Zero_Page, 2, 5,
  Zero_Page_X, 2, 6,
  Absolute, 3, 6,
  Absolute_X, 3, 7,
  RTI,
  Implied, 1, 6,
  RTS,
  Implied, 1, 6,
  SBC,
  Immediate, 2, 2,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 4,
  Absolute_Y, 3, 4,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 5,
  SEC,
  Implied, 1, 2,
  SED,
  Implied, 1, 2,
  SEI,
  Implied, 1, 2,
  STA,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  Absolute_X, 3, 5,
  Absolute_Y, 3, 5,
  Indirect_X, 2, 6,
  Indirect_Y, 2, 6,
  STX,
  Zero_Page, 2, 3,
  Zero_Page_Y, 2, 4,
  Absolute, 3, 4,
  STY,
  Zero_Page, 2, 3,
  Zero_Page_X, 2, 4,
  Absolute, 3, 4,
  TAX,
  Implied, 1, 2,
  TAY,
  Implied, 1, 2,
  TSX,
  Implied, 1, 2,
  TXS,
  Implied, 1, 2,
  TYA,
  Implied, 1, 2
)



method len*(asm_action: ASMAction): int {.base.} =
  echo "ASMAction len should not be called"
  return 0

method len*(asm_call: ASMCall): int = 
  return info_table[asm_call.op][asm_call.mode].len

method len*(asm_label: ASMLabel): int =
  return 0


proc time(asm_call: ASM_Call): int =
  return info_table[asm_call.op][asm_call.mode].time


proc op(name: OPCODE, param: string): ASMCall = 
  return ASMCall(op: name, str: $name, param: param)




proc partition[T](sequence: seq[T], pred: proc): tuple[selected: seq[T],rejected: seq[T]] =
  var selected: seq[T] = @[]
  var rejected: seq[T] = @[]
  for el in sequence:
    if el.pred:
      selected.add(el)
    else:
      rejected.add(el)
  return (selected, rejected)


proc group_word_defs_last*(root: SequenceNode) = 
  var partition = root.sequence.partition(is_def)
  root.sequence = partition.rejected & partition.selected


proc group_vars_first*(root: SequenceNode) =
  var partition = root.sequence.partition(is_var)
  root.sequence = partition.selected  & partition.rejected

proc add_start_label*(root: SequenceNode) =
  var asm_node = newASMNode()
  asm_node.add(ASMLabel(label_name: "Start:"))
  var tmp_seq: seq[ASTNode] = @[]
  tmp_seq.add(asm_node)
  root.sequence = tmp_seq & root.sequence




type
  ASTVisitor = ref object of RootObj


method visit(visitor: ASTVisitor, node: ASTNode) {.base.} =
  return

method accept(node: ASTNode, visitor: ASTVisitor) {.base.} =
  visitor.visit(node)

type
  CollectVisitor = ref object of ASTVisitor
    pred: proc(node: ASTNode): bool
    defs: seq[DefineWordNode]

proc newCollectVisitor(pred: proc(node:ASTNode): bool = nil): CollectVisitor =
  result = CollectVisitor(pred: pred)
  result.defs = @[]

method visit(collect_visitor: CollectVisitor, node: ASTNode)  =
  return

method visit(collect_visitor: CollectVisitor, node: DefineWordNode) =
  collect_visitor.defs.add(node)
  return

method visit(collect_visitor: CollectVisitor, node: SequenceNode)  =
  for n in node.sequence:
    n.accept(collect_visitor)
  

proc collect_defs(node: ASTNode): seq[DefineWordNode] =
  var visitor: CollectVisitor = newCollectVisitor(is_def)
  node.accept(visitor)
  return visitor.defs

proc count[T](t_seq: seq[T], t_el: T): int =
  result = 0
  for seq_el in t_seq:
    if seq_el == t_el:
      inc(result)

proc check_multiple_defs(compiler: FESCompiler, node: ASTNode) =
  var defs = collect_defs(cast[SequenceNode](node))
  var names: seq[string] = @[]
  for def in defs:
    names.add(def.word_name)
  var names_set = names.toSet
  if names.len != names_set.len:
    for set_name in names_set:
      if names.count(set_name) > 1:
        compiler.parser.report(node, errWordAlreadyDefined, set_name)



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
  group_word_defs_last(compiler.parser.root)
  compiler.parser.root.add_start_label()
  compiler.check_multiple_defs(compiler.parser.root)



const core = readFile("src/core/core.fth")
const ppopt_src = readFile("src/ppopt/peephole_6502.txt")
  

proc pp_optimize(compiler: FESCompiler, asm_code: var seq[ASMAction]) =
  var pp_optimizer = newNESPPOptimizer()
  pp_optimizer.optimize(ppopt_src, asm_code)


proc compile*(compiler: FESCompiler) =
  let time = cpuTime()
  compiler.report(reportCompilerVersion, compiler.name, compiler.version)
  compiler.report(reportBeginCompilation, compiler.file_path)
  var src = readFile(compiler.file_path)
  if compiler.load_core_words:
    compiler.parser.parse_string(core, "core")
    
  compiler.parser.parse_string(src, compiler.file_path)

  compiler.do_passes()
  compiler.generator.gen(compiler.parser.root)
  var asm_calls = compiler.generator.code
  if compiler.optimize:
    compiler.pp_optimize(asm_calls)
  var asm_str = aasm_to_string(asm_calls)
  if (compiler.out_asm_folder != nil):
    var out_name = compiler.out_asm_folder & extract_file_name(compiler.file_path).file_ending(".asm")
  else:
    var out_name = compiler.out_asm_folder & compiler.file_path.file_ending(".asm")
  compiler.generate_and_assemble(asm_calls, compiler.out_asm_folder & "test_asm.asm")
  compiler.report(reportFinishedCompilation)
  compiler.report(reportCompilationTime, $(cpuTime() - time))
  var num_warnings = compiler.error_handler.num_warnings
  var num_errors = compiler.error_handler.num_errors
  compiler.report(reportWarningCount, $num_warnings)
  compiler.report(reportErrorCount, $num_errors)
  if compiler.run:
    discard  #compiler.run_in_emu()
    








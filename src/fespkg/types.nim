import
  terminal, strutils, tables

type
  FESCompiler* = ref object of RootObj
    name*: string
    version*: string
    parser*: Parser
    generator*: CodeGenerator
    error_handler*: ErrorHandler
    pass_runner*: PassRunner
    out_asm_folder*: string
    out_passes_folder*: string
    show_asm_log*: bool
    optimize*: bool
    file_path*: string
    run*: bool
    load_core_words*: bool
    silent*: bool

  PassRunner* = ref object of RootObj
    error_handler*: ErrorHandler
    var_table*: TableRef[string, VariableNode]
    definitions*: TableRef[string, DefineWordNode]
    calls*: TableRef[string, CallWordNode]
    structs*: TableRef[string, StructNode]
    var_index*: int

  ASTVisitor* = ref object of RootObj

  CollectVisitor*[T] = ref object of ASTVisitor
    pred*: proc(node: ASTNode): bool
    collected*: seq[T]

  CodeGenerator* = ref object of RootObj
    current_ifelse*: int
    current_while*: int
    code*: seq[ASMAction]
    current_address*: int
    variables*: TableRef[string, VariableNode]

  ASTNode* = ref object of RootObj
    file_name*: string
    line_range*: LineRange
    column_range*: ColumnRange

  OtherNode* = ref object of ASTNode
    name*: string

  StructNode* = ref object of ASTNode
    name*: string
    members*: seq[string]
    address*: int

  VariableType* = enum
    Struct, List, Number

  VariableNode* = ref object of ASTNode
    name*: string
    address*: int
    size*: int # in bytes
    var_type*: VariableType
    type_node*: ASTNode

  LoadVariableNode* = ref object of ASTNode
    name*: string
    var_node*: VariableNode

  ConstantNode* = ref object of ASTNode
    name*: string
    value: int

  WhileNode* = ref object of ASTNode
    condition_block*: ASTNode
    then_block*: ASTNode

  IfElseNode* = ref object of ASTNode
    then_block*: ASTNode
    else_block*: ASTnode

  PushNumberNode* = ref object of ASTNode
    number*: int

  SequenceNode* = ref object of ASTNode
    sequence*: seq[ASTNode]

  DefineWordNode* = ref object of ASTNode
    word_name*: string
    definition*: SequenceNode
  
  CallWordNode* = ref object of ASTNode
    word_name*: string
    word_def*: DefineWordNode

  ASMNode* = ref object of ASTNode
    asm_calls*: seq[ASMAction]

  ASMAction* = ref object of RootObj

  ASMCall* = ref object of ASMAction
    str*: string
    op*: OPCODE
    param*: string
    mode*: OP_MODE

  ASMLabel* = ref object of ASMAction
    label_name*: string

  OPCODE* = enum
    ADC, AND, ASL, BIT, BPL, BMI, BVC, BVS, BCC, BCS, BNE, BEQ, BRK, CMP, CPX, CPY,
    DEC, EOR,
    CLC, SEC, CLI, SEI, CLV, CLD, SED,
    INC, JMP, JSR,
    LDA, LDX, LDY,
    LSR, NOP, ORA,
    TAX, TXA, DEX, INX, TAY, TYA, DEY, INY,
    ROL, ROR, RTI, RTS, SBC, STA,
    TXS, TSX, PHA, PLA, PHP, PLP,
    STX, STY, INVALID_OPCODE
  
  OP_MODE* = enum
    Immediate, Zero_Page, Zero_Page_X, Zero_Page_Y Absolute, Absolute_X, Absolute_Y, Indirect, Indirect_X, Indirect_Y, Accumulator, Relative, Implied

  ASMInfo* = ref object of ASTNode
    mode*: OP_MODE
    len*: int
    time*: int
   
  Scanner* = ref object of RootObj
    src_index*: int
    sources*: seq[string]
    source_names*: seq[string]
    src_name*: string
    src*: string
    lines*: seq[string]
    columns*: seq[string]
    line*: int
    column*: int
    column_accurate*: int

  Parser* = ref object of RootObj
    root*: SequenceNode
    scanner*: Scanner
    error_handler*: ErrorHandler
    var_table*: TableRef[string, VariableNode]
    var_index*: int
    definitions*: TableRef[string, DefineWordNode]
    calls*: TableRef[string, CallWordNode]
    structs*: TableRef[string, StructNode]

  LineInfo* = ref object of RootObj
    line*: int
    column*: int
    file_name*: string
    line_str*: string
  
  CustomRange* = ref object of RootObj
    low*: int
    high*: int
  ColumnRange* = ref object of CustomRange
  LineRange* = ref object of CustomRange

  ErrorIndication* = ref object of RootObj
    line*: int
    column_range*: ColumnRange
    msg*: string
    args*: seq[string]

  FError* = ref object of RootObj
    file_name*: string
    start_line*: int
    start_column*: int
    msg*: MsgKind
    msg_args*: seq[string]
    line_range*: LineRange
    indications*: seq[ErrorIndication]

  ErrorHandler* = ref object of RootObj
    errors*: seq[FError]
    warnings*: seq[MSGKind]
    silent*: bool
    scanner*: Scanner

  MsgKind* = enum
    BEGIN_ERRORS
    errWordAlreadyDefined = "word \'$1\' already exists"
    errMissingWordEnding = "word \'$1\' has no definition ending \";\""
    errNestedWordDef = "word \'$1\' has another definition inside it"
    errInvalidDefinitionWordName = "wordname \'$1\' in definition is not a valid name"
    errInvalidCallWordName = "wordname \'$1\' for a call not a valid name"
    errMissingWordDefName = "word definition has no name"
    errMissingASMEnding = "asm block has no ending"
    errTooManyASMOperands = "asm statement \'$\' has too many operands: \'$\'"
    errInvalidASMInstruction = "asm instruction \'$1\' is not valid"
    errMissingIfElseEnding = "\'if\' statement has no corresponding \'then\' to close it"
    errASMSourceError = "the generated source file doesn't conform to the expected nes assembly format:\n\n$1"
    errAssemblyError = "error: $1, $2"
    errInvalidVariableName = "name \'$1\' is not a valid variable name"
    errMissingVariableName = "variable name is missing"
    errTooManyVariablesDefined = "the maximum number of variables which can be used is the address range from $0000 to $0200\nwhich are 512 variables" 
    errWordCallWithoutDefinition = "the word \'$1\' has no corresponding definition!"
    errMissingStructEnding = "struct \'$1\' has no ending \'}\'"
    errMissingStructName = "struct is missing a name"
    errMalformedStruct = "struct is malformed"

    errTestError = "Error in test \'$1\' occured"
    END_ERRORS

    BEGIN_WARNINGS
    warnMissingWordDefBody = "word definition \'$1\' has no body" 
    warnMissingASMBody = "asm block has no body"
    warnMissingThenBody = "\'if\' statement has no \'then\' body"
    warnMissingElseBody = "\'if\' statement has no \'else\' body"
    warnMissingWhileConditionBody = "\'while\' statement has no condition body"
    warnMissingWhileThenBody = "\'while\' statement has no then body"
    warnMissingStructBody = "struct $1 has no body"
    END_WARNINGS

    BEGIN_HINTS
    END_HINTS

    BEGIN_RESULTS
    reportGeneratedASMFile = "file: \'$1\' has been generated"
    reportCompilerVersion = "Compiler: $1 Version: $2"
    reportBeginCompilation = "Compile file: \'$1\'"
    reportFinishedCompilation = "Finished compilation"
    reportCompilationTime = "compiled in $1 seconds"
    reportWarningCount = "warnings: $1"
    reportErrorCount = "errors: $1"
    END_RESULTS

proc with_arg*(call: ASMCall): bool =
  return call.param != nil

proc to_LineRange*(slice: HSlice): LineRange =
  return LineRange(low: slice.a, high: slice.b)
proc to_ColumnRange*(slice: HSlice): ColumnRange =
  return ColumnRange(low: slice.a, high: slice.b)

proc `$`*(r: CustomRange): string =
  result = "(" & $r.low & ".." & $r.high & ")"

proc clamp*(custom_range: CustomRange, min: int, max: int) =
  if custom_range.low < min:
    custom_range.low = min
  if custom_range.high > max:
    custom_range.high = max

proc clamp_min*(custom_range: CustomRange, min: int) =
  custom_range.clamp(min, high(int))
proc clamp_max*(custom_range: CustomRange, max: int) =
  custom_range.clamp(low(int), max)

proc shift_to*(custom_range: CustomRange, middle: int) =
  custom_range.low += middle
  custom_range.high += middle

proc isOPCODE*(str: string): bool =
  try:
    discard parseEnum[OPCODE] str
  except ValueError:
     return false
  return true

proc isOP_MODE*(str: string): bool =
  try:
    discard parseEnum[OP_MODE] str
  except ValueError:
     return false
  return true



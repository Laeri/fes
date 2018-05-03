import
  terminal, strutils

type
  FESCompiler* = ref object of RootObj
    parser*: Parser
    error_handler*: ErrorHandler
    out_asm_folder*: string
    out_passes_folder*: string
    optimize*: bool
    file_path*: string
    run*: bool
    load_core_words*: bool
    silent*: bool
  ASTNode* = ref object of RootObj

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

  LineInfo* = tuple[line: int, column: int, line_str: string, file_name: string]

  ErrorInfo* = ref object of RootObj
    msg*: MsgKind
    msg_args*: seq[string]
    line_info*: LineInfo
  ErrorHandler* = ref object of RootObj
    errors*: seq[ErrorInfo]
    silent*: bool
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
    END_ERRORS

    BEGIN_WARNINGS
    warnMissingWordDefBody = "word definition \'$1\' has no body" 
    warnMissingASMBody = "asm block has no body"
    warnMissingThenBody = "\'if\' statement has no \'then\' body"
    warnMissingElseBody = "\'if\' statement has no \'else\' body"
    END_WARNINGS

    BEGIN_HINTS
    END_HINTS

    BEGIN_RESULTS
    END_RESULTS

proc with_arg*(call: ASMCall): bool =
  return call.param != nil


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



import
  types, compiler, strutils, typetraits, tables


type
  NESPParser* = ref object of RootObj
    scanner: Scanner
  NESPPRule* = ref object of RootObj
    name: string
    id: int
    descr: string
    r_from: seq[ASMMatcher]
    r_to: seq[ASMMatcher]
    matched: bool
    index_from: int
    index_to: int
    symbols: TableRef[string, string]
  NESPPOptimizer* = ref object of RootObj
    rules: seq[NESPPRule]
  ASMMatcher = ref object of RootObj
  ASMCallMatcher = ref object of ASMMatcher
    op: OPCODE
    symbol: ASMSymbol
    with_arg: bool
  ASMLabelMatcher = ref object of ASMMatcher
    label_symbol: ASMSymbol
  ASMSymbol = ref object of RootObj  
    value: string
  MatchAnySymbol = ref object of ASMSymbol
  MatchAndBindSymbol = ref object of ASMSymbol
    bound: string
  ConcreteSymbol = ref object of ASMSymbol
    literal_value: string

method `$`(rule: NESPPRule): string =
  result = "NESPPRule:\n"
  result &= "  from:\n"
  for act in rule.r_from:
    result &= "    " & act.repr & "\n"
  result &= "  to:\n"
  for act in rule.r_to:
    result &= "    " & act.repr & "\n"
  return result

proc bind_symbol(symbol: MatchAndBindSymbol, token: string) = 
  symbol.bound = token
proc is_bound(symbol: MatchAndBindSymbol): bool =
  return symbol.bound != nil

method `$`(matcher: ASMSymbol): string =
  return "ASMSymbol" 
method `$`(matcher: MatchAnySymbol): string =
  return "ASMMatchAnySymbol: _*"
method `$`(matcher: MatchAndBindSymbol): string =
  if matcher.is_bound:
    return "MatchAndBindSymbol: " & matcher.bound 
  else:
    return "MatchAndBindSymbol: unbound"
method `$`(matcher: ConcreteSymbol): string =
  return "ConcreteSymbol: " & matcher.literal_value 
method `$`(matcher: ASMMatcher): string = 
  return "ASMMatcher"
method `$`(matcher: ASMCallMatcher): string =
  if matcher.with_arg:
    return "ASMCallMatcher: " & $matcher.op & ", " & $matcher.symbol
  else:
    return "ASMCallMatcher: " & $matcher.op 
method `$`(matcher: ASMLabelMatcher): string =
  return "ASMLabelMatcher: " & $matcher.label_symbol 


method match(symbol: ASMSymbol, token: string): bool =
  echo "this should never be called"

method match(symbol: MatchAnySymbol, token: string): bool =
  return true

method match(symbol: MatchAndBindSymbol, token: string): bool =
  if symbol.bound != nil:
    return symbol.bound == token
  else:
    symbol.bound = token
    return true

method match(symbol: ConcreteSymbol, token: string): bool =
  return symbol.literal_value == token

method match(matcher: ASMMatcher, asm_code: ASMAction): bool = 
  echo "this should never be called"
  return false

method match(matcher: ASMLabelMatcher, asm_code: ASMLabel): bool =
  return matcher.label_symbol.match(asm_code.label_name)
  
method match(matcher: ASMCallMatcher, asm_code: ASMCall): bool =
  if matcher.op != asm_code.op:
    return false
  if matcher.with_arg and asm_code.with_arg:
    return matcher.symbol.match(asm_code.param)
  elif not(matcher.with_arg) and not(asm_code.with_arg):
    return true
  else:
    return false



proc newNESPParser(): NESPParser =
  result = NESPParser()
  result.scanner = Scanner()

proc newNESPPRule(): NESPPRule =
  result = NESPPRule()
  result.r_from = @[]
  result.r_to = @[]
  result.symbols = newTable[string, string]()

proc newNESPPOptimizer*(): NESPPOptimizer =
  return NESPPOptimizer()




proc parse_matcher_symbol(token: string, symbol_table: TableRef[string, ASMSymbol]): ASMSymbol = 
  if token.startsWith("_"):
    if token.contains("*"):
      return MatchAnySymbol()
    else:
      if symbol_table.contains(token):
        return symbol_table[token]
      else:
        var symbol = MatchAndBindSymbol()
        symbol_table[token] = symbol
        return symbol
  else:
    return ConcreteSymbol(literal_value: token)

proc parse_asm_line_to_matcher(tokens: seq[string], symbol_table: TableRef[string, ASMSymbol]): ASMMatcher =
  if tokens.len == 1:
      if tokens[0].contains(":"):
        return ASMLabelMatcher(label_symbol: parse_matcher_symbol(tokens[0], symbol_table))
      else:
        return ASMCallMatcher(op: parseEnum[OPCODE] tokens[0], with_arg: false)
  elif tokens.len == 2:
    var arg_string = tokens[1]
    return ASMCallMatcher(op: parseEnum[OPCODE] tokens[0], symbol: parse_matcher_symbol(arg_string, symbol_table), with_arg: true)

proc parse_rules(parser: NESPParser, src: string): seq[NESPPRule] =
  var scanner = parser.scanner
  scanner.read_string(src)
  var token: string
  var rules: seq[NESPPRule] = @[]
  var rule = newNESPPRule()
  var in_second_part = false
  var in_rule_def = false
  var in_description = false
  var descr = ""
  var symbol_table: TableRef[string, ASMSymbol] = newTable[string, ASMSymbol]()
  while scanner.has_next:
    if in_rule_def:
      var line = scanner.up_to_next_line()
      var matcher: ASMMatcher
      if line[0].contains("-"):
        rules.add(rule)
        in_rule_def = false
        in_second_part = false
        rule = newNESPPRule()
      elif line[0].contains("="):
        in_second_part = true
      else:
       matcher = parse_asm_line_to_matcher(line, symbol_table)
       if in_second_part:
         rule.r_to.add(matcher)
       else:
         rule.r_from.add(matcher)
    else:
      token = scanner.next
      if token == "Name:":
        rule.name = scanner.next
      elif token == "ID:":
        rule.id = scanner.next.parseInt
      elif token == "Descr:":
        in_description = true
      elif in_description:
        while in_description:
          var line = scanner.up_to_next_line()
          if line[0].contains("-"):
            in_description = false
            in_rule_def = true
      else:
        echo "tokens between definition: ", token
  return rules

method match_type(act: ASMAction, other: ASMAction): bool =
  return false

method match_type(label: ASMLabel, other: ASMLabel): bool =
  return (label.label_name == other.label_name)

method match_type(call: ASMCall, other: ASMCall): bool =
  return call.op == other.op


proc match(rule: NESPPRule, asm_code: seq[ASMAction]): bool =
  var window = rule.r_from.len
  var current: ASMAction
  var r_index = 0
  var r_asm: ASMMatcher = rule.r_from[r_index]
  var symbols = rule.symbols
  symbols.clear
  for asm_index in countup(0, asm_code.len - 1):
    current = asm_code[asm_index]
    echo $r_asm
    if r_asm.match(current):
        echo "a match with: " & $current.repr
        r_index += 1
        if r_index == rule.r_from.len:
          return true
        r_asm = rule.r_from[r_index]
    else:
      echo "no match with: " & $current.repr
      return false


proc apply(rule: NESPPrule, asm_code: var seq[ASMAction]) =
  echo "apply"

method optimize*(optimizer: NESPPOptimizer, rule_file_name: string, asm_code: var seq[ASMAction]) = 
  var parser = newNESPParser()
  var rules_src: string = readFile(rule_file_name)
  var rules = parser.parse_rules(rules_src)
  var any_matched = true
  while any_matched:
    any_matched = false
    for rule in rules:
      var match = rule.match(asm_code)
      echo match
      if match:
        any_matched = true
        rule.apply(asm_code)
      

import
  types, compiler, strutils, typetraits, tables


type
  NESPParser = ref object of RootObj
    scanner: Scanner
  NESPPRule = ref object of RootObj
    name: string
    id: int
    descr: string
    r_from: seq[ASMAction]
    r_to: seq[ASMAction]
    matched: bool
    index_from: int
    index_to: int
    symbols: TableRef[string, string]
  NESPPOptimizer = ref object of RootObj
    rules: seq[NESPPRule]



proc newNESPParser(): NESPParser =
  result = NESPParser()
  result.scanner = Scanner()

proc newNESPPRule(): NESPPRule =
  result = NESPPRule()
  result.r_from = @[]
  result.r_to = @[]
  result.symbols = newTable[string, string]()

method `$`(rule: NESPPRule): string =
  result = "NESPPRule:\n"
  result &= "  from:\n"
  for act in rule.r_from:
    result &= "    " & act.repr & "\n"
  result &= "  to:\n"
  for act in rule.r_to:
    result &= "    " & act.repr & "\n"
  return result

proc parse_rules(parser: NESPParser, src: string): seq[NESPPRule] =
  let scanner = parser.scanner
  scanner.read_string(src)
  var token: string
  var rules: seq[NESPPRule] = @[]
  var rule = newNESPPRule()
  var in_second_part = false
  var in_rule_def = false
  var in_description = false
  var descr = ""
  while scanner.has_next:
    if in_rule_def:
      var line = scanner.up_to_next_line()
      var asm_code: ASMAction
      if line[0].contains("-"):
        rules.add(rule)
        in_rule_def = false
        in_second_part = false
      elif line[0].contains("="):
        in_second_part = true
      else:
       asm_code = parse_asm_line(line)
       if in_second_part:
         rule.r_to.add(asm_code)
       else:
         rule.r_from.add(asm_code)
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

proc match(rule: NESPPRule, asm_code: seq[ASMAction]): bool =
  echo "NOTHING"

proc apply(rule: NESPPrule, asm_code: var seq[ASMAction]) =
  echo "apply"

proc optimize(optimizer: NESPPOptimizer, rule_file_name: string, asm_code: var seq[ASMAction]) = 
  var parser = newNESPParser()
  var rules_src: string = readFile(rule_file_name)
  var rules = parser.parse_rules(rules_src)
  var any_matched: bool
  while any_matched:
    any_matched = false
    for rule in rules:
      var match = rule.match(asm_code)
      if match:
        any_matched = true
        rule.apply(asm_code)
      

var test_rules = """
Name: Optimize_JMP_Before_RTS
ID: 1
Descr:
If we JSR to another subroutine last in a given subroutine we 
can jump directly
----------------
JSR _b_
RTS
================
JMP _b_
---------------

Name: Test_Syntax
ID: 2
Descr:
ADC _mem_
_st_1_
_st_2_
----------------


================


----------------
"""

var parser = newNESPParser()
var rules = parser.parse_rules(test_rules)
  
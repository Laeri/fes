import
  random, sets, unittest, strutils, sequtils, scanner, types

proc to_string(char_set: set[char]): string =
  var char_seq = toSeq(char_set.items)
  result = newStringOfCap(len(char_seq))
  for ch in char_seq:
    add(result, ch)

proc to_string(char_seq: seq[char]): string =
  result = newStringOfCap(len(char_seq))
  for ch in char_seq:
    add(result, ch)

suite "Scanner Suite":

  setup:
    var scanner = Scanner()

  teardown:
    discard
  
  test "has_next should return tokens for all letters and digits separated by whitespace":
    var sequence = (Letters + Digits).to_string
    var space_separated_sequence = sequence.insertSep(' ', 1)
    var str_seq = space_separated_sequence.splitWhitespace
    scanner.read_string(space_separated_sequence)
    var i = 0
    while (scanner.has_next):
      var token = scanner.next
      check(token.str_val == str_seq[i])
      i += 1

  test "has_next should return false for trailing newline":
    scanner.read_string("A\n")
    check(scanner.has_next == true)
    discard scanner.next
    check(scanner.has_next == false)

  test "has_next should return false for empty string":
    scanner.read_string("")
    check(scanner.has_next == false)

  test "has_next should return false for only whitespace characters":
    scanner.read_string(Whitespace.to_string)
    check(scanner.has_next == false)

  test "has_next should return false for only newline characters":
    scanner.read_string(NewLines.to_string)
    check(scanner.has_next == false)

  test "has_next should return false for only whitespace AND newlines randomized":
    var src: seq[char] = toSeq((Whitespace + NewLines).items)
    src.shuffle
    scanner.read_string(src.to_string)
    check(scanner.has_next == false)

  test "has_next should return true for one character string":
    scanner.read_string("A")
    check(scanner.has_next == true)

  test "peek should not advance scanner":
    scanner.read_string("A")
    check(scanner.peek.str_val == "A")
    check(scanner.peek.str_val == "A")
    check(scanner.has_next == true)

  test "backtrack by one inside column":
    scanner.read_string("A B")
    discard scanner.next()
    scanner.backtrack(1)
    check(scanner.next().str_val == "A")
 
  test "backtrack over newlines":
    scanner.read_string("A\nB")
    discard scanner.next()
    scanner.backtrack(1)
    check(scanner.next().str_val == "A")

  test "backtrack over several newlines":
    scanner.read_string("A\n\n\n\nB")
    discard scanner.next()
    scanner.backtrack(1)
    check(scanner.next().str_val == "A")

  test "backtrack over several newlines and whitespace":
    scanner.read_string("A\n    \n     \n    B")
    discard scanner.next()
    scanner.backtrack(1)
    check(scanner.next().str_val == "A")

  test "get position of a single token":
    scanner.read_string("A")
    check(scanner.column_position == 0)

  test "get position of several tokens in a line":
    scanner.read_string("A B  CDEF G")
    check(scanner.column_position == 0)
    discard scanner.next
    check(scanner.column_position == 2)
    discard scanner.next
    check(scanner.column_position == 5)
    discard scanner.next
    check(scanner.column_position == 10)
    discard scanner.next

  test "get position of several equal tokens in a line":
    scanner.read_string("A A A A")
    discard scanner.next()
    check(scanner.column_position == 2)
    discard scanner.next()
    check(scanner.column_position == 4)
    discard scanner.next()
    check(scanner.column_position == 6)
    
  test "get line number":
    scanner.read_string("A\n  \nBC")
    check(scanner.line_position == 0)
    discard scanner.next
    check(scanner.line_position == 2)

  test "accurate column position of string at start":
    scanner.read_string("if")
    check(scanner.column_position == 0)
  
  test "accurate column position of string after whitespace":
    scanner.read_string(" if")
    check(scanner.column_position == 1)
    scanner.read_string("  if")
    check(scanner.column_position == 2)

  test "current word range of \'if\'":
    scanner.read_string("if")
    check(scanner.current_word_range.low == 0)
    check(scanner.current_word_range.high == 1)

  test "current word range of \'  if\'":
    scanner.read_string("  if")
    check(scanner.current_word_range.low == 2)
    check(scanner.current_word_range.high == 3)
    

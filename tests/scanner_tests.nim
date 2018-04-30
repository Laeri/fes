import
  ../src/scanner, unittest, strutils, sequtils, ../src/types, random, sets

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
      check(token == str_seq[i])
      i += 1
  
  test "has_next should handle trailing newline":
    scanner.read_string("A\n")
    while scanner.has_next:
      echo scanner.next

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
    check(scanner.peek == "A")
    check(scanner.peek == "A")
    check(scanner.has_next == true)

  test "backtrack by one inside column":
    scanner.read_string("A B")
    discard scanner.next()
    scanner.backtrack(1)
    check(scanner.next() == "A")
 
  test "backtrack over newlines":
    scanner.read_string("A\nB")
    discard scanner.next()
    scanner.backtrack(1)
    check(scanner.next() == "A")

  test "backtrack over several newlines":
    scanner.read_string("A\n\n\n\nB")
    discard scanner.next()
    scanner.backtrack(1)
    check(scanner.next() == "A")

  test "backtrack over several newlines and whitespace":
    scanner.read_string("A\n    \n     \n    B")
    discard scanner.next()
    scanner.backtrack(1)
    check(scanner.next() == "A")

  
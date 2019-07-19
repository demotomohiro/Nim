discard """
action: "run"
output: '''Received (name: "Foo", species: "Bar")'''
"""

# issue #7632

import genericstrformat
import macros

doAssert works(5) == "formatted  5"
doAssert fails0(6) == "formatted  6"
doAssert fails(7) == "formatted  7"
doAssert fails2[0](8) == "formatted  8"

# other tests

import strformat

type Obj = object

proc `$`(o: Obj): string = "foobar"

# for custom types, formatValue needs to be overloaded.
template formatValue(result: var string; value: Obj; specifier: string) =
  result.formatValue($value, specifier)

var o: Obj
doAssert fmt"{o}" == "foobar"
doAssert fmt"{o:10}" == "foobar    "

# see issue #7933
var str = "abc"
doAssert fmt">7.1 :: {str:>7.1}" == ">7.1 ::       a"
doAssert fmt">7.2 :: {str:>7.2}" == ">7.2 ::      ab"
doAssert fmt">7.3 :: {str:>7.3}" == ">7.3 ::     abc"
doAssert fmt">7.9 :: {str:>7.9}" == ">7.9 ::     abc"
doAssert fmt">7.0 :: {str:>7.0}" == ">7.0 ::        "
doAssert fmt" 7.1 :: {str:7.1}" == " 7.1 :: a      "
doAssert fmt" 7.2 :: {str:7.2}" == " 7.2 :: ab     "
doAssert fmt" 7.3 :: {str:7.3}" == " 7.3 :: abc    "
doAssert fmt" 7.9 :: {str:7.9}" == " 7.9 :: abc    "
doAssert fmt" 7.0 :: {str:7.0}" == " 7.0 ::        "
doAssert fmt"^7.1 :: {str:^7.1}" == "^7.1 ::    a   "
doAssert fmt"^7.2 :: {str:^7.2}" == "^7.2 ::   ab   "
doAssert fmt"^7.3 :: {str:^7.3}" == "^7.3 ::   abc  "
doAssert fmt"^7.9 :: {str:^7.9}" == "^7.9 ::   abc  "
doAssert fmt"^7.0 :: {str:^7.0}" == "^7.0 ::        "
str = "äöüe\u0309\u0319o\u0307\u0359"
doAssert fmt"^7.1 :: {str:^7.1}" == "^7.1 ::    ä   "
doAssert fmt"^7.2 :: {str:^7.2}" == "^7.2 ::   äö   "
doAssert fmt"^7.3 :: {str:^7.3}" == "^7.3 ::   äöü  "
doAssert fmt"^7.0 :: {str:^7.0}" == "^7.0 ::        "
# this is actually wrong, but the unicode module has no support for graphemes
doAssert fmt"^7.4 :: {str:^7.4}" == "^7.4 ::  äöüe  "
doAssert fmt"^7.9 :: {str:^7.9}" == "^7.9 :: äöüe\u0309\u0319o\u0307\u0359"

# see issue #7932
doAssert fmt"{15:08}" == "00000015" # int, works
doAssert fmt"{1.5:08}" == "000001.5" # float, works
doAssert fmt"{1.5:0>8}" == "000001.5" # workaround using fill char works for positive floats
doAssert fmt"{-1.5:0>8}" == "0000-1.5" # even that does not work for negative floats
doAssert fmt"{-1.5:08}" == "-00001.5" # works
doAssert fmt"{1.5:+08}" == "+00001.5" # works
doAssert fmt"{1.5: 08}" == " 00001.5" # works

# only add explicitly requested sign if value != -0.0 (neg zero)
doAssert fmt"{-0.0:g}" == "-0"
doassert fmt"{-0.0:+g}" == "-0"
doassert fmt"{-0.0: g}" == "-0"
doAssert fmt"{0.0:g}" == "0"
doAssert fmt"{0.0:+g}" == "+0"
doAssert fmt"{0.0: g}" == " 0"

# seq format

let data1 = [1'i64, 10000'i64, 10000000'i64]
let data2 = [10000000'i64, 100'i64, 1'i64]

proc formatValue(result: var string; value: (array|seq|openArray); specifier: string) =
  result.add "["
  for i, it in value:
    if i != 0:
      result.add ", "
    result.formatValue(it, specifier)
  result.add "]"

doAssert fmt"data1: {data1:8} #" == "data1: [       1,    10000, 10000000] #"
doAssert fmt"data2: {data2:8} =" == "data2: [10000000,      100,        1] ="

# custom format Value

type
  Vec2[T] = object
    x,y: T

proc formatValue[T](result: var string; value: Vec2[T]; specifier: string) =
  result.add '['
  result.formatValue value.x, specifier
  result.add ", "
  result.formatValue value.y, specifier
  result.add "]"

let v1 = Vec2[float32](x:1.0, y: 2.0)
let v2 = Vec2[int32](x:1, y: 1337)
doAssert fmt"v1: {v1:+08}  v2: {v2:>4}" == "v1: [+0000001, +0000002]  v2: [   1, 1337]"

# bug #11012

type
  Animal = object
    name, species: string
  AnimalRef = ref Animal

proc print_object(animalAddr: AnimalRef) =
  echo fmt"Received {animalAddr[]}"

print_object(AnimalRef(name: "Foo", species: "Bar"))

# bug #11723

let pos: Positive = 64
doAssert fmt"{pos:3}" == " 64"
doAssert fmt"{pos:3b}" == "1000000"
doAssert fmt"{pos:3d}" == " 64"
doAssert fmt"{pos:3o}" == "100"
doAssert fmt"{pos:3x}" == " 40"
doAssert fmt"{pos:3X}" == " 40"

let nat: Natural = 64
doAssert fmt"{nat:3}" == " 64"
doAssert fmt"{nat:3b}" == "1000000"
doAssert fmt"{nat:3d}" == " 64"
doAssert fmt"{nat:3o}" == "100"
doAssert fmt"{nat:3x}" == " 40"
doAssert fmt"{nat:3X}" == " 40"

block:
  proc testFmt(openStr, closeStr: static string) =
    macro doAssertFmt(pattern, value, openStr, closeStr: string) =
      newCall(
              "doAssert",
              newTree(
                      nnkInfix,
                      newIdentNode("=="),
                      newCall("fmt", pattern.strVal.newLit, openStr, closeStr),
                      value.strVal.newLit))

    template doAssertFmt1(pattern, value: string) =
      doAssertFmt(pattern, value, openStr, closeStr)

    template rep2(s: string): string = s & s
    template rep3(s: string): string = s & s & s
    template rep4(s: string): string = s & s & s & s

    #Test escaping
    doAssertFmt1 openStr.rep2, openStr
    doAssertFmt1 closeStr.rep2, closeStr
    doAssertFmt1 openStr.rep2 & " ", openStr & " "
    doAssertFmt1 closeStr.rep2 & " ", closeStr & " "
    doAssertFmt1 " " & openStr.rep2, " " & openStr
    doAssertFmt1 " " & closeStr.rep2, " " & closeStr
    doAssertFmt1 " " & openStr.rep2 & " ", " " & openStr & " "
    doAssertFmt1 " " & closeStr.rep2 & " ", " " & closeStr & " "
    doAssertFmt1 openStr.rep4, openStr.rep2
    doAssertFmt1 closeStr.rep4, closeStr.rep2
    doAssertFmt1 openStr.rep2 & " " & openStr.rep2, openStr & " " & openStr
    doAssertFmt1 closeStr.rep2 & " " & closeStr.rep2, closeStr & " " & closeStr
    doAssertFmt1 openStr.rep2 & closeStr.rep2, openStr & closeStr
    doAssertFmt1 closeStr.rep2 & openStr.rep2, closeStr & openStr

    let
      testInt = 123
      testStr = "foobar"
      testFlt = 3.141592

    doAssertFmt1 openStr & "testInt" & closeStr, "123"
    doAssertFmt1 openStr & "testFlt:1.2f" & closeStr, "3.14"
    doAssertFmt1 "testInt" & openStr & "testInt" & closeStr, "testInt123"
    doAssertFmt1 openStr & "testInt" & closeStr & openStr & "testStr" & closeStr, "123foobar"
    doAssertFmt1 openStr & "testInt" & closeStr & "{}" & openStr & "testStr" & closeStr, "123{}foobar"
    doAssertFmt1 openStr & "testInt" & closeStr & openStr.rep3 & "testStr" & closeStr, "123" & openStr & "foobar"
    doAssertFmt1 openStr & "testInt" & closeStr.rep3 & openStr & "testStr" & closeStr, "123" & closeStr & "foobar"
    doAssertFmt1 "α" & openStr.rep3 & "testInt" & closeStr.rep3 & "α" , "α" & openStr & "123" & closeStr & "α"
    doAssertFmt1 closeStr.rep2 & openStr & "testStr" & closeStr & openStr.rep2, closeStr & "foobar" & openStr
    doAssertFmt1 "{" & openStr.rep3 & "123 + 321" & closeStr.rep3 & "} {" &
                 closeStr.rep2 & openStr & "3 in {2..7}" & closeStr & openStr.rep2 & "}",
                 "{" & openstr & "444" & closeStr & "} {" & closeStr & "true" & openStr & "}"

  macro testFmtEachStr(): untyped =
    # "<".len == 1
    # "β".len == 2
    # "Д".len == 2
    # "【".len == 3
    # "♪".len == 3
    # "🐵".len == 4
    # "😀".len == 4
    const testOpenCloseStrs = ["<", ">>", "β", "Д", "【", "】】", "♪", "🐵", "😀"]

    result = newStmtList()
    for i in testOpenCloseStrs:
      for j in testOpenCloseStrs:
        result.add newCall("testFmt", i.newLit, j.newLit)

  testFmtEachStr()

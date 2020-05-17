import options
import strutils


  
type
  Style* = ref object
    fontsize*: Option[int]
    textcolor*: Option[string]
          
proc `or`[T](self: Option[T], other: Option[T]): Option[T] =
  if self.isNone:
    return other
  return self

proc `or`*(x: Style, y: Style): Style =
    result = Style()
    # copy
    for name, v, r in fieldPairs(x[], result[]):
      r = r or v
    # fill      
    for name, v, r in fieldPairs(y[], result[]):
      r = r or v
    return result
    
proc `$`*(x: Style): string =
  var l = newSeq[string](0)
  for name, v in fieldPairs(x[]):
    if not v.isNone:
      l.add(name & ": " & $v)
  return "Style("&l.join(", ")&")" 

let EMPTY_STYLE* = Style()
let DEFAULT_STYLE* = Style(fontsize: option(12), textcolor: option("black"))


when isMainModule:
  import unittest  
  suite "testing styles.nim":

    test "constructor":
      var c: Style
      check(c.isNil)

    test "default values":
      var d = Style()
      check(d.fontsize.isNone)

    let a = Style(fontsize: option(12))      
    test "comparison":
      check(a[] == Style(fontsize: option(12))[])

    test "as string":
      check($a == "Style(fontsize: Some(12))")
      
    test "updating styles":
      let b = Style(textcolor: option("red"))
      let c = Style(textcolor: option("black"))
      check((b or c)[] == Style(textcolor: option("red"))[])


     
      


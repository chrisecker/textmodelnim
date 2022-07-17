import options
import strutils
import hashes
import tables


  
type
  Style* = ref object
    fontsize*: Option[int]
    textcolor*: Option[string]


proc hash(x: Style): Hash = 
  var empty = true
  for key, value in fieldPairs(x[]):
    if value.isSome:
      if empty:
        result = value.get().hash
        empty = false
      else:
        result = result !& value.get().hash
      result = !$result

      
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


# Hash tables compare objects using `==` which by default compares the
# pointer addresses. Since we want a comparison by values, we need to
# redefine the equality operator. 
proc `==`*(x: Style, y: Style): bool = 
  for c, d in fields(x[], y[]):
    if not (c==d): return false
  return true
  

var
  pool = initTable[Style, Style]()

  
proc pooled*(style: Style): Style =
  if style in pool:
    return pool[style]
  pool[style] = style
  return style

  
let EMPTY_STYLE* = pooled(Style())
let DEFAULT_STYLE* = pooled(Style(fontsize: option(12), textcolor: option("black")))


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

    test "style equality":
      let b = Style(textcolor: option("red"))
      let c = Style(textcolor: option("red"))
      let d = Style(textcolor: option("black"))
      check(b==c)
      check(b!=d)

    test "pooling styles":
      let b = pooled(Style(textcolor: option("red")))
      let c = pooled(Style(textcolor: option("red")))
      let d = pooled(Style(textcolor: option("black")))        
      check(b[].unsafeAddr == c[].unsafeAddr)      
      check(b[].unsafeAddr!=d[].unsafeAddr)


     
      


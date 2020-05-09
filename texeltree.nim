import styles
import options
import strutils

  
const
  NMAX = 15

type Texel* = ref object of RootObj
type Single* = ref object of Texel
  style*: Style
  text*: string # XXX Sollte immutable sein!
type Text* = ref object of Texel
  style*: Style
  text*: string # XXX Sollte immutable sein!
type TexelWithChilds = ref object of Texel
  childs: seq[Texel]
  length: int
  lineno: int
type Container = ref object of TexelWithChilds
type Group* = ref object of TexelWithChilds
  depth: int
type NewLine* = ref object of Single
  parstyle: Style
type Tabulator* = ref object of Single

  
method get_depth*(this: Texel): int {.base.} = 0
method get_depth*(this: Group): int = this.depth

method get_length*(this: Texel): int {.base.} = 0
method get_length*(this: Single): int = 1
method get_length*(this: Text): int = this.text.len
method get_length*(this: TexelWithChilds): int = this.length

method get_lineno*(this: Texel): int {.base.} = 0
method get_lineno*(this: NewLine): int = 1
method get_lineno*(this: Group): int = this.lineno

method `$`*(this: Texel): string {.base.} = "Texel()"
method `$`*(this: Single): string = "S[" & escape(this.text) & "]"
method `$`*(this: Text): string = "T[" & escape(this.text) & "]"
method `$`*(this: Group): string = 
  var l = newSeq[string](0)
  for child in this.childs:
    l.add($child)
  "G[" & l.join(", ") & "]"
method `$`*(this: NewLine): string = "NL"
method `$`*(this: Tabulator): string = "TAB"
  
proc copy*(this: Texel): Texel =
  var new: Texel
  deepCopy(new, this)
  return new

proc copy*(this: Single, style: Option[Style]): Single =
  var new: Single
  deepCopy(new, this)
  if not style.isNone:
    new.style = style.get()
  return new
  
proc copy*(this: Text, style: Option[Style],
           text: Option[string]): Text =
  var new: Text
  deepCopy(new, this)
  if not style.isNone:
    new.style = style.get()
  if not text.isNone:
    new.text = text.get()
  return new
  
proc sum_length(l: seq[Texel]): int =
  var r = 0
  for texel in l:
    r += texel.get_length()
  return r
  
proc sum_lineno(l: seq[Texel]): int =
  var r = 0
  for texel in l:
    r += texel.get_lineno()
  return r

proc init*(texel: Container) =
  texel.length = sum_length(texel.childs)
  texel.lineno = sum_lineno(texel.childs)
  
proc copy*(this: Container, childs: Option[seq[Texel]]): Container =
  var new: Container
  deepCopy(new, this)
  if not childs.isNone:
    deepCopy(new.childs, childs.get())
  new.init()
  return new
  
  
proc newGroup*(childs: seq[Texel]) : Group =
  var texel: Group 
  texel = Group()
  texel.childs = childs
  texel.length = sum_length(childs)
  texel.lineno = sum_lineno(childs)
  var i = 0
  for child in childs:
    i = max(i, child.get_depth()+1)
  texel.depth = i
  return texel
  
  
let SPACE* = Single(text: " ", style: EMPTYSTYLE)
let NL* = NewLine(text: "\n", style: EMPTYSTYLE)
let TAB* = Tabulator(text: "\t", style: EMPTYSTYLE)
  
  
proc groups*(l: seq[Texel]) : seq[Group]=
  #"""Transform the list of texels *l* into a list of groups.
  const
    NMAXH = int(0.5*NMAX)
    
  var r : seq[Group]
  r = newSeq[Group](0) # empty array of Group-Elements
  var N = len(l)
  if N == 0:
     return r    
  var n = int(0.75*NMAX)
  var i = 0
  while N > NMAXH+n:
    N -= n
    var i2 = i+n
    r.add(newGroup(l[i..i2]))
    i += n
  if N <= NMAX:
    r.add(newGroup(l[i..N]))
  else:
    n = NMAXH
    r.add(newGroup(l[i..i+n-1]))
    r.add(newGroup(l[i+n..NMAX-1]))
  return r

when isMainModule:
  import unittest  
  suite "testing texeltree.nim":
    var r : seq[Texel]
    test "single constants":
      check(NL.get_lineno() == 1)
      check(TAB.get_lineno() == 0)
      
    r.add(NL)
    r.add(TAB)
    
    test "creating a group":
      var g = newGroup(r)
      check($g == "G[S[\"\\x0A\"], S[\"\\x09\"]]")
      check(g.length == 2)
      check(g.get_length() == 2)
      check(g.lineno == 1)
      check(g.get_lineno() == 1)


import options
import styles

  
const
  NMAX = 15

type Texel* = ref object of RootObj
method get_depth*(this: Texel): int {.base.} = 0
method get_length*(this: Texel): int {.base.} = 0
method get_lineno*(this: Texel): int {.base.} = 0
proc copy*(this: Texel): Texel =
  var new: Texel
  deepCopy(new, this)
  return new



type Single* = ref object of Texel
  style*: Style
  text*: string # XXX Sollte immutable sein!
method get_length(this: Single): int = 1
proc copy*(this: Single, style: Option[Style]): Single =
  var new: Single
  deepCopy(new, this)
  if not style.isNone:
    new.style = style.get()
  return new
  

type Text* = ref object of Texel
  style*: Style
  text*: string # XXX Sollte immutable sein!
method get_length(this: Text): int = this.text.len
proc copy*(this: Text, style: Option[Style],
           text: Option[string]): Text =
  var new: Text
  deepCopy(new, this)
  if not style.isNone:
    new.style = style.get()
  if not text.isNone:
    new.text = text.get()
  return new
  

type TexelWithChilds = ref object of Texel
  childs: seq[Texel]
  length: int
  lineno: int


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


type Container = ref object of TexelWithChilds
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
  
  
type Group* = ref object of TexelWithChilds
  depth: int
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
  
  

type NewLine* = ref object of Single
  parstyle: Style
method get_lineno*(this: NewLine): int = 1

  
let TAB* = Single(text: "\t", style: EMPTYSTYLE)
let SPACE* = Single(text: " ", style: EMPTYSTYLE)
let NL* = NewLine(text: "\n", style: EMPTYSTYLE)
  
  
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
    #echo "suite setup: run once before the tests"

    test "essential truths":
      # give up and stop if this fails
      require(true)


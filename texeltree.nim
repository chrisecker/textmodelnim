import styles
import options
import strutils
    
  
const
  NMAX = 15
  NMIN = int(NMAX / 2)

type Texel* = ref object of RootObj
type Single* = ref object of Texel
  text*: string # XXX Sollte immutable sein!
  style*: Style
type Text* = ref object of Texel
  text*: string # XXX Sollte immutable sein!
  style*: Style
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

proc childs*(texel: Texel): seq[Texel] =
  if texel of TexelWithChilds:
    return TexelWithChilds(texel).childs

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

  
proc length*(texel: Texel): int = texel.get_length()
proc depth*(texel: Texel): int = texel.get_depth()
proc lineno*(texel: Texel): int = texel.get_lineno()

iterator iter_childs*(texel: Texel): tuple[i1: int, i2: int, child: Texel]=
  var i1 = 0
  for child in texel.childs:
    let n = length(child)
    var i2 = i1+n
    yield (i1, i2, child)
    i2 = i1
  
let SPACE* = Single(text: " ", style: EMPTYSTYLE)
let NL* = NewLine(text: "\n", style: EMPTYSTYLE)
let TAB* = Tabulator(text: "\t", style: EMPTYSTYLE)
  
  
proc groups*(l: seq[Texel]) : seq[Texel]=
  #"""Transform the list of texels *l* into a list of groups.
    
  var r : seq[Texel]
  r = newSeq[Texel](0) # empty array of Group-Elements
  var N = len(l)
  if N < NMIN:
    assert 1 == 0 # XX raise exception

  const n = int(0.75*NMAX)
  var i = 0
  var i2 = 0
  # NOTIZ:
  # - Einzelne Seq-Indices sind wie in Python: von 0 bis len(l)-1
  # - Ranges entahlten aber die obere Grenze, anders als in Python
  # - Die obere Grenze schließt man aus per [i1..<i2]
  while N >= NMAX+n:
    N -= n
    i2 = i+n
    r.add(newGroup(l[i..<i2]))
    i = i2
  # Es ist jetzt NMIN < N < NMAX+0.75*NMAX

  if N > NMAX:
    # Halbieren
    var e = int(N/2)
    N -= e
    i2 = i+e
    r.add(newGroup(l[i..<i2]))
    i = i2
  # Es ist jetzt NMIN < N <= NMAX
    
  if N >= 0:
    i2 = i+N
    r.add(newGroup(l[i..<i2]))
  return r


proc join*(l1, l2: seq[Texel]) : seq[Texel]=
  # l1 = filter(length, l1) # strip off empty elements
  # l2 = filter(length, l2) #
  for texel in l1:
    assert length(texel)>0
  for texel in l2:
    assert length(texel)>0
    
  if len(l1) == 0:
    return l2
  if len(l2) == 0:
    return l1
  let t1 = l1[^1]
  let t2 = l2[0]
  let d1 = depth(t1)
  let d2 = depth(t2)
  if d1 == d2:
    return l1 & l2
  elif d1 > d2:
    let g1 = Group(t1)
    return l1[0..^2] & groups(join(childs(t1), l2))
  # d1 < d2
  let g2 = Group(t2)
  return groups(join(l1, childs(t2))) & l2[1..^1]

  
proc join*(l1, l2, l3: seq[Texel]) : seq[Texel]=
  return join(join(l1, l2), l3)

proc join*(l1, l2, l3, l4: seq[Texel]) : seq[Texel]=
  return join(join(join(l1, l2), l3), l4)

proc fuse*(l1, l2: seq[Texel]) : seq[Texel]=
  # XXX wrong!
  return join(l1, l2)

proc fuse*(l1, l2, l3: seq[Texel]) : seq[Texel]=
  # XXX wrong!
  return join(join(l1, l2), l3)
  
proc get_rightmost(texel: Texel): Texel =
    if texel of TexelWithChilds:
        return get_rightmost(childs(texel)[^1])
    return texel

proc get_leftmost(texel: Texel): Texel =
    if texel of TexelWithChilds:
        return get_leftmost(childs(texel)[^1])
    return texel

proc exchange_rightmost(texel, new: Texel):Texel =
    if texel of TexelWithChilds:
      let cl = childs(texel)
      let l = exchange_rightmost(cl[^1], new)
      return Group(childs: cl[0..^2] & @[l])
    return new

proc remove_leftmost(texel: Texel): seq[Texel] =
  if length(texel) == 0 or depth(texel) == 0:
    # XXX needed?
    return @[]
  let l = remove_leftmost(texel.childs[0])
  return join(l, childs(texel)[1..^1])

proc can_merge(texel1, texel2: Texel): bool =
  if texel1 of Text and texel2 of Text and Text(texel1).style == Text(texel2).style:
    return true
  return false

proc merge(texel1, texel2: Text): Text =
    return Text(text: texel1.text & texel2.text, style: texel1.style)
  
proc insert*(texel: Texel, i: int, stuff: seq[Texel]) : seq[Texel]=
    if not 0 <= i and i <= length(texel):
      raise newException(IndexError, "index out of bounds: " & repr(i))
    if texel of Group:
        var k = -1
        for i1, i2, child in iter_childs(texel):
            k += 1
            if i1 <= i and i <= i2:
                let l = insert(child, i-i1, stuff)
                let r1 = texel.childs[0..<k]
                let r2 = texel.childs[k+1..^1]
                return join(r1, l, r2)
    # XXX fehlt noch:
    #elif texel.is_container:
    #    mutable = texel.get_mutability()
    #    k = -1
    #    for i1, i2, child in iter_childs(texel):
    #        k += 1
    #        if (i1 < i < i2) or ((i1 <= i <= i2) and mutable[k]):
    #            l = insert(child, i-i1, stuff)
    #            r1 = texel.childs[:k]
    #            r2 = texel.childs[k+1:]
    #            return [texel.set_childs(r1+[grouped(l)]+r2)]
    #    if i == 0:
    #        return join(stuff, [texel])
    #    elif i == length(texel):
    #        return join([texel], stuff)
    #    assert False

    if i==0:
      return fuse(stuff, @[texel])
    if i==length(texel):
      return fuse(@[texel], stuff)
    assert 1==0

  
proc get_text*(texel: Texel): string =
  if texel of Text:
    return Text(texel).text
  if texel of Single:
    return Single(texel).text     
  if texel of TexelWithChilds:
    var r = ""
    for child in childs(texel):
      r.add(get_text(child))
    return r
  assert false
    

    
when isMainModule:
  import unittest  
  suite "testing texeltree.nim":
    var r : seq[Texel]
    test "single constants":
      check(NL.get_lineno() == 1)
      check(TAB.get_lineno() == 0)
      check($NL == "NL")
      check($TAB == "TAB")
      
    r.add(NL)
    r.add(TAB)
    
    var g = newGroup(r)
    test "creating a group":
      check($g == "G[NL, TAB]")
      check(g.length == 2)
      check(g.get_length() == 2)
      check(g.lineno == 1)
      check(g.get_lineno() == 1)

    test "get_text":
      check(get_text(g) == "\x0A\x09")
      
    var e : seq[Texel]
    for i in 1..20:
      e.add(Text(text: $i))
    echo $e
    
    test "groups()":
      var h = groups(e)
      check(len(h) == 2)
      check(len(childs(h[0]))+len(childs(h[1])) == len(e))
      echo $h
    

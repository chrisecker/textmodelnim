import styles
import options
import strutils
import contra
import random

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
  nlines: int

type Container* = ref object of TexelWithChilds

type Group* = ref object of TexelWithChilds
  depth: int

type NewLine* = ref object of Single
  parstyle: Style

type Tabulator* = ref object of Single


proc get_childs*(texel: Texel): seq[Texel] =
  if texel of TexelWithChilds:
    return TexelWithChilds(texel).childs

    
method get_depth*(this: Texel): int {.base.} = 0
method get_depth*(this: Group): int = this.depth


method get_length*(this: Texel): int {.base.} = 0
method get_length*(this: Single): int = 1
method get_length*(this: Text): int = this.text.len
method get_length*(this: TexelWithChilds): int = this.length


method get_nlines*(this: Texel): int {.base.} = 0
method get_nlines*(this: NewLine): int = 1
method get_nlines*(this: Group): int = this.nlines


method `$`*(this: Texel): string {.base.} = "Texel()"
method `$`*(this: Single): string = "S[" & escape(this.text) & "]"
method `$`*(this: Text): string = "T[" & escape(this.text) & "]"
method `$`*(this: Group): string =
  var l = newSeq[string](0)
  for child in this.childs:
    l.add($child)
  return "G[" & l.join(", ") & "]"
method `$`*(this: NewLine): string = "NL"
method `$`*(this: Tabulator): string = "TAB"


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


proc sum_nlines(l: seq[Texel]): int =
  var r = 0
  for texel in l:
    r += texel.get_nlines()
  return r


proc init*(texel: Container) =
  texel.length = sum_length(texel.childs)
  texel.nlines = sum_nlines(texel.childs)

proc copy*(this: Container, childs: Option[seq[Texel]]): Container =
  var new: Container
  deepCopy(new, this)
  if not childs.isNone:
    deepCopy(new.childs, childs.get())
  new.init()
  return new


proc newGroup*(childs: seq[Texel]): Group =
  var texel: Group
  texel = Group()
  texel.childs = childs
  texel.length = sum_length(childs)
  texel.nlines = sum_nlines(childs)
  var i = 0
  var j = 0
  for child in childs:
    let d = child.get_depth()+1
    i = max(i, d)
    j = min(i, d)
  texel.depth = i
  assert i == j
  return texel


proc length*(texel: Texel): int = texel.get_length()
proc depth*(texel: Texel): int = texel.get_depth()
proc nlines*(texel: Texel): int = texel.get_nlines()


iterator iter_childs*(texel: Texel): tuple[i1: int, i2: int, child: Texel] =
  var i1 = 0
  var i2 = 0
  for child in texel.get_childs():
    let n = length(child)
    i1 = i2
    i2 = i1+n
    yield (i1, i2, child)


proc left(t: string, n: int): string =
  if len(t) <= n:
    return t
  return t[0..<n] & "..."
  

proc dump*(texel: Texel, i, n: int=0) =
  ## Dump a texel
  echo ' '.repeat(2*n), i, "..", i+length(texel), " ", left($texel, 20)
  for i1, i2, child in iter_childs(texel):
    dump(child, i1, n+1)

proc dump*(l: seq[Texel]) =
  ## Dump a seq of texels
  var i = 0
  for texel in l:
    echo "item ", i, ":"
    dump(texel)

proc homogeneous(l: seq[Texel]): bool =
  var i = -1
  for texel in l:
    if i == -1:
      i = depth(texel)
    else:
      if i != depth(texel):
        return false
  return true
     
proc efficient(texel: Texel): bool =
  if not (texel of TexelWithChilds):
    return true
  let childs = texel.get_childs()
  if len(childs) < NMIN:
    return false
  if len(childs) > NMAX:
    return false
  for child in childs:
    if not efficient(child):
       return false
  return true

proc efficient(l: seq[Texel]): bool =
  if not homogeneous(l):
    return false
  for texel in l:
    if not efficient(texel):
      return false
  return true

  
proc efficient_root(texel: Texel): bool =
  for child in texel.get_childs():
    if not efficient(child):
       return false
  return true

  
proc get_text*(texel: Texel): string =
  ## Get the content of `texel`as a text string which has the same length.
  if texel of Text:
    return Text(texel).text
  if texel of Single:
    return Single(texel).text
  if texel of TexelWithChilds:
    var r = ""
    for child in texel.get_childs():
      r.add(get_text(child))
    return r
  echo "Texel=", repr(texel)
  assert false


proc get_text(l: seq[Texel]): string =
  var r = ""
  for texel in l:
    r.add(get_text(texel))
  return r

  
let SPACE* = Single(text: " ", style: EMPTYSTYLE)
let NL* = NewLine(text: "\n", style: EMPTYSTYLE)
let TAB* = Tabulator(text: "\t", style: EMPTYSTYLE)


proc groups*(l: seq[Texel]): seq[Texel] =
  ## Transform the seq of texels `l` into a seq of groups. If texel
  ## have depth d, groups will have depth d+1. All returned groups are
  ## efficient if len(l)>=NMIN and efficient(l).

  postconditions len(l)<NMIN or efficient(l)==false or efficient(result),
     get_text(l) == get_text(result)

  var r: seq[Texel]
  r = newSeq[Texel](0) # empty array of Group-Elements
  var N = len(l)
  if N < NMIN:
    return @[Texel(newGroup(l))]

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

  if not efficient(r):
    dump(r)
    assert false
  return r


proc join*(l1, l2: seq[Texel]): seq[Texel] =
  ## Join several homogeneous sequences of texels. The returned list
  ## is homogeneous. It is even efficient if l1 and l2 both are
  ## efficient.

  preconditions homogeneous(l1), homogeneous(l2)
  postconditions homogeneous(result),
     efficient(l1)==false or efficient(l2)==false or efficient(result)==true,
     get_text(l1) & get_text(l2) == get_text(result)
  
  # l1 = filter(length, l1) # strip off empty elements
  # l2 = filter(length, l2) #
  for texel in l1:
    assert length(texel) > 0
  for texel in l2:
    assert get_length(texel) > 0

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
    return l1[0..^2] & groups(join(get_childs(t1), l2))
  # d1 < d2
  return groups(join(l1, get_childs(t2))) & l2[1..^1]

proc join*(l1, l2, l3: seq[Texel]): seq[Texel] =
  return join(join(l1, l2), l3)

proc join*(l1, l2, l3, l4: seq[Texel]): seq[Texel] =
  return join(join(join(l1, l2), l3), l4)


proc get_rightmost(texel: Texel): Texel =
  assert length(texel) > 0
  if texel of TexelWithChilds:
    return get_rightmost(get_childs(texel)[^1])
  return texel


proc get_leftmost(texel: Texel): Texel =
  assert length(texel) > 0
  if texel of TexelWithChilds:
    return get_leftmost(get_childs(texel)[0])
  return texel


proc exchange_rightmost(texel, new: Texel): seq[Texel] =
  assert not (new of Group)
  if texel of TexelWithChilds:
    let cl = texel.get_childs()
    let l = exchange_rightmost(cl[^1], new)
    return @[Texel(newGroup(cl[0..^2] & l))]
  return @[new]


proc without_leftmost(texel: Texel): seq[Texel] =
  let childs = get_childs(texel)
  if len(childs) == 0:
    return @[]
  let l = without_leftmost(childs[0])
  return join(l, childs[1..^1])


proc can_merge(texel1, texel2: Texel): bool =
  if texel1 of Text and texel2 of Text and
      Text(texel1).style == Text(texel2).style:
    return true
  return false


proc merge(texel1, texel2: Texel): Texel =
  let t1 = Text(texel1)
  let t2 = Text(texel2)
  return Text(text: t1.text & t2.text, style: t1.style)


proc fuse*(l1, l2: seq[Texel]): seq[Texel] =
  ## Like join(...) but also merge the arguments if possible.  The
  ## returned list is homogeneous. It is even efficient if l1 and l2
  ## both are efficient.
  
  preconditions homogeneous(l1), homogeneous(l2)
  postconditions homogeneous(result),
     efficient(l1)==false or efficient(l2)==false or efficient(result)==true,
     get_text(l1) & get_text(l2) == get_text(result)

  if len(l1) == 0:
    return l2
  elif len(l2) == 0:
    return l1
  let t1 = get_rightmost(l1[^1])
  let t2 = get_leftmost(l2[0])
  if not can_merge(t1, t2):
    return join(l1, l2)
  return join(
    l1[0..^2],
    exchange_rightmost(l1[^1], merge(t1, t2)),
    without_leftmost(l2[0]),
    l2[1..^1])

proc fuse*(l1, l2, l3: seq[Texel]): seq[Texel] =
  ## Like join(...) but also merge the arguments if possible.
  ## The returned list is homogeneous.
  return fuse(fuse(l1, l2), l3)


proc strip(root: Texel): Texel =
  ## Removes unnecessary Group-elements from the root.
  var root: Texel = root
  while root of Group and len(Group(root).childs) == 1:
    root = Group(root).childs[0]
  return root


proc grouped(stuff: seq[Texel]): Texel =
  ## Creates a single group from the list of texels *stuff*.
  var l: seq[Texel] = stuff
  while len(l) > NMAX:
    l = groups(l)
  return strip(newGroup(l))


proc insert(x: string, i: int, item: string) : string =
  var r: string = x
  insert(r, item, i)
  return r
  
proc insert*(texel: Texel, i: int, stuff: seq[Texel]): seq[Texel] =
  ## Inserts the seq `stuff` at position `i`.
  ##
  ## `Texel` must be root-efficient, `stuff` must be
  ## list-efficient. Note that insert can increase the texels
  ## depth. The returned list is efficient when texel is root
  ## efficient and stuff is efficient.

  postconditions true,
     homogeneous(result),
     insert(get_text(texel), i, get_text(stuff)) == get_text(result),
     efficient(stuff)==false or efficient_root(texel)==false or
       efficient(result)==true

     
  if not (0 <= i and i <= length(texel)):
    raise newException(IndexError, "index out of bounds: " & repr(i))

  if texel of Group:
    var k = -1
    #echo "\ninsert called"
    let childs = texel.get_childs()
    for i1, i2, child in iter_childs(texel):
      #echo "i:", i, "[", i1, ", ", i2, "]"
      k += 1
      if i1 <= i and i <= i2:
        let l = insert(child, i-i1, stuff)
        let r1 = childs[0..<k]
        let r2 = childs[k+1..^1]
        return join(r1, l, r2)
    assert false

  elif i == 0:
    return fuse(stuff, @[texel])

  elif i == length(texel):
    return fuse(@[texel], stuff)

    # An der Stelle muss texel ein Text oder ein Container sein. Grund:
    # die anderen beiden Möglichkeiten sind schon vorher behandelt.
    # - Group ganz am Anfang
    # - Single wird durch i == 0 oder i == length erwischt, da Single immer
    #   length 1 hat

  elif texel of Text:
    # So könnten alle Fälle behandelt werden. Da wir copy() noch
    # nicht haben, gehe ich die Fälle einzeln durch.  return
    # fuse(copy(texel, 0, i), stuff, copy(texel, i,
    # length(texel)))
    let t = Text(texel)
    let t1: Texel = Text(text: t.text[0..<i], style: t.style)
    let t2: Texel = Text(text: t.text[i..^1], style: t.style)
    return fuse(@[t1], stuff, @[t2])

  elif texel of Container:
    let container = Container(texel)
    var mutable: bool = true
    var k: int = -1
    for i1, i2, child in iter_childs(container):
      k += 1
      mutable = not mutable
      if (i1 < i and i < i2) or ((i1 <= i and i <= i2) and mutable):
        var n = container.childs[0..^1]
        n[k] = grouped(insert(child, i-i1, stuff))
        return @[Texel(container.copy(childs = option(n)))]
  assert 1 == 0


when isMainModule:
  import unittest
  suite "testing texeltree.nim":
    var r: seq[Texel]
    test "single constants":
      check(NL.get_nlines() == 1)
      check(TAB.get_nlines() == 0)
      check($NL == "NL")
      check($TAB == "TAB")

    r.add(NL)
    r.add(TAB)

    var g = newGroup(r)
    test "creating a group":
      check($g == "G[NL, TAB]")
      check(g.length == 2)
      check(g.get_length() == 2)
      check(g.nlines == 1)
      check(g.get_nlines() == 1)

    test "get_text":
      check(get_text(g) == "\x0A\x09")

    var e: seq[Texel]
    for i in 1..20:
      e.add(Text(text: $i))
      #echo $e

    test "groups()":
      var h = groups(e)
      check(len(h) == 2)
      check(len(get_childs(h[0]))+len(get_childs(h[1])) == len(e))
      #echo $h

    test "insert()":
      var w = "0123456789"
      check(insert(w, 2, "xyz") == "01xyz23456789")
      check(w == "0123456789")
      var i: int = 1
      assert 0 <= i
      var b = not (0 <= i and i <= 2)
      assert b == false
      check(get_text(g) == "\n\t")

      var t = Text(text: "Chris")
      check(get_text(grouped(g.insert(0, @[Texel(t)]))) == "Chris\n\t")
      check(get_text(grouped(g.insert(1, @[Texel(t)]))) == "\nChris\t")
      check(get_text(grouped(g.insert(2, @[Texel(t)]))) == "\n\tChris")

      # not compatible with contract checks!
      #expect(IndexError):
      #  discard g.insert(-1, @[Texel(t)])

      expect(IndexError):
        discard g.insert(3, @[Texel(t)])

      check(get_text(grouped(t.insert(0, @[Texel(g)]))) == "\n\tChris")
      check(get_text(grouped(t.insert(1, @[Texel(g)]))) == "C\n\thris")
      check(get_text(grouped(t.insert(2, @[Texel(g)]))) == "Ch\n\tris")
      check(get_text(grouped(t.insert(3, @[Texel(g)]))) == "Chr\n\tis")
      check(get_text(grouped(t.insert(4, @[Texel(g)]))) == "Chri\n\ts")
      check(get_text(grouped(t.insert(5, @[Texel(g)]))) == "Chris\n\t")
      expect(IndexError):
        discard t.insert(6, @[Texel(g)])

      # not compatible with contract checks
      #expect(IndexError):
      #  discard t.insert(-1, @[Texel(g)])

      var h = grouped(t.insert(2, @[Texel(g)]))
      #echo h
      let hh = h.insert(3, @[Texel(g)])
      assert len(hh) == 1
      assert depth(hh[0]) == 1

      # absichern, dass durch das Slicing eine Kopie erzeugt wird:
      var r = @[0, 1, 2, 3, 4]
      var s = r[2..^1]
      s[1] = -1
      assert s == @[2, -1, 4]
      assert r == @[0, 1, 2, 3, 4]

      # auch bei einem vollständigen Slice
      s = r[0..^1]
      s[1] = -1
      assert r == @[0, 1, 2, 3, 4]
      

    test "merge()":
      var t1 = Text(text: "Hi ")
      var t2 = Text(text: "Chris")
      check(can_merge(t1, t2) == true)

      var g1 = groups(@[TAB, t1])
      var g2 = groups(@[Texel(t2)])
      check(get_text(join(g1, g2)) == "\tHi Chris")
      check(get_text(fuse(g1, g2)) == "\tHi Chris")

      dump(join(g1, g2))

    test "random insert":
      # XXX leere Texel funktionieren noch nicht!
      var t: Texel = Text(text: "XX")
      var n: Texel
      var j: int
      let red = Style(textcolor: option("red"))
      let black = Style(textcolor: option("black"))

      for i in 0..20:
        let style = sample(@[red, black])
        n = Text(text: ":" & $i, style: style)
        j = rand(0..length(t))
        echo "inserting ", $n, " at ", j, " in ", $t 
        t = grouped(insert(t, j, @[n]))
      dump(t)


      

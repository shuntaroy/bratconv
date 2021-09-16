## # bratconv
## 
## Convert or modify brat standoff format files into something different.
## 
## The current version only supports attribute-to-entity_type modification.
## 
## ## attribute-to-entity_type
## 
## This modifies a brat files that contain some attributes to some entity types into an attribute-free entity only format.
## That is, it simply puts attribute values to entity type name:
## 
## > Disease certainty=positive => Disease-positive
## 
## Currently, this only supports the PRISM scheme.
import tables
import strutils
import strformat
import os

const validAttr = ["certainty", "state", "type"]

type
  Entity = tuple
    id: int
    tag: string
    span: tuple[head: int, tail: int]
    text: string
  Attribute = tuple
    id: int
    key: string
    val: string
    attachedTo: int
  Doc = Table[int, Entity]

func parseId(idStr: string): int =
  # e.g.) T11, A4, T34, ...
  return parseInt(idStr[1..^1])

func toString(ent: Entity): string =
  return &"T{ent.id}\t{ent.tag} {ent.span.head} {ent.span.tail}\t{ent.text}"

proc readAnAnn(inputPath: string): (Doc, seq[Attribute]) =
  # let fileSplit = splitFile(inputPath)
  var
    doc = initTable[int, Entity]()
    attrs: seq[Attribute]

  for line in lines(inputPath):
    case line[0]
    of 'T':
      let
        splitLine = line.strip().split("\t") # Tid, anno, text
        numId = parseId(splitLine[0])
        splitAnno = splitLine[1].split()     # entType, head, tail
      var ent: Entity = (
            id: numId,
            tag: splitAnno[0],
            span: (head: parseInt(splitAnno[1]), tail: parseInt(splitAnno[2])),
            text: splitLine[2]
        )
      doc[ent.id] = ent
    of 'A':
      let
        splitLine = line.strip().split("\t") # Aid, attr
        numId = parseId(splitLine[0])
        splitAttr = splitLine[1].split()     # key, to, val
        numTo = parseId(splitAttr[1])
      if splitAttr[0] notin validAttr: continue
      var attr: Attribute = (
          id: numId,
          key: splitAttr[0],
          val: splitAttr[2],
          attachedTo: numTo,
        )
      attrs.add(attr)
    else:
      discard

  return (doc, attrs)

proc modifyDoc(doc: var Doc, attrs: seq[Attribute]) =
  for attr in attrs:
    var toEnt = doc[attr.attachedTo]
    let newTag = toEnt.tag & "-" & attr.val
    toEnt.tag = newTag
    doc[attr.attachedTo] = toEnt

proc writeANewAnn(inputAnnPath: string, doc: Doc) =
  let
    fileSplit = splitFile(inputAnnPath)
    f = open(joinPath(fileSplit.dir, fileSplit.name & "-attr" & fileSplit.ext), fmWrite)
  for ent in doc.values:
    writeLine(f, toString(ent))

proc convertAttr2Tag(inputAnnPath: string) =
  var (doc, attrs) = readAnAnn(inputAnnPath)
  # echo doc
  # echo attrs
  modifyDoc(doc, attrs)
  # echo doc
  writeANewAnn(inputAnnPath, doc)

when isMainModule:
  if paramCount() != 1:
    echo "Specify a single file or dir to read"
    quit(1)

  let
    inputPath = paramStr(1)
    inputSplit = splitFile(inputPath)
  if dirExists(inputPath):
    var toDel: seq[string]
    for filePath in walkDirRec(inputPath):
      # echo filePath
      let fileSplit = splitFile(filePath)
      if fileSplit.name.startsWith("."): continue
      elif fileSplit.ext == ".ann":
        convertAttr2Tag(filePath)
      toDel.add(filePath)
    for toDelFP in toDel:
      removeFile(toDelFP)
  else:
    if inputSplit.ext == ".ann":
      convertAttr2Tag(inputPath)
    else:
      echo "File should be .ann"
      quit(1)

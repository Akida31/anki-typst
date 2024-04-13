#let anki_do_export = state("anki::export", false)

#let _to_string(content) = {
  if type(content) == str {
    content
  } else if (int, float, length).contains(type(content)) {
    str(content)
  } else if content == none {
    "none"
  } else if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(_to_string).join("")
  } else if content.has("body") {
    _to_string(content.body)
  } else if content == [ ] {
    " "
  }
}

// convert the content to a string if it is plain.
// else return `none`
#let _to_plain(content) = {
  if type(content) == str {
    content
  } else if (int, float).contains(type(content)) {
    str(content)
  } else if content == [] {
    ""
  } else {
    none
  }
}

#let _is_empty(val) = if type(val) == content {
  val.fields().len() == 0
} else if type(val) == dictionary {
  val.keys().len() == 0
} else if type(val) == array {
  val.len() == 0
} else if type(val) == str {
  val.len() == 0
} else {
  panic("can't check emptiness: Unknown type " + type(val) + " for " + val)
}

#let assert_ty(ty_name, val, ..valid_tys) = {
  if valid_tys.named().len() != 0 {
    panic("can check only for positional types in " + ty_name)
  }
  if valid_tys.pos().all(ty => type(val) != ty) {
    let ty_names = valid_tys.pos().map(ty => str(ty)).join(", ")
    panic(ty_name + " must be of type " + ty_names + " but was " + type(val) + ": " + _to_string(val))
  }
  val
}

#let _assert_not_empty(ty_name, val) = {
    if _is_empty(val) {
      panic(ty_name + " must be not empty")
    }
    val
}

#let _get_label_page(id, loc) = {
  let elems = query(label(id), loc)
  if elems.len() == 0 {
    return none
  }
  if elems.len() != 1 {
    panic("expected one elem for " + id + " but got " + str(elems.len()) + ". Did you use the same id twice?")
  }
  elems.at(0).location().page()
}

#let set_export(val) = {
  anki_do_export.update(val)
}

#let set_export_from_sys() = {
  let val = sys.inputs.at("export", default: false)
  let val = if (true, "true", "yes").contains(val) {
    true
  } else if (none, false, "false", "no").contains(val) {
    false
  } else {
    panic("unexpected export value: " + val)
  }
  set_export(val)
}

#let anki-export(
  fields: (:), 
  tags: (), 
  id_fields: (),
  fmt: (fields: (:)) => panic("supply a fmt function"),
  fmt_tags: (tags: ()) => [Tags: #tags.join(", ") #linebreak()],
) = {
  for tag in tags {
    let _ = assert_ty("tag", tag, str)
  }
  if id_fields.len() == 0 {
    panic("id_fields must be not empty")
  }

  let id = id_fields.map(name => _to_string(fields.at(name))).join(".<.<>>") + ".<.<>>"

  anki_do_export.display(export => 
    if export {
      locate(loc => {
        let meta = (:)
        for (name, val) in fields.pairs() {
            [ 
              #pagebreak(weak: true)
              #val #label(id + name)
            ]
            meta.insert(name, (
              content: _to_string(val),
              page: _get_label_page(id, name, loc),
            ))
        }
        meta.insert("tags", tags)
        [#metadata(meta) <anki-export>]
      })
      pagebreak(weak: true)
    } else {
      fmt(fields)
      if tags.len() > 0 {
        fmt_tags(tags: tags)
      }
    }
  )
}

#let chapter(title) = [
  #pagebreak(weak: true)
  #let id = "chapter" + ".<.<>>" + _assert_not_empty("title", assert_ty("title", title, str))
  #heading(
    numbering: none,
    level: title.matches("::").len() + 1,
    [#title]
  ) #label(id + "heading")
  #anki_do_export.display(export => 
    if export {
      locate(loc => {
        metadata((
          chapter: (
            content: title,
            page: _get_label_page(id, "heading", loc)
          )
        ))
    })
    }
  )
]

#let _inner_heading(content) = heading(numbering: none, level: 5, text(weight: "semibold", content))

#let _simple_group(name) = {
  let inner(reference, tags: (), front, back) = anki-export(
  tags: tags,
  id_fields: ("front", "reference"),
  fields: (
    "front": _assert_not_empty("front", front),
    "reference": _assert_not_empty("reference", assert_ty("reference", reference, str)),
    "back": _assert_not_empty("back", back),
  ), fmt: fields => [
    #_inner_heading[#name #(fields.reference) (#(fields.front))]
    #(fields.back)
  ])
  inner
}

#let beispiel = _simple_group("Beispiel")
#let bemerkung = _simple_group("Bemerkung")
#let definition = _simple_group("Definition")
#let satz(reference, tags: (), front: [], back, proof) = anki-export(
  tags: tags,
  id_fields: ("front", "reference"),
  fields: (
    "front": _assert_not_empty("front", front),
    "reference": _assert_not_empty("reference", assert_ty("reference", reference, str)),
    "proof": proof,
    "back": _assert_not_empty("back", back),
  ), fmt: fields => [
    #_inner_heading[Satz #(fields.reference) (#(fields.front))]
    #(fields.back)
    #if _to_string(fields.proof) != none [
      proof #label(id + "proof")
    ]
  ]
)
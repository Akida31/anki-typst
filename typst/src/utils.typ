#let to_string(content) = {
  if type(content) == str {
    content
  } else if (int, float, length).contains(type(content)) {
    str(content)
  } else if content == none {
    "none"
  } else if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(to_string).join("")
  } else if content.has("body") {
    to_string(content.body)
  } else if content == [ ] {
    " "
    // TODO
    // } else {
    //   panic(content)
  }
}

#let is_empty(val) = if type(val) == content {
  val.fields().len() == 0
} else if type(val) == dictionary {
  val.keys().len() == 0
} else if type(val) == array {
  val.len() == 0 or val.map(is_empty).all()
} else if type(val) == str {
  val.len() == 0
} else {
  false
}

// convert the c to a string if it is plain.
// else return `none`
#let to_plain(c) = {
  if type(c) == str {
    c
  } else if (int, float).contains(type(c)) {
    str(c)
  } else if c == [] {
    ""
  } else if type(c) == content {
    if c.fields().len() > 1 {
      none
    } else {
      let val = c.fields().values().first()
      to_plain(val)
    }
  } else if type(c) == array {
    let got_non_empty = none
    for val in c {
      if not is_empty(val) {
        if got_non_empty != none {
          return none
        }
        got_non_empty = val
      }
    }
    to_plain(got_non_empty)
  } else {
    none
  }
}

#let assert_ty(ty_name, val, ..valid_tys) = {
  if valid_tys.named().len() != 0 {
    panic("can check only for positional types in " + ty_name)
  }
  if valid_tys.pos().all(ty => type(val) != ty) {
    let ty_names = valid_tys.pos().map(ty => str(ty)).join(", ")
    panic(ty_name + " must be of type " + ty_names + " but was " + type(val) + ": " + to_string(val))
  }
  val
}

#let get_label_page(id, id_name, loc) = {
  let elems = query(label(id), loc)
  if elems.len() == 0 {
    return none
  }
  if elems.len() != 1 {
    panic("expected one elem for id " + id_name + " but got " + str(
      elems.len(),
    ) + ". Did you use the same id twice?")
  }
  elems.at(0).location().page()
}


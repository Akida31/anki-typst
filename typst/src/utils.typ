/// Convert content to a string.
///
/// This function is best effort and lossy.
/// - content (content): Content to convert.
/// -> str
#let to_string(content) = {
  if type(content) == str {
    content
  } else if (int, float, length).contains(type(content)) {
    str(content)
  } else if content == none {
    "none"
  } else if content.has("text") {
    to_string(content.text)
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

/// Determine whether something is empty.
///
/// - val (content, dict, array, str): #h(0pt)
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

/// Try to get the plain value from content.
///
/// This function is not lossy and will return `none` if it can't find the plain value.
/// - c (content): Content to convert.
/// -> str, none
#let to_plain(c) = {
  if type(c) == str {
    c
  } else if (int, float).contains(type(c)) {
    str(c)
  } else if c == [] {
    ""
  } else if type(c) == content {
    // equation
    if c.fields().keys() == ("block", "body") {
      to_plain(c.body)
    }
    else if c.fields().len() > 1 {
      if c.has("children") {
        // TODO warn here
        c.children.map(to_plain).join("")
      } else {
        none
      }
    } else if c.fields().len() == 0 {
      if c.func() == [ ].func() {
        // space
        " "
      } else {
        ""
      }
    } else {
      let val = c.fields().values().first()
      to_plain(val)
    }
  } else if type(c) == array {
    let got_non_empty = none
    let res = ""
    for val in c {
      if not is_empty(val) {
        if got_non_empty != none {
          // TODO warn here
          // return none
        }
        got_non_empty = val
      }
      res += to_plain(val)
    }
    res
  } else {
    none
  }
}

/// Assert that val has a valid type.
///
/// If val is not of some type in `valid_tys` this function will panic.
///
/// - ty_name (str): Name of the type, used for `panic`.
/// - val (any): Value to check.
/// - ..valid_tys (array): Array of valid types (e.g. str, int, content).
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

/// Get the page at which the label with `id` can be found.
///
/// *Panics* if there are multiple labels with `id`.
///
/// - id (str): The label to search for.
/// - id_name (str): Name of the id, used for `panic`.
/// - loc (location): Some location, used for `query`
/// -> int
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


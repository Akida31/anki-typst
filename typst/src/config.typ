#let anki_config = state(
  "anki::config",
  (
    export: false,
    date: none,
    title: none,
  ),
)

#let set_export(val) = {
  anki_config.update(conf => {
    conf.export = val
    conf
  })
}

#let is_export(f) = {
  anki_config.display(val => f(val.export))
}

#let get_title(f) = {
  anki_config.display(val => f(val.title))
}

#let set_date(val) = {
  anki_config.update(conf => {
    conf.date = val
    conf
  })
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
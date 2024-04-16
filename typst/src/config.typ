#let anki_config = state(
  "anki::config",
  (
    export: false,
    date: none,
    title: none,
  ),
)

#let get_val_from_sys(
  key,
  default: false,
  options: (
    (true, (true, "true", "yes")),
    (false, (none, false, "false", "no")),
  ),
) = {
  let val = sys.inputs.at(key, default: default)
  for (key, vals) in options {
    if vals.contains(val) {
      return key
    }
  }
  panic("unexpected value for key " + key + ": " + val)
}

#let set_export(val) = {
  anki_config.update(conf => {
    conf.export = val
    conf
  })
}

// TODO use this from state
#let is_export() = {
  // anki_config.display(val => f(val.export))
  get_val_from_sys("export")
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
  let val = get_val_from_sys("export")
  set_export(val)
}
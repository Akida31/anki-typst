#let anki_config = state(
  "anki::config",
  (
    export: false,
    date: none,
    title: none,
    prefix_deck_names_with_numbers: false,
  ),
)

/// Get a value from `sys.inputs`.
///
/// - key (str): The input key to read from.
/// - default (any): The default value if it can't be read.
/// - options (dict): Map to get from option to value.
/// -> any
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

/// Enable or disable export mode.
///
/// - export (bool): The new value.
#let set_export(export) = {
  anki_config.update(conf => {
    conf.export = export
    conf
  })
}

/// Determine whether the export mode is active.
/// - loc (location): Current location
/// -> bool
#let is_export(loc) = {
  anki_config.at(loc).export
}

/// Set the date.
///
/// If the date is set (not `none`), all anki items after this will have an additional date field.
/// - date (str, none): #v(0cm)
#let set_date(date) = {
  anki_config.update(conf => {
    conf.date = date
    conf
  })
}

/// Enable or disable export mode depending on `sys.inputs`.
#let set_export_from_sys() = {
  let val = get_val_from_sys("export")
  set_export(val)
}

#import "raw.typ": anki_export
#import "config.typ"
#import config: set_date, is_export
#import "theorems.typ"

#let setup(
  doc,
  set_export_from_sys: false,
  enable_theorems: false,
  title: none,
  prefix_deck_names_with_numbers: false,
  title_as_deck_name: false,
) = {
  import "config.typ"
  if set_export_from_sys {
    config.set_export_from_sys()
  }
  
  config.anki_config.update(conf => {
    conf.title = title
    conf.prefix_deck_names_with_numbers = prefix_deck_names_with_numbers
    conf.title_as_deck_name = title_as_deck_name
    conf
  })
  
  let doc = if enable_theorems {
    show: theorems.setup
    doc
  } else {
    doc
  }
  if is_export() {
    set page(margin: 0.5cm, height: auto)
    doc
  } else {
    doc
  }
}
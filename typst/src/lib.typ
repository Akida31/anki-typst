#import "raw.typ": anki_export
#import "config.typ"
#import config: set_date, is_export
#import "theorems.typ"

#let setup(
  doc,
  set_export_from_sys: false,
  enable_theorems: false,
  title: none,
) = {
  import "config.typ"
  if set_export_from_sys {
    config.set_export_from_sys()
  }
  
  config.anki_config.update(conf => {
    conf.title = title
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
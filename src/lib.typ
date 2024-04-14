#import "raw.typ": anki_export
#import "config.typ": set_export_from_sys, set_date, is_export
#import "theorems.typ"

#let setup(
  doc,
  set_export_from_sys: false,
  enable_theorems: false,
) = {
  import "config.typ"
  if set_export_from_sys {
    config.set_export_from_sys()
  }
  
  config.is_export(export => {
    if enable_theorems {
      show: theorems.setup
      doc
    } else {
      doc
    }
  })
}
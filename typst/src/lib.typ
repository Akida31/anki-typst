#import "raw.typ": anki_export
#import "config.typ"
#import config: set_date, is_export
#import "theorems.typ"

/// Setup the document
///
/// This is crucial for displaying everything correctly!
///
/// *Example*:
/// #example(`show: anki.setup.with(enable_theorems: true)`, ratio: 1000, scale-preview: 100%)
///
/// - doc (content): The document to wrap.
/// - export (bool, auto): Whether to enable export mode.
///   If `export` is `auto`, anki-typst will try to read from `sys.inputs`.
/// - enable_theorems (bool): Whether to enable theorem support (via `ctheorems`)
/// - title (str, none): The top-level deck name of all cards.
/// - prefix_deck_names_with_numbers (bool): Whether to prefix all deck names with the corresponding heading number.
/// -> content
#let setup(
  doc,
  export: auto,
  enable_theorems: false,
  title: none,
  prefix_deck_names_with_numbers: false,
) = {
  import "config.typ"
  if export == auto {
    config.set_export_from_sys()
  }

  config.anki_config.update(conf => {
    conf.title = title
    conf.prefix_deck_names_with_numbers = prefix_deck_names_with_numbers
    conf
  })

  let doc = if enable_theorems {
    show: theorems.setup
    doc
  } else {
    doc
  }
  locate(loc => if is_export(loc) {
    set page(margin: 0.5cm, height: auto)
    doc
  } else {
    doc
  })
}

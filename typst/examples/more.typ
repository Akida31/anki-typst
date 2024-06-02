#import "../src/lib.typ" as anki
#import anki.theorems: item

#show: anki.setup.with(
  set_export_from_sys: true,
  enable_theorems: true,
  prefix_deck_names_with_numbers: true,
  title_as_deck_name: true,
  title: "TITLE",
)
#set heading(numbering: "1.")

#let theorem = item("Theorem", proof_name: "Precious Proof", initial_tags: ("proof",))
#let example = item("Example", initial_tags: ("example",), id: fields => fields.at("number"))
#let unnumbered = item("Unnumbered", numbering: none)

// NOTE that this requires a model named `some-model`. If you just want to try this out you can delete this line.
// The default model is anki-typst.
#anki.theorems.model("some-model")

= Heading
== Subheading
#theorem("Euclid")[
  Theorem-content
][
  This is a proof
]<euclid>

#unnumbered("Notation")[
  Did you know? @euclid was also a human
]

= Heading2

#example("Pythagoras")[
  Did you know?
  $ a^2 + b^2 = c^2 $
]

#import "/src/lib.typ" as anki
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


#example("hey", secondary: auto)[]
#anki.set_date("2024")
#example("ho")[]

#let bemerkung = item("Bemerkung")

#bemerkung("F", secondary: auto)[
]

#anki.set_date("2024")

#bemerkung("∞")[
  D
]

#anki.set_date("2024-04-13")
We start with an example

#example("TODO")[
  This is an example: $i^2 = -1$
]

#example("whats", secondary: auto)[
  $ 1 + 1 = 2 $
]
#anki.set_date("2024")
#example("up")[]
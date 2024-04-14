#import "../src/lib.typ" as anki
#import anki.theorems: item, item_with_proof

#show: anki.setup.with(set_export_from_sys: true, enable_theorems: true)
#set heading(numbering: "1.")

#let theorem = item_with_proof("Theorem", "Proof", initial_tags: ("proof",))
#let example = item("Example", initial_tags: ("example",))
#let unnumbered = item("Unnumbered", numbering: none)

= Heading
== Subheading
#theorem("Euclid")[
  Theorem-content
][
  This is a proof
]

#unnumbered("Notation")[
  Did you know?
]

#example("Pythagoras")[
  Did you know?
  $ a^2 + b^2 = c^2 $
]
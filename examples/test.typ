#import "../src/lib.typ" as anki
#import anki.theorems: item, item_with_proof

#show: anki.setup.with(set_export_from_sys: true, enable_theorems: true)
#set heading(numbering: "1.")

#let theorem = item_with_proof("Theorem", "Proof")
#let example = item("Example")

= Heading1
== Subheading1
=== SubSubheading1

= Heading
== Subheading
#theorem("Euclid")[
  Theorem-content
][
  This is a proof
]

#example("Pythagoras")[
  Did you know?
  $ a^2 + b^2 = c^2 $
]
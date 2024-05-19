#import "../src/lib.typ" as anki
#import anki.theorems: item, item_with_proof

#show: anki.setup.with(set_export_from_sys: true, enable_theorems: true)
#set heading(numbering: "1.")

#let theorem = item_with_proof("Theorem", "Proof", initial_tags: ("proof",))
#let example = item("Example", initial_tags: ("example",))

= Heading1

#theorem("Euclid")[
  Theorem-content
][
  This is a proof
]
#example("Numbered part 2", number: n => "?" + n + "!")[
  This is numbered differently depending on the current number
]

#example("Numbered", number: "42")[
  This is numbered differently and has no influence.
]

#example("Pythagoras")[
  Did you know?
  $ a^2 + b^2 = c^2 $
]
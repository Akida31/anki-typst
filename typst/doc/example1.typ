#import "../src/lib.typ" as anki
#set page(width: 16cm, height: auto, margin: 1cm)
// remove until here for doc
#import anki.theorems: item
// Don't forget this! v
#show: anki.setup.with(enable_theorems: true)

// create item kinds
#let example = item("Example", initial_tags: ("example",))
#let theorem = item("Theorem", proof_name: "\"Proof\"")

// create item
#example("Pythagoras")[
 $ a^2 + b^2 = c^2 $
]

// use secondary numbering
#example("triangle", secondary: auto)[
  #sym.triangle.tr.filled
]
#example("another triangle", secondary: auto)[
  #sym.triangle.t.stroked
]

// and a theorem, with a custom number
#theorem("Triangular numbers", number: "42")[
  The triangular numbers are given by:
  $ T_n = sum_(k=1)^n k = (n(n+1))/2 $
][
  Induction over n.
]

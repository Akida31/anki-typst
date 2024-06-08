#import "/src/lib.typ" as anki
#import anki.theorems: item

#show: anki.setup.with(set_export_from_sys: true, enable_theorems: true)
#set heading(numbering: "1.")

#let theorem = item("Theorem", initial_tags: ("proof",))
#let example = item("Example", initial_tags: ("example",))
#let definition = item("Definition", initial_tags: ("definition",))

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

#example("triangle", secondary: auto)[
  #sym.triangle.tr.filled
]

#example("another triangle", secondary: auto)[
  #sym.triangle.t.stroked
]

#definition("Imaginery unit")[
  We define the Imaginery unit $i$ by its property $i^2 = -1$.
]

#definition("Imaginery unit2")[
  We define the Imaginery unit $i$ by its property $i^2 = -1$.
]

#example("one last triangle", secondary: auto)[
  #sym.triangle.br.stroked
]
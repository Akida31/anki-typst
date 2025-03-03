#import "/src/lib.typ" as anki
#import anki.theorems: item

#show: anki.setup.with(enable_theorems: true)
#set heading(numbering: "1.")

#let theorem = item("Theorem", initial_tags: ("proof",))
#let example = item("Example", initial_tags: ("example",))

= Heading1
== Subheading1
=== SubSubheading1

= Heading
== Subheading

// update the item counter manually
// #anki.theorems.set_thmcounter(items: (3, 5, 7))
#theorem("Euclid")[
  Theorem-content
][
  This is a proof
]

#example("Pythagoras")[
  Did you know?
  $ a^2 + b^2 = c^2 $
]

// run typst query examples/simple.typ '<anki-export>' --input export=true --root=.
// to get something like this (the format isn't stable):
/*
[
  {
    "func": "metadata",
    "value": {
      "id": "Euclid",
      "deck": "Heading::Subheading",
      "model": "",
      "fields": {
        "front": {
          "plain": "Euclid"
        },
        "back": {
          "plain": {
            "func": "text",
            "text": "Theorem-content"
          }
        },
        "proof": {
          "plain": {
            "func": "text",
            "text": "This is a proof"
          }
        }
      },
      "tags": [
        "proof"
      ]
    },
    "label": "<anki-export>"
  },
  {
    "func": "metadata",
    "value": {
      "id": "Pythagoras",
      "deck": "Heading::Subheading",
      "model": "",
      "fields": {
        "front": {
          "plain": "Pythagoras"
        },
        "back": {
          "content": " Did you know?  +  =  ",
          "page_start": 2,
          "page_end": 2
        }
      },
      "tags": [
        "example"
      ]
    },
    "label": "<anki-export>"
  }
]
*/

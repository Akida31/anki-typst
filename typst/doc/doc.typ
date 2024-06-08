#import "@preview/tidy:0.3.0"
#import "../src/lib.typ" as anki

#set heading(numbering: (..num) => if num.pos().len() < 3 {
  numbering("1.1.", ..num)
})
#show heading.where(level: 1, outlined: true): inner => [
  #{
    set text(size: 24pt)
    inner
  }

  // #set text(size: 13pt)
  // Items:
]

#set document(title: "anki documentation")
#show link: it => underline(text(fill: blue, it))

#let version = [v#toml("../typst.toml").package.version]

#align(center + horizon)[
  #set text(size: 20pt)
  #block(text(weight: 700, size: 40pt, "anki-typst"))
  Create anki cards from typst.
  #v(40pt)
  #version
  #h(40pt)
  #datetime.today().display()

  // TODO
  // #link("https://repolink")
]

#pagebreak(weak: true)
#set page(numbering: "1/1")
#outline(indent: true, depth: 2)

#set page(numbering: "1/1", header: grid(columns: (auto, 1fr, auto),
  align(left, version),
  [],
  align(right)[anki-typst],
))

#pagebreak(weak: true)

#let module(name, path, private: false, do_pagebreak: true) = {
  let docs = tidy.parse-module(
    read(path),
    name: name,
    scope: (anki: anki),
    preamble: "import anki: *;",
    require-all-parameters: not private,
  )
  if do_pagebreak {
    pagebreak(weak: true)
  }
  tidy.show-module(
    docs,
    omit-private-definitions: true,
    first-heading-level: 2,
    show-outline: false,
  )
}

= Examples
#let example(name) = {
  let file_content = read(name).split("\n").slice(3).join("\n")
  tidy.show-example.show-example(raw(file_content), scale-preview: 100%, mode: "markup", scope: (anki: anki))
}

*Via theorem environment:*
#example("example1.typ")

*Via raw function:*
#example("example2.typ")

#pagebreak(weak: true)

= Function reference

#module("lib", "../src/lib.typ", do_pagebreak: false)
#module("raw", "../src/raw.typ")
#module("theorems", "../src/theorems.typ")

// #module("Private: config", "../src/config.typ", private: true)
// #module("Private: utils", "../src/utils.typ", private: true)

#import "config.typ": is_export, get_title
#import "raw.typ"
#import "utils.typ": assert_ty, to_plain, to_string

#import "@preview/ctheorems:1.1.2" as ct
#import ct: thmrules

// prevent shadowing
#let _global_numbering = numbering

#let anki_state = state(
  "anki_state",
  (
    "deck": "",
    "model": "",
  ),
)

#let deck(name) = {
  anki_state.update(state => {
    state.deck = name
    state
  })
}

#let model(name) = {
  anki_state.update(state => {
    state.model = name
    state
  })
}

#let _get_headings(loc) = {
  let levels = ()
  let elems = query(selector(heading).before(loc))
  for elem in elems {
    let body = to_plain(elem.body)
    if body == none {
      panic("headings must be plain text but got " + to_string(elem.body))
    }
    if elem.level == levels.len() + 1 {
      levels.push(body)
    } else if elem.level <= levels.len() {
      levels = levels.slice(0, count: elem.level - 1)
      levels.push(body)
    } else {
      // TODO
      panic("missing heading level. Got heading '" + body + "' with level " + str(elem.level) + " but last heading had level " + str(
        levels.len(),
      ))
    }
  }
  levels.join("::")
}

#let anki_thm(
  id,
  tags: (),
  deck: none,
  model: none,
  numbering: "1.1",
  ..fields,
) = {
  let _ = assert_ty("tags", tags, array)
  anki_state.display(state => {
    get_title(title => {
      locate(loc => {
        let deck = if deck != none {
          deck
        } else if state.deck != none and state.deck != "" {
          state.deck
        } else {
          let headings = _get_headings(loc)
          if title != none and title != "" {
            title + "::" + headings
          } else {
            headings
          }
        }
        
        let model = if model != none {
          model
        } else if state.model != none and state.model != "" {
          state.model
        } else {
          "anki-typst"
        }
        
        ct.thmcounters.display(x => {
          let number = none
          if numbering != none {
            number = _global_numbering(numbering, ..x.at("latest"))
          }
          raw.anki_export(
            id: id,
            tags: tags,
            deck: deck,
            model: model,
            number: number,
            ..fields,
          )
        })
      })
    })
  })
}

#let _item_inner(
  export,
  name,
  identifier,
  inner_args: (:),
  base: "heading",
  base_level: none,
  ..args,
) = {
  let item_name = name
  if export {
    let args_named = args.named()
    for key in ("inset", "separator") {
      let _ = args_named.remove(key, default: none)
    }
    let args_pos = args.pos()
    let inner(name, content) = {
      ct.thmenv(
        "items",
        base,
        base_level,
        (..args) => [],
        ..args_pos,
        ..args_named,
      )(name, content, supplement: name, ..inner_args)
    }
    
    return inner
  } else {
    let inner(name, content) = {
      ct.thmbox(
        "items",
        item_name,
        base: base,
        base_level: base_level,
        ..args,
      )(name, content, ..inner_args)
    }
    
    return inner
  }
}

#let _make_referencable(content, identifier, numbering) = {
  figure(
    content + [#metadata(identifier) <meta:anki-thmenvcounter>],
    placement: none,
    caption: none,
    kind: "anki-item",
    supplement: identifier,
    numbering: numbering,
    gap: 0em,
    outlined: false,
  )
}

#let item(
  name,
  identifier: "items",
  initial_tags: (),
  base_level: 2,
  inset: 0em,
  separator: [*.* #h(0.1em)],
  numbering: "1.1",
  ..args,
) = {
  let inner(
    front,
    content,
    tags: (),
    deck: none,
    model: none,
    clear_tags: false,
  ) = {
    let tags = if clear_tags {
      tags
    } else {
      (..initial_tags, ..tags)
    }
    let cont = is_export(export => {
      _item_inner(
        export,
        name,
        identifier,
        base_level: base_level,
        inset: inset,
        separator: separator,
        inner_args: (numbering: numbering),
        ..args,
      )(
        front,
        content,
      )
    })
    let meta = anki_thm(
      front,
      deck: deck,
      model: model,
      tags: tags,
      front: front,
      back: content,
      numbering: numbering,
    )
    
    _make_referencable(cont + meta, name, numbering)
  }
  return inner
}

#let item_with_proof(
  name,
  proof_name,
  identifier: "items",
  proof_identifier: "item",
  item_args: (:),
  proof_args: (:),
  initial_tags: (),
  base_level: 2,
  inset: 0em,
  separator: [*.* #h(0.1em)],
  numbering: "1.1",
) = {
  let inner(
    front,
    content,
    proof,
    tags: (),
    deck: none,
    model: none,
    clear_tags: false,
  ) = {
    let tags = if clear_tags {
      tags
    } else {
      (..initial_tags, ..tags)
    }
    
    let cont = is_export(export => {
      _item_inner(
        export,
        name,
        identifier,
        base_level: base_level,
        inset: inset,
        separator: separator,
        inner_args: (numbering: numbering),
        ..item_args,
      )(
        front,
        content,
      )
      
      if not export {
        ct.thmplain(
          proof_identifier,
          proof_name,
          // base: "theorem",
          // TODO prefer these from `proof_args`
          titlefmt: strong,
          separator: [*.*#h(0.2em)],
          bodyfmt: body => [#body #h(1fr) $square$],
          padding: (top: -0.5em),
          inset: 0em,
          ..proof_args,
        ).with(numbering: none)(proof)
      }
    })
    let meta = anki_thm(
      front,
      deck: deck,
      model: model,
      tags: tags,
      front: front,
      back: content,
      proof: proof,
      numbering: numbering,
    )
    
    _make_referencable(cont + meta, name, numbering)
  }
  
  return inner
}

#let setup(doc) = {
  show: thmrules
  
  // copied from ctheorems
  show figure.where(kind: "anki-item"): it => it.body
  show ref: it => {
    if it.element == none {
      return it
    }
    if it.element.func() != figure {
      return it
    }
    if it.element.kind != "anki-item" {
      return it
    }
    
    let supplement = it.element.supplement
    if it.citation.supplement != none {
      supplement = it.citation.supplement
    }
    
    let loc = it.element.location()
    let thms = query(selector(<meta:anki-thmenvcounter>).after(loc), loc)
    let number = ct.thmcounters.at(thms.first().location()).at("latest")
    return link(
      it.target,
      [#supplement~#numbering(it.element.numbering, ..number)],
    )
  }
  
  doc
}
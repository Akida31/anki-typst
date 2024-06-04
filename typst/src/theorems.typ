#import "config.typ": is_export, anki_config
#import "raw.typ"
#import "utils.typ": assert_ty, to_plain, to_string

#import "@preview/ctheorems:1.1.2" as ct

// prevent shadowing
#let _global_numbering = numbering

#let anki_state = state(
  "anki_state",
  (
    "deck": "",
    "model": "",
  ),
)

#let secondary_numbering_counter = counter("anki-secondary-numbering")

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

// prevent shadowing
#let _heading = heading
#let set_thmcounter(heading: none, items: none) = {
  if heading == none {
    heading = items.slice(0, -1)
  }
  counter(_heading).update(heading)
  ct.thmcounters.update(val => {
    val.counters.heading = heading
    if items != none {
      val.counters.items = items
      val.latest = items
    }
    val
  })
}

#let _with_get_number(loc, number, numbering, secondary, secondary_numbering, f, allow_auto: false, step_secondary: true) = {
  if number == auto and allow_auto and secondary == none {
    return f(auto) + secondary_numbering_counter.update(0)
  }
  if secondary == none {
    secondary_numbering_counter.update(0)
  }
  let (secondary_counter,) = secondary_numbering_counter.at(loc)
  if step_secondary and (secondary == auto or secondary == true) {
    secondary_numbering_counter.step()
    secondary_counter += 1
  }
  let secondary = secondary
  if secondary == auto or secondary == true {
      secondary = _global_numbering(secondary_numbering, secondary_counter)
  }
  let x = ct.thmcounters.at(loc)
  let prev = if numbering != none {
    _global_numbering(numbering, ..x.at("latest"))
  } else {
    none
  }
  if secondary != none {
    prev = prev + secondary
  }
  if number == auto {
    f(prev)
  } else if type(number) == function {
    f(number(prev))
  } else {
    f(number)
  }
}

#let _get_headings(loc, prefix_deck_names_with_numbers) = {
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
  if prefix_deck_names_with_numbers {
    let numbers = counter(heading).at(loc)
    levels = numbers.zip(levels).map(args => {
      let (number, body) = args
      str(number) + " - " + body
    })
  }

  levels.join("::")
}

#let anki_thm(
  id,
  tags: (),
  deck: none,
  model: none,
  numbering: "1.1",
  number: auto,
  secondary: none,
  secondary_numbering: "a",
  ..fields,
) = {
  locate(loc => {
    anki_thm_with_loc(
      loc,
      id,
      tags: tags,
      deck: deck,
      model: model,
      numbering: numbering,
      number: number,
      secondary: secondary,
      secondary_numbering: secondary_numbering,
      ..fields
    )
  })
}

#let anki_thm_with_loc(
  loc,
  id,
  tags: (),
  deck: none,
  model: none,
  numbering: "1.1",
  number: auto,
  secondary: none,
  secondary_numbering: "a",
  ..fields,
) = {
  let _ = assert_ty("tags", tags, array)
  let state = anki_state.at(loc)
  let config = anki_config.at(loc)
  let deck = if deck != none {
    deck
  } else if state.deck != none and state.deck != "" {
    state.deck
  } else {
    let headings = _get_headings(
      loc,
      config.prefix_deck_names_with_numbers,
    )
    if config.title_as_deck_name and config.title != none and config.title != "" {
      config.title + "::" + headings
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

  _with_get_number(
    loc,
    number,
    numbering,
    secondary,
    secondary_numbering,
    step_secondary: false,
    number => raw.anki_export(
      id: id,
      tags: tags,
      deck: deck,
      model: model,
      number: number,
      ..fields,
    ),
  )
}

#let _item_inner(
  loc,
  export,
  name,
  identifier,
  inner_args: (:),
  base: "heading",
  base_level: none,
  breakable: true,
  create_item_label: true,
  item_label_prefix: "",
  number: auto,
  numbering: "1.1",
  secondary: none,
  secondary_numbering: "a",
  ..args,
) = {
  let item_name = name
  if export {
    let args_named = args.named()
    for key in ("inset", "separator") {
      let _ = args_named.remove(key, default: none)
    }
    let args_pos = args.pos()
    // not really used, just there to keep numbering
    let inner(name, content) = _with_get_number(loc, number, numbering, secondary, secondary_numbering, allow_auto: true, step_secondary: true, number => [
      #ct.thmenv(
        "items",
        base,
        base_level,
        (..args) => [],
        ..args_pos,
        ..args_named,
      )(
        name,
        content,
        supplement: name,
        number: number,
        numbering: numbering,
        ..inner_args,
      )
      #if create_item_label {
        let name = item_label_prefix + name
        label(name)
      }
    ])

    return inner
  } else {
    let inner(name, content) = _with_get_number(loc, number, numbering, secondary, secondary_numbering,allow_auto: true, step_secondary: true, number => [
      #ct.thmbox(
        "items",
        item_name,
        base: base,
        base_level: base_level,
        breakable: breakable,
        ..args,
      )(name, content, number: number, numbering: numbering, ..inner_args)
      #if create_item_label {
        let name = to_plain(name)
        if name != none {
          let name = item_label_prefix + name
          label(name)
        }
      }
    ])

    return inner
  }
}

#let _make_referencable(
  name,
  content,
  identifier,
  numbering,
) = {
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
  create_item_label: true,
  item_label_prefix: "",
  secondary_numbering: "a",
  item_args: (:),
  id: fields => fields.at("plain_front"),

  proof_name: "Proof",
  proof_identifier: "item",
  proof_args: (:),
) = {
  let inner(
    front,
    content,
    tags: (),
    deck: none,
    model: none,
    clear_tags: false,
    number: auto,
    secondary: none,
    ..maybe_proof,
  ) = {
    let proof = (() => {
      let pos = maybe_proof.pos()
      if pos.len() == 0 {
        for (key, value) in maybe_proof.named() {
          if key != "proof" {
            panic("expected only keyword `proof` but got " + str(proof))
          }
          return value;
        }
        return none
      }
      if pos.len() != 1 {
        panic("expected only one positional (`proof`) argument but got " + str(pos.len()))
      }
      return pos.at(0)
    })()

    let tags = if clear_tags {
      tags
    } else {
      (..initial_tags, ..tags)
    }

    let cont_meta = locate(loc => {
      let export = is_export()
      let cont = {
        _item_inner(
          loc,
          export,
          name,
          identifier,
          base_level: base_level,
          create_item_label: create_item_label,
          item_label_prefix: item_label_prefix,
          inset: inset,
          separator: separator,
          number: number,
          secondary: secondary,
          secondary_numbering: secondary_numbering,
          inner_args: (numbering: numbering),
          ..item_args,
        )(
          front,
          content,
        )

        if not export and proof != none {
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
      }
      let plain_front = to_plain(front)
      if plain_front == none {
        plain_front = front
      }
      let meta = if export {
        _with_get_number(loc, number, numbering, secondary, secondary_numbering, allow_auto: false, step_secondary: false, number => {
          let fields = (
            front: front,
            back: content,
            proof: proof,
          )

          let identifier = id((
            plain_front: plain_front,
            deck: deck,
            model: model,
            number: number,
            secondary: secondary,
            ..fields
          ))
          return anki_thm_with_loc(
            loc,
            identifier,
            deck: deck,
            model: model,
            number: number,
            numbering: numbering,
            secondary: secondary,
            secondary_numbering: secondary_numbering,
            tags: tags,
            ..fields,
          )
        })
      } else [
      ]
      return cont + meta
    })

    _make_referencable(
      front,
      cont_meta,
      name,
      numbering,
    )
  }

  return inner
}

// copied from ctheorems
// since we don't use `thm-qedhere` we can remove this functionality to get some speedups
#let thmrules(doc) = {
  show figure.where(kind: "thmenv"): it => it.body

  show ref: it => {
    if it.element == none {
      return it
    }
    if it.element.func() != figure {
      return it
    }
    if it.element.kind != "thmenv" {
      return it
    }

    let supplement = it.element.supplement
    if it.citation.supplement != none {
      supplement = it.citation.supplement
    }

    let loc = it.element.location()
    let thms = query(selector(<meta:thmenvcounter>).after(loc), loc)
    let number = thmcounters.at(thms.first().location()).at("latest")
    return link(
      it.target,
      [#supplement~#numbering(it.element.numbering, ..number)]
    )
  }

  doc
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

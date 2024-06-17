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

/// Set the current deck name.
///
/// - name (str): New name.
#let deck(name) = {
  anki_state.update(state => {
    state.deck = name
    state
  })
}

/// Set the current model name.
///
/// - name (str): New name.
#let model(name) = {
  anki_state.update(state => {
    state.model = name
    state
  })
}

// prevent shadowing
#let _heading = heading

/// Set the counter for the theorems.
///
/// *Example*:
/// #example(```
/// anki.theorems.set_thmcounter(items: (3, 5, 7))
/// // After this, the next item will have the number 1.0.2
/// anki.theorems.set_thmcounter(items: (1, 0, 1))
/// ```, ratio: 100, scale-preview: 100%)
///
/// - heading (int, array, function): The new heading counter value.
/// - items (array): The new item counter value.
///     Each element in `items` corresponds to a level.
///     The `base_level` argument of `item` corresponds to the number of `items`.
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

/// Get the current number.
///
/// - loc (location): Current location.
/// - number (auto, function, array): Primary number.
/// - numbering (str, function, none): Primary numbering pattern
/// - secondary (none, auto, true, function, array): Secondary number.
/// - secondary_numbering (str, function, none): Secondary numbering pattern.
/// - f (function): Closure which will be called with the resolved number.
/// - allow_auto (bool): If `allow_auto` is `true`, `secondary` is `none` and `number` is auto, this will call the closure with just `auto`.
/// - step_secondary (bool): Whether to step the secondary counter.
///     This argument is necessary to prevent stepping the secondary counter multiple times for one item.
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

/// Get the deck name from headings.
///
/// The headings will be joined with `::` to create anki subdecks.
///
/// - loc (location): Current location
/// - prefix_deck_names_with_numbers (bool): Whether the deck names will be prefixed with the corresponding heading number.
/// -> str
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

/// Same as `anki_thm` but takes the current location.
///
/// This should improve performance if you already called `locate`.
///
/// - loc (location): The current location.
/// - id (str): The id of the card. Used to update the card later on.
/// - tags (array): Tags to add to the card.
/// - deck (none, str): Name of the deck.
///     Anki nests decks with `::`, so you can try `Deck::Subdeck`.
///     If `deck` is `none` it will be read from state.
/// - model (none, str): Name of the model.
///     If `model` is `none` it will be read from state.
/// - number (auto, function, array): The primary number of the card.
/// - numbering (str, function, none): The pattern for the primary number.
/// - secondary (none, auto, true, function, array): The secondary number of the card.
/// - secondary_numbering (str, function, none): The pattern for the secondary number.
/// - ..fields (arguments): Additional fields for the anki card.
#let _anki_thm_with_loc(
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
    if config.title != none and config.title != "" {
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
    number => raw._anki_export_with_config(
      config,
      id: id,
      tags: tags,
      deck: deck,
      model: model,
      number: number,
      ..fields,
    ),
  )
}

/// Create an anki card.
///
/// *Example*
/// #example(```
/// #import anki.theorems: anki_thm
///
/// #anki_thm(
///   "id 29579",
///   tags: ("Perfect", ),
///   deck: "beauty",
///   question: "Are you beautiful?",
///   answer: "Yes!",
/// )
/// ```, scale-preview: 100%, mode: "markup", preamble: "", scope: (_anki_thm_with_loc: anki.theorems._anki_thm_with_loc), ratio: 1000)
///
/// - id (str): The id of the card. Used to update the card later on.
/// - tags (array): Tags to add to the card.
/// - deck (none, str): Name of the deck.
///     Anki nests decks with `::`, so you can try `Deck::Subdeck`.
///     If `deck` is `none` it will be read from state.
/// - model (none, str): Name of the model.
///     If `model` is `none` it will be read from state.
/// - number (auto, function, array): The primary number of the card.
/// - numbering (str, function, none): The pattern for the primary number.
/// - secondary (none, auto, true, function, array): The secondary number of the card.
/// - secondary_numbering (str, function, none): The pattern for the secondary number.
/// - ..fields (arguments): Additional fields for the anki card.
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
    _anki_thm_with_loc(
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

/// Inner function which calls ctheorems.
///
/// - loc (location): Current location.
/// - export (bool): Whether export mode is enabled.
/// - name (str): Name of the item for `ctheorems.thmbox`.
/// - inner_args (dict): Arguments which will be passed to `ctheorems`.
/// - base (none, str): Base for `ctheorems`. `none` means "do not attach, count globally".
/// - base_level (none, int): The number of levels from base to take for item numbering. `none` means "use the base as-is".
/// - breakable (bool): Argument to the `block` of `ctheorems`. Whether to allow (page) breaks inside the item.
/// - create_item_label (bool): Whether to create a new label for this item. The label will be `item_level_prefix + name`
/// - item_label_prefix (str): Prefix for item labels.
/// - number (auto, function, array): The primary number of the card.
/// - numbering (str, function, none): The pattern for the primary number.
/// - secondary (none, auto, true, function, array): The secondary number of the card.
/// - secondary_numbering (str, function, none): The pattern for the secondary number.
/// - ..args (arguments): Arguments which will be passed to `ctheorems`.
#let _item_inner(
  loc,
  export,
  name,
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

/// Make the body referenceable.
///
/// This function is necessary because we use functions like `locate` which create opaque content,
/// which can't be referenced.
/// So this function wraps the content in a figure.
///
/// - body (content): The body to wrap.
/// - identifier (str): The identifier of the content. This will be available as metadata at `<meta:anki-thmenvcounter>` and the supplement of the figure.
/// - numbering (none, str, function): The numbering of the figure.
#let _make_referencable(
  body,
  identifier,
  numbering,
) = {
  figure(
    body + [#metadata(identifier) <meta:anki-thmenvcounter>],
    placement: none,
    caption: none,
    kind: "anki-item",
    supplement: identifier,
    numbering: numbering,
    gap: 0em,
    outlined: false,
  )
}

/// Main function to create anki items.
///
/// This function returns a function which represents an item kind.
/// You can call the returned function multiple times to create multiple items.
///
/// *Examples*
/// #example(```
/// #import anki.theorems: item
/// // Don't forget this!
/// #show: anki.setup.with(enable_theorems: true)
///
/// // create item kinds
/// #let example = item("Example", initial_tags: ("example",))
/// #let theorem = item("Theorem", proof_name: "\"Proof\"")
///
/// // create item
/// #example("Pythagoras")[
///  $ a^2 + b^2 = c^2 $
/// ]
///
/// // use secondary numbering
/// #example("triangle", secondary: auto)[
///   #sym.triangle.tr.filled
/// ]
/// #example("another triangle", secondary: auto)[
///   #sym.triangle.t.stroked
/// ]
///
/// // and a theorem, with a custom number
/// #theorem("Triangular numbers", number: "42")[
///   The triangular numbers are given by:
///   $ T_n = sum_(k=1)^n k = (n(n+1))/2 $
/// ][
///   Induction over n.
/// ]
/// ```, scale-preview: 100%, mode: "markup", preamble: "")
///
/// - name (str): Name of the item kind.
/// - initial_tags (array): Tags to add to each item of this kind.
///   To remove these tags pass `clear_tags: true` to the inner function.
/// - base_level (none, int): The number of levels from headings to take for item numbering.
///     `none` means "use all heading levels".
/// - inset (relative, dictionary): How much to pad the block's content.
/// - separator (content): Separator between name and body.
/// - numbering (str, function, none): The numbering pattern for the primary number.
/// - secondary_numbering (str, function): The numbering pattern for the secondary number.
/// - create_item_label (bool): Whether to create a new label for each item of this kind. The label will be `item_level_prefix + name`
/// - item_label_prefix (str): Prefix for item labels.
/// - item_args (dict): Arguments which will be passed to `ctheorems` for each item of this kind.
/// - id (function): Function to create the id of the card.
///      The id must be unique as it is used to update cards later on.
///      The function will be called with `plain_front, deck, model, number, secondary, ..fields`.
/// - proof_name (str): How the proof (or in general second argument) should be called.
/// - proof_args (dict): Arguments which will be passed to `ctheorems` for each proof.
#let item(
  name,
  initial_tags: (),
  base_level: 2,
  inset: 0em,
  separator: [. #h(0.1em)],
  numbering: "1.1",
  secondary_numbering: "a",
  create_item_label: true,
  item_label_prefix: "",
  item_args: (:),
  id: fields => fields.at("plain_front"),
  proof_name: "Proof",
  proof_args: (:),
) = {

  /// Inner function to create anki items.
  ///
  /// - front (content, str): Front content for the card.
  /// - content (content): Main content for the card.
  /// - tags (array): Tags to add to the card.
  /// - deck (none, str): Name of the deck.
  ///     Anki nests decks with `::`, so you can try `Deck::Subdeck`.
  ///     If `deck` is `none` it will be read from state.
  /// - model (none, str): Name of the model.
  ///     If `model` is `none` it will be read from state.
  /// - clear_tags (bool): Remove `initial_tags` and use only `tags`.
  /// - number (auto, function, array): The primary number of the card.
  /// - secondary (none, auto, true, function, array): The secondary number of the card.
  /// - ..maybe_proof (none, content): The proof of the card if specified.
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
            panic("expected only keyword `proof` but got " + str(key))
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
      let export = is_export(loc)
      let cont = {
        _item_inner(
          loc,
          export,
          name,
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
            "items",
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
          return _anki_thm_with_loc(
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
      cont_meta,
      name,
      numbering,
    )
  }

  return inner
}

/// Show-rule for theorems.
///
/// Copied from ctheorems, since we don't use `thm-qedhere` we can remove this functionality to get some speedups.
///
/// - doc (content): The document to wrap.
/// -> content
#let _thmrules(doc) = {
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
    let number = ct.thmcounters.at(thms.first().location()).at("latest")
    return link(
      it.target,
      [#supplement~#numbering(it.element.numbering, ..number)]
    )
  }

  doc
}

/// Setup the document
///
/// This is crucial for displaying everything correctly!
///
/// *Example*:
/// #example(`show: anki.theorems.setup`, ratio: 1000, scale-preview: 100%)
///
/// - doc (content): The document to wrap.
/// -> content
#let setup(doc) = {
  show: _thmrules

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

#import "config.typ": anki_config
#import "utils.typ": assert_ty, to_plain, get_label_page, to_string

/// Same as `anki_export` but takes the config.
///
/// This is to remove double reads/ state dependencies.
///
/// - config (dict): `anki_config`
/// - id (str): The id of the card. Used to update the card later on.
/// - tags (array): Tags to add to the card.
/// - deck (str): Name of the card deck. Anki nests decks with `::`, so you can try `Deck::Subdeck`.
/// - model (str): Name of the card model.
/// - number (int, str, none): The number of the card. Not really special but passed differently to the command line interface.
/// - ..fields (arguments): Additional fields for the anki card.
#let _anki_export_with_config(
  config,
  id: none,
  tags: (),
  deck: none,
  model: none,
  number: none,
  ..fields,
) = {
  for tag in tags {
    let _ = assert_ty("tag", tag, str)
  }
  if fields.pos().len() > 0 {
    panic("expected only named arguments", fields.pos())
  }
  assert(id != none)
  assert(deck != none)
  assert(model != none)
  let _ = assert_ty("deck", deck, str)
  let _ = assert_ty("model", model, str)

  if type(id) == content {
    panic("id may not be content but was " + id)
  }
  let id = str(id)

  let fields = fields.named()
  if config.export {
    locate(loc => {
      let meta = (
        id: id,
        deck: deck,
        model: model,
        fields: (:),
        tags: tags,
      )
      if config.date != none {
        meta.fields.insert("date", config.date)
      }
      if number != none {
        meta.fields.insert("number", number)
      }
      for (name, val) in fields.pairs() {
        let plain = to_plain(val)
        let spacer = "<<anki>>"
        let start_id = deck + id + name + "start"
        let end_id = deck + id + name + "end"
        let page_start = get_label_page(start_id, deck + "." + id, loc)
        let page_end = get_label_page(end_id, deck + "." + id, loc)

        if val == none {
          // ensure that duplicate ids get detected
          [
            #[] #label(start_id)
            #[] #label(end_id)
          ]
          meta.fields.insert(
            name,
            none,
          )
        } else if plain == none {
          [
            #pagebreak(weak: true)
            #[] #label(start_id)
            #val
            #[] #label(end_id)
          ]
          meta.fields.insert(
            name,
            (
              content: to_string(val),
              page_start: page_start,
              page_end: page_end,
            ),
          )
        } else {
          // ensure that duplicate ids get detected
          [
            #[] #label(start_id)
            #[] #label(end_id)
          ]
          meta.fields.insert(
            name,
            (
              plain: plain,
            ),
          )
        }
      }
      [#metadata(meta) <anki-export>]
    })
    pagebreak(weak: true)
  }
}

/// Create an anki card.
///
/// Even though the default values of `id`, `deck` and `model` are `none`, they are required! \
/// This does not create the card on its own, you have to use the command line interface!
///
/// *Example*
/// #example(```
/// #import anki: anki_export
///
/// #anki_export(
///   id: "id 29579",
///   tags: ("Perfect", ),
///   deck: "beauty",
///   model: "simple",
///   question: "Are you beautiful?",
///   answer: "Yes!",
/// )
/// ```, scale-preview: 100%, mode: "markup", preamble: "", scope: (_anki_export_with_config: anki.theorems.raw._anki_export_with_config), ratio: 1000)
///
///
/// - id (str): The id of the card. Used to update the card later on.
/// - tags (array): Tags to add to the card.
/// - deck (str): Name of the card deck. Anki nests decks with `::`, so you can try `Deck::Subdeck`.
/// - model (str): Name of the card model.
/// - number (int, str, none): The number of the card. Not really special but passed differently to the command line interface.
/// - ..fields (arguments): Additional fields for the anki card.
#let anki_export(
  id: none,
  tags: (),
  deck: none,
  model: none,
  number: none,
  ..fields,
) = {
  anki_config.display(config => {
    _anki_export_with_config(config, id: id, tags: tags, deck: deck, model: model, number: number, ..fields)
  })
}

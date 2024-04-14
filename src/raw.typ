#import "config.typ": anki_config
#import "utils.typ": assert_ty, to_plain, get_label_page, to_string

#let anki_export(
  id: none,
  tags: (),
  deck: none,
  model: none,
  in_container: false,
  ..fields,
) = {
  for tag in tags {
    let _ = assert_ty("tag", tag, str)
  }
  if fields.pos().len() > 0 {
    panic("expected only named arguments")
  }
  assert(id != none)
  assert(deck != none)
  assert(model != none)
  let _ = assert_ty("deck", deck, str)
  let _ = assert_ty("model", model, str)
  
  let id = str(id)
  
  let fields = fields.named()
  anki_config.display(config => {
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
        for (name, val) in fields.pairs() {
          let plain = to_plain(val)
          let spacer = "<<anki>>"
          let start_id = deck + id + name + "start"
          let end_id = deck + id + name + "end"
          let page_start = get_label_page(start_id, deck + "." + id, loc)
          let page_end = get_label_page(end_id, deck + "." + id, loc)
          
          if plain == none {
            [
              #if not in_container {
                pagebreak(weak: true)
              }
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
      if not in_container {
        pagebreak(weak: true)
      }
    }
  })
}

mod types;

use std::{borrow::Cow, collections::HashMap};

use color_eyre::{Help, Result};
use serde::{Deserialize, Serialize};
use tracing::debug;

use types::{empty, Request};

pub fn request<'a, T: Serialize + 'a, U: for<'de> Deserialize<'de> + std::fmt::Debug>(
    action: impl Into<Cow<'a, str>>,
    data: &'a T,
) -> Result<U> {
    let action = action.into();

    debug!("requesting action {}", action);
    let request = Request::new(action.clone(), data);
    let res = match ureq::post("http://localhost:8765").send_json(&request) {
        Ok(v) => v,
        Err(e) => {
            if let ureq::Error::Transport(ref t) = e {
                if t.kind() == ureq::ErrorKind::ConnectionFailed {
                    return Err(e)
                        .note("is anki open?")
                        .note("you also need to install anki-connect: https://ankiweb.net/shared/info/2055492159");
                }
            }
            return Err(e.into());
        }
    };

    debug!("got response with status {}", res.status());
    let raw = res.into_string()?;
    let res: std::result::Result<types::ReqResult<U>, _> = serde_json::from_str(&raw);
    match res {
        Ok(v) => v.get().with_note(|| format!("action was {action}")),
        Err(e) => Result::Err(e).with_note(|| format!("body: {raw}")),
    }
}

pub fn request_multi<'a, T: Serialize + 'a, U: for<'de> Deserialize<'de> + std::fmt::Debug>(
    action: &str,
    data: impl IntoIterator<Item = T>,
) -> Result<Vec<U>> {
    #[derive(Debug, Serialize)]
    #[serde(rename_all = "camelCase")]
    struct Params<'a, T: 'a> {
        actions: Vec<InnerParams<'a, T>>,
    }

    #[derive(Debug, Serialize)]
    #[serde(rename_all = "camelCase")]
    struct InnerParams<'a, T: 'a> {
        action: &'a str,
        params: T,
    }

    let res = request::<_, Vec<types::ReqResult<U>>>(
        "multi",
        &Params {
            actions: data
                .into_iter()
                .map(|params| InnerParams { action, params })
                .collect::<Vec<_>>(),
        },
    )?;
    res.into_iter().map(types::ReqResult::get).collect()
}

/// Returns
/// - `id` if the note was created
/// - `None` if the note wasn't created (e.g. duplicate)
pub fn create_deck(deck: &str) -> Result<Option<usize>> {
    #[derive(Debug, Serialize)]
    #[serde(rename_all = "camelCase")]
    struct Params<'a> {
        deck: &'a str,
    }

    request("createDeck", &Params { deck })
}

#[derive(Debug, Deserialize)]
pub struct DeckNames(pub Vec<String>);

pub fn get_deck_names() -> Result<DeckNames> {
    request("deckNames", &empty())
}

#[derive(Debug, Deserialize)]
pub struct ModelNames(pub Vec<String>);

pub fn get_model_names() -> Result<ModelNames> {
    request("modelNames", &empty())
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
#[serde(untagged)]
pub enum SingleOrMulti<T> {
    Multi(Vec<T>),
    Single(T),
}

impl<T> Default for SingleOrMulti<T> {
    fn default() -> Self {
        Self::Multi(Vec::default())
    }
}

impl<T> SingleOrMulti<T> {
    #[allow(unused)]
    pub fn into_vec(self) -> Vec<T> {
        match self {
            Self::Multi(v) => v,
            Self::Single(v) => vec![v],
        }
    }
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaData {
    /// To prevent Anki from removing files not used by any cards (e.g. for configuration files), prefix the filename with an underscore
    pub(crate) filename: String,
    #[serde(flatten)]
    pub(crate) inner: MediaDataInner,
    #[serde(default = "MediaData::default_delete_existing")]
    pub(crate) delete_existing: bool,
}

impl MediaData {
    const fn default_delete_existing() -> bool {
        true
    }
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum MediaDataInner {
    Data(String),
    Path(String),
    Url(String),
}

/// returns the assigned filename
pub fn store_media_file(data: &MediaData) -> Result<String> {
    request("storeMediaFile", data)
}

#[derive(Default, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Note {
    pub deck_name: String,
    pub model_name: String,
    pub fields: HashMap<String, String>,
    pub tags: Vec<String>,
    #[serde(default)]
    pub audio: SingleOrMulti<MediaData>,
    #[serde(default)]
    pub video: SingleOrMulti<MediaData>,
    #[serde(default)]
    pub picture: SingleOrMulti<MediaData>,
    // TODO
    // options
}

#[derive(Debug, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct NoteInfoField {
    pub value: String,
    pub order: usize,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NoteInfo {
    pub note_id: usize,
    pub model_name: String,
    pub fields: HashMap<String, NoteInfoField>,
    pub tags: Vec<String>,
    pub cards: Vec<usize>,
}

pub fn add_notes(notes: &[Note]) -> Result<Vec<Option<usize>>> {
    #[derive(Debug, Serialize)]
    #[serde(rename_all = "camelCase")]
    struct NoteParams<'a> {
        notes: &'a [Note],
    }

    request("addNotes", &NoteParams { notes })
}

/// Returns
/// - `id` if the note was created
/// - `None` if the note wasn't created (e.g. duplicate)
#[allow(unused)]
pub fn add_note(note: &Note) -> Result<Option<usize>> {
    #[derive(Debug, Deserialize)]
    pub struct AddNote(Option<usize>);

    #[derive(Debug, Serialize)]
    #[serde(rename_all = "camelCase")]
    struct NoteParams<'a> {
        note: &'a Note,
    }

    let res = request::<_, AddNote>("addNote", &NoteParams { note });
    match res {
        Err(e)
            if e.root_cause()
                .to_string()
                .ends_with("cannot create note because it is a duplicate") =>
        {
            Ok(None)
        }
        Err(e) => Err(e),
        Ok(AddNote(res)) => Ok(res),
    }
}

#[derive(Debug, Deserialize)]
pub struct ModelFieldNames(pub Vec<String>);
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ModelFieldNameParams<'a> {
    model_name: &'a str,
}

#[allow(unused)]
pub fn get_model_field_names(model_name: &str) -> Result<ModelFieldNames> {
    request("modelFieldNames", &ModelFieldNameParams { model_name })
}

pub fn get_model_field_names_multi<'a>(
    model_names: impl IntoIterator<Item = impl Into<&'a str>>,
) -> Result<Vec<ModelFieldNames>> {
    request_multi(
        "modelFieldNames",
        model_names
            .into_iter()
            .map(|model_name| ModelFieldNameParams {
                model_name: model_name.into(),
            }),
    )
}

/// See <https://docs.ankiweb.net/searching.html>
pub fn find_notes(query: &str) -> Result<Vec<usize>> {
    #[derive(Debug, Serialize)]
    #[serde(rename_all = "camelCase")]
    struct Params<'a> {
        query: &'a str,
    }

    request("findNotes", &Params { query })
}

pub fn notes_info(ids: &[usize]) -> Result<Vec<NoteInfo>> {
    #[derive(Debug, Serialize)]
    #[serde(rename_all = "camelCase")]
    struct Params<'a> {
        notes: &'a [usize],
    }

    request("notesInfo", &Params { notes: ids })
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CardInfo {
    pub answer: String,
    pub question: String,
    pub deck_name: String,
    pub model_name: String,
    pub field_order: i32,
    pub fields: HashMap<String, NoteInfoField>,
    pub css: String,
    pub card_id: usize,
    pub interval: i32,
    pub note: usize,
    pub ord: i32,
    pub r#type: i32,
    pub queue: i32,
    pub due: i32,
    pub reps: i32,
    pub lapses: i32,
    pub left: i32,
    pub r#mod: i32,
}

pub fn cards_info(ids: &[usize]) -> Result<Vec<CardInfo>> {
    #[derive(Debug, Serialize)]
    #[serde(rename_all = "camelCase")]
    struct Params<'a> {
        cards: &'a [usize],
    }

    request("cardsInfo", &Params { cards: ids })
}

pub fn sync() -> Result<()> {
    request("sync", &empty())
}

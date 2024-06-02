use indexmap::IndexMap;
use serde::de::Error;
use serde::Deserialize;
use std::fmt::Formatter;

const EXPORT_LABEL: &str = "<anki-export>";

#[derive(Debug, Clone, PartialEq, Deserialize)]
pub struct Metadata(pub Vec<InnerMetadata>);

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(remote = "Self")]
pub struct InnerMetadata {
    // must be `metadata`
    func: String,
    pub(crate) value: Note,
    // must be EXPORT_LABEL
    label: String,
}

impl<'de> Deserialize<'de> for InnerMetadata {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let this = Self::deserialize(deserializer)?;

        if this.func != "metadata" {
            return Err(Error::custom(format!(
                "func must be metadata but was {}",
                this.func
            )));
        }
        if this.label != EXPORT_LABEL {
            return Err(Error::custom(format!(
                "label must be {} but was {}",
                EXPORT_LABEL, this.label
            )));
        }

        Ok(this)
    }
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
pub struct Note {
    // may be [`None`] for notes coming from anki
    pub(crate) id: Option<String>,
    pub(crate) deck: String,
    pub(crate) model: String,
    pub(crate) fields: IndexMap<String, Field>,
    pub(crate) tags: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(untagged)]
pub enum Field {
    Raw(String),
    Plain {
        plain: String,
    },
    Content {
        content: String,
        page_start: usize,
        page_end: usize,
    },
    Empty,
}

impl std::fmt::Display for Field {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::Raw(val) => val,
            Self::Plain { plain } => plain,
            Self::Content { content, .. } => content,
            Self::Empty => "",
        })
    }
}

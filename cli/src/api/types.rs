use color_eyre::{eyre::eyre, Help, Result};
use std::borrow::Cow;

use serde::{Deserialize, Serialize};

#[derive(Serialize)]
pub struct Request<'a, T> {
    action: Cow<'a, str>,
    params: &'a T,
    version: i32,
}

impl<'a, T: Serialize> Request<'a, T> {
    pub fn new(action: impl Into<Cow<'a, str>>, params: &'a T) -> Self {
        Self {
            action: action.into(),
            params,
            version: 6,
        }
    }
}

pub fn empty() -> impl Serialize {
    serde_json::map::Map::new()
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum ReqResult<T> {
    Raw(T),
    Struct(ReqResultStruct<T>),
}

impl<T: std::fmt::Debug> ReqResult<T> {
    pub fn get(self) -> Result<T> {
        match self {
            Self::Raw(t) => Ok(t),
            Self::Struct(s) => s.get(),
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct ReqResultStruct<T> {
    result: Option<T>,
    error: Option<String>,
}

impl<T: std::fmt::Debug> ReqResultStruct<T> {
    pub fn get(self) -> Result<T> {
        match (self.result, self.error) {
            (None, None) => Err(eyre!("invalid response, got neither result or error")),
            (None, Some(error)) => Err(eyre!("anki returned an error: {}", error)),
            (Some(result), None) => Ok(result),
            (Some(result), Some(error)) => Err(eyre!("invalid response, got result and error")
                .with_note(|| format!("the result was {result:?}"))
                .with_note(|| format!("the error was {error}"))),
        }
    }
}

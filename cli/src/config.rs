use std::path::PathBuf;

use color_eyre::eyre::eyre;
use color_eyre::{Help, Result};
use regex::Regex;
use serde::Deserialize;
use tracing::info;

#[derive(Debug)]
pub struct RegexString {
    re: Regex,
    re_str: String,
}

impl<'de> Deserialize<'de> for RegexString {
    fn deserialize<D>(deserializer: D) -> std::result::Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        use serde::de::Error;
        let re_str: String = serde::Deserialize::deserialize(deserializer)?;

        let re = Regex::new(&re_str).map_err(Error::custom)?;

        Ok(Self { re, re_str })
    }
}

#[derive(Debug)]
pub struct Config {
    pub path: Option<PathBuf>,
    pub file_include: Vec<RegexString>,
    pub file_exclude: Vec<RegexString>,
    pub add_generated: bool,
    pub add_generation_date: Option<String>,
}

impl Config {
    pub fn load(add_generated: bool, add_generation_date: Option<String>) -> Result<Self> {
        #[derive(Default, serde::Deserialize)]
        struct ExternalConfig {
            path: Option<PathBuf>,
            #[serde(default)]
            file_include: Vec<RegexString>,
            #[serde(default)]
            file_exclude: Vec<RegexString>,
        }

        let project_dirs = directories_next::ProjectDirs::from("", "akida", "anki-typst")
            .expect("no valid home directory path could be found");
        let config_dir = project_dirs.config_dir();
        if !config_dir.is_dir() {
            std::fs::create_dir_all(config_dir)?;
        }
        let config_path = config_dir.join("config.toml");

        let config: ExternalConfig = if !config_path.is_file() {
            info!(
                "no config file found. You can create one at {}",
                config_path.to_string_lossy()
            );
            ExternalConfig::default()
        } else {
            let config_text = std::fs::read_to_string(&config_path).with_note(|| {
                eyre!(
                    "while reading config file from {}",
                    config_path.to_string_lossy()
                )
            })?;
            toml::from_str(&config_text).with_note(|| {
                eyre!(
                    "while parsing config file from {}",
                    config_path.to_string_lossy()
                )
            })?
        };

        Ok(Self {
            path: config.path,
            file_include: config.file_include,
            file_exclude: config.file_exclude,
            add_generated,
            add_generation_date,
        })
    }

    pub fn is_ignored(&self, path: &str) -> bool {
        if !self.file_include.is_empty() {
            if !self.file_include.iter().any(|r| r.re.is_match(path)) {
                info!(
                    "ignoring {} because it is not included (regex={})",
                    path,
                    self.file_include
                        .iter()
                        .map(|r| format!("\"{}\"", r.re_str))
                        .collect::<Vec<_>>()
                        .join(", ")
                );
                return true;
            }
        }
        for RegexString { re, re_str } in &self.file_exclude {
            if re.is_match(path) {
                info!(
                    "ignoring {} because it is excluded (regex={})",
                    path, re_str
                );
                return true;
            }
        }
        false
    }
}

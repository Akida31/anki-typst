use clap::Parser;
use color_eyre::eyre::{bail, eyre};
use color_eyre::{Help, Result};
use notify::{Event, EventKind, RecursiveMode, Watcher};
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use tracing::{debug, error, info, Level};
use tracing_subscriber::FmtSubscriber;

use crate::api::{
    add_notes, create_model, get_model_field_names_multi, CreateModelData, MediaData,
    MediaDataInner, SingleOrMulti,
};
use crate::interface::{compile, query, CompileOutput, ThemedCompileOutput};
use crate::metadata::{Field, Note};
use api::{cards_info, find_notes, get_deck_names, get_model_names, notes_info, sync};
use config::Config;

mod api;
mod config;
mod interface;
mod metadata;

const BIN_NAME: &str = "anki-typst";

#[derive(Debug, Clone)]
pub struct NoteWithInfo {
    pub note: Note,
    pub id: Option<usize>,
    // just for error messages
    pub question: Option<String>,
}

impl PartialEq<Note> for NoteWithInfo {
    fn eq(&self, oinner: &Note) -> bool {
        let inner = &self.note;
        let matching =
            inner.deck == oinner.deck && inner.model == oinner.model && inner.tags == oinner.tags;

        let get_fields = |val: &Note| {
            val.fields
                .iter()
                .filter(|(_, v)| match v {
                    Field::Raw(v) | Field::Plain { plain: v } => !v.is_empty(),
                    Field::Content { .. } | Field::Empty => false,
                })
                .map(|(k, v)| (String::from(k), v.to_string()))
                .collect::<HashSet<_>>()
        };
        let a_fields = get_fields(inner);
        let b_fields = get_fields(oinner);
        let fields_match = a_fields == b_fields;

        let same = matching && fields_match;

        if let (Some(s_id), Some(o_id)) = (&inner.id, &oinner.id) {
            if same && s_id != o_id {
                error!("Id differs {} != {} but contents are the same (deck {}, model {}, fields {:?}, tags {:?})",
                    s_id, o_id, inner.deck, inner.model, inner.fields, inner.tags);
            }
        }

        same
    }
}

#[derive(Debug, PartialEq)]
struct Model {
    field_names: Vec<String>,
}

#[derive(Debug)]
struct State {
    deck_names: Vec<String>,
    models: HashMap<String, Model>,
    added_notes: Vec<NoteWithInfo>,
    last_hashes: HashMap<PathBuf, u64>,
}

impl State {
    fn load_models() -> Result<HashMap<String, Model>> {
        let model_names = get_model_names()?.0;
        get_model_field_names_multi(model_names.iter().map(String::as_str))?
            .into_iter()
            .zip(model_names)
            .map(|(field_names, name)| {
                Ok((
                    name,
                    Model {
                        field_names: field_names.0,
                    },
                ))
            })
            .collect()
    }

    fn new() -> Result<Self> {
        debug!("loading state");
        let models = Self::load_models()?;
        Ok(Self {
            deck_names: get_deck_names()?.0,
            models,
            added_notes: get_notes("*")?,
            last_hashes: HashMap::default(),
        })
    }

    // TODO reload state less often
    fn reload(&mut self) -> Result<()> {
        debug!("reloading state");
        self.deck_names = get_deck_names()?.0;
        self.models = Self::load_models()?;

        Ok(())
    }
}

fn update_change(state: &mut State, config: &Config, path: &Path, args: &CreateArgs) -> Result<()> {
    let path_str = path.to_string_lossy();
    if config.is_ignored(&path_str) {
        return Ok(());
    }
    if path.is_dir() {
        debug!(
            "{} is a directory. Updating children instead",
            path.display()
        );
        let children = std::fs::read_dir(path)
            .with_note(|| eyre!("while collecting children of {}", path.display()))?;
        for read_dir in children {
            let new_path = read_dir?.path();
            update_change(state, config, &new_path, args)?;
        }

        return Ok(());
    }

    let content = std::fs::read_to_string(path)
        .with_note(|| eyre!("while reading file {}", path.display()))?;
    let content_hash = fasthash::metro::hash64(content);

    if let Some(last_hash) = state.last_hashes.get(path) {
        if *last_hash == content_hash {
            debug!("nothing changed");
            return Ok(());
        }
    }
    state.last_hashes.insert(path.into(), content_hash);
    info!("updating changes from {}", path.display());
    state.reload()?;

    debug!("getting metadata for file {}", path.display());
    let metadata = query(&path_str)?;
    debug!("compiling file {}", path.display());
    let output = compile(&path_str, args.theme)?;
    debug!("finished compiling file");

    let mut note_decks: HashMap<String, (Vec<_>, Vec<_>)> = HashMap::new();

    debug!("checking notes");
    for inner_meta in metadata.0 {
        let mut note = inner_meta.value;
        let Some(model) = state.models.get(&note.model) else {
            error!("create note with invalid model name {}", note.model);
            return Ok(());
        };
        for field_name in note.fields.keys() {
            if !model.field_names.contains(field_name) {
                error!(
                    "model {} does not contain field `{}`",
                    note.model, field_name
                );
                info!("field names: {}", model.field_names.join(", "));
                return Ok(());
            }
        }

        if config.add_generated {
            note.tags.push(String::from("generated"));
        }

        if let Some(date) = &config.add_generation_date {
            note.tags.push(date.clone());
        }

        // if state.added_notes.contains(&note)
        if state.added_notes.iter().any(|y| *y == note) {
            continue;
        }

        let mut fields = HashMap::with_capacity(note.fields.len());
        for (name, value) in &note.fields {
            let content = match value {
                Field::Raw(val) => val.clone(),
                Field::Plain { plain } => plain.clone(),
                Field::Content {
                    content,
                    page_start,
                    page_end,
                } => {
                    let mut field = String::new();
                    assert!(page_start <= page_end);
                    let mut is_first = true;
                    for page_number in *page_start..=*page_end {
                        let res = build_note_field_with_img(
                            &output,
                            &note,
                            content,
                            is_first,
                            page_number,
                        )?;
                        field.push_str(&res);
                        is_first = false;
                    }

                    field
                }
                Field::Empty => String::new(),
            };
            fields.insert(name.clone(), content);
        }

        let api_note = api::Note {
            deck_name: note.deck.clone(),
            model_name: note.model.clone(),
            fields,
            tags: note.tags.clone(),
            picture: SingleOrMulti::default(),
            audio: SingleOrMulti::default(),
            video: SingleOrMulti::default(),
        };

        let (notes, api_notes) = note_decks.entry(note.deck.clone()).or_default();
        notes.push(note);
        api_notes.push(api_note);
    }
    debug!("checked notes");

    let mut global_added_notes = 0;

    for (deck, (notes, api_notes)) in note_decks {
        // TODO id
        if !state.deck_names.contains(&deck) {
            error!("create note with invalid deck name {}", deck);
            info!(
                "create all decks in the file with `{} create-all-decks`",
                BIN_NAME
            );
            return Ok(());
        }
        info!("creating {} notes in deck {}", notes.len(), deck);

        let mut duplicates = 0;
        let mut added_notes = 0;
        let ids = add_notes(&api_notes)?;
        for (id, note) in ids.into_iter().zip(notes) {
            if id.is_none() {
                duplicates += 1;
                debug!(
                    "Duplicate! Note in deck {} with fields {:?} already existed",
                    &note.deck, note.fields,
                );
            } else {
                added_notes += 1;
                debug!(
                    "created note in deck {} with fields {:?}",
                    &note.deck, note.fields,
                );
            }
            let note = NoteWithInfo {
                id,
                note,
                question: None,
            };
            state.added_notes.push(note);
        }

        if duplicates != 0 {
            info!(
                "Duplicates! {} Notes in deck {} already existed",
                duplicates, deck
            );
        }
        if added_notes != 0 {
            info!("added {} new notes in deck {}", added_notes, deck);
            global_added_notes += added_notes;
        }
    }

    if global_added_notes == 0 {
        info!("nothing to do :)");
    } else {
        info!("added {} new notes", global_added_notes);
    }

    Ok(())
}

fn build_note_field_with_img(
    output: &ThemedCompileOutput,
    note: &Note,
    content: &String,
    is_first: bool,
    page_number: usize,
) -> Result<String> {
    let get_data = |files: &CompileOutput| {
        let Some((_path, encoded_data)) = files.files.get(&page_number).cloned() else {
            bail!(
                "missing page with number {} for note {:?}",
                page_number,
                note.fields
            );
        };
        let filename = api::store_media_file(&MediaData {
            filename: match &note.id {
                Some(val) => format!("{val}_page{page_number}.svg"),
                None => bail!("note requires id: {:?}", note),
            },
            inner: MediaDataInner::Data(encoded_data),
            delete_existing: false,
        })?;
        Ok(filename)
    };

    let alt = if is_first {
        format!(" alt=\"{content}\"")
    } else {
        String::new()
    };

    let res = match output {
        ThemedCompileOutput::Light(out) => {
            let filename = get_data(out)?;
            format!("<img src=\"{filename}\"{alt}>")
        }
        ThemedCompileOutput::Dark(out) => {
            let filename = get_data(out)?;
            format!("<img src=\"{filename}\"{alt}>")
        }
        ThemedCompileOutput::Both { light, dark } => {
            let light_file = get_data(light)?;
            let dark_file = get_data(dark)?;
            format!(
                r#"
                <img src="{light_file}"{alt} class="lighttheme">
                <img src="{dark_file}"{alt} class="darktheme">
            "#
            )
        }
    };

    Ok(res)
}

/// Create Anki notes from file
#[derive(clap::Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Path of the file to read from.
    ///
    /// If no value is given and no config file exists `anki.typ` will be used.
    #[arg(short, long)]
    path: Option<PathBuf>,
    /// Log Level
    #[arg(long, default_value = "info")]
    log_level: Level,
    /// Use short log output
    #[arg(long)]
    short_log: bool,
    /// Add a tag with the value `generated` for each new note.
    #[arg(long, default_value = "true")]
    add_generated: bool,
    /// Add a tag with the value `generated@$date` for each new note.
    #[arg(long, default_value = "true")]
    add_generation_date: bool,

    #[command(subcommand)]
    subcommand: Commands,
}

/// Create anki notes from typst files
#[derive(Debug, clap::Subcommand)]
enum Commands {
    /// Watch for changes and create new notes
    Watch(CreateArgs),
    /// Create new notes
    #[clap(visible_alias = "c")]
    Create(CreateArgs),
    /// Create all decks in the file if they don't exist already
    CreateAllDecks,
    /// Create the default `anki-typst` model
    CreateDefaultModel {
        #[arg(default_value = "anki-typst")]
        model_name: String,
    },
    /// Get all deck names
    GetDecks,
    /// Get all model names
    GetModels,
    /// Get all Notes for the given query
    GetNotes {
        /// See <https://docs.ankiweb.net/searching.html>
        #[arg(default_value = "*")]
        query: String,
    },
    /// Sync all notes to ankiweb
    #[clap(visible_alias = "s")]
    Sync,
}

#[derive(Debug, clap::Args)]
struct CreateArgs {
    /// Set the theme for images
    #[arg(long, value_enum, default_value_t = Theme::Both)]
    theme: Theme,
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, PartialOrd, Ord, clap::ValueEnum)]
enum Theme {
    // Create cards with dark theme
    Dark,
    // Create cards with dark theme
    Light,
    // Create cards with light and cards with dark theme
    Both,
}

fn main() -> Result<()> {
    color_eyre::install()?;

    let args = Args::parse();

    let builder = FmtSubscriber::builder().with_max_level(args.log_level);

    if args.short_log {
        let subscriber = builder.without_time().compact().finish();
        tracing::subscriber::set_global_default(subscriber)?;
    } else {
        tracing::subscriber::set_global_default(builder.finish())?;
    }

    let config = Config::load(
        args.add_generated,
        args.add_generation_date
            .then(|| format!("{}", chrono::Local::now().format("%Y-%m-%d"))),
    )?;

    let main_path = args
        .path
        .or_else(|| config.path.clone())
        .unwrap_or_else(|| "anki.typ".into());
    // drop args so it can't be used later on
    let Args { subcommand, .. } = args;

    match subcommand {
        Commands::Watch(args) => watch(&config, &main_path, &args)?,
        Commands::Create(args) => {
            let mut state = State::new()?;
            update_change(&mut state, &config, &main_path, &args)?;
        }
        Commands::GetDecks => {
            let names = get_deck_names()?;
            println!("All deck names: \n {}", names.0.join("\n "));
        }
        Commands::GetModels => {
            let names = get_model_names()?;
            println!("All model names: \n {}", names.0.join("\n "));
        }
        Commands::GetNotes { query } => {
            let notes = get_notes(&query)?;
            let notes_len = notes.len();

            for note in notes {
                println!(
                    "In deck '{}' with model '{}'",
                    note.note.deck, note.note.model
                );
                for (k, v) in note.note.fields {
                    println!("[{k}] {v}");
                }
                if !note.note.tags.is_empty() {
                    println!("Tags: {}", note.note.tags.join(", "));
                }
                println!("{}", "-".repeat(100));
            }

            println!("fetched {notes_len} notes in total");
        }
        Commands::CreateAllDecks => {
            create_all_decks(&main_path)?;
        }
        Commands::CreateDefaultModel { model_name } => {
            create_default_model(&model_name)?;
        }
        Commands::Sync => {
            info!("syncing all notes");
            sync()?;
            println!("Success");
        }
    }

    Ok(())
}

fn watch(config: &Config, path: &Path, args: &CreateArgs) -> Result<()> {
    let mut state = State::new()?;
    update_change(&mut state, config, path, args)?;

    let (tx, rx) = std::sync::mpsc::channel();

    let mut watcher = notify::recommended_watcher(tx)?;
    watcher.watch(path, RecursiveMode::Recursive)?;
    watcher.watch(path, RecursiveMode::NonRecursive)?;

    info!("You can exit with Ctrl+C");
    for res in rx {
        let event: Event = res?;
        match event.kind {
            EventKind::Access(_) => {}
            EventKind::Create(_) => error!("file was created but should have existed before"),
            // TODO finer
            EventKind::Modify(_) => {
                if let Err(e) = update_change(&mut state, config, path, args) {
                    error!("{:#?}", e);
                }
            }
            EventKind::Any | EventKind::Other => {
                error!("unknown file watcher event: {:?}", event);
            }
            EventKind::Remove(_) => {
                // TODO is this necessary?
                watcher.watch(path, RecursiveMode::Recursive)?;
                if !path.is_file() {
                    error!("file was removed.");
                } else if let Err(e) = update_change(&mut state, config, path, args) {
                    error!("{}", e);
                }
            }
        }
    }

    info!("Exiting");

    Ok(())
}

fn get_notes(query: &str) -> Result<Vec<NoteWithInfo>> {
    let ids = find_notes(query)?;
    info!("getting {} notes", ids.len());
    let notes = notes_info(&ids)?;
    debug!("got notes");
    let card_ids = notes
        .iter()
        .flat_map(|note_info| note_info.cards.clone())
        .collect::<Vec<_>>();
    debug!("getting card info of {} cards", card_ids.len());
    let cards = cards_info(&card_ids)?;
    debug!("got card info");
    assert_eq!(card_ids.len(), cards.len());
    let mut cards = cards.into_iter();

    notes
        .into_iter()
        .map(|note_info| {
            let id = note_info.fields.iter().find_map(|(name, field)| {
                if name == "id" {
                    Some(field.value.clone())
                } else {
                    None
                }
            });
            let fields = note_info
                .fields
                .into_iter()
                .map(|(name, field)| {
                    (
                        name,
                        // TODO is this correct?
                        Field::Raw(field.value),
                    )
                })
                .collect();

            let mut deck_name = None;
            let mut question = None;
            for _ in 0..note_info.cards.len() {
                let card = cards.next().unwrap();
                let n = card.deck_name;
                if let Some(name) = deck_name.as_ref() {
                    assert_eq!(&n, name);
                } else {
                    deck_name = Some(n);
                }
                question = Some(card.question);
            }
            let note = Note {
                id,
                deck: deck_name.unwrap(),
                model: note_info.model_name,
                fields,
                tags: note_info.tags,
            };

            Ok(NoteWithInfo {
                note,
                id: Some(note_info.note_id),
                question,
            })
        })
        .collect()
}

fn create_all_decks(path: &Path) -> Result<()> {
    debug!("parsing file for used decks");
    let path_str = path.to_string_lossy();
    let metadata = query(&path_str)?;
    let used_decks = metadata.0.into_iter().map(|inner| inner.value.deck);

    let used_decks = used_decks
        .flat_map(|full| {
            let mut decks = Vec::new();
            let mut prefix = String::new();

            for part in full.split("::") {
                if !prefix.is_empty() {
                    prefix.push_str("::");
                }
                prefix.push_str(part);
                decks.push(prefix.clone());
            }

            decks
        })
        .collect::<Vec<_>>();

    debug!("collecting available decks from anki");
    let available_decks: HashSet<_> = get_deck_names()?.0.into_iter().collect();

    let mut created: HashSet<String> = HashSet::new();

    for deck in used_decks {
        if available_decks.contains(&deck) || created.contains(&deck) {
            continue;
        }
        if api::create_deck(&deck)?.is_some() {
            info!("created deck {}", deck);
        }
        assert!(created.insert(deck));
    }

    if created.is_empty() {
        info!("All decks were already created");
    }

    Ok(())
}

fn create_default_model(model_name: &str) -> Result<()> {
    debug!("getting all deck names");
    let names = get_deck_names()?;
    if names.0.iter().find(|name| *name == model_name).is_some() {
        bail!("default model with name {} already exists", model_name);
    }

    create_model(&CreateModelData {
        model_name: model_name.into(),
        in_order_fields: ["front", "back", "proof", "number", "date"]
            .into_iter()
            .map(String::from)
            .collect(),
        css: String::from(
            r#"
.card {
 font-family: arial;
 font-size: 20px;
 text-align: center;
 color: black;
 background-color: white;
}

.darktheme {
  display: none;
}

.nightMode .darktheme {
  display: inline;
}

.nightMode .lighttheme {
  display: none;
}
"#,
        ),
        is_cloze: false,
        card_templates: vec![HashMap::from_iter(
            [
                ("Name", "front+number -> back"),
                ("Front", "{{front}} - {{number}}"),
                ("Back", "{{FrontSide}}\n\n<hr id=answer>\n\n{{back}}"),
            ]
            .map(|(a, b)| (String::from(a), String::from(b))),
        )],
    })?;

    info!("created default model with name {}", model_name);

    Ok(())
}

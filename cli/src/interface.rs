use std::collections::BTreeMap;

pub use cli::{compile, query};

#[derive(Debug, Clone, PartialEq)]
pub struct CompileOutput {
    pub files: BTreeMap<usize, (String, String)>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ThemedCompileOutput {
    Light(CompileOutput),
    Dark(CompileOutput),
    Both {
        light: CompileOutput,
        dark: CompileOutput,
    },
}

mod cli {
    use std::collections::BTreeMap;
    use std::process::Command;

    use color_eyre::eyre::{bail, eyre, Context, OptionExt};
    use color_eyre::Help;
    use color_eyre::Result;
    use tracing::{debug, error, info, warn};

    use crate::interface::{CompileOutput, ThemedCompileOutput};
    use crate::metadata::Metadata;
    use crate::Theme;

    fn run_cmd(args: &[&str]) -> Result<Vec<u8>> {
        let fmt_cmd = format!("typst {}", args.join(" "));
        debug!("running {}", fmt_cmd);
        let mut cmd = Command::new("typst");
        cmd.args(args);
        let res = cmd
            .output()
            .map_err(|e| eyre!("can't run typst command `{}`: {}", fmt_cmd, e))?;

        if !res.status.success() {
            return Err(eyre!(
                "typst returned error code {} for command {}.\nStdout:\n{}\nStderr:\n{}",
                res.status,
                fmt_cmd,
                String::from_utf8_lossy(&res.stdout),
                String::from_utf8_lossy(&res.stderr)
            ));
        }

        if !res.stderr.is_empty() {
            warn!(
                "typst command {} had non-empty stderr:\n{}",
                fmt_cmd,
                String::from_utf8_lossy(&res.stderr)
            );
        }

        Ok(res.stdout)
    }

    pub fn compile(path: &str, theme: Theme) -> Result<ThemedCompileOutput> {
        match theme {
            Theme::Dark => compile_inner(path, theme).map(ThemedCompileOutput::Dark),
            Theme::Light => compile_inner(path, theme).map(ThemedCompileOutput::Light),
            Theme::Both => {
                let light = compile_inner(path, Theme::Light)?;
                let dark = compile_inner(path, Theme::Dark)?;

                Ok(ThemedCompileOutput::Both { light, dark })
            }
        }
    }

    pub fn compile_inner(path: &str, theme: Theme) -> Result<CompileOutput> {
        let tempdir = tempfile::tempdir().context("create temporary compile output directory")?;
        let output = tempdir.path().join("page{n}.svg");
        let output = output
            .to_str()
            .ok_or_eyre("tempdir path must be valid utf-8")?;
        let theme_str = format!(
            "theme={}",
            match theme {
                Theme::Dark => "dark",
                Theme::Light => "light",
                Theme::Both => bail!("theme both should be handled elsewhere"),
            }
        );
        let args = &[
            "compile",
            path,
            output,
            "--input",
            "export=true",
            "--input",
            &theme_str,
        ];
        let stdout = run_cmd(args)?;

        if !stdout.is_empty() {
            warn!(
                "typst command typst {} had non-empty stdout:\n{}",
                args.join(" "),
                String::from_utf8_lossy(&stdout)
            );
        }

        let mut res = BTreeMap::default();
        for file in std::fs::read_dir(&tempdir)
            .with_context(|| eyre!("list output files at {}", tempdir.path().display()))?
        {
            let file =
                file.with_context(|| eyre!("list file output from {}", tempdir.path().display()))?;
            let path = file.path();
            if !path.is_file() {
                error!(
                    "got non-file {} in output dir {}",
                    path.display(),
                    tempdir.path().display()
                );
                continue;
            }
            let reader = std::fs::File::open(&path)
                .with_context(|| eyre!("open output file from {}", path.display()))?;
            let mut reader = std::io::BufReader::new(reader);
            let mut writer =
                base64::write::EncoderStringWriter::new(&base64::engine::general_purpose::STANDARD);

            std::io::copy(&mut reader, &mut writer)
                .with_context(|| eyre!("encode file data from {} to base64", path.display()))?;
            let page = {
                let filename = path
                    .file_name()
                    .ok_or_else(|| eyre!("output should have a filename: {}", path.display()))?;
                let filename = filename.to_str().ok_or_else(|| {
                    eyre!(
                        "output filename should be valid utf-8 but was {}",
                        path.display()
                    )
                })?;
                let Some(filename) = filename.strip_prefix("page") else {
                    bail!(
                        "output filename must start with `page` but was {}",
                        filename
                    )
                };
                let Some(filename) = filename.strip_suffix(".svg") else {
                    bail!("output filename must end with `.svg` but was {}", filename)
                };
                let page: usize = filename.parse().map_err(|e| {
                    eyre!(
                        "output filename should be a valid number but was {}: {}",
                        filename,
                        e
                    )
                })?;
                page
            };
            let path = path
                .to_str()
                .ok_or_else(|| eyre!("output path must be valid utf-8 but was {}", path.display()))?
                .to_string();
            res.insert(page, (path, writer.into_inner()));
        }

        Ok(CompileOutput { files: res })
    }

    pub fn query(path: &str) -> Result<Metadata> {
        info!("running typst query");
        let json = run_cmd(&["query", path, "<anki-export>", "--input", "export=true"])?;
        let jd = &mut serde_json::Deserializer::from_slice(&json);

        serde_path_to_error::deserialize(jd).map_err(|e| {
            let json_str = match std::str::from_utf8(&json) {
                Ok(v) => v.to_string(),
                Err(e) => {
                    warn!("typst output is invalid utf-8: {}", e);
                    String::from_utf8_lossy(&json).to_string()
                }
            };
            debug!("output: {}", json_str);
            eyre!(
                "cannot deserialize query output at {}: {}",
                e.path(),
                e.inner()
            )
            .suggestion("run with `--log-level debug` to see typsts outptu")
        })
    }
}

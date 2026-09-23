use std::env;
use std::ffi::{OsStr, OsString};
use std::process::{Command, ExitCode};

const DEFAULT_PALETTE: &str = "196 46 21 226 201 51 208 118 27 199 214 82 39 220 165 50 202 154 33 129 190 48 57 93 197 45 213 159 87 228";

fn main() -> ExitCode {
    match run(env::args_os().skip(1).collect()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("pane-beacon: {message}");
            ExitCode::FAILURE
        }
    }
}

fn run(args: Vec<OsString>) -> Result<(), String> {
    let Some(command) = args.first().and_then(|arg| arg.to_str()) else {
        return Err(usage());
    };

    match command {
        "init" | "assign-color" => assign_colors(args.get(1)),
        "alert" => alert(&args[1..]),
        "update" => update(&args[1..]),
        "clear" => clear(&args[1..]),
        "--help" | "-h" | "help" => {
            println!("{}", usage());
            Ok(())
        }
        "--version" | "-V" => {
            println!("pane-beacon {}", env!("CARGO_PKG_VERSION"));
            Ok(())
        }
        other => Err(format!("unknown command: {other}\n{}", usage())),
    }
}

fn usage() -> String {
    "Usage:\n  pane-beacon init\n  pane-beacon assign-color [pane_id]\n  pane-beacon alert <pane_id> <message> [window-status-style]\n  pane-beacon update <pane_id> [--agent NAME] [--status STATUS] --summary TEXT\n  pane-beacon clear <pane_id>".into()
}

fn tmux<I, S>(args: I) -> Result<String, String>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let output = Command::new(env::var_os("PANE_BEACON_TMUX").unwrap_or_else(|| "tmux".into()))
        .args(args)
        .output()
        .map_err(|error| format!("failed to run tmux: {error}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
        return Err(if stderr.is_empty() {
            format!("tmux exited with {}", output.status)
        } else {
            stderr
        });
    }
    Ok(String::from_utf8_lossy(&output.stdout)
        .trim_end()
        .to_owned())
}

fn global_option(name: &str) -> Result<Option<String>, String> {
    let value = tmux(["show-option", "-gqv", name])?;
    Ok((!value.is_empty()).then_some(value))
}

fn palette() -> Result<Vec<String>, String> {
    let raw = global_option("@pane_beacon_palette")?.unwrap_or_else(|| DEFAULT_PALETTE.into());
    parse_palette(&raw)
}

fn parse_palette(raw: &str) -> Result<Vec<String>, String> {
    let colors: Vec<_> = raw.split_whitespace().map(str::to_owned).collect();
    if colors.is_empty() {
        return Err("@pane_beacon_palette must contain at least one color".into());
    }
    if let Some(invalid) = colors
        .iter()
        .find(|color| !color.chars().all(|c| c.is_ascii_digit()))
    {
        return Err(format!("invalid palette color: {invalid}"));
    }
    Ok(colors)
}

fn assign_colors(pane: Option<&OsString>) -> Result<(), String> {
    let colors = palette()?;
    if let Some(pane) = pane {
        return assign_one(pane, &colors);
    }

    tmux(["set-option", "-g", "@pane_beacon_next", "0"])?;
    for pane in tmux(["list-panes", "-a", "-F", "#{pane_id}"])?.lines() {
        assign_one(OsStr::new(pane), &colors)?;
    }
    Ok(())
}

fn assign_one(pane: &OsStr, colors: &[String]) -> Result<(), String> {
    let next = global_option("@pane_beacon_next")?
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(0)
        % colors.len();
    let color = format!("colour{}", colors[next]);
    tmux([
        OsStr::new("set-option"),
        OsStr::new("-p"),
        OsStr::new("-t"),
        pane,
        OsStr::new("@pane_beacon_color"),
        OsStr::new(&color),
    ])?;
    tmux([
        "set-option",
        "-g",
        "@pane_beacon_next",
        &((next + 1) % colors.len()).to_string(),
    ])?;

    let active = tmux([
        OsStr::new("display-message"),
        OsStr::new("-p"),
        OsStr::new("-t"),
        pane,
        OsStr::new("#{pane_active}"),
    ])?;
    if active == "1" {
        let window = window_target(pane)?;
        tmux([
            "set-window-option",
            "-t",
            &window,
            "pane-active-border-style",
            &format!("fg={color},bg=terminal"),
        ])?;
    }
    Ok(())
}

fn window_target(pane: &OsStr) -> Result<String, String> {
    tmux([
        OsStr::new("display-message"),
        OsStr::new("-p"),
        OsStr::new("-t"),
        pane,
        OsStr::new("#{session_name}:#{window_index}"),
    ])
}

fn alert(args: &[OsString]) -> Result<(), String> {
    if args.len() < 2 || args.len() > 3 {
        return Err("Usage: pane-beacon alert <pane_id> <message> [window-status-style]".into());
    }
    set_alert(
        &args[0],
        &args[1],
        args.get(2)
            .map(OsString::as_os_str)
            .unwrap_or(OsStr::new("fg=yellow,bold")),
    )
}

fn set_alert(pane: &OsStr, message: &OsStr, style: &OsStr) -> Result<(), String> {
    let visible = tmux([
        OsStr::new("display-message"),
        OsStr::new("-p"),
        OsStr::new("-t"),
        pane,
        OsStr::new("#{&&:#{session_attached},#{&&:#{window_active},#{pane_active}}}"),
    ])?;
    if visible == "1" {
        return Ok(());
    }
    let window = window_target(pane)?;
    tmux([
        OsStr::new("set-option"),
        OsStr::new("-p"),
        OsStr::new("-t"),
        pane,
        OsStr::new("@pane_beacon_alert"),
        message,
    ])?;
    tmux([
        OsStr::new("set-window-option"),
        OsStr::new("-t"),
        OsStr::new(&window),
        OsStr::new("window-status-style"),
        style,
    ])?;
    Ok(())
}

#[derive(Debug, PartialEq)]
struct Update {
    title: String,
    status: String,
    summary: String,
}

fn parse_update(args: &[OsString]) -> Result<Update, String> {
    let mut agent: Option<String> = None;
    let mut status = "working".to_owned();
    let mut summary: Option<String> = None;
    let mut index = 0;
    while index < args.len() {
        let flag = args[index].to_string_lossy();
        let value = args
            .get(index + 1)
            .ok_or_else(|| format!("missing value for {flag}"))?;
        match flag.as_ref() {
            "--agent" => agent = Some(value.to_string_lossy().into_owned()),
            "--status" => status = value.to_string_lossy().into_owned(),
            "--summary" => summary = Some(value.to_string_lossy().into_owned()),
            _ => return Err(format!("unknown update option: {flag}")),
        }
        index += 2;
    }
    let summary = summary.ok_or_else(|| "--summary is required".to_owned())?;
    if !matches!(
        status.as_str(),
        "working" | "waiting" | "completed" | "error"
    ) {
        return Err(format!(
            "invalid status: {status} (expected working, waiting, completed, or error)"
        ));
    }
    let title = match agent {
        Some(agent) => format!("{agent}: {summary}"),
        None => summary.clone(),
    };
    Ok(Update {
        title,
        status,
        summary,
    })
}

fn update(args: &[OsString]) -> Result<(), String> {
    let Some(pane) = args.first() else {
        return Err(
            "Usage: pane-beacon update <pane_id> [--agent NAME] [--status STATUS] --summary TEXT"
                .into(),
        );
    };
    let Update {
        title,
        status,
        summary,
    } = parse_update(&args[1..])?;
    tmux([
        OsStr::new("select-pane"),
        OsStr::new("-t"),
        pane,
        OsStr::new("-T"),
        OsStr::new(&title),
    ])?;
    tmux([
        OsStr::new("set-option"),
        OsStr::new("-p"),
        OsStr::new("-t"),
        pane,
        OsStr::new("@pane_beacon_status"),
        OsStr::new(&status),
    ])?;
    if matches!(status.as_str(), "completed" | "waiting" | "error") {
        set_alert(
            pane,
            OsStr::new(&summary),
            OsStr::new(status_style(&status)),
        )?;
    }
    Ok(())
}

fn status_style(status: &str) -> &'static str {
    match status {
        "error" => "fg=red,bold",
        "waiting" => "fg=magenta,bold",
        _ => "fg=yellow,bold",
    }
}

fn clear(args: &[OsString]) -> Result<(), String> {
    if args.len() != 1 {
        return Err("Usage: pane-beacon clear <pane_id>".into());
    }
    let pane = &args[0];
    tmux([
        OsStr::new("set-option"),
        OsStr::new("-p"),
        OsStr::new("-u"),
        OsStr::new("-t"),
        pane,
        OsStr::new("@pane_beacon_alert"),
    ])?;
    tmux([
        OsStr::new("set-option"),
        OsStr::new("-p"),
        OsStr::new("-u"),
        OsStr::new("-t"),
        pane,
        OsStr::new("@pane_beacon_status"),
    ])?;
    let window = window_target(pane)?;
    tmux([
        "set-window-option",
        "-u",
        "-t",
        &window,
        "window-status-style",
    ])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn os_args(args: &[&str]) -> Vec<OsString> {
        args.iter().map(OsString::from).collect()
    }

    #[test]
    fn maps_status_to_window_style() {
        assert_eq!(status_style("completed"), "fg=yellow,bold");
        assert_eq!(status_style("waiting"), "fg=magenta,bold");
        assert_eq!(status_style("error"), "fg=red,bold");
    }

    #[test]
    fn default_palette_is_valid() {
        assert_eq!(parse_palette(DEFAULT_PALETTE).unwrap().len(), 30);
    }

    #[test]
    fn palette_rejects_empty_and_named_colors() {
        assert!(parse_palette("  ").is_err());
        assert_eq!(
            parse_palette("196 red").unwrap_err(),
            "invalid palette color: red"
        );
    }

    #[test]
    fn update_prefixes_title_with_agent() {
        let update = parse_update(&os_args(&[
            "--agent",
            "codex",
            "--status",
            "completed",
            "--summary",
            "Done",
        ]))
        .unwrap();
        assert_eq!(
            update,
            Update {
                title: "codex: Done".into(),
                status: "completed".into(),
                summary: "Done".into(),
            }
        );
    }

    #[test]
    fn update_defaults_to_working_without_agent() {
        let update = parse_update(&os_args(&["--summary", "Reading"])).unwrap();
        assert_eq!(update.title, "Reading");
        assert_eq!(update.status, "working");
    }

    #[test]
    fn update_rejects_bad_arguments() {
        assert_eq!(
            parse_update(&os_args(&["--agent", "codex"])).unwrap_err(),
            "--summary is required"
        );
        assert_eq!(
            parse_update(&os_args(&["--summary"])).unwrap_err(),
            "missing value for --summary"
        );
        assert!(parse_update(&os_args(&["--summary", "x", "--status", "done"])).is_err());
        assert!(parse_update(&os_args(&["--color", "red"])).is_err());
    }
}

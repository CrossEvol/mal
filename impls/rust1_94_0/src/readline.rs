use rustyline::{DefaultEditor, Result};

pub fn readline(prompt: &str) -> Result<String> {
    let mut rl = DefaultEditor::new()?;
    if rl.load_history("history.txt").is_err() {
        println!("No previous history.");
    }
    let input = rl.readline(prompt)?;
    let _ = rl.save_history("history.txt");
    Ok(input)
}

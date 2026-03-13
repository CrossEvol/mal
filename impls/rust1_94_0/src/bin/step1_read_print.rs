use rust1_94_0::{
    error::MalError,
    printer::pr_str,
    reader::read_str,
    readline as rl,
    types::{MalObject, MalResult},
};

fn read(input: &str) -> MalResult {
    read_str(input)
}

fn eval(ast: &MalObject) -> MalObject {
    ast.clone()
}

fn print(ast: &MalObject) -> String {
    pr_str(ast, true)
}

fn rep(input: &str) -> Result<String, MalError> {
    Ok(print(&eval(&read(input)?)))
}

fn main() {
    loop {
        let input = rl::readline("user> ").unwrap();
        let result = rep(&input);
        match result {
            Ok(output) => println!("{}", output),
            Err(MalError::ParseError(message)) => println!("{}", message),
            _ => {}
        }
    }
}

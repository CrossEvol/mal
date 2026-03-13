use std::collections::HashMap;

use rust1_94_0::{
    error::MalError,
    printer::pr_str,
    reader::read_str,
    readline as rl,
    types::{
        MalFunction, MalHashmap, MalList, MalNumber, MalObject, MalProcedure, MalResult, MalSymbol,
        MalVector, mal_func,
    },
};

type Env = HashMap<String, MalFunction>;

fn repl_env() -> HashMap<String, MalFunction> {
    let mut env = HashMap::new();
    env.insert(
        "+".to_string(),
        mal_func(|args: &[MalObject]| match args {
            &[
                MalObject::Number(MalNumber { n: a, .. }),
                MalObject::Number(MalNumber { n: b, .. }),
            ] => Ok(MalObject::Number(MalNumber::new(a + b))),
            _ => Err(MalError::InvalidArguments),
        }),
    );
    env.insert(
        "-".to_string(),
        mal_func(|args: &[MalObject]| match args {
            &[
                MalObject::Number(MalNumber { n: a, .. }),
                MalObject::Number(MalNumber { n: b, .. }),
            ] => Ok(MalObject::Number(MalNumber::new(a - b))),
            _ => Err(MalError::InvalidArguments),
        }),
    );
    env.insert(
        "*".to_string(),
        mal_func(|args: &[MalObject]| match args {
            &[
                MalObject::Number(MalNumber { n: a, .. }),
                MalObject::Number(MalNumber { n: b, .. }),
            ] => Ok(MalObject::Number(MalNumber::new(a * b))),
            _ => Err(MalError::InvalidArguments),
        }),
    );
    env.insert(
        "/".to_string(),
        mal_func(|args: &[MalObject]| match args {
            &[
                MalObject::Number(MalNumber { n: a, .. }),
                MalObject::Number(MalNumber { n: b, .. }),
            ] => Ok(MalObject::Number(MalNumber::new(a / b))),
            _ => Err(MalError::InvalidArguments),
        }),
    );
    env
}

fn read(input: &str) -> MalResult {
    read_str(input)
}

fn eval(ast: &MalObject, env: &Env) -> MalResult {
    match ast {
        MalObject::Symbol(MalSymbol { name, .. }) => {
            let key = name.clone().to_string();
            if env.contains_key(&key) {
                Ok(MalObject::Procedure(MalProcedure::new(
                    env.get(&key).unwrap().clone(),
                )))
            } else {
                Err(MalError::RuntimeError(format!("'{key}' not found")))
            }
        }
        MalObject::Vector(MalVector { items, .. }) => items
            .iter()
            .try_fold(Vec::new(), |mut acc, arg| {
                let item = eval(arg, env)?;
                acc.push(item);
                Ok(acc)
            })
            .map(|items| MalObject::Vector(MalVector::new(items))),
        MalObject::Hashmap(MalHashmap { items, .. }) => items
            .iter()
            .try_fold(HashMap::new(), |mut acc, entry| {
                let (key, value) = (entry.0.clone(), entry.1.clone());
                let value = eval(&value, env)?;
                acc.insert(key, value);
                Ok(acc)
            })
            .map(|items| MalObject::Hashmap(MalHashmap::new(items))),
        MalObject::List(MalList { items, .. }) => match items.as_slice() {
            [MalObject::Symbol(MalSymbol { name, .. }), ops @ ..] => {
                let op = env.get(&name.clone().to_string());
                if let Some(op) = op {
                    let ops = ops.iter().try_fold(Vec::new(), |mut acc, arg| {
                        let item = eval(arg, env)?;
                        acc.push(item);
                        Ok(acc)
                    })?;
                    op.call(&ops)
                } else {
                    Err(MalError::RuntimeError(format!("Error: '{name}' not found")))
                }
            }
            _ => Ok(ast.clone()),
        },
        _ => Ok(ast.clone()),
    }
}

fn print(ast: &MalObject) -> String {
    println!("{:#?}", ast);
    pr_str(ast, true)
}

fn rep(input: &str) -> Result<String, MalError> {
    let env = repl_env();
    Ok(print(&eval(&read(input)?, &env)?))
}

fn main() {
    loop {
        let input = rl::readline("user> ").unwrap();
        let result = rep(&input);
        match result {
            Ok(output) => println!("{}", output),
            Err(MalError::ParseError(message) | MalError::RuntimeError(message)) => {
                println!("{}", message)
            }
            _ => {}
        }
    }
}

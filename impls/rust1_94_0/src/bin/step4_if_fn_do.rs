use std::collections::HashMap;

use rust1_94_0::{
    core::ns,
    env::Env,
    error::MalError,
    printer::pr_str,
    reader::read_str,
    readline as rl,
    types::{
        MalClosure, MalHashmap, MalList, MalNil, MalObject, MalProcedure, MalResult, MalSymbol,
        MalVector, mal_func, mal_procedure,
    },
};

fn repl_env() -> Result<Env, MalError> {
    let mut env = Env::new(None, None, None)?;
    ns().iter().for_each(|(k, v)| {
        env.set(MalSymbol::new(k), mal_procedure(v.clone()));
    });
    Ok(env)
}

fn read(input: &str) -> MalResult {
    read_str(input)
}

fn eval(ast: &MalObject, env: &mut Env) -> MalResult {
    let dbgeval = env.get(&MalSymbol::new("DEBUG-EVAL"));
    if dbgeval.is_some() {
        println!("EVAL: {}", pr_str(ast, true));
    }

    match ast {
        MalObject::Symbol(key) => {
            if let Some(value) = env.get(key) {
                Ok(value)
            } else {
                Err(MalError::RuntimeError(format!("'{}' not found", key.name)))
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
            [MalObject::Symbol(key), MalObject::Symbol(symbol), value]
                if key.name.to_string() == "def!" =>
            {
                let value = eval(value, env)?;
                env.set(symbol.clone(), value.clone());
                Ok(value)
            }
            [
                MalObject::Symbol(symbol),
                MalObject::List(MalList { items: binds, .. })
                | MalObject::Vector(MalVector { items: binds, .. }),
                form,
            ] if symbol.name.to_string() == "let*" => {
                if binds.len() % 2 != 0 {
                    return Err(MalError::RuntimeError("unbalanced list".to_string()));
                }
                let mut new_env = Env::new(Some(env.clone()), None, None)?;
                for entry in binds.chunks_exact(2) {
                    let (key, value) = (entry[0].clone(), entry[1].clone());
                    let value = eval(&value, &mut new_env)?;
                    if let MalObject::Symbol(symbol) = key {
                        new_env.set(symbol, value);
                    }
                }
                eval(form, &mut new_env)
            }
            [MalObject::Symbol(symbol), forms @ ..] if symbol.name.to_string() == "do" => {
                if let Some((last_form, forms)) = forms.split_last() {
                    for form in forms {
                        eval(form, env)?;
                    }
                    eval(last_form, env)
                } else {
                    Ok(MalObject::Nil(MalNil::new()))
                }
            }
            [MalObject::Symbol(symbol), condition, branches @ ..]
                if symbol.name.to_string() == "if" =>
            {
                let condition = eval(condition, env)?;
                match condition {
                    MalObject::False(_) | MalObject::Nil(_) => match branches {
                        [_] => Ok(MalObject::Nil(MalNil::new())),
                        [_, else_branch] => eval(else_branch, env),
                        _ => Err(MalError::RuntimeError(
                            "Invalid conditional structure".to_string(),
                        )),
                    },
                    _ => match branches {
                        [then_branch] | [then_branch, ..] => eval(then_branch, env),
                        _ => Err(MalError::RuntimeError(
                            "Invalid conditional structure".to_string(),
                        )),
                    },
                }
            }
            [
                MalObject::Symbol(symbol),
                MalObject::List(MalList { items: binds, .. })
                | MalObject::Vector(MalVector { items: binds, .. }),
                body,
            ] if symbol.name.to_string() == "fn*" => {
                let captured_env = env.clone();
                let captured_env_for_func = captured_env.clone();
                let body_clone = body.clone();
                let binds_clone = binds.clone();

                let func = mal_func(move |args| {
                    let bind_symbols: Vec<MalSymbol> = binds_clone
                        .iter()
                        .filter_map(|b| match b {
                            MalObject::Symbol(s) => Some(s.clone()),
                            _ => None,
                        })
                        .collect();

                    let mut call_env = Env::new(
                        Some(captured_env_for_func.clone()),
                        Some(bind_symbols),
                        Some(args.to_vec()),
                    )?;

                    eval(&body_clone, &mut call_env)
                });

                let clos = MalClosure::new(
                    Box::new(body.clone()),
                    binds.clone(),
                    captured_env,
                    func,
                    false,
                );

                Ok(MalObject::Closure(clos))
            }
            [op, ops @ ..] => {
                let op = eval(op, env)?;
                let ops = ops.iter().try_fold(Vec::new(), |mut acc, arg| {
                    let item = eval(arg, env)?;
                    acc.push(item);
                    Ok(acc)
                })?;
                if let MalObject::Procedure(MalProcedure { func: op, .. })
                | MalObject::Closure(MalClosure { func: op, .. }) = op
                {
                    op.call(&ops)
                } else {
                    Ok(ast.clone())
                }
            }
            _ => Ok(ast.clone()),
        },
        _ => Ok(ast.clone()),
    }
}

fn print(ast: &MalObject) -> String {
    pr_str(ast, true)
}

fn rep(input: &str, env: &mut Env) -> Result<String, MalError> {
    Ok(print(&eval(&read(input)?, env)?))
}

fn main() -> Result<(), MalError> {
    let mut env = repl_env()?;

    rep("(def! not (fn* (a) (if a false true)))", &mut env)?;

    loop {
        let input = rl::readline("user> ").unwrap();
        let result = rep(&input, &mut env);
        match result {
            Ok(output) => println!("{}", output),
            Err(MalError::ParseError(message) | MalError::RuntimeError(message)) => {
                println!("{}", message)
            }
            Err(MalError::InvalidArguments) => println!("Invalid arguments"),
            _ => {}
        }
    }
}

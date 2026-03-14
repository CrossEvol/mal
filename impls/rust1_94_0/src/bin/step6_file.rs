use std::{collections::HashMap, env, vec};

use rust1_94_0::{
    core::ns,
    env::Env,
    error::MalError,
    printer::pr_str,
    reader::read_str,
    readline as rl,
    types::{
        MalClosure, MalHashmap, MalList, MalNil, MalObject, MalProcedure, MalResult, MalString,
        MalSymbol, MalVector, mal_func, mal_procedure,
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
    let mut ast = ast.clone();
    let mut env = env.clone();
    loop {
        let dbgeval = env.get(&MalSymbol::new("DEBUG-EVAL"));
        if dbgeval.is_some() {
            println!("EVAL: {}", pr_str(&ast, true));
        }

        match &ast {
            MalObject::Symbol(key) => {
                return if let Some(value) = env.get(key) {
                    Ok(value)
                } else {
                    Err(MalError::RuntimeError(format!("'{}' not found", key.name)))
                };
            }
            MalObject::Vector(MalVector { items, .. }) => {
                return items
                    .iter()
                    .try_fold(Vec::new(), |mut acc, arg| {
                        let item = eval(arg, &mut env)?;
                        acc.push(item);
                        Ok(acc)
                    })
                    .map(|items| MalObject::Vector(MalVector::new(items)));
            }
            MalObject::Hashmap(MalHashmap { items, .. }) => {
                return items
                    .iter()
                    .try_fold(HashMap::new(), |mut acc, entry| {
                        let (key, value) = (entry.0.clone(), entry.1.clone());
                        let value = eval(&value, &mut env)?;
                        acc.insert(key, value);
                        Ok(acc)
                    })
                    .map(|items| MalObject::Hashmap(MalHashmap::new(items)));
            }
            MalObject::List(MalList { items, .. }) => match items.as_slice() {
                [MalObject::Symbol(key), MalObject::Symbol(symbol), value]
                    if key.name.to_string() == "def!" =>
                {
                    let value = eval(value, &mut env)?;
                    env.set(symbol.clone(), value.clone());
                    return Ok(value);
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
                    ast = form.clone();
                    env = new_env;
                    continue;
                }
                [MalObject::Symbol(symbol), forms @ ..] if symbol.name.to_string() == "do" => {
                    if let Some((last_form, forms)) = forms.split_last() {
                        for form in forms {
                            eval(form, &mut env)?;
                        }
                        ast = last_form.clone();
                        continue;
                    } else {
                        return Ok(MalObject::Nil(MalNil::new()));
                    }
                }
                [MalObject::Symbol(symbol), condition, branches @ ..]
                    if symbol.name.to_string() == "if" =>
                {
                    let condition = eval(condition, &mut env)?;
                    match condition {
                        MalObject::False(_) | MalObject::Nil(_) => match branches {
                            [_] => return Ok(MalObject::Nil(MalNil::new())),
                            [_, else_branch] => {
                                ast = else_branch.clone();
                                continue;
                            }
                            _ => {
                                return Err(MalError::RuntimeError(
                                    "Invalid conditional structure".to_string(),
                                ));
                            }
                        },
                        _ => match branches {
                            [then_branch] | [then_branch, ..] => {
                                ast = then_branch.clone();
                                continue;
                            }
                            _ => {
                                return Err(MalError::RuntimeError(
                                    "Invalid conditional structure".to_string(),
                                ));
                            }
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

                    return Ok(MalObject::Closure(clos));
                }
                [op, ops @ ..] => {
                    let op = eval(op, &mut env)?;
                    let ops = ops.iter().try_fold(Vec::new(), |mut acc, arg| {
                        let item = eval(arg, &mut env)?;
                        acc.push(item);
                        Ok(acc)
                    })?;
                    match op {
                        MalObject::Procedure(MalProcedure { func: op, .. }) => {
                            return op.call(&ops);
                        }
                        MalObject::Closure(MalClosure {
                            ast: func_ast,
                            params: binds,
                            env: outer,
                            ..
                        }) => {
                            let binds = binds
                                .iter()
                                .filter_map(|b| match b {
                                    MalObject::Symbol(s) => Some(s.clone()),
                                    _ => None,
                                })
                                .collect();
                            let new_env = Env::new(Some(outer.clone()), Some(binds), Some(ops))?;
                            ast = *func_ast;
                            env = new_env;
                            continue;
                        }
                        _ => return Err(MalError::RuntimeError("bad!".to_string())),
                    }
                }
                _ => return Ok(ast.clone()),
            },
            _ => return Ok(ast.clone()),
        }
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

    let repl_env = env.clone();
    env.set(
        MalSymbol::new("eval"),
        mal_procedure(move |args| {
            let mut repl_env = repl_env.clone();
            eval(&args[0], &mut repl_env)
        }),
    );

    let args: Vec<String> = env::args().skip(1).collect();
    env.set(
        MalSymbol::new("*ARGV*"),
        MalObject::List(MalList::new(if args.len() == 0 {
            vec![]
        } else {
            args.iter()
                .skip(1)
                .map(|arg| MalObject::String(MalString::new(&arg)))
                .collect::<Vec<_>>()
        })),
    );

    rep(r#"(def! not (fn* (a) (if a false true)))"#, &mut env)?;
    rep(
        r#"(def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) "\nnil)")))))"#,
        &mut env,
    )?;

    match args.len() {
        0 => loop {
            let input = rl::readline("user> ").unwrap();
            let result = rep(&input, &mut env);
            match result {
                Ok(output) => println!("{}", output),
                Err(MalError::ParseError(message) | MalError::RuntimeError(message)) => {
                    println!("{}", message)
                }
                Err(MalError::UserError(mal_object)) => {
                    println!("[error] {}", pr_str(&mal_object, true))
                }
                Err(MalError::InvalidArguments) => println!("Invalid arguments"),
                _ => {}
            }
        },
        _ => {
            rep(&format!("(load-file \"{}\")", args[0]), &mut env)?;
            Ok(())
        }
    }
}

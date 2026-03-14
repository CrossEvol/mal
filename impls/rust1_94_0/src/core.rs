use std::{collections::HashMap, fs::read_to_string, time::SystemTime};

use crate::{
    error::MalError,
    printer,
    reader::read_str,
    readline as rl,
    types::{
        MalAtom, MalClosure, MalFalse, MalHashmap, MalKeyword, MalList, MalNil, MalNumber,
        MalObject, MalProcedure, MalResult, MalString, MalSymbol, MalTrue, MalVector,
    },
};

fn to_printed_string(args: &[MalObject], print_readably: bool, sep: &str) -> String {
    args.iter()
        .map(|arg| printer::pr_str(arg, print_readably))
        .collect::<Vec<_>>()
        .join(sep)
}

//==============================================>

fn add(args: &[MalObject]) -> MalResult {
    match args {
        &[
            MalObject::Number(MalNumber { n: a, .. }),
            MalObject::Number(MalNumber { n: b, .. }),
        ] => Ok(MalObject::Number(MalNumber::new(a + b))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn sub(args: &[MalObject]) -> MalResult {
    match args {
        &[
            MalObject::Number(MalNumber { n: a, .. }),
            MalObject::Number(MalNumber { n: b, .. }),
        ] => Ok(MalObject::Number(MalNumber::new(a - b))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn mul(args: &[MalObject]) -> MalResult {
    match args {
        &[
            MalObject::Number(MalNumber { n: a, .. }),
            MalObject::Number(MalNumber { n: b, .. }),
        ] => Ok(MalObject::Number(MalNumber::new(a * b))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn div(args: &[MalObject]) -> MalResult {
    match args {
        &[
            MalObject::Number(MalNumber { n: a, .. }),
            MalObject::Number(MalNumber { n: b, .. }),
        ] => Ok(MalObject::Number(MalNumber::new(a / b))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn list(args: &[MalObject]) -> MalResult {
    Ok(MalObject::List(MalList::new(args.to_vec())))
}

fn listp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::List(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn emptyp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::List(MalList { items, .. }) | MalObject::Vector(MalVector { items, .. })] => {
            if items.len() == 0 {
                Ok(MalObject::True(MalTrue::new()))
            } else {
                Ok(MalObject::False(MalFalse::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn count(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::List(MalList { items, .. }) | MalObject::Vector(MalVector { items, .. })] => {
            Ok(MalObject::Number(MalNumber::new(
                items.len().try_into().unwrap(),
            )))
        }
        [_] => Ok(MalObject::Number(MalNumber::new(0))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn less(args: &[MalObject]) -> MalResult {
    match args {
        &[
            MalObject::Number(MalNumber { n: a, .. }),
            MalObject::Number(MalNumber { n: b, .. }),
        ] => {
            if a < b {
                Ok(MalObject::True(MalTrue::new()))
            } else {
                Ok(MalObject::False(MalFalse::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn less_equal(args: &[MalObject]) -> MalResult {
    match args {
        &[
            MalObject::Number(MalNumber { n: a, .. }),
            MalObject::Number(MalNumber { n: b, .. }),
        ] => {
            if a <= b {
                Ok(MalObject::True(MalTrue::new()))
            } else {
                Ok(MalObject::False(MalFalse::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn greater(args: &[MalObject]) -> MalResult {
    match args {
        &[
            MalObject::Number(MalNumber { n: a, .. }),
            MalObject::Number(MalNumber { n: b, .. }),
        ] => {
            if a > b {
                Ok(MalObject::True(MalTrue::new()))
            } else {
                Ok(MalObject::False(MalFalse::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn greater_equal(args: &[MalObject]) -> MalResult {
    match args {
        &[
            MalObject::Number(MalNumber { n: a, .. }),
            MalObject::Number(MalNumber { n: b, .. }),
        ] => {
            if a >= b {
                Ok(MalObject::True(MalTrue::new()))
            } else {
                Ok(MalObject::False(MalFalse::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn equal(args: &[MalObject]) -> MalResult {
    match args {
        [a, b] => {
            if a == b {
                Ok(MalObject::True(MalTrue::new()))
            } else {
                Ok(MalObject::False(MalFalse::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn pr_str(args: &[MalObject]) -> MalResult {
    let s = to_printed_string(args, true, " ");
    Ok(MalObject::String(MalString::new(&s)))
}

fn str(args: &[MalObject]) -> MalResult {
    let s = to_printed_string(args, false, "");
    Ok(MalObject::String(MalString::new(&s)))
}

fn prn(args: &[MalObject]) -> MalResult {
    let s = to_printed_string(args, true, " ");
    println!("{s}");
    Ok(MalObject::Nil(MalNil::new()))
}

fn println(args: &[MalObject]) -> MalResult {
    let s = to_printed_string(args, false, " ");
    println!("{s}");
    Ok(MalObject::Nil(MalNil::new()))
}

fn read_string(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::String(MalString { string, .. })] => read_str(&string),
        _ => Err(MalError::InvalidArguments),
    }
}

fn slurp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::String(MalString { string: path, .. })] => Ok(MalObject::String(
            MalString::new(&read_to_string(path.as_ref()).unwrap()),
        )),
        _ => Err(MalError::InvalidArguments),
    }
}

fn throw(args: &[MalObject]) -> MalResult {
    match args {
        [single] => Err(MalError::UserError(single.clone())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn readline(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::String(MalString { string: prompt, .. })] => {
            if let Ok(line) = rl::readline(&prompt) {
                Ok(MalObject::String(MalString::new(&line)))
            } else {
                Ok(MalObject::Nil(MalNil::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn time_ms(_args: &[MalObject]) -> MalResult {
    let ms = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_millis();
    Ok(MalObject::Number(MalNumber::new(ms.try_into().unwrap())))
}

fn atom(args: &[MalObject]) -> MalResult {
    match args {
        [single] => Ok(MalObject::Atom(MalAtom::new(single.clone()))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn atomp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Atom(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn deref(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Atom(MalAtom { item, .. })] => Ok(item.borrow_mut().clone()),
        _ => Err(MalError::InvalidArguments),
    }
}

fn reset(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Atom(atom), x] => {
            *atom.item.borrow_mut() = x.clone();
            Ok(x.clone())
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn swap(args: &[MalObject]) -> MalResult {
    match args {
        [
            MalObject::Atom(atom),
            MalObject::Procedure(MalProcedure { func, .. })
            | MalObject::Closure(MalClosure { func, .. }),
            rest @ ..,
        ] => {
            let mut args = Vec::with_capacity(rest.len() + 1);
            args.push(atom.item.borrow().clone());
            args.extend_from_slice(rest);
            let value = func.call(&args)?;
            *atom.item.borrow_mut() = value.clone();
            Ok(value.clone())
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn cons(args: &[MalObject]) -> MalResult {
    match args {
        [
            x,
            MalObject::List(MalList { items: xs, .. })
            | MalObject::Vector(MalVector { items: xs, .. }),
        ] => {
            let mut vec: Vec<MalObject> = vec![x.clone()];
            vec.extend_from_slice(xs);
            Ok(MalObject::List(MalList::new(vec)))
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn concat(args: &[MalObject]) -> MalResult {
    args.iter()
        .try_fold(Vec::new(), |mut acc, arg| match arg {
            MalObject::List(MalList { items, .. }) | MalObject::Vector(MalVector { items, .. }) => {
                acc.extend_from_slice(items);
                Ok(acc)
            }
            _ => Err(MalError::InvalidArguments),
        })
        .map(|items| MalObject::List(MalList::new(items)))
}

fn vec(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Vector(_)] => Ok(args[0].clone()),
        [MalObject::List(MalList { items, .. })] => {
            Ok(MalObject::Vector(MalVector::new(items.to_vec())))
        }
        [_, ..] => Err(MalError::InvalidArguments),
        _ => Err(MalError::RuntimeError("seq expects a sequence".to_string())),
    }
}

fn nth(args: &[MalObject]) -> MalResult {
    match args {
        [
            MalObject::List(MalList { items, .. }) | MalObject::Vector(MalVector { items, .. }),
            MalObject::Number(MalNumber { n: index, .. }),
        ] => {
            if *index < items.len().try_into().unwrap() {
                Ok(items.get(*index as usize).unwrap().clone())
            } else {
                Err(MalError::RuntimeError(format!("Out of range: {index}")))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn first(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Nil(_)] => Ok(args[0].clone()),
        [MalObject::List(MalList { items, .. }) | MalObject::Vector(MalVector { items, .. })] => {
            if items.len() == 0 {
                Ok(MalObject::Nil(MalNil::new()))
            } else {
                Ok(items.first().unwrap().clone())
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn rest(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Nil(_)] => Ok(MalObject::List(MalList::new(vec![]))),
        [MalObject::List(MalList { items, .. }) | MalObject::Vector(MalVector { items, .. })] => {
            if items.len() == 0 {
                Ok(MalObject::List(MalList::new(vec![])))
            } else {
                let items = items.to_vec().into_iter().skip(1).collect::<Vec<_>>();
                Ok(MalObject::List(MalList::new(items)))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn conj(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Vector(MalVector { items, .. }), args @ ..] => {
            let mut items = items.to_vec();
            items.extend_from_slice(args);
            Ok(MalObject::Vector(MalVector::new(items)))
        }
        [MalObject::List(MalList { items, .. }), args @ ..] => {
            let mut args = args.to_vec();
            args.reverse();
            args.extend_from_slice(items);
            Ok(MalObject::Vector(MalVector::new(args)))
        }
        [_, ..] => Err(MalError::RuntimeError(
            "invalid collection type".to_string(),
        )),
        _ => Err(MalError::InvalidArguments),
    }
}

fn seq(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Nil(_)] => Ok(args[0].clone()),
        [MalObject::List(MalList { items, .. })] => {
            if items.len() == 0 {
                Ok(MalObject::Nil(MalNil::new()))
            } else {
                Ok(args[0].clone())
            }
        }
        [MalObject::Vector(MalVector { items, .. })] => {
            if items.len() == 0 {
                Ok(MalObject::Nil(MalNil::new()))
            } else {
                Ok(MalObject::List(MalList::new(items.to_vec())))
            }
        }
        [MalObject::String(MalString { string, .. })] => {
            if string.len() == 0 {
                Ok(MalObject::Nil(MalNil::new()))
            } else {
                let items = string
                    .chars()
                    .map(|s| MalObject::String(MalString::new(&s.to_string())))
                    .collect::<Vec<_>>();
                Ok(MalObject::List(MalList::new(items)))
            }
        }
        [_] => Err(MalError::RuntimeError(
            "invalid collection type".to_string(),
        )),
        _ => Err(MalError::InvalidArguments),
    }
}

fn apply(args: &[MalObject]) -> MalResult {
    match args {
        [
            MalObject::Procedure(MalProcedure { func, .. })
            | MalObject::Closure(MalClosure { func, .. }),
            args @ ..,
        ] => {
            let args_len = args.len();
            if args_len == 1 {
                func.call(&vec![args[0].clone()])
            } else {
                let last = args.last().unwrap();
                let mut args = args
                    .iter()
                    .take(args_len - 1)
                    .skip(1)
                    .map(|arg| arg.clone())
                    .collect::<Vec<_>>();
                if let MalObject::List(MalList { items, .. })
                | MalObject::Vector(MalVector { items, .. }) = last
                {
                    args.extend_from_slice(&items);
                } else {
                    return Err(MalError::InvalidArguments);
                }
                func.call(&args)
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn map(args: &[MalObject]) -> MalResult {
    match args {
        [
            MalObject::Procedure(MalProcedure { func, .. })
            | MalObject::Closure(MalClosure { func, .. }),
            MalObject::List(MalList { items, .. }) | MalObject::Vector(MalVector { items, .. }),
        ] => items
            .iter()
            .try_fold(Vec::new(), |mut acc, arg| {
                let item = func.call(&vec![arg.clone()])?;
                acc.push(item);
                Ok(acc)
            })
            .map(|items| MalObject::List(MalList::new(items))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn nilp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Nil(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn truep(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::True(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn falsep(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::False(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn numberp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Number(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn stringp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::String(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn symbolp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Symbol(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn symbol(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::String(MalString { string, .. })] => {
            Ok(MalObject::Symbol(MalSymbol::new(&string)))
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn keywordp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Keyword(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn keyword(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Keyword(_)] => Ok(args[0].clone()),
        [MalObject::String(MalString { string, .. })] => {
            Ok(MalObject::Keyword(MalKeyword::new(string)))
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn vectorp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Vector(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn vector(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::List(MalList { items, .. })] => {
            Ok(MalObject::Vector(MalVector::new(items.to_vec())))
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn mapp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Hashmap(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn hash_map(args: &[MalObject]) -> MalResult {
    args.chunks_exact(2)
        .try_fold(HashMap::new(), |mut m, entry| {
            let (k, v) = (entry[0].clone(), entry[1].clone());
            m.insert(k, v);
            Ok(m)
        })
        .map(|m| MalObject::Hashmap(MalHashmap::new(m)))
}

fn sequentialp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Vector(_) | MalObject::List(_)] => Ok(MalObject::True(MalTrue::new())),
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn fnp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Procedure(_)] => Ok(MalObject::True(MalTrue::new())),
        [
            MalObject::Closure(MalClosure {
                func: _, is_macro, ..
            }),
        ] => {
            if !*is_macro {
                Ok(MalObject::True(MalTrue::new()))
            } else {
                Ok(MalObject::False(MalFalse::new()))
            }
        }
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn macrop(args: &[MalObject]) -> MalResult {
    match args {
        [
            MalObject::Closure(MalClosure {
                func: _, is_macro, ..
            }),
        ] => {
            if *is_macro {
                Ok(MalObject::True(MalTrue::new()))
            } else {
                Ok(MalObject::False(MalFalse::new()))
            }
        }
        [_] => Ok(MalObject::False(MalFalse::new())),
        _ => Err(MalError::InvalidArguments),
    }
}

fn assoc(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Hashmap(MalHashmap { items, .. }), args @ ..] if args.len() % 2 == 0 => args
            .to_vec()
            .chunks_exact(2)
            .try_fold(items.clone(), |mut m, e| {
                let (k, v) = (e[0].clone(), e[1].clone());
                m.insert(k, v);
                Ok(m)
            })
            .map(|m| MalObject::Hashmap(MalHashmap::new(m))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn dissoc(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Hashmap(MalHashmap { items, .. }), args @ ..] => args
            .to_vec()
            .iter()
            .try_fold(items.clone(), |mut m, k| {
                m.remove(k);
                Ok(m)
            })
            .map(|m| MalObject::Hashmap(MalHashmap::new(m))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn get(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Hashmap(MalHashmap { items, .. }), key] => {
            if items.contains_key(key) {
                Ok(items.get(key).unwrap().clone())
            } else {
                Ok(MalObject::Nil(MalNil::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn containsp(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Hashmap(MalHashmap { items, .. }), key] => {
            if items.contains_key(key) {
                Ok(MalObject::True(MalTrue::new()))
            } else {
                Ok(MalObject::False(MalFalse::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn keys(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Hashmap(MalHashmap { items, .. })] => Ok(MalObject::List(MalList::new(
            items.keys().map(|k| k.clone()).collect::<Vec<_>>(),
        ))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn vals(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::Hashmap(MalHashmap { items, .. })] => Ok(MalObject::List(MalList::new(
            items.values().map(|v| v.clone()).collect::<Vec<_>>(),
        ))),
        _ => Err(MalError::InvalidArguments),
    }
}

fn with_meta(args: &[MalObject]) -> MalResult {
    match args {
        [MalObject::True(mal_true), meta] => {
            let mut mal_true = mal_true.clone();
            mal_true.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::True(mal_true))
        }
        [MalObject::False(mal_false), meta] => {
            let mut mal_false = mal_false.clone();
            mal_false.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::False(mal_false))
        }
        [MalObject::Nil(mal_nil), meta] => {
            let mut mal_nil = mal_nil.clone();
            mal_nil.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::Nil(mal_nil))
        }
        [MalObject::Number(mal_number), meta] => {
            let mut mal_number = mal_number.clone();
            mal_number.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::Number(mal_number))
        }
        [MalObject::String(mal_string), meta] => {
            let mut mal_string = mal_string.clone();
            mal_string.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::String(mal_string))
        }
        [MalObject::Symbol(mal_symbol), meta] => {
            let mut mal_symbol = mal_symbol.clone();
            mal_symbol.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::Symbol(mal_symbol))
        }
        [MalObject::Keyword(mal_keyword), meta] => {
            let mut mal_keyword = mal_keyword.clone();
            mal_keyword.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::Keyword(mal_keyword))
        }
        [MalObject::List(mal_list), meta] => {
            let mut mal_list = mal_list.clone();
            mal_list.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::List(mal_list))
        }
        [MalObject::Vector(mal_vector), meta] => {
            let mut mal_vector = mal_vector.clone();
            mal_vector.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::Vector(mal_vector))
        }
        [MalObject::Hashmap(mal_hashmap), meta] => {
            let mut mal_hashmap = mal_hashmap.clone();
            mal_hashmap.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::Hashmap(mal_hashmap))
        }
        [MalObject::Atom(mal_atom), meta] => {
            let mut mal_atom = mal_atom.clone();
            mal_atom.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::Atom(mal_atom))
        }
        [MalObject::Procedure(mal_procedure), meta] => {
            let mut mal_procedure = mal_procedure.clone();
            mal_procedure.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::Procedure(mal_procedure))
        }
        [MalObject::Closure(mal_closure), meta] => {
            let mut mal_closure = mal_closure.clone();
            mal_closure.meta = Some(Box::new(meta.clone()));
            Ok(MalObject::Closure(mal_closure))
        }
        _ => Err(MalError::InvalidArguments),
    }
}

fn meta(args: &[MalObject]) -> MalResult {
    match args {
        [
            MalObject::True(MalTrue { meta, .. })
            | MalObject::False(MalFalse { meta, .. })
            | MalObject::Nil(MalNil { meta, .. })
            | MalObject::Number(MalNumber { meta, .. })
            | MalObject::String(MalString { meta, .. })
            | MalObject::Symbol(MalSymbol { meta, .. })
            | MalObject::Keyword(MalKeyword { meta, .. })
            | MalObject::List(MalList { meta, .. })
            | MalObject::Vector(MalVector { meta, .. })
            | MalObject::Hashmap(MalHashmap { meta, .. })
            | MalObject::Atom(MalAtom { meta, .. })
            | MalObject::Procedure(MalProcedure { meta, .. })
            | MalObject::Closure(MalClosure { meta, .. }),
        ] => {
            if let Some(meta) = meta {
                Ok(*meta.clone())
            } else {
                Ok(MalObject::Nil(MalNil::new()))
            }
        }
        _ => Err(MalError::InvalidArguments),
    }
}

pub fn ns() -> Vec<(&'static str, fn(&[MalObject]) -> MalResult)> {
    vec![
        ("+", add),
        ("-", sub),
        ("*", mul),
        ("/", div),
        ("list", list),
        ("list?", listp),
        ("empty?", emptyp),
        ("count", count),
        ("=", equal),
        ("<", less),
        ("<=", less_equal),
        (">", greater),
        (">=", greater_equal),
        ("pr-str", pr_str),
        ("str", str),
        ("prn", prn),
        ("println", println),
        ("read-string", read_string),
        ("slurp", slurp),
        ("atom", atom),
        ("atom?", atomp),
        ("deref", deref),
        ("reset!", reset),
        ("swap!", swap),
        ("cons", cons),
        ("concat", concat),
        ("vec", vec),
        ("nth", nth),
        ("first", first),
        ("rest", rest),
        ("throw", throw),
        ("nil?", nilp),
        ("true?", truep),
        ("false?", falsep),
        ("symbol", symbol),
        ("symbol?", symbolp),
        ("keyword", keyword),
        ("keyword?", keywordp),
        ("number?", numberp),
        ("fn?", fnp),
        ("macro?", macrop),
        ("vector", vector),
        ("vector?", vectorp),
        ("hash-map", hash_map),
        ("map?", mapp),
        ("assoc", assoc),
        ("dissoc", dissoc),
        ("get", get),
        ("contains?", containsp),
        ("keys", keys),
        ("vals", vals),
        ("sequential?", sequentialp),
        ("readline", readline),
        ("time-ms", time_ms),
        ("conj", conj),
        ("string?", stringp),
        ("seq", seq),
        ("map", map),
        ("apply", apply),
        ("meta", meta),
        ("with-meta", with_meta),
    ]
}

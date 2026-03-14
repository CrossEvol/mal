use std::collections::HashMap;

use crate::types::{
    MalAtom, MalHashmap, MalKeyword, MalList, MalNumber, MalObject, MalString, MalSymbol, MalVector,
};

pub fn pr_str(ast: &MalObject, print_readably: bool) -> String {
    match &ast {
        MalObject::True(_) => "true".to_string(),
        MalObject::False(_) => "false".to_string(),
        MalObject::Nil(_) => "nil".to_string(),
        MalObject::Number(MalNumber { n, .. }) => n.to_string(),
        MalObject::String(MalString { string, .. }) => {
            if print_readably {
                let mut sb = String::new();
                sb.push('"');
                for c in string.chars() {
                    match c {
                        '\\' => sb.push_str("\\\\"),
                        '"' => sb.push_str("\\\""),
                        '\n' => sb.push_str("\\n"),
                        c => sb.push(c),
                    }
                }
                sb.push('"');
                sb
            } else {
                string.to_string()
            }
        }
        MalObject::Symbol(MalSymbol { name, .. }) => name.to_string(),
        MalObject::Keyword(MalKeyword { name, .. }) => format!(":{}", name),
        MalObject::List(MalList { items, .. }) => pr_list(items, '(', ')', print_readably),
        MalObject::Vector(MalVector { items, .. }) => pr_list(items, '[', ']', print_readably),
        MalObject::Hashmap(MalHashmap { items, .. }) => pr_map(items, '{', '}', print_readably),
        MalObject::Atom(MalAtom { item, .. }) => {
            format!("(atom {})", pr_str(&item.borrow(), print_readably))
        }
        MalObject::Procedure(_) => "#<fn>".to_string(),
        MalObject::Closure(_) => "#<func>".to_string(),
    }
}

pub fn pr_list(items: &[MalObject], starter: char, ender: char, print_readably: bool) -> String {
    let mut sb = String::new();
    sb.push(starter);
    let joined = &items
        .iter()
        .enumerate()
        .fold(String::new(), |mut acc, (i, o)| {
            if i > 0 {
                acc.push_str(" ");
            }
            acc.push_str(&pr_str(o, print_readably));
            acc
        });
    sb.push_str(joined);
    sb.push(ender);
    sb
}

pub fn pr_map(
    items: &HashMap<MalObject, MalObject>,
    starter: char,
    ender: char,
    print_readably: bool,
) -> String {
    let mut sb = String::new();
    sb.push(starter);
    let joined = &items
        .iter()
        .enumerate()
        .fold(String::new(), |mut acc, (i, (k, v))| {
            if i > 0 {
                acc.push_str(" ");
            }
            acc.push_str(&pr_str(k, print_readably));
            acc.push_str(" ");
            acc.push_str(&pr_str(v, print_readably));
            acc
        });
    sb.push_str(joined);
    sb.push(ender);
    sb
}

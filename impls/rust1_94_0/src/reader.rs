use std::collections::HashMap;

use crate::{
    error::MalError,
    types::{
        MalFalse, MalHashmap, MalKeyword, MalList, MalNil, MalNumber, MalObject, MalResult,
        MalString, MalSymbol, MalTrue, MalVector,
    },
};

struct Reader {
    tokens: Vec<String>,
    position: usize,
}

impl Reader {
    pub fn new(tokens: Vec<String>) -> Self {
        Self {
            tokens,
            position: 0,
        }
    }

    pub fn peek(&self) -> Option<&str> {
        self.tokens.get(self.position).map(|s| s.as_str())
    }

    pub fn next(&mut self) -> Option<String> {
        let token = if let Some(token) = self.peek() {
            Some(token.to_owned())
        } else {
            None
        };
        self.position += 1;
        token
    }

    pub fn read_form(&mut self) -> MalResult {
        let token = self.peek();
        if let Some(token) = token {
            match token {
                "'" => self.read_macro("quote"),
                "`" => self.read_macro("quasiquote"),
                "~" => self.read_macro("unquote"),
                "~@" => self.read_macro("splice-unquote"),
                "@" => self.read_macro("deref"),
                "^" => self.read_meta(),
                "(" => self.read_list(")", |items| Ok(MalObject::List(MalList::new(items)))),
                "{" => self.read_list("}", |items| {
                    if items.len() % 2 != 0 {
                        return Err(MalError::ParseError("unbalanced list".to_string()));
                    }

                    let items = items
                        .chunks_exact(2)
                        .map(|chunk| (chunk[0].clone(), chunk[1].clone()))
                        .collect::<HashMap<_, _>>();

                    Ok(MalObject::Hashmap(MalHashmap::new(items)))
                }),
                "[" => self.read_list("]", |items| Ok(MalObject::Vector(MalVector::new(items)))),
                _ => self.read_atom(),
            }
        } else {
            self.read_atom()
        }
    }

    pub fn read_macro(&mut self, symbol: &str) -> MalResult {
        self.next(); // skip macro token
        let symbol = MalObject::Symbol(MalSymbol::new(symbol));
        let form = self.read_form()?;
        Ok(MalObject::List(MalList::new(vec![symbol, form])))
    }

    pub fn read_meta(&mut self) -> MalResult {
        self.next(); // skip macro token
        let form = self.read_form()?;
        let meta = self.read_form()?;
        let with_meta = MalObject::Symbol(MalSymbol::new("with-meta"));
        Ok(MalObject::List(MalList::new(vec![with_meta, meta, form])))
    }

    pub fn read_list(&mut self, ender: &str, proc: fn(Vec<MalObject>) -> MalResult) -> MalResult {
        self.next(); // skip list start
        let mut items = Vec::new();
        while self.peek().is_some_and(|token| token != ender) {
            items.push(self.read_form()?);
        }
        if self.peek().is_some_and(|token| token == ender) {
            self.next(); // skip list end
            proc(items)
        } else {
            Err(MalError::ParseError(format!(
                "expected '{}', got EOF",
                ender
            )))
        }
    }

    pub fn read_atom(&mut self) -> MalResult {
        let token = self.next();
        if let Some(token) = token {
            if token == "true" {
                Ok(MalObject::True(MalTrue::new()))
            } else if token == "false" {
                Ok(MalObject::False(MalFalse::new()))
            } else if token == "nil" {
                Ok(MalObject::Nil(MalNil::new()))
            } else if token.parse::<i64>().is_ok() {
                let i = token.parse::<i64>().unwrap();
                Ok(MalObject::Number(MalNumber::new(i)))
            } else if token.chars().nth(0).is_some_and(|c| c == '"') {
                let mut chars = token.chars().skip(1); // skip start quote

                let mut s = String::new();
                while let Some(c) = chars.next() {
                    if c == '"' {
                        return Ok(MalObject::String(MalString::new(&s)));
                    }
                    if c == '\\' {
                        if let Some(next) = chars.next() {
                            s.push('\\');
                            s.push(next);
                        } else {
                            return Err(MalError::ParseError(format!("unbalanced")));
                        }
                    } else {
                        s.push(c);
                    }
                }

                return Err(MalError::ParseError(format!("EOF")));
            } else if token.chars().nth(0).is_some_and(|c| c == ':') {
                let s: String = token.chars().skip(1).collect();
                Ok(MalObject::Keyword(MalKeyword::new(&s)))
            } else {
                Ok(MalObject::Symbol(MalSymbol::new(&token)))
            }
        } else {
            Err(MalError::ParseError("end of token stream".to_string()))
        }
    }
}

pub fn read_str(input: &str) -> MalResult {
    let tokkens = tokenizer(input);
    let mut reader = Reader::new(tokkens);
    reader.read_form()
}

const SPECIAL_CHARS: &[char] = &['[', ']', '{', '}', '(', ')', '\'', '`', '~', '^', '@'];

const NON_WORD_CHARS: &[char] = &['[', ']', '{', '}', '(', ')', '\'', '"', '`', ';'];

fn is_whitespace_char(ch: &char) -> bool {
    ch.is_whitespace() || *ch == ','
}

fn is_special_char(ch: &char) -> bool {
    SPECIAL_CHARS.contains(ch)
}

fn is_non_word_char(ch: &char) -> bool {
    is_whitespace_char(ch) || NON_WORD_CHARS.contains(ch)
}

pub fn tokenizer(input: &str) -> Vec<String> {
    let mut tokens: Vec<String> = Vec::new();

    let mut char_iter = input.chars().peekable();
    let mut char = char_iter.next();
    loop {
        if let Some(ch) = char {
            if is_whitespace_char(&ch) {
                // skip
            } else if ch == '~' && char_iter.peek().is_some_and(|c| *c == '@') {
                char_iter.next();
                tokens.push("~@".to_string());
            } else if ch == '"' {
                let mut token = String::new();
                token.push(ch);
                while char_iter.peek().is_some_and(|c| *c != '"') {
                    if char_iter.peek().is_some_and(|c| *c == '\\') {
                        let c = char_iter.next().unwrap();
                        token.push(c);
                        let c = char_iter.next().unwrap();
                        token.push(c);
                    } else {
                        let c = char_iter.next().unwrap();
                        token.push(c);
                    }
                }
                if char_iter.peek().is_some_and(|c| *c == '"') {
                    char_iter.next();
                    token.push('"');
                }
                tokens.push(token);
            } else if ch == ';' {
                while char_iter.peek().is_some_and(|c| *c != '\n') {
                    char_iter.next();
                }
                char_iter.next(); // skip newline
            } else if is_special_char(&ch) {
                tokens.push(ch.to_string());
            } else {
                let mut token = String::new();
                token.push(ch);
                while char_iter.peek().is_some_and(|c| !is_non_word_char(&c)) {
                    token.push(char_iter.next().unwrap());
                }

                tokens.push(token);
            }
            char = char_iter.next();
        } else {
            break;
        }
    }

    tokens
}

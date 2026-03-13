use crate::env::Env;
use crate::error::MalError;
use std::cell::RefCell;
use std::collections::{HashMap, hash_map::DefaultHasher};
use std::fmt::Debug;
use std::hash::{Hash, Hasher};
use std::rc::Rc;

pub type MalResult = Result<MalObject, MalError>;

#[derive(Hash, Clone, Debug)]
pub enum MalObject {
    True(MalTrue),
    False(MalFalse),
    Nil(MalNil),
    Number(MalNumber),
    String(MalString),
    Symbol(MalSymbol),
    Keyword(MalKeyword),
    List(MalList),
    Vector(MalVector),
    Hashmap(MalHashmap),
    Atom(MalAtom),
    Procedure(MalProcedure),
    Closure(MalClosure),
}

impl PartialEq for MalObject {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::True(l0), Self::True(r0)) => l0 == r0,
            (Self::False(l0), Self::False(r0)) => l0 == r0,
            (Self::Nil(l0), Self::Nil(r0)) => l0 == r0,
            (Self::Number(l0), Self::Number(r0)) => l0 == r0,
            (Self::String(l0), Self::String(r0)) => l0 == r0,
            (Self::Symbol(l0), Self::Symbol(r0)) => l0 == r0,
            (Self::Keyword(l0), Self::Keyword(r0)) => l0 == r0,
            (
                Self::List(MalList { items: l0, .. }) | Self::Vector(MalVector { items: l0, .. }),
                Self::List(MalList { items: r0, .. }) | Self::Vector(MalVector { items: r0, .. }),
            ) => l0 == r0,
            (Self::Hashmap(l0), Self::Hashmap(r0)) => l0 == r0,
            (Self::Atom(l0), Self::Atom(r0)) => l0 == r0,
            (Self::Procedure(l0), Self::Procedure(r0)) => l0 == r0,
            (Self::Closure(l0), Self::Closure(r0)) => l0 == r0,
            _ => false,
        }
    }
}

impl Eq for MalObject {}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalTrue {
    pub meta: Option<Box<MalObject>>,
}

impl MalTrue {
    pub fn new() -> Self {
        Self { meta: None }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalFalse {
    pub meta: Option<Box<MalObject>>,
}

impl MalFalse {
    pub fn new() -> Self {
        Self { meta: None }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalNil {
    pub meta: Option<Box<MalObject>>,
}

impl MalNil {
    pub fn new() -> Self {
        Self { meta: None }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalNumber {
    pub n: i64,
    pub meta: Option<Box<MalObject>>,
}

impl MalNumber {
    pub fn new(n: i64) -> Self {
        Self { n, meta: None }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalString {
    pub string: Rc<str>,
    pub meta: Option<Box<MalObject>>,
}

impl MalString {
    pub fn new(string: &str) -> Self {
        Self {
            string: Rc::from(string),
            meta: None,
        }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalSymbol {
    pub name: Rc<str>,
    pub meta: Option<Box<MalObject>>,
}

impl MalSymbol {
    pub fn new(symbol: &str) -> Self {
        Self {
            name: Rc::from(symbol),
            meta: None,
        }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalKeyword {
    pub name: Rc<str>,
    pub meta: Option<Box<MalObject>>,
}

impl MalKeyword {
    pub fn new(keyword: &str) -> Self {
        Self {
            name: Rc::from(keyword),
            meta: None,
        }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalList {
    pub items: Vec<MalObject>,
    pub meta: Option<Box<MalObject>>,
}

impl MalList {
    pub fn new(items: Vec<MalObject>) -> Self {
        Self { items, meta: None }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalVector {
    pub items: Vec<MalObject>,
    pub meta: Option<Box<MalObject>>,
}

impl MalVector {
    pub fn new(items: Vec<MalObject>) -> Self {
        Self { items, meta: None }
    }
}

#[derive(Clone, Debug)]
pub struct MalHashmap {
    pub items: HashMap<MalObject, MalObject>,
    pub meta: Option<Box<MalObject>>,
}

impl PartialEq for MalHashmap {
    fn eq(&self, other: &Self) -> bool {
        if self.items.len() != other.items.len() {
            return false;
        }
        for (k, v) in self.items.iter() {
            if !other.items.contains_key(k) {
                return false;
            }
            if other.items.get(k) != Some(v) {
                return false;
            }
        }
        true
    }
}

impl Eq for MalHashmap {}

impl MalHashmap {
    pub fn new(items: HashMap<MalObject, MalObject>) -> Self {
        Self { items, meta: None }
    }
}

impl Hash for MalHashmap {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let mut combined: u64 = 0;
        for (key, value) in self.items.iter() {
            let mut pair_hasher = DefaultHasher::new();
            key.hash(&mut pair_hasher);
            value.hash(&mut pair_hasher);
            combined ^= pair_hasher.finish();
        }
        combined.hash(state);
        self.meta.hash(state); // TODO:这里有必要吗？
    }
}

#[derive(Eq, Clone, Debug)]
pub struct MalAtom {
    pub item: Rc<RefCell<MalObject>>,
    pub meta: Option<Box<MalObject>>,
}

impl MalAtom {
    pub fn new(item: MalObject) -> Self {
        Self {
            item: Rc::new(RefCell::new(item)),
            meta: None,
        }
    }
}

impl PartialEq for MalAtom {
    fn eq(&self, other: &Self) -> bool {
        Rc::ptr_eq(&self.item, &other.item)
    }
}

impl Hash for MalAtom {
    fn hash<H: Hasher>(&self, state: &mut H) {
        (Rc::as_ptr(&self.item) as usize).hash(state)
    }
}

#[derive(Clone)]
pub struct MalFunction(pub Rc<dyn Fn(&[MalObject]) -> MalResult + 'static>);

pub fn mal_func(f: impl Fn(&[MalObject]) -> MalResult + 'static) -> MalFunction {
    MalFunction(Rc::new(f))
}

pub fn mal_procedure(f: impl Fn(&[MalObject]) -> MalResult + 'static) -> MalObject {
    MalObject::Procedure(MalProcedure::new(MalFunction(Rc::new(f))))
}

impl MalFunction {
    pub fn call(&self, args: &[MalObject]) -> MalResult {
        self.0(args)
    }
}

impl Debug for MalFunction {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_tuple("MalFunction").finish()
    }
}

impl PartialEq for MalFunction {
    fn eq(&self, other: &Self) -> bool {
        Rc::ptr_eq(&self.0, &other.0)
    }
}

impl Eq for MalFunction {}

impl Hash for MalFunction {
    fn hash<H: Hasher>(&self, state: &mut H) {
        (Rc::as_ptr(&self.0) as *const () as usize).hash(state)
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalProcedure {
    pub func: MalFunction,
    pub meta: Option<Box<MalObject>>,
}

impl MalProcedure {
    pub fn new(func: MalFunction) -> Self {
        Self { func, meta: None }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MalClosure {
    ast: Box<MalObject>,
    params: Vec<MalObject>,
    env: Env,
    pub func: MalFunction,
    pub is_macro: bool,
    pub meta: Option<Box<MalObject>>,
}

impl MalClosure {
    pub fn new(
        ast: Box<MalObject>,
        params: Vec<MalObject>,
        env: Env,
        func: MalFunction,
        is_macro: bool,
    ) -> Self {
        Self {
            ast,
            params,
            env,
            func,
            is_macro,
            meta: None,
        }
    }
}

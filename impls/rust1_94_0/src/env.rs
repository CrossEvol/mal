use crate::types::{MalList, MalObject, MalSymbol};
use std::{cell::RefCell, collections::HashMap, hash::Hash, rc::Rc};

#[derive(PartialEq, Eq, Debug, Clone)]
pub struct Env(Rc<RefCell<EnvInner>>);

impl Hash for Env {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        (self as *const Env as usize).hash(state)
    }
}

impl Env {
    pub fn new(
        outer: Option<Env>,
        binds: Option<Vec<MalSymbol>>,
        exprs: Option<Vec<MalObject>>,
    ) -> Self {
        Self(Rc::new(RefCell::new(EnvInner::new(outer, binds, exprs))))
    }

    pub fn set(&mut self, key: MalSymbol, value: MalObject) -> Option<MalObject> {
        self.0.borrow_mut().set(key, value)
    }

    pub fn get(&self, key: &MalSymbol) -> Option<MalObject> {
        self.0.borrow().get(key)
    }
}

#[derive(Eq, Debug)]
struct EnvInner {
    outer: Option<Env>,
    data: HashMap<MalSymbol, MalObject>,
}

impl PartialEq for EnvInner {
    fn eq(&self, other: &Self) -> bool {
        std::ptr::eq(self, other)
    }
}

impl EnvInner {
    fn empty_env(outer: Option<Env>) -> Self {
        Self {
            outer,
            data: HashMap::new(),
        }
    }

    fn new(
        outer: Option<Env>,
        binds: Option<Vec<MalSymbol>>,
        exprs: Option<Vec<MalObject>>,
    ) -> Self {
        match (binds, exprs) {
            (Some(binds), Some(exprs)) => {
                let mut env = Self::empty_env(outer);
                let mut bind_iter = binds.into_iter();
                let mut expr_iter = exprs.into_iter();
                let mut bind = bind_iter.next();
                let mut expr = expr_iter.next();
                loop {
                    match (bind, expr) {
                        (Some(key), Some(value)) => {
                            if key.name.to_string() == "&" {
                                bind_iter.next(); // skip '&'
                                let exprs: Vec<MalObject> = expr_iter.collect();
                                env.set(key, MalObject::List(MalList::new(exprs)));
                                break;
                            } else {
                                env.set(key, value);
                                bind = bind_iter.next();
                                expr = expr_iter.next();
                            }
                        }
                        _ => break,
                    }
                }
                env
            }
            _ => Self::empty_env(outer),
        }
    }

    fn set(&mut self, key: MalSymbol, value: MalObject) -> Option<MalObject> {
        self.data.insert(key, value)
    }

    fn get(&self, key: &MalSymbol) -> Option<MalObject> {
        if self.data.contains_key(key) {
            self.data.get(key).cloned()
        } else if let Some(outer) = &self.outer {
            outer.get(key)
        } else {
            None
        }
    }
}

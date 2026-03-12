use crate::types::MalObject;

#[derive(Debug, Clone)]
pub enum MalError {
    UserError(MalObject),
    ParseError(String),
    InvalidArguments,
    RuntimeError(String),
    NotFound(String),
}

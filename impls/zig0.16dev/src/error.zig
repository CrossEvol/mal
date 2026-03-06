const std = @import("std");

pub const MalError = error{
    LackOfCatchClause,
    OutOfMemory,
    Overflow,
    InvalidCharacter,
    EOF,
    ParseError,
    NoInput,
    ImpossibleState,
    Unbalanced,
    InvalidRegex,
    UnrecognizedType,
    IncompatibleTypeConversion,
    SymbolNotFound,
    InvalidArgument,
    InvalidArgCount,
    IndexOutOfRange,
} || std.Io.Writer.Error || std.Io.File.OpenError || std.Io.File.StatError || std.Io.Cancelable || std.Io.UnexpectedError || std.Io.Reader.Error;

///|
pub enum UnaryOp {
  Plus
  Minus
} derive(Eq, Show)

///|
pub enum BinaryOp {
  Add
  Sub
  Mul
  Div
  Pow
} derive(Eq, Show)

///|
pub enum CompareOp {
  Eq
  EqEq
  Lt
  Le
  Gt
  Ge
} derive(Eq, Show)

///|
pub enum Ast {
  Number(span~ : Span, String)
  Symbol(span~ : Span, String)
  Unary(span~ : Span, UnaryOp, Ast)
  Binary(span~ : Span, BinaryOp, Ast, Ast)
  Call(span~ : Span, Ast, Array[Ast])
  Tuple(span~ : Span, Array[Ast])
  Compare(span~ : Span, Array[Ast], Array[CompareOp])
}

///|
pub fn ast_span(ast : Ast) -> Span {
  match ast {
    Ast::Number(span~, _) => span
    Ast::Symbol(span~, _) => span
    Ast::Unary(span~, _, _) => span
    Ast::Binary(span~, _, _, _) => span
    Ast::Call(span~, _, _) => span
    Ast::Tuple(span~, _) => span
    Ast::Compare(span~, _, _) => span
  }
}

///|
pub struct ParseOptions {
  caret_as_power : Bool
  evaluate : Bool
  implicit_multiplication : Bool
  implicit_application : Bool
  function_exponentiation : Bool
  factorial_notation : Bool
  convert_equals_signs : Bool
} derive(Eq, Show)

///|
pub struct ParseContext {
  callable_names : Array[String]
  bindings : Map[String, Expr]
  global_callable_names : Array[String]
  global_bindings : Map[String, Expr]
} derive(Eq)

///|
pub fn default_parse_options() -> ParseOptions {
  ParseOptions::{
    caret_as_power: true,
    evaluate: true,
    implicit_multiplication: false,
    implicit_application: false,
    function_exponentiation: false,
    factorial_notation: false,
    convert_equals_signs: false,
  }
}

///|
pub fn default_parse_context() -> ParseContext {
  ParseContext::{
    callable_names: [],
    bindings: {},
    global_callable_names: [],
    global_bindings: {},
  }
}

///|
pub fn parse_context(
  callable_names? : Array[String] = [],
  bindings? : Map[String, Expr] = {},
  global_callable_names? : Array[String] = [],
  global_bindings? : Map[String, Expr] = {},
) -> ParseContext {
  ParseContext::{
    callable_names,
    bindings,
    global_callable_names,
    global_bindings,
  }
}

///|
pub fn parse_options(
  caret_as_power? : Bool = true,
  evaluate? : Bool = true,
  implicit_multiplication? : Bool = false,
  implicit_application? : Bool = false,
  function_exponentiation? : Bool = false,
  factorial_notation? : Bool = false,
  convert_equals_signs? : Bool = false,
) -> ParseOptions {
  ParseOptions::{
    caret_as_power,
    evaluate,
    implicit_multiplication,
    implicit_application,
    function_exponentiation,
    factorial_notation,
    convert_equals_signs,
  }
}

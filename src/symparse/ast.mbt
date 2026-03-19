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
} derive(Eq, Show)

///|
pub fn default_parse_options() -> ParseOptions {
  ParseOptions::{ caret_as_power: true, evaluate: true }
}

///|
pub fn parse_options(
  caret_as_power? : Bool = true,
  evaluate? : Bool = true,
) -> ParseOptions {
  ParseOptions::{ caret_as_power, evaluate }
}

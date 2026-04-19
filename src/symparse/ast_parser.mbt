///|
/// Lightweight AST-parser compatibility front door.
///
/// Current Limits:
/// - This helper enables only lambda notation, automatic symbols, and automatic
///   numbers.
/// - It does not turn on the relaxed parser conveniences.

///|
fn ast_parser_transformations() -> Array[Transformation] {
  [
    Transformation::LambdaNotation,
    Transformation::AutoSymbol,
    Transformation::AutoNumber,
  ]
}

///|
/// Parse a source string using the lightweight AST-parser configuration.
///
/// This helper is intended for places that want convenient expression parsing
/// without the full relaxed syntax pipeline. Only a small transformation set is
/// enabled: lambda syntax, automatic symbols, and automatic numeric literals.
///
/// - Does: Parses source text into `Expr` with the lightweight AST-parser
///   transformation set.
/// - Input: A source string and optional local name bindings.
/// - Returns: A `symcore.Expr`, or raises `ParseError`.
/// - Limits: Does not enable implicit multiplication, `^` power conversion, or
///   custom callable-name declarations.
pub fn ast_parse_expr(
  src : String,
  local_bindings? : Map[String, Expr] = {},
) -> Expr raise ParseError {
  parse_expr_in(
    src,
    parse_options(transformations=ast_parser_transformations(), evaluate=true),
    parse_context(bindings=local_bindings),
  )
}

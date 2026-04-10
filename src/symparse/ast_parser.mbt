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

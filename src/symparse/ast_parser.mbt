///|
fn ast_parser_transformations() -> Array[Transformation] {
  [
    Transformation::LambdaNotation,
    Transformation::AutoSymbol,
    Transformation::AutoNumber,
  ]
}

///|
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

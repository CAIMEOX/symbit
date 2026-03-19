///|
/// Parse a source string into a `symcore.Expr` using the default parser
/// options.
pub fn parse_expr(src : String) -> @symcore.Expr raise ParseError {
  lower_ast(parse_ast(src))
}

///|
/// Parse a source string into a `symcore.Expr` with explicit parser options.
pub fn parse_expr_with(
  src : String,
  options : ParseOptions,
) -> @symcore.Expr raise ParseError {
  lower_ast_with(parse_ast_with(src, options), options)
}

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

///|
pub fn parse_expr_in(
  src : String,
  options : ParseOptions,
  context : ParseContext,
) -> @symcore.Expr raise ParseError {
  lower_ast_in(parse_ast_in(src, options, context), options, context)
}

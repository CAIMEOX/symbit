///|
/// Parse a source string into a `symcore.Expr` using the default parser
/// options.
pub fn parse_expr(src : String) -> Expr raise ParseError {
  parse_expr_with(src, default_parse_options())
}

///|
/// Parse a source string into a `symcore.Expr` with explicit parser options.
pub fn parse_expr_with(
  src : String,
  options : ParseOptions,
) -> Expr raise ParseError {
  lower_ast_with(parse_ast_with(src, options), options)
}

///|
pub fn parse_expr_in(
  src : String,
  options : ParseOptions,
  context : ParseContext,
) -> Expr raise ParseError {
  lower_ast_in(parse_ast_in(src, options, context), options, context)
}

///|
pub fn parse_expr_with_transformations(
  src : String,
  transformations : Array[Transformation],
  evaluate? : Bool = true,
) -> Expr raise ParseError {
  parse_expr_with(src, parse_options(transformations~, evaluate~))
}

///|
pub fn parse_expr_in_with_transformations(
  src : String,
  transformations : Array[Transformation],
  context : ParseContext,
  evaluate? : Bool = true,
) -> Expr raise ParseError {
  parse_expr_in(src, parse_options(transformations~, evaluate~), context)
}

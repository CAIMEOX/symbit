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
/// Parse a source string with explicit options and name bindings.
///
/// Use this entry point when symbol lookup depends on a caller-supplied
/// environment. `context` can pre-bind names to expressions and mark names as
/// callable so that parsing can distinguish `f(x)` from `f * (x)`.
pub fn parse_expr_in(
  src : String,
  options : ParseOptions,
  context : ParseContext,
) -> Expr raise ParseError {
  lower_ast_in(parse_ast_in(src, options, context), options, context)
}

///|
/// Parse a source string with a custom transformation pipeline.
///
/// `transformations` controls syntax conveniences such as automatic symbol
/// creation, implicit multiplication, or caret-to-power rewriting. Set
/// `evaluate=false` to keep raw tree shape where possible instead of folding
/// arithmetic during lowering.
pub fn parse_expr_with_transformations(
  src : String,
  transformations : Array[Transformation],
  evaluate? : Bool = true,
) -> Expr raise ParseError {
  parse_expr_with(src, parse_options(transformations~, evaluate~))
}

///|
/// Parse a source string with both custom transformations and a custom context.
///
/// This is the most configurable front-end in the package. Use it when parsing
/// user input that needs special syntax rules and predeclared local names.
pub fn parse_expr_in_with_transformations(
  src : String,
  transformations : Array[Transformation],
  context : ParseContext,
  evaluate? : Bool = true,
) -> Expr raise ParseError {
  parse_expr_in(src, parse_options(transformations~, evaluate~), context)
}

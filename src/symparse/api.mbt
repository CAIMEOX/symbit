///|
/// Public expression parser front doors.
///
/// Current Limits:
/// - The parser covers the package's current Python-like expression subset.
/// - Unsupported syntax raises `ParseError` with source spans.
/// - External parser formats such as LaTeX, Fortran, Mathematica, and Maxima are
///   outside this front door.

///|
/// Parse a source string into a `symcore.Expr` using the default parser
/// options.
///
/// - Does: Tokenizes, parses, and lowers source text with default options.
/// - Input: A source string containing one expression.
/// - Returns: A `symcore.Expr`, or raises `ParseError` on invalid input.
/// - Limits: Uses the standard transformation set, not relaxed implicit
///   multiplication or custom bindings.
pub fn parse_expr(src : String) -> Expr raise ParseError {
  parse_expr_with(src, default_parse_options())
}

///|
/// Parse a source string into a `symcore.Expr` with explicit parser options.
///
/// - Does: Tokenizes, parses, and lowers source text using caller-supplied
///   parser options.
/// - Input: A source string and `ParseOptions`.
/// - Returns: A `symcore.Expr`, or raises `ParseError` on invalid input.
/// - Limits: Name resolution uses an empty context.
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
///
/// - Does: Tokenizes, parses, and lowers source text using explicit options and
///   name-resolution context.
/// - Input: A source string, parser options, and parse context.
/// - Returns: A `symcore.Expr`, or raises `ParseError` on invalid input or
///   unsupported lowering.
/// - Limits: Context bindings only affect names handled by the current lowering
///   pipeline.
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
///
/// - Does: Parses source text with a caller-supplied transformation list.
/// - Input: A source string, transformation array, and optional `evaluate` flag.
/// - Returns: A `symcore.Expr`, or raises `ParseError`.
/// - Limits: Name resolution uses an empty context.
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
///
/// - Does: Parses source text with custom transformations and custom
///   name-resolution context.
/// - Input: A source string, transformation array, parse context, and optional
///   `evaluate` flag.
/// - Returns: A `symcore.Expr`, or raises `ParseError`.
/// - Limits: Unsupported syntax and unsupported lowering constructs still raise
///   `ParseError`.
pub fn parse_expr_in_with_transformations(
  src : String,
  transformations : Array[Transformation],
  context : ParseContext,
  evaluate? : Bool = true,
) -> Expr raise ParseError {
  parse_expr_in(src, parse_options(transformations~, evaluate~), context)
}

///|
/// Parser AST, options, and transformation descriptors.
///
/// Current Limits:
/// - The AST represents the expression grammar currently supported by
///   `symparse`.
/// - Transformations are switches for this parser pipeline, not a complete
///   clone of every external parser mode.

///|
/// Unary operators that can appear in parsed syntax.
///
/// - Does: Represents unary plus and unary minus before lowering.
/// - Input: Produced by the expression parser.
/// - Returns: A `UnaryOp` variant stored inside `Ast::Unary`.
/// - Limits: Only prefix `+` and `-` are represented.
pub enum UnaryOp {
  Plus
  Minus
} derive(Eq, Debug)

///|
/// Binary arithmetic operators that can appear in parsed syntax.
///
/// - Does: Represents infix arithmetic operators before lowering.
/// - Input: Produced by the expression parser.
/// - Returns: A `BinaryOp` variant stored inside `Ast::Binary`.
/// - Limits: Only addition, subtraction, multiplication, division, and power are
///   represented.
pub enum BinaryOp {
  Add
  Sub
  Mul
  Div
  Pow
} derive(Eq, Debug)

///|
/// Comparison operators recorded in parsed comparison chains.
///
/// - Does: Represents equality and ordering operators before lowering.
/// - Input: Produced by the expression parser.
/// - Returns: A `CompareOp` variant stored inside `Ast::Compare`.
/// - Limits: Single `=` is only accepted when the relevant transformation is
///   enabled.
pub enum CompareOp {
  Eq
  EqEq
  Ne
  Lt
  Le
  Gt
  Ge
} derive(Eq, Debug)

///|
/// A parser transformation switch.
///
/// Transformations enable or disable syntax conveniences before lowering. For
/// example, implicit multiplication lets `2x` parse as `2*x`, while
/// `ConvertXor` treats `^` as exponentiation.
///
/// - Does: Describes one parser transformation switch.
/// - Input: Passed in `ParseOptions.transformations`.
/// - Returns: A `Transformation` value consumed by parsing and lowering.
/// - Limits: Some switches are conservative and only cover the syntax currently
///   implemented in `parser_expr`.
pub(all) enum Transformation {
  LambdaNotation
  AutoSymbol
  RepeatedDecimals
  AutoNumber
  FactorialNotation
  SplitSymbols
  SplitSymbolsCustom((String) -> Bool)
  ImplicitMultiplication
  ImplicitApplication
  FunctionExponentiation
  ConvertXor
  ConvertEqualsSigns
  Rationalize
  ImplicitMultiplicationApplication
}

///|
/// Typed syntax tree produced by the parser before lowering to `Expr`.
///
/// The AST preserves source spans and syntactic distinctions such as unary
/// minus, chained comparisons, and lambda syntax. Lowering can then decide how
/// much evaluation to perform.
///
/// - Does: Stores parsed syntax before it is converted to `symcore.Expr`.
/// - Input: Produced by `parse_ast*` front doors or constructed directly by
///   callers.
/// - Returns: An `Ast` tree carrying spans and operator structure.
/// - Limits: Represents only the grammar supported by this package.
pub enum Ast {
  Number(span~ : Span, String)
  Symbol(span~ : Span, String)
  Unary(span~ : Span, UnaryOp, Ast)
  Binary(span~ : Span, BinaryOp, Ast, Ast)
  Call(span~ : Span, Ast, Array[Ast])
  Tuple(span~ : Span, Array[Ast])
  Compare(span~ : Span, Array[Ast], Array[CompareOp])
  Lambda(span~ : Span, Array[String], Ast)
}

///|
/// Return the source span that covers an AST node.
///
/// - Does: Extracts the stored source span from any AST variant.
/// - Input: One `Ast` node.
/// - Returns: The half-open `Span` associated with that node.
/// - Limits: Assumes the AST was built with meaningful spans.
pub fn ast_span(ast : Ast) -> Span {
  match ast {
    Number(span~, _) => span
    Symbol(span~, _) => span
    Unary(span~, _, _) => span
    Binary(span~, _, _, _) => span
    Call(span~, _, _) => span
    Tuple(span~, _) => span
    Compare(span~, _, _) => span
    Lambda(span~, _, _) => span
  }
}

///|
/// Parser configuration controlling evaluation and syntax rewrites.
///
/// `evaluate` decides whether lowering should immediately fold simple arithmetic
/// and normalize constructor calls. `transformations` enables optional syntax
/// features such as automatic symbol creation or implicit multiplication.
///
/// - Does: Stores parser and lowering options.
/// - Input: Built with `parse_options` or struct construction.
/// - Returns: A `ParseOptions` value.
/// - Limits: Options only affect behavior implemented in this package.
pub struct ParseOptions {
  evaluate : Bool
  transformations : Array[Transformation]
}

///|
/// Name-resolution environment used while parsing and lowering.
///
/// Local bindings shadow global ones. The callable-name fields let the parser
/// treat certain names as function heads even before lowering them to runtime
/// expressions.
///
/// - Does: Stores local/global name bindings and callable-name declarations.
/// - Input: Built with `parse_context` or struct construction.
/// - Returns: A `ParseContext` value.
/// - Limits: Binding resolution is limited to names handled by the current
///   parser and lowerer.
pub struct ParseContext {
  callable_names : Array[String]
  bindings : Map[String, Expr]
  global_callable_names : Array[String]
  global_bindings : Map[String, Expr]
} derive(Eq)

///|
/// Return the default parser options.
///
/// The default configuration enables the standard transformation set and
/// performs normal evaluation while lowering.
///
/// - Does: Builds the default `ParseOptions`.
/// - Input: No input.
/// - Returns: `ParseOptions` with standard transformations and evaluation
///   enabled.
/// - Limits: Does not include relaxed transformations such as implicit
///   multiplication.
pub fn default_parse_options() -> ParseOptions {
  { evaluate: true, transformations: standard_transformations() }
}

///|
/// Return an empty parse context with no predefined names.
///
/// - Does: Builds an empty `ParseContext`.
/// - Input: No input.
/// - Returns: A context with empty binding and callable-name tables.
/// - Limits: Does not predeclare any user-level callable names.
pub fn default_parse_context() -> ParseContext {
  {
    callable_names: [],
    bindings: {},
    global_callable_names: [],
    global_bindings: {},
  }
}

///|
/// Build a parse context from explicit local and global bindings.
///
/// Use `callable_names` when a name should parse as a function head, and use
/// `bindings` when a name should resolve to a concrete expression value.
///
/// - Does: Builds a `ParseContext` from optional local and global tables.
/// - Input: Optional callable-name arrays and binding maps.
/// - Returns: A `ParseContext` value.
/// - Limits: Does not validate that callable names and bindings are consistent.
pub fn parse_context(
  callable_names? : Array[String] = [],
  bindings? : Map[String, Expr] = {},
  global_callable_names? : Array[String] = [],
  global_bindings? : Map[String, Expr] = {},
) -> ParseContext {
  { callable_names, bindings, global_callable_names, global_bindings }
}

///|
/// Build parser options from a transformation list and evaluation flag.
///
/// - Does: Builds `ParseOptions` from caller-provided settings.
/// - Input: Optional transformation array and optional `evaluate` flag.
/// - Returns: A `ParseOptions` value.
/// - Limits: Does not validate mutually redundant transformation switches.
pub fn parse_options(
  transformations? : Array[Transformation] = standard_transformations(),
  evaluate? : Bool = true,
) -> ParseOptions {
  { evaluate, transformations: transformations.map(x => x) }
}

///|
/// Return the conservative transformation set used by default parsing.
///
/// These transformations cover common numeric and symbol syntax without turning
/// on more opinionated rewrites such as implicit multiplication.
///
/// - Does: Returns the default transformation pipeline.
/// - Input: No input.
/// - Returns: An array of `Transformation` values.
/// - Limits: Omits relaxed syntax conveniences such as implicit multiplication
///   and `^` power conversion.
pub fn standard_transformations() -> Array[Transformation] {
  [LambdaNotation, AutoSymbol, RepeatedDecimals, AutoNumber, FactorialNotation]
}

///|
/// Return a more permissive transformation set for user-facing input.
///
/// This extends [`standard_transformations`](#standard_transformations) with
/// conveniences such as caret exponentiation, implicit multiplication plus
/// application, and single equals signs in comparisons.
///
/// - Does: Returns a more permissive transformation pipeline.
/// - Input: No input.
/// - Returns: An array of `Transformation` values.
/// - Limits: Still limited to the grammar implemented in this package.
pub fn relaxed_transformations() -> Array[Transformation] {
  [
    ..standard_transformations(),
    ConvertXor,
    ImplicitMultiplicationApplication,
    ConvertEqualsSigns,
  ]
}

///|
fn option_has(options : ParseOptions, target : Transformation) -> Bool {
  for transformation in options.transformations {
    match (transformation, target) {
      (LambdaNotation, LambdaNotation)
      | (AutoSymbol, AutoSymbol)
      | (RepeatedDecimals, RepeatedDecimals)
      | (AutoNumber, AutoNumber)
      | (FactorialNotation, FactorialNotation)
      | (SplitSymbols, SplitSymbols)
      | (ImplicitMultiplication, ImplicitMultiplication)
      | (ImplicitApplication, ImplicitApplication)
      | (FunctionExponentiation, FunctionExponentiation)
      | (ConvertXor, ConvertXor)
      | (ConvertEqualsSigns, ConvertEqualsSigns)
      | (Rationalize, Rationalize)
      | (ImplicitMultiplicationApplication, ImplicitMultiplicationApplication) =>
        return true
      (SplitSymbolsCustom(_), SplitSymbols) => return true
      _ => ()
    }
  }
  false
}

///|
fn option_has_lambda(options : ParseOptions) -> Bool {
  option_has(options, LambdaNotation)
}

///|
fn option_has_auto_symbol(options : ParseOptions) -> Bool {
  option_has(options, AutoSymbol)
}

///|
fn option_has_repeated_decimals(options : ParseOptions) -> Bool {
  option_has(options, RepeatedDecimals)
}

///|
fn option_has_factorial(options : ParseOptions) -> Bool {
  option_has(options, FactorialNotation)
}

///|
fn option_has_implicit_multiplication(options : ParseOptions) -> Bool {
  option_has(options, ImplicitMultiplication) ||
  option_has(options, ImplicitMultiplicationApplication)
}

///|
fn option_has_implicit_application(options : ParseOptions) -> Bool {
  option_has(options, ImplicitApplication) ||
  option_has(options, ImplicitMultiplicationApplication)
}

///|
fn option_has_function_exponentiation(options : ParseOptions) -> Bool {
  option_has(options, FunctionExponentiation) ||
  option_has(options, ImplicitMultiplicationApplication)
}

///|
fn option_has_convert_xor(options : ParseOptions) -> Bool {
  option_has(options, ConvertXor)
}

///|
fn option_has_convert_equals_signs(options : ParseOptions) -> Bool {
  option_has(options, ConvertEqualsSigns)
}

///|
fn option_has_rationalize(options : ParseOptions) -> Bool {
  option_has(options, Rationalize)
}

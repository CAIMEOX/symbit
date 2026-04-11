///|
/// Unary operators that can appear in parsed syntax.
pub enum UnaryOp {
  Plus
  Minus
} derive(Eq, Debug)

///|
/// Binary arithmetic operators that can appear in parsed syntax.
pub enum BinaryOp {
  Add
  Sub
  Mul
  Div
  Pow
} derive(Eq, Debug)

///|
/// Comparison operators recorded in parsed comparison chains.
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
pub fn ast_span(ast : Ast) -> Span {
  match ast {
    Ast::Number(span~, _) => span
    Ast::Symbol(span~, _) => span
    Ast::Unary(span~, _, _) => span
    Ast::Binary(span~, _, _, _) => span
    Ast::Call(span~, _, _) => span
    Ast::Tuple(span~, _) => span
    Ast::Compare(span~, _, _) => span
    Ast::Lambda(span~, _, _) => span
  }
}

///|
/// Parser configuration controlling evaluation and syntax rewrites.
///
/// `evaluate` decides whether lowering should immediately fold simple arithmetic
/// and normalize constructor calls. `transformations` enables optional syntax
/// features such as automatic symbol creation or implicit multiplication.
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
pub fn default_parse_options() -> ParseOptions {
  ParseOptions::{ evaluate: true, transformations: standard_transformations() }
}

///|
/// Return an empty parse context with no predefined names.
pub fn default_parse_context() -> ParseContext {
  ParseContext::{
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
pub fn parse_context(
  callable_names? : Array[String] = [],
  bindings? : Map[String, Expr] = {},
  global_callable_names? : Array[String] = [],
  global_bindings? : Map[String, Expr] = {},
) -> ParseContext {
  ParseContext::{
    callable_names,
    bindings,
    global_callable_names,
    global_bindings,
  }
}

///|
/// Build parser options from a transformation list and evaluation flag.
pub fn parse_options(
  transformations? : Array[Transformation] = standard_transformations(),
  evaluate? : Bool = true,
) -> ParseOptions {
  ParseOptions::{ evaluate, transformations: transformations.map(x => x) }
}

///|
/// Return the conservative transformation set used by default parsing.
///
/// These transformations cover common numeric and symbol syntax without turning
/// on more opinionated rewrites such as implicit multiplication.
pub fn standard_transformations() -> Array[Transformation] {
  [
    Transformation::LambdaNotation,
    Transformation::AutoSymbol,
    Transformation::RepeatedDecimals,
    Transformation::AutoNumber,
    Transformation::FactorialNotation,
  ]
}

///|
/// Return a more permissive transformation set for user-facing input.
///
/// This extends [`standard_transformations`](#standard_transformations) with
/// conveniences such as caret exponentiation, implicit multiplication plus
/// application, and single equals signs in comparisons.
pub fn relaxed_transformations() -> Array[Transformation] {
  [
    ..standard_transformations(),
    Transformation::ConvertXor,
    Transformation::ImplicitMultiplicationApplication,
    Transformation::ConvertEqualsSigns,
  ]
}

///|
fn option_has(options : ParseOptions, target : Transformation) -> Bool {
  for transformation in options.transformations {
    match (transformation, target) {
      (Transformation::LambdaNotation, Transformation::LambdaNotation)
      | (Transformation::AutoSymbol, Transformation::AutoSymbol)
      | (Transformation::RepeatedDecimals, Transformation::RepeatedDecimals)
      | (Transformation::AutoNumber, Transformation::AutoNumber)
      | (Transformation::FactorialNotation, Transformation::FactorialNotation)
      | (Transformation::SplitSymbols, Transformation::SplitSymbols)
      | (
        Transformation::ImplicitMultiplication,
        Transformation::ImplicitMultiplication,
      )
      | (
        Transformation::ImplicitApplication,
        Transformation::ImplicitApplication,
      )
      | (
        Transformation::FunctionExponentiation,
        Transformation::FunctionExponentiation,
      )
      | (Transformation::ConvertXor, Transformation::ConvertXor)
      | (Transformation::ConvertEqualsSigns, Transformation::ConvertEqualsSigns)
      | (Transformation::Rationalize, Transformation::Rationalize)
      | (
        Transformation::ImplicitMultiplicationApplication,
        Transformation::ImplicitMultiplicationApplication,
      ) => return true
      (Transformation::SplitSymbolsCustom(_), Transformation::SplitSymbols) =>
        return true
      _ => ()
    }
  }
  false
}

///|
fn option_has_lambda(options : ParseOptions) -> Bool {
  option_has(options, Transformation::LambdaNotation)
}

///|
fn option_has_auto_symbol(options : ParseOptions) -> Bool {
  option_has(options, Transformation::AutoSymbol)
}

///|
fn option_has_repeated_decimals(options : ParseOptions) -> Bool {
  option_has(options, Transformation::RepeatedDecimals)
}

///|
fn option_has_factorial(options : ParseOptions) -> Bool {
  option_has(options, Transformation::FactorialNotation)
}

///|
fn option_has_implicit_multiplication(options : ParseOptions) -> Bool {
  option_has(options, Transformation::ImplicitMultiplication) ||
  option_has(options, Transformation::ImplicitMultiplicationApplication)
}

///|
fn option_has_implicit_application(options : ParseOptions) -> Bool {
  option_has(options, Transformation::ImplicitApplication) ||
  option_has(options, Transformation::ImplicitMultiplicationApplication)
}

///|
fn option_has_function_exponentiation(options : ParseOptions) -> Bool {
  option_has(options, Transformation::FunctionExponentiation) ||
  option_has(options, Transformation::ImplicitMultiplicationApplication)
}

///|
fn option_has_convert_xor(options : ParseOptions) -> Bool {
  option_has(options, Transformation::ConvertXor)
}

///|
fn option_has_convert_equals_signs(options : ParseOptions) -> Bool {
  option_has(options, Transformation::ConvertEqualsSigns)
}

///|
fn option_has_rationalize(options : ParseOptions) -> Bool {
  option_has(options, Transformation::Rationalize)
}

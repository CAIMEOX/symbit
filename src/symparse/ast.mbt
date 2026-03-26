///|
pub enum UnaryOp {
  Plus
  Minus
} derive(Eq, Show)

///|
pub enum BinaryOp {
  Add
  Sub
  Mul
  Div
  Pow
} derive(Eq, Show)

///|
pub enum CompareOp {
  Eq
  EqEq
  Ne
  Lt
  Le
  Gt
  Ge
} derive(Eq, Show)

///|
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
pub struct ParseOptions {
  evaluate : Bool
  transformations : Array[Transformation]
}

///|
pub struct ParseContext {
  callable_names : Array[String]
  bindings : Map[String, Expr]
  global_callable_names : Array[String]
  global_bindings : Map[String, Expr]
} derive(Eq)

///|
pub fn default_parse_options() -> ParseOptions {
  ParseOptions::{ evaluate: true, transformations: standard_transformations() }
}

///|
pub fn default_parse_context() -> ParseContext {
  ParseContext::{
    callable_names: [],
    bindings: {},
    global_callable_names: [],
    global_bindings: {},
  }
}

///|
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
pub fn parse_options(
  transformations? : Array[Transformation] = standard_transformations(),
  evaluate? : Bool = true,
) -> ParseOptions {
  ParseOptions::{ evaluate, transformations: transformations.map(x => x) }
}

///|
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

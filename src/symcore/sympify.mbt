///|
/// Typed inputs accepted by the `sympify` coercion entrypoint.
pub(all) enum SympifyInput {
  FromExpr(Expr)
  FromBool(Bool)
  FromInt(Int)
  FromRational(@symnum.BigRational)
  FromFloat(Float)
  FromComplexFloat(ComplexFloat)
  NumberSymbol(NumberSymbolKind)
  SymbolName(String)
  DummyName(String)
  WildName(String)
  WildSpec(String, Array[SympifyInput], Array[WildProperty])
  FunctionHeadName(String)
  UndefinedFunctionName(String)
  Application(SympifyInput, Array[SympifyInput])
  Tuple(Array[SympifyInput])
  Dict(Array[(SympifyInput, SympifyInput)])
}

///|
/// Convert a typed value into a core symbolic expression.
///
/// - Does: Lifts a supported host-side input into `Expr`.
/// - Input: A `SympifyInput`.
/// - Returns: A single `Expr`.
/// - Limits: This is typed lifting, not full textual parsing; text parsing
///   belongs in `symparse`.
///
/// ```mbt check
/// test "symcore sympify lifts typed inputs into expr" {
///   let expr = sympify(
///     SympifyInput::Tuple([
///       SympifyInput::FromInt(1),
///       SympifyInput::SymbolName("x"),
///     ]),
///   )
///   inspect(@symprint.to_string(expr), content="(1, x)")
/// }
/// ```
pub fn sympify(input : SympifyInput) -> Expr {
  match input {
    SympifyInput::FromExpr(expr) => normalize_legacy_expr(expr)
    SympifyInput::FromBool(value) => Expr::Boolean(value)
    SympifyInput::FromInt(value) => int(value)
    SympifyInput::FromRational(value) => Expr::Number(value)
    SympifyInput::FromFloat(value) => Expr::Float(value)
    SympifyInput::FromComplexFloat(value) => Expr::ComplexFloat(value)
    SympifyInput::NumberSymbol(kind) => Expr::NumberSymbol(kind)
    SympifyInput::SymbolName(name) => Expr::Symbol(name)
    SympifyInput::DummyName(name) => dummy(name~)
    SympifyInput::WildName(name) => Expr::Wild(name, [], [])
    SympifyInput::WildSpec(name, exclude, properties) =>
      Expr::Wild(name, exclude.map(sympify), properties)
    SympifyInput::FunctionHeadName(name) => Expr::FunctionHead(name)
    SympifyInput::UndefinedFunctionName(name) => Expr::UndefinedFunction(name)
    SympifyInput::Application(head, args) => {
      let head_expr = sympify(head)
      let arg_exprs = args.map(sympify)
      match apply(head_expr, arg_exprs) {
        Some(expr) => expr
        None => Expr::Apply(head_expr, arg_exprs)
      }
    }
    SympifyInput::Tuple(items) => Expr::Tuple(items.map(sympify))
    SympifyInput::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((sympify(key), sympify(value)))
      }
      Expr::Dict(out)
    }
  }
}

///|
/// Treat a string as a symbolic name and lift it into `Expr`.
pub fn sympify_name(name : String) -> Expr {
  sympify(SympifyInput::SymbolName(name))
}

///|
/// Lift a tuple payload into a first-class core tuple node.
pub fn sympify_tuple(items : Array[SympifyInput]) -> Expr {
  sympify(SympifyInput::Tuple(items))
}

///|
/// Lift dictionary-like key/value pairs into a first-class core dict node.
pub fn sympify_dict(items : Array[(SympifyInput, SympifyInput)]) -> Expr {
  sympify(SympifyInput::Dict(items))
}

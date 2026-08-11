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
///   let expr = sympify(Tuple([FromInt(1), SymbolName("x")]))
///   inspect(@symprint.pretty_string(expr), content="(1, x)")
/// }
/// ```
pub fn sympify(input : SympifyInput) -> Expr {
  match input {
    FromExpr(expr) => normalize_legacy_expr(expr)
    FromBool(value) => Boolean(value)
    FromInt(value) => int(value)
    FromRational(value) => Number(value)
    FromFloat(value) => Float(value)
    FromComplexFloat(value) => ComplexFloat(value)
    NumberSymbol(kind) => NumberSymbol(kind)
    SymbolName(name) => Symbol(name)
    DummyName(name) => dummy(name~)
    WildName(name) => Wild(name, [], [])
    WildSpec(name, exclude, properties) =>
      Wild(name, exclude.map(sympify), properties)
    FunctionHeadName(name) => FunctionHead(name)
    UndefinedFunctionName(name) => UndefinedFunction(name)
    Application(head, args) => {
      let head_expr = sympify(head)
      let arg_exprs = args.map(sympify)
      match apply(head_expr, arg_exprs) {
        Some(expr) => expr
        None => Apply(head_expr, arg_exprs)
      }
    }
    Tuple(items) => Tuple(items.map(sympify))
    Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((sympify(key), sympify(value)))
      }
      Dict(out)
    }
  }
}

///|
/// Treat a string as a symbolic name and lift it into `Expr`.
pub fn sympify_name(name : String) -> Expr {
  sympify(SymbolName(name))
}

///|
/// Lift a tuple payload into a first-class core tuple node.
pub fn sympify_tuple(items : Array[SympifyInput]) -> Expr {
  sympify(Tuple(items))
}

///|
/// Lift dictionary-like key/value pairs into a first-class core dict node.
pub fn sympify_dict(items : Array[(SympifyInput, SympifyInput)]) -> Expr {
  sympify(Dict(items))
}

///|
/// Typed inputs accepted by the `sympify` coercion entrypoint.
pub enum SympifyInput {
  FromExpr(Expr)
  FromBool(Bool)
  FromInt(Int)
  FromRational(@symnum.BigRational)
  FromFloat(Float)
  FromComplexFloat(ComplexFloat)
  SymbolName(String)
  Tuple(Array[SympifyInput])
  Dict(Array[(SympifyInput, SympifyInput)])
}

///|
/// Convert a typed value into a core symbolic expression.
pub fn sympify(input : SympifyInput) -> Expr {
  match input {
    SympifyInput::FromExpr(expr) => expr
    SympifyInput::FromBool(value) => bool_expr(value)
    SympifyInput::FromInt(value) => int(value)
    SympifyInput::FromRational(value) => number(value)
    SympifyInput::FromFloat(value) => float(value)
    SympifyInput::FromComplexFloat(value) => complex_float(value)
    SympifyInput::SymbolName(name) => symbol(name)
    SympifyInput::Tuple(items) => tuple_expr(items.map(sympify))
    SympifyInput::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((sympify(key), sympify(value)))
      }
      dict_expr(out)
    }
  }
}

///|
pub fn sympify_expr_input(expr : Expr) -> SympifyInput {
  SympifyInput::FromExpr(expr)
}

///|
pub fn sympify_bool_input(value : Bool) -> SympifyInput {
  SympifyInput::FromBool(value)
}

///|
pub fn sympify_int_input(value : Int) -> SympifyInput {
  SympifyInput::FromInt(value)
}

///|
pub fn sympify_rational_input(value : @symnum.BigRational) -> SympifyInput {
  SympifyInput::FromRational(value)
}

///|
pub fn sympify_float_input(value : Float) -> SympifyInput {
  SympifyInput::FromFloat(value)
}

///|
pub fn sympify_complex_float_input(value : ComplexFloat) -> SympifyInput {
  SympifyInput::FromComplexFloat(value)
}

///|
pub fn sympify_symbol_input(name : String) -> SympifyInput {
  SympifyInput::SymbolName(name)
}

///|
/// Treat a string as a symbolic name and lift it into `Expr`.
pub fn sympify_name(name : String) -> Expr {
  sympify(sympify_symbol_input(name))
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

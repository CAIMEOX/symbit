///|
pub fn singleton_expr_by_name(name : String) -> Expr? {
  match name {
    "Zero" => Some(int(0))
    "One" => Some(int(1))
    "NegativeOne" => Some(int(-1))
    "Half" =>
      Some(
        Number(
          @symnum.BigRational::from_ints(1, 2) catch {
            _ => abort("half-singleton")
          },
        ),
      )
    "ImaginaryUnit" => Some(NumberSymbol(ImaginaryUnit))
    "Exp1" => Some(NumberSymbol(Exp1))
    "Pi" => Some(NumberSymbol(Pi))
    "GoldenRatio" => Some(NumberSymbol(GoldenRatio))
    "EulerGamma" => Some(NumberSymbol(EulerGamma))
    "Catalan" => Some(NumberSymbol(Catalan))
    "Infinity" => Some(NumberSymbol(Infinity))
    "NegativeInfinity" => Some(NumberSymbol(NegativeInfinity))
    "ComplexInfinity" => Some(NumberSymbol(ComplexInfinity))
    "NaN" => Some(NumberSymbol(NaN))
    "true" => Some(Boolean(true))
    "false" => Some(Boolean(false))
    _ => None
  }
}

///|
pub fn singleton_instance_name(expr : Expr) -> String? {
  match normalize_legacy_expr(expr) {
    Boolean(true) => Some("true")
    Boolean(false) => Some("false")
    Number(value) =>
      Some(exact_number_head_name(exact_number_kind_from_rational(value)))
    NumberSymbol(kind) =>
      match kind {
        ImaginaryUnit => Some("ImaginaryUnit")
        Exp1 => Some("Exp1")
        Pi => Some("Pi")
        GoldenRatio => Some("GoldenRatio")
        EulerGamma => Some("EulerGamma")
        Catalan => Some("Catalan")
        Infinity => Some("Infinity")
        NegativeInfinity => Some("NegativeInfinity")
        ComplexInfinity => Some("ComplexInfinity")
        NaN => Some("NaN")
      }
    _ => None
  }
}

///|
pub fn is_singleton_expr(expr : Expr) -> Bool {
  singleton_instance_name(expr) is Some(_)
}

///|
pub fn s(input : SympifyInput) -> Expr {
  sympify(input)
}

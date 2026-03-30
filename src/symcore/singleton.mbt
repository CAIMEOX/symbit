///|
pub fn singleton_expr_by_name(name : String) -> Expr? {
  match name {
    "Zero" => Some(int(0))
    "One" => Some(int(1))
    "NegativeOne" => Some(int(-1))
    "Half" =>
      Some(
        Expr::Number(
          @symnum.BigRational::from_ints(1, 2) catch {
            _ => abort("half-singleton")
          },
        ),
      )
    "ImaginaryUnit" => Some(Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit))
    "Exp1" => Some(Expr::NumberSymbol(NumberSymbolKind::Exp1))
    "Pi" => Some(Expr::NumberSymbol(NumberSymbolKind::Pi))
    "GoldenRatio" => Some(Expr::NumberSymbol(NumberSymbolKind::GoldenRatio))
    "EulerGamma" => Some(Expr::NumberSymbol(NumberSymbolKind::EulerGamma))
    "Catalan" => Some(Expr::NumberSymbol(NumberSymbolKind::Catalan))
    "Infinity" => Some(Expr::NumberSymbol(NumberSymbolKind::Infinity))
    "NegativeInfinity" =>
      Some(Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity))
    "ComplexInfinity" =>
      Some(Expr::NumberSymbol(NumberSymbolKind::ComplexInfinity))
    "NaN" => Some(Expr::NumberSymbol(NumberSymbolKind::NaN))
    "true" => Some(Expr::Boolean(true))
    "false" => Some(Expr::Boolean(false))
    _ => None
  }
}

///|
pub fn singleton_instance_name(expr : Expr) -> String? {
  match normalize_legacy_expr(expr) {
    Expr::Boolean(true) => Some("true")
    Expr::Boolean(false) => Some("false")
    Expr::Number(value) =>
      Some(exact_number_head_name(exact_number_kind_from_rational(value)))
    Expr::NumberSymbol(kind) =>
      match kind {
        NumberSymbolKind::ImaginaryUnit => Some("ImaginaryUnit")
        NumberSymbolKind::Exp1 => Some("Exp1")
        NumberSymbolKind::Pi => Some("Pi")
        NumberSymbolKind::GoldenRatio => Some("GoldenRatio")
        NumberSymbolKind::EulerGamma => Some("EulerGamma")
        NumberSymbolKind::Catalan => Some("Catalan")
        NumberSymbolKind::Infinity => Some("Infinity")
        NumberSymbolKind::NegativeInfinity => Some("NegativeInfinity")
        NumberSymbolKind::ComplexInfinity => Some("ComplexInfinity")
        NumberSymbolKind::NaN => Some("NaN")
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

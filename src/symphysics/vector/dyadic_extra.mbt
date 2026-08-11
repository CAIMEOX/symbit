///|
/// Additional `Dyadic` helpers aligned with SymPy's dyadic surface.

///|
pub fn Dyadic::truediv(
  self : Dyadic,
  scalar : Expr,
) -> Dyadic raise VectorError {
  if expr_is_zero(scalar) {
    raise ValueError("division by zero")
  }
  self.scale(simplify_expr(scalar ^ int(-1)))
}

///|
pub fn Dyadic::subs(self : Dyadic, env : Map[String, Expr]) -> Dyadic {
  let out : Array[(Expr, Int, Int, Int, Int)] = []
  for item in self.args {
    out.push((@symcore.subst(item.0, env), item.1, item.2, item.3, item.4))
  }
  dyadic_normalize(out)
}

///|
pub fn Dyadic::applyfunc(self : Dyadic, f : (Expr) -> Expr) -> Dyadic {
  let out : Array[(Expr, Int, Int, Int, Int)] = []
  for item in self.args {
    out.push((f(item.0), item.1, item.2, item.3, item.4))
  }
  dyadic_normalize(out)
}

///|
pub fn Dyadic::simplify(self : Dyadic) -> Dyadic {
  self.applyfunc(simplify_expr)
}

///|
pub fn Dyadic::doit(self : Dyadic) -> Dyadic {
  self.simplify()
}

///|
/// First-order (affine) error propagation helpers.

///|
pub fn cov_key(a : String, b : String) -> String {
  if a <= b {
    "\{a}|\{b}"
  } else {
    "\{b}|\{a}"
  }
}

///|
priv struct AffineForm {
  constant : @symnum.BigRational
  coeffs : Map[String, @symnum.BigRational]
}

///|
fn empty_affine() -> AffineForm {
  { constant: @symnum.BigRational::zero(), coeffs: {} }
}

///|
fn affine_add(a : AffineForm, b : AffineForm) -> AffineForm {
  let out : Map[String, @symnum.BigRational] = {}
  for name, c in a.coeffs {
    out[name] = c
  }
  for name, c in b.coeffs {
    match out.get(name) {
      Some(prev) => out[name] = prev.add_r(c)
      None => out[name] = c
    }
  }
  { constant: a.constant.add_r(b.constant), coeffs: out }
}

///|
fn affine_scale(a : AffineForm, scalar : @symnum.BigRational) -> AffineForm {
  let out : Map[String, @symnum.BigRational] = {}
  for name, c in a.coeffs {
    out[name] = c.mul_r(scalar)
  }
  { constant: a.constant.mul_r(scalar), coeffs: out }
}

///|
fn expr_to_affine(expr : @symcore.Expr) -> AffineForm? {
  match eval_arith(expr) {
    @symcore.Expr::Number(n) => Some({ constant: n, coeffs: {} })
    @symcore.Expr::Symbol(name) => {
      let coeffs : Map[String, @symnum.BigRational] = {}
      coeffs[name] = @symnum.BigRational::one()
      Some({ constant: @symnum.BigRational::zero(), coeffs })
    }
    @symcore.Expr::Add(items) => {
      let mut acc = empty_affine()
      for item in items {
        match expr_to_affine(item) {
          Some(form) => acc = affine_add(acc, form)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(items) => {
      let mut scalar = @symnum.BigRational::one()
      let mut other : @symcore.Expr? = None
      for item in items {
        match eval_arith(item) {
          @symcore.Expr::Number(n) => scalar = scalar.mul_r(n)
          non_num =>
            match other {
              None => other = Some(non_num)
              Some(_) => return None
            }
        }
      }
      match other {
        None => Some({ constant: scalar, coeffs: {} })
        Some(inner) =>
          match expr_to_affine(inner) {
            Some(form) => Some(affine_scale(form, scalar))
            None => None
          }
      }
    }
    @symcore.Expr::Pow(base, exp) =>
      if exp == @symcore.int(1) {
        expr_to_affine(base)
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn variance_prop(
  expr : @symcore.Expr,
  variances : Map[String, @symcore.Expr],
  covariances? : Map[String, @symcore.Expr] = {},
) -> @symcore.Expr {
  match expr_to_affine(expr) {
    None => @symcore.function("variance_prop", [expr])
    Some(form) => {
      let names : Array[String] = Array::new()
      for name, coeff in form.coeffs {
        if !coeff.is_zero() {
          names.push(name)
        }
      }
      names.sort()
      let terms : Array[@symcore.Expr] = Array::new()
      for name in names {
        let coeff = form.coeffs[name]
        let coeff_expr = expr_from_big_rational(coeff)
        let var_expr = match variances.get(name) {
          Some(v) => v
          None => @symcore.function("Variance", [@symcore.symbol(name)])
        }
        terms.push(eval_arith(@symcore.mul([
          @symcore.pow(coeff_expr, @symcore.int(2)),
          var_expr,
        ])))
      }
      for i in 0..<names.length() {
        for j in (i + 1)..<names.length() {
          let ni = names[i]
          let nj = names[j]
          let ci = form.coeffs[ni]
          let cj = form.coeffs[nj]
          let key = cov_key(ni, nj)
          match covariances.get(key) {
            Some(cov) => {
              terms.push(eval_arith(@symcore.mul([
                @symcore.int(2),
                expr_from_big_rational(ci),
                expr_from_big_rational(cj),
                cov,
              ])))
            }
            None => ()
          }
        }
      }
      if terms.is_empty() {
        @symcore.int(0)
      } else {
        eval_arith(@symcore.add(terms))
      }
    }
  }
}

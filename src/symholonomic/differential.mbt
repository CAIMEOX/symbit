///|
pub struct DifferentialOperatorAlgebra {
  symbol_var : @symcore.Expr
  generator : String
}

///|
pub struct DifferentialOperator {
  coeffs : Array[@symcore.Expr]
  parent : DifferentialOperatorAlgebra
}

///|
pub fn differential_operator(
  coeffs : Array[@symcore.Expr],
  parent : DifferentialOperatorAlgebra,
) -> DifferentialOperator {
  let normalized = trim_coeffs(coeffs)
  DifferentialOperator::{ coeffs: normalized, parent }
}

///|
pub fn differential_operators(
  symbol_var? : @symcore.Expr = @symcore.symbol("x"),
  generator? : String = "Dx",
) -> (DifferentialOperatorAlgebra, DifferentialOperator) {
  ignore(require_symbol_name(symbol_var))
  let algebra = DifferentialOperatorAlgebra::{ symbol_var, generator }
  (algebra, differential_operator([holo_zero(), holo_one()], algebra))
}

///|
pub fn DifferentialOperatorAlgebra::variable(
  self : DifferentialOperatorAlgebra,
) -> @symcore.Expr {
  self.symbol_var
}

///|
pub fn DifferentialOperatorAlgebra::generator(
  self : DifferentialOperatorAlgebra,
) -> String {
  self.generator
}

///|
pub fn DifferentialOperator::coefficients(self : DifferentialOperator) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for c in self.coeffs {
    out.push(c)
  }
  out
}

///|
pub fn DifferentialOperator::order(self : DifferentialOperator) -> Int {
  self.coeffs.length() - 1
}

///|
pub fn DifferentialOperator::algebra(
  self : DifferentialOperator,
) -> DifferentialOperatorAlgebra {
  self.parent
}

///|
fn differential_same_parent(
  a : DifferentialOperator,
  b : DifferentialOperator,
) -> Bool {
  a.parent == b.parent
}

///|
fn differential_add(
  a : DifferentialOperator,
  b : DifferentialOperator,
) -> DifferentialOperator {
  if !differential_same_parent(a, b) {
    return differential_operator([holo_zero()], a.parent)
  }
  let len = if a.coeffs.length() > b.coeffs.length() {
    a.coeffs.length()
  } else {
    b.coeffs.length()
  }
  let out : Array[@symcore.Expr] = Array::new()
  for i in 0..<len {
    out.push(expr_add(coeff_at(a.coeffs, i), coeff_at(b.coeffs, i)))
  }
  differential_operator(out, a.parent)
}

///|
fn differential_mul(
  a : DifferentialOperator,
  b : DifferentialOperator,
) -> DifferentialOperator {
  if !differential_same_parent(a, b) {
    return differential_operator([holo_zero()], a.parent)
  }
  let max_order = a.order() + b.order()
  let out : Array[@symcore.Expr] = Array::new()
  for _ in 0..=max_order {
    out.push(holo_zero())
  }
  let x = a.parent.symbol_var
  for i in 0..<a.coeffs.length() {
    let ai = a.coeffs[i]
    if expr_is_zero(ai) {
      continue
    }
    for j in 0..<b.coeffs.length() {
      let bj = b.coeffs[j]
      if expr_is_zero(bj) {
        continue
      }
      for r in 0..=i {
        let diff_b = diff_n(bj, x, r)
        if expr_is_zero(diff_b) {
          continue
        }
        let c = @symcore.number(binom_int(i, r))
        let term = expr_mul(ai, expr_mul(c, diff_b))
        let power = i - r + j
        out[power] = expr_add(out[power], term)
      }
    }
  }
  differential_operator(out, a.parent)
}

///|
pub fn DifferentialOperator::pow(
  self : DifferentialOperator,
  exp : Int,
) -> DifferentialOperator {
  if exp < 0 {
    return differential_operator([holo_one()], self.parent)
  }
  if exp == 0 {
    return differential_operator([holo_one()], self.parent)
  }
  let mut e = exp
  let mut base = self
  let mut result = differential_operator([holo_one()], self.parent)
  while e > 0 {
    if e % 2 == 1 {
      result = differential_mul(result, base)
    }
    e = e / 2
    if e > 0 {
      base = differential_mul(base, base)
    }
  }
  result
}

///|
pub fn DifferentialOperator::to_sympy_str(self : DifferentialOperator) -> String {
  let parts : Array[String] = Array::new()
  for i, c in self.coeffs {
    if expr_is_zero(c) {
      continue
    }
    let cs = expr_to_sympy_string(c)
    if i == 0 {
      parts.push("(\{cs})")
    } else if i == 1 {
      parts.push("(\{cs})*\{self.parent.generator}")
    } else {
      parts.push("(\{cs})*\{self.parent.generator}**\{i}")
    }
  }
  if parts.is_empty() {
    "(0)"
  } else {
    parts.join(" + ")
  }
}

///|
pub impl Add for DifferentialOperator with add(self, other) {
  differential_add(self, other)
}

///|
pub impl Mul for DifferentialOperator with mul(self, other) {
  differential_mul(self, other)
}

///|
pub impl Eq for DifferentialOperatorAlgebra with equal(
  self,
  other : DifferentialOperatorAlgebra,
) -> Bool {
  self.symbol_var == other.symbol_var && self.generator == other.generator
}

///|
pub impl Eq for DifferentialOperatorAlgebra with not_equal(
  self,
  other : DifferentialOperatorAlgebra,
) -> Bool {
  !self.equal(other)
}

///|
pub impl Eq for DifferentialOperator with equal(
  self,
  other : DifferentialOperator,
) -> Bool {
  self.parent == other.parent && self.coeffs == other.coeffs
}

///|
pub impl Eq for DifferentialOperator with not_equal(
  self,
  other : DifferentialOperator,
) -> Bool {
  !self.equal(other)
}

///|
pub impl Show for DifferentialOperator with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_sympy_str())
}

///|
pub impl Show for DifferentialOperatorAlgebra with output(
  self,
  logger : &Logger,
) -> Unit {
  logger.write_string(
    "Univariate Differential Operator Algebra in intermediate \{self.generator} over variable \{@symprint.to_string(self.symbol_var)}",
  )
}

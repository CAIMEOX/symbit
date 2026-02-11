///|
pub struct RecurrenceOperatorAlgebra {
  symbol_var : @symcore.Expr
  generator : String
}

///|
pub struct RecurrenceOperator {
  coeffs : Array[@symcore.Expr]
  parent : RecurrenceOperatorAlgebra
}

///|
pub fn recurrence_operator(
  coeffs : Array[@symcore.Expr],
  parent : RecurrenceOperatorAlgebra,
) -> RecurrenceOperator {
  let normalized = trim_coeffs(coeffs)
  RecurrenceOperator::{ coeffs: normalized, parent }
}

///|
pub fn recurrence_operators(
  symbol_var? : @symcore.Expr = @symcore.symbol("n"),
  generator? : String = "Sn",
) -> (RecurrenceOperatorAlgebra, RecurrenceOperator) {
  ignore(require_symbol_name(symbol_var))
  let algebra = RecurrenceOperatorAlgebra::{ symbol_var, generator }
  (algebra, recurrence_operator([holo_zero(), holo_one()], algebra))
}

///|
pub fn RecurrenceOperatorAlgebra::variable(
  self : RecurrenceOperatorAlgebra,
) -> @symcore.Expr {
  self.symbol_var
}

///|
pub fn RecurrenceOperatorAlgebra::generator(
  self : RecurrenceOperatorAlgebra,
) -> String {
  self.generator
}

///|
pub fn RecurrenceOperator::coefficients(
  self : RecurrenceOperator,
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for c in self.coeffs {
    out.push(c)
  }
  out
}

///|
pub fn RecurrenceOperator::order(self : RecurrenceOperator) -> Int {
  self.coeffs.length() - 1
}

///|
pub fn RecurrenceOperator::algebra(
  self : RecurrenceOperator,
) -> RecurrenceOperatorAlgebra {
  self.parent
}

///|
fn recurrence_same_parent(
  a : RecurrenceOperator,
  b : RecurrenceOperator,
) -> Bool {
  a.parent == b.parent
}

///|
fn recurrence_add(
  a : RecurrenceOperator,
  b : RecurrenceOperator,
) -> RecurrenceOperator {
  if !recurrence_same_parent(a, b) {
    return recurrence_operator([holo_zero()], a.parent)
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
  recurrence_operator(out, a.parent)
}

///|
fn recurrence_mul(
  a : RecurrenceOperator,
  b : RecurrenceOperator,
) -> RecurrenceOperator {
  if !recurrence_same_parent(a, b) {
    return recurrence_operator([holo_zero()], a.parent)
  }
  let out_len = a.coeffs.length() + b.coeffs.length() - 1
  let out : Array[@symcore.Expr] = Array::new()
  for _ in 0..<out_len {
    out.push(holo_zero())
  }
  let n = a.parent.symbol_var
  for i in 0..<a.coeffs.length() {
    if expr_is_zero(a.coeffs[i]) {
      continue
    }
    for j in 0..<b.coeffs.length() {
      if expr_is_zero(b.coeffs[j]) {
        continue
      }
      let shifted = shift_symbol(b.coeffs[j], n, i)
      let term = expr_mul(a.coeffs[i], shifted)
      out[i + j] = expr_add(out[i + j], term)
    }
  }
  recurrence_operator(out, a.parent)
}

///|
pub fn RecurrenceOperator::pow(
  self : RecurrenceOperator,
  exp : Int,
) -> RecurrenceOperator {
  if exp < 0 {
    return recurrence_operator([holo_one()], self.parent)
  }
  if exp == 0 {
    return recurrence_operator([holo_one()], self.parent)
  }
  let mut e = exp
  let mut base = self
  let mut result = recurrence_operator([holo_one()], self.parent)
  while e > 0 {
    if e % 2 == 1 {
      result = recurrence_mul(result, base)
    }
    e = e / 2
    if e > 0 {
      base = recurrence_mul(base, base)
    }
  }
  result
}

///|
pub fn RecurrenceOperator::to_sympy_str(self : RecurrenceOperator) -> String {
  let parts : Array[String] = Array::new()
  for i, c in self.coeffs {
    if expr_is_zero(c) {
      continue
    }
    let cs = expr_to_sympy_string(c)
    if i == 0 {
      parts.push("(\{cs})")
    } else if i == 1 {
      parts.push("(\{cs})\{self.parent.generator}")
    } else {
      parts.push("(\{cs})\{self.parent.generator}**\{i}")
    }
  }
  if parts.is_empty() {
    "(0)"
  } else {
    parts.join(" + ")
  }
}

///|
pub impl Add for RecurrenceOperator with add(self, other) {
  recurrence_add(self, other)
}

///|
pub impl Mul for RecurrenceOperator with mul(self, other) {
  recurrence_mul(self, other)
}

///|
pub impl Eq for RecurrenceOperatorAlgebra with equal(
  self,
  other : RecurrenceOperatorAlgebra,
) -> Bool {
  self.symbol_var == other.symbol_var && self.generator == other.generator
}

///|
pub impl Eq for RecurrenceOperatorAlgebra with not_equal(
  self,
  other : RecurrenceOperatorAlgebra,
) -> Bool {
  !self.equal(other)
}

///|
pub impl Eq for RecurrenceOperator with equal(self, other : RecurrenceOperator) -> Bool {
  self.parent == other.parent && self.coeffs == other.coeffs
}

///|
pub impl Eq for RecurrenceOperator with not_equal(
  self,
  other : RecurrenceOperator,
) -> Bool {
  !self.equal(other)
}

///|
pub impl Show for RecurrenceOperator with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_sympy_str())
}

///|
pub impl Show for RecurrenceOperatorAlgebra with output(self, logger : &Logger) -> Unit {
  logger.write_string(
    "Univariate Recurrence Operator Algebra in intermediate \{self.generator} over variable \{@symprint.to_string(self.symbol_var)}",
  )
}

///|
pub struct HolonomicSequence {
  recurrence : RecurrenceOperator
  u0 : Array[@symcore.Expr]
}

///|
pub fn holonomic_sequence(
  recurrence : RecurrenceOperator,
  u0? : Array[@symcore.Expr] = [],
) -> HolonomicSequence {
  let init : Array[@symcore.Expr] = Array::new()
  for v in u0 {
    init.push(v)
  }
  HolonomicSequence::{ recurrence, u0: init }
}

///|
pub fn HolonomicSequence::recurrence(self : HolonomicSequence) -> RecurrenceOperator {
  self.recurrence
}

///|
pub fn HolonomicSequence::initial_values(self : HolonomicSequence) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for v in self.u0 {
    out.push(v)
  }
  out
}

///|
pub fn HolonomicSequence::to_sympy_str(self : HolonomicSequence) -> String {
  let n = @symprint.to_string(self.recurrence.parent.variable())
  let base = "HolonomicSequence(\{self.recurrence.to_sympy_str()}, \{n})"
  if self.u0.is_empty() {
    base
  } else {
    let mut suffix = ""
    for i, v in self.u0 {
      suffix = suffix + ", u(\{i}) = \{expr_to_sympy_string(v)}"
    }
    base + suffix
  }
}

///|
pub impl Eq for HolonomicSequence with equal(self, other : HolonomicSequence) -> Bool {
  self.recurrence == other.recurrence && self.u0 == other.u0
}

///|
pub impl Eq for HolonomicSequence with not_equal(self, other : HolonomicSequence) -> Bool {
  !self.equal(other)
}

///|
pub impl Show for HolonomicSequence with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_sympy_str())
}

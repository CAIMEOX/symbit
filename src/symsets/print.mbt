///|
/// Printing helpers for sets.

///|
fn expr_str(expr : @symcore.Expr) -> String {
  @symprint.to_string(expr)
}

///|
pub fn setbool_to_string(val : SetBool) -> String {
  match val {
    SetBool::True => "True"
    SetBool::False => "False"
    SetBool::Unknown => "Unknown"
  }
}

///|
pub fn to_string(set : Set) -> String {
  match set {
    Set::EmptySet => "EmptySet"
    Set::UniversalSet => "UniversalSet"
    Set::Naturals => "Naturals"
    Set::Naturals0 => "Naturals0"
    Set::Integers => "Integers"
    Set::Rationals => "Rationals"
    Set::Reals => "Reals"
    Set::FiniteSet(items) => {
      let rendered = items.map(expr_str).join(", ")
      "{" + rendered + "}"
    }
    Set::Interval(left=left, right=right, left_open=left_open, right_open=right_open) => {
      let l = expr_str(left)
      let r = expr_str(right)
      if left_open && right_open {
        "Interval.open(" + l + ", " + r + ")"
      } else if left_open {
        "Interval.Lopen(" + l + ", " + r + ")"
      } else if right_open {
        "Interval.Ropen(" + l + ", " + r + ")"
      } else {
        "Interval(" + l + ", " + r + ")"
      }
    }
    Set::Union(items) => {
      if items.is_empty() {
        "EmptySet"
      } else {
        let rendered = items.map(to_string).join(", ")
        "Union(" + rendered + ")"
      }
    }
    Set::Intersection(items) => {
      if items.is_empty() {
        "UniversalSet"
      } else {
        let rendered = items.map(to_string).join(", ")
        "Intersection(" + rendered + ")"
      }
    }
    Set::Complement(a, b) =>
      "Complement(" + to_string(a) + ", " + to_string(b) + ")"
  }
}

///|
impl Show for Set with to_string(self) {
  to_string(self)
}

///|
impl Show for Set with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
impl Show for SetBool with to_string(self) {
  setbool_to_string(self)
}

///|
impl Show for SetBool with output(self, logger) {
  logger.write_string(self.to_string())
}

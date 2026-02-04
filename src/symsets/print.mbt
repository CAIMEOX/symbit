///|
/// Printing helpers for sets.

///|
fn expr_str(expr : @symcore.Expr) -> String {
  match expr {
    @symcore.Expr::Function(name, args) if name == "Tuple" =>
      if args.is_empty() {
        "()"
      } else if args.length() == 1 {
        "(\{expr_str(args[0])},)"
      } else {
        let rendered = args.map(expr_str).join(", ")
        "(\{rendered})"
      }
    _ => @symprint.to_string(expr)
  }
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
    Set::Interval(left~, right~, left_open~, right_open~) => {
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
    Set::ConditionSet(symbol~, condition~, base~) => {
      let sym = expr_str(symbol)
      let cond = @symlogic.to_string(condition)
      "ConditionSet(" + sym + ", " + cond + ", " + to_string(base) + ")"
    }
    Set::ImageSet(symbol~, expr~, base~) => {
      let sym = expr_str(symbol)
      let body = expr_str(expr)
      let lambda = "Lambda(" + sym + ", " + body + ")"
      "ImageSet(" + lambda + ", " + to_string(base) + ")"
    }
    Set::ProductSet(items) => {
      let rendered = items.map(to_string).join(", ")
      "ProductSet(" + rendered + ")"
    }
    Set::Union(items) =>
      if items.is_empty() {
        "EmptySet"
      } else {
        let rendered = items.map(to_string).join(", ")
        "Union(" + rendered + ")"
      }
    Set::Intersection(items) =>
      if items.is_empty() {
        "UniversalSet"
      } else {
        let rendered = items.map(to_string).join(", ")
        "Intersection(" + rendered + ")"
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

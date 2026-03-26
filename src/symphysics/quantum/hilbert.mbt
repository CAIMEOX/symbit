///|
/// Hilbert-space metadata aligned with the current transferable subset of
/// `sympy.physics.quantum.hilbert`.

///|
pub enum HilbertSpace {
  Abstract
  Complex(Expr)
  L2(Expr)
  Fock
  TensorProduct(Array[HilbertSpace])
  DirectSum(Array[HilbertSpace])
  TensorPower(HilbertSpace, Expr)
} derive(Eq)

///|
fn oo_expr() -> Expr {
  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
}

///|
fn hilbert_expr_repr(expr : Expr) -> String {
  match expr {
    Expr::Number(n) if n.is_integral() =>
      "Integer(\{n.numerator().to_string()})"
    Expr::Number(n) =>
      "Rational(\{n.numerator().to_string()}, \{n.denominator().to_string()})"
    Expr::Symbol(name) if name == "oo" => "oo"
    Expr::Symbol(name) => "Symbol('\{name}')"
    Expr::Function(name, args) if name == "Interval" && args.length() == 2 =>
      "Interval(\{hilbert_expr_repr(args[0])}, \{hilbert_expr_repr(args[1])})"
    _ => @symprint.to_string(expr)
  }
}

///|
pub fn interval(start : Expr, stop : Expr) -> Expr {
  @symcore.function("Interval", [start, stop])
}

///|
pub fn hilbert_space() -> HilbertSpace {
  HilbertSpace::Abstract
}

///|
pub fn complex_space(
  dimension : Expr,
) -> HilbertSpace raise @symphysics.PhysicsError {
  match dimension {
    Expr::Number(n) if n.is_integral() && n.numerator().to_int() > 0 =>
      HilbertSpace::Complex(dimension)
    Expr::Symbol(name) if name == "oo" => HilbertSpace::Complex(dimension)
    Expr::Symbol(_) => HilbertSpace::Complex(dimension)
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "ComplexSpace dimension must be a positive integer, oo, or a symbol",
      )
  }
}

///|
pub fn l2_space(
  interval_expr : Expr,
) -> HilbertSpace raise @symphysics.PhysicsError {
  match interval_expr {
    Expr::Function(name, args) if name == "Interval" && args.length() == 2 =>
      HilbertSpace::L2(interval_expr)
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "L2 expects Interval(start, stop)",
      )
  }
}

///|
pub fn fock_space() -> HilbertSpace {
  HilbertSpace::Fock
}

///|
fn same_base(lhs : HilbertSpace, rhs : HilbertSpace) -> Bool {
  match (lhs, rhs) {
    (HilbertSpace::TensorPower(base1, _), HilbertSpace::TensorPower(base2, _)) =>
      base1 == base2
    (HilbertSpace::TensorPower(base, _), other) => base == other
    (other, HilbertSpace::TensorPower(base, _)) => other == base
    _ => lhs == rhs
  }
}

///|
fn power_base(space : HilbertSpace) -> HilbertSpace {
  match space {
    HilbertSpace::TensorPower(base, _) => base
    _ => space
  }
}

///|
fn power_exp(space : HilbertSpace) -> Expr {
  match space {
    HilbertSpace::TensorPower(_, exp) => exp
    _ => int(1)
  }
}

///|
pub fn tensor_power(
  base : HilbertSpace,
  exp : Expr,
) -> HilbertSpace raise @symphysics.PhysicsError {
  match exp {
    Expr::Number(n) if n.is_integral() && n.numerator().to_int() <= 0 =>
      raise @symphysics.PhysicsError::ValueError(
        "Tensor powers require a positive integer or symbol",
      )
    _ => ()
  }
  if exp == int(1) {
    base
  } else {
    HilbertSpace::TensorPower(base, exp)
  }
}

///|
pub fn tensor_product_space(
  args : Array[HilbertSpace],
) -> HilbertSpace raise @symphysics.PhysicsError {
  guard !args.is_empty() else { return hilbert_space() }
  let flat : Array[HilbertSpace] = Array::new()
  for arg in args {
    match arg {
      HilbertSpace::TensorProduct(items) =>
        for item in items {
          flat.push(item)
        }
      _ => flat.push(arg)
    }
  }
  let combined : Array[HilbertSpace] = Array::new()
  for arg in flat {
    if combined.is_empty() {
      combined.push(arg)
    } else {
      let prev = combined[combined.length() - 1]
      if same_base(prev, arg) {
        combined[combined.length() - 1] = tensor_power(
          power_base(prev),
          power_exp(prev) + power_exp(arg),
        )
      } else {
        combined.push(arg)
      }
    }
  }
  if combined.length() == 1 {
    combined[0]
  } else {
    HilbertSpace::TensorProduct(combined)
  }
}

///|
pub fn direct_sum_space(args : Array[HilbertSpace]) -> HilbertSpace {
  guard !args.is_empty() else { return hilbert_space() }
  let flat : Array[HilbertSpace] = Array::new()
  for arg in args {
    match arg {
      HilbertSpace::DirectSum(items) =>
        for item in items {
          flat.push(item)
        }
      _ => flat.push(arg)
    }
  }
  if flat.length() == 1 {
    flat[0]
  } else {
    HilbertSpace::DirectSum(flat)
  }
}

///|
pub fn HilbertSpace::dimension(
  self : HilbertSpace,
) -> Expr raise @symphysics.PhysicsError {
  match self {
    HilbertSpace::Abstract =>
      raise @symphysics.PhysicsError::ValueError(
        "Abstract HilbertSpace has no fixed dimension",
      )
    HilbertSpace::Complex(dimension) => dimension
    HilbertSpace::L2(_) | HilbertSpace::Fock => oo_expr()
    HilbertSpace::TensorProduct(args) => {
      let mut out = int(1)
      for arg in args {
        let dim = arg.dimension()
        if dim == oo_expr() {
          return oo_expr()
        }
        out = out * dim
      }
      out
    }
    HilbertSpace::DirectSum(args) => {
      let mut out = int(0)
      for arg in args {
        let dim = arg.dimension()
        if dim == oo_expr() {
          return oo_expr()
        }
        out = out + dim
      }
      out
    }
    HilbertSpace::TensorPower(base, exp) => {
      let dim = base.dimension()
      if dim == oo_expr() {
        oo_expr()
      } else {
        dim ^ exp
      }
    }
  }
}

///|
pub fn HilbertSpace::spaces(
  self : HilbertSpace,
) -> Array[HilbertSpace] raise @symphysics.PhysicsError {
  match self {
    HilbertSpace::TensorProduct(args) | HilbertSpace::DirectSum(args) => args
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "spaces is only defined on tensor/direct sums",
      )
  }
}

///|
pub fn HilbertSpace::base(
  self : HilbertSpace,
) -> HilbertSpace raise @symphysics.PhysicsError {
  match self {
    HilbertSpace::TensorPower(base, _) => base
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "base is only defined on tensor powers",
      )
  }
}

///|
pub fn HilbertSpace::exp(
  self : HilbertSpace,
) -> Expr raise @symphysics.PhysicsError {
  match self {
    HilbertSpace::TensorPower(_, exp) => exp
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "exp is only defined on tensor powers",
      )
  }
}

///|
pub fn HilbertSpace::repr(self : HilbertSpace) -> String {
  match self {
    HilbertSpace::Abstract => "HilbertSpace()"
    HilbertSpace::Complex(dimension) =>
      "ComplexSpace(\{hilbert_expr_repr(dimension)})"
    HilbertSpace::L2(interval_expr) => "L2(\{hilbert_expr_repr(interval_expr)})"
    HilbertSpace::Fock => "FockSpace()"
    HilbertSpace::TensorProduct(args) => {
      let rendered = args.map(space => space.to_string()).join(",")
      "TensorProductHilbertSpace(\{rendered})"
    }
    HilbertSpace::DirectSum(args) => {
      let rendered = args.map(space => space.to_string()).join(",")
      "DirectSumHilbertSpace(\{rendered})"
    }
    HilbertSpace::TensorPower(base, exp) =>
      "TensorPowerHilbertSpace(\{base.to_string()},\{@symprint.to_string(exp)})"
  }
}

///|
pub impl Show for HilbertSpace with to_string(self) {
  match self {
    HilbertSpace::Abstract => "H"
    HilbertSpace::Complex(dimension) => "C(\{@symprint.to_string(dimension)})"
    HilbertSpace::L2(interval_expr) =>
      "L2(\{@symprint.to_string(interval_expr)})"
    HilbertSpace::Fock => "F"
    HilbertSpace::TensorProduct(args) =>
      args
      .map(item => {
        match item {
          HilbertSpace::DirectSum(_) => "(\{item.to_string()})"
          _ => item.to_string()
        }
      })
      .join("*")
    HilbertSpace::DirectSum(args) =>
      args.map(item => item.to_string()).join("+")
    HilbertSpace::TensorPower(base, exp) =>
      "\{base.to_string()}**\{@symprint.to_string(exp)}"
  }
}

///|
pub impl Show for HilbertSpace with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Add for HilbertSpace with add(self, other : HilbertSpace) {
  direct_sum_space([self, other])
}

///|
pub impl Mul for HilbertSpace with mul(self, other : HilbertSpace) {
  tensor_product_space([self, other]) catch {
    _ => HilbertSpace::TensorProduct([self, other])
  }
}

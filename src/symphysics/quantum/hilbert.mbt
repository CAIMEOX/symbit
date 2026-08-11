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
fn hilbert_expr_repr(expr : Expr) -> String {
  match expr {
    Number(n) if n.is_integral() => "Integer(\{n.numerator().to_string()})"
    Number(n) =>
      "Rational(\{n.numerator().to_string()}, \{n.denominator().to_string()})"
    Symbol(name) if name == "oo" => "oo"
    Symbol(name) => "Symbol('\{name}')"
    _ if @symcore.application_has_name(expr, "Interval", arity=2) => {
      let args = @symcore.application_args(expr).unwrap()
      "Interval(\{hilbert_expr_repr(args[0])}, \{hilbert_expr_repr(args[1])})"
    }
    _ => @symprint.pretty_string(expr)
  }
}

///|
pub fn interval(start : Expr, stop : Expr) -> Expr {
  @symcore.function("Interval", [start, stop])
}

///|
pub fn hilbert_space() -> HilbertSpace {
  Abstract
}

///|
pub fn complex_space(
  dimension : Expr,
) -> HilbertSpace raise @symphysics.PhysicsError {
  match dimension {
    Number(n) if n.is_integral() && n.numerator().to_int() > 0 =>
      Complex(dimension)
    Symbol(name) if name == "oo" => Complex(dimension)
    Symbol(_) => Complex(dimension)
    _ =>
      raise ValueError(
        "ComplexSpace dimension must be a positive integer, oo, or a symbol",
      )
  }
}

///|
pub fn l2_space(
  interval_expr : Expr,
) -> HilbertSpace raise @symphysics.PhysicsError {
  if @symcore.application_has_name(interval_expr, "Interval", arity=2) {
    L2(interval_expr)
  } else {
    raise ValueError("L2 expects Interval(start, stop)")
  }
}

///|
pub fn fock_space() -> HilbertSpace {
  Fock
}

///|
fn same_base(lhs : HilbertSpace, rhs : HilbertSpace) -> Bool {
  match (lhs, rhs) {
    (TensorPower(base1, _), TensorPower(base2, _)) => base1 == base2
    (TensorPower(base, _), other) => base == other
    (other, TensorPower(base, _)) => other == base
    _ => lhs == rhs
  }
}

///|
fn power_base(space : HilbertSpace) -> HilbertSpace {
  match space {
    TensorPower(base, _) => base
    _ => space
  }
}

///|
fn power_exp(space : HilbertSpace) -> Expr {
  match space {
    TensorPower(_, exp) => exp
    _ => int(1)
  }
}

///|
pub fn tensor_power(
  base : HilbertSpace,
  exp : Expr,
) -> HilbertSpace raise @symphysics.PhysicsError {
  match exp {
    Number(n) if n.is_integral() && n.numerator().to_int() <= 0 =>
      raise ValueError("Tensor powers require a positive integer or symbol")
    _ => ()
  }
  if exp == int(1) {
    base
  } else {
    TensorPower(base, exp)
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
      TensorProduct(items) =>
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
    TensorProduct(combined)
  }
}

///|
pub fn direct_sum_space(args : Array[HilbertSpace]) -> HilbertSpace {
  guard !args.is_empty() else { return hilbert_space() }
  let flat : Array[HilbertSpace] = Array::new()
  for arg in args {
    match arg {
      DirectSum(items) =>
        for item in items {
          flat.push(item)
        }
      _ => flat.push(arg)
    }
  }
  if flat.length() == 1 {
    flat[0]
  } else {
    DirectSum(flat)
  }
}

///|
pub fn HilbertSpace::dimension(
  self : HilbertSpace,
) -> Expr raise @symphysics.PhysicsError {
  match self {
    Abstract => raise ValueError("Abstract HilbertSpace has no fixed dimension")
    Complex(dimension) => dimension
    L2(_) | Fock => NumberSymbol(Infinity)
    TensorProduct(args) => {
      let mut out = int(1)
      for arg in args {
        let dim = arg.dimension()
        if dim == NumberSymbol(Infinity) {
          return NumberSymbol(Infinity)
        }
        out = out * dim
      }
      out
    }
    DirectSum(args) => {
      let mut out = int(0)
      for arg in args {
        let dim = arg.dimension()
        if dim == NumberSymbol(Infinity) {
          return NumberSymbol(Infinity)
        }
        out = out + dim
      }
      out
    }
    TensorPower(base, exp) => {
      let dim = base.dimension()
      if dim == NumberSymbol(Infinity) {
        NumberSymbol(Infinity)
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
    TensorProduct(args) | DirectSum(args) => args
    _ => raise ValueError("spaces is only defined on tensor/direct sums")
  }
}

///|
pub fn HilbertSpace::base(
  self : HilbertSpace,
) -> HilbertSpace raise @symphysics.PhysicsError {
  match self {
    TensorPower(base, _) => base
    _ => raise ValueError("base is only defined on tensor powers")
  }
}

///|
pub fn HilbertSpace::exp(
  self : HilbertSpace,
) -> Expr raise @symphysics.PhysicsError {
  match self {
    TensorPower(_, exp) => exp
    _ => raise ValueError("exp is only defined on tensor powers")
  }
}

///|
pub fn HilbertSpace::repr(self : HilbertSpace) -> String {
  match self {
    Abstract => "HilbertSpace()"
    Complex(dimension) => "ComplexSpace(\{hilbert_expr_repr(dimension)})"
    L2(interval_expr) => "L2(\{hilbert_expr_repr(interval_expr)})"
    Fock => "FockSpace()"
    TensorProduct(args) => {
      let rendered = args.map(space => Show::to_string(space)).join(",")
      "TensorProductHilbertSpace(\{rendered})"
    }
    DirectSum(args) => {
      let rendered = args.map(space => Show::to_string(space)).join(",")
      "DirectSumHilbertSpace(\{rendered})"
    }
    TensorPower(base, exp) =>
      "TensorPowerHilbertSpace(\{Show::to_string(base)},\{@symprint.pretty_string(exp)})"
  }
}

///|
pub impl Show for HilbertSpace with fn to_string(self) {
  match self {
    Abstract => "H"
    Complex(dimension) => "C(\{@symprint.pretty_string(dimension)})"
    L2(interval_expr) => "L2(\{@symprint.pretty_string(interval_expr)})"
    Fock => "F"
    TensorProduct(args) =>
      args
      .map(item => {
        match item {
          DirectSum(_) => "(\{Show::to_string(item)})"
          _ => Show::to_string(item)
        }
      })
      .join("*")
    DirectSum(args) => args.map(item => Show::to_string(item)).join("+")
    TensorPower(base, exp) =>
      "\{Show::to_string(base)}**\{@symprint.pretty_string(exp)}"
  }
}

///|
pub impl Show for HilbertSpace with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub impl Add for HilbertSpace with fn add(self, other : HilbertSpace) {
  direct_sum_space([self, other])
}

///|
pub impl Mul for HilbertSpace with fn mul(self, other : HilbertSpace) {
  tensor_product_space([self, other]) catch {
    _ => TensorProduct([self, other])
  }
}

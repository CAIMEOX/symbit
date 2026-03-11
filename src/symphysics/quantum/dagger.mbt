///|
/// Hermitian-conjugation helpers aligned with the matrix and symbolic subset
/// of `sympy.physics.quantum.dagger`.

///|
pub fn expr_conjugate(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(_) => expr
    @symcore.Expr::Symbol(name) =>
      if name == "I" {
        @symcore.int(-1) * expr
      } else {
        @symcore.raw_function("conjugate", [expr])
      }
    @symcore.Expr::Add(args) => @symcore.add(args.map(expr_conjugate))
    @symcore.Expr::Mul(args) => @symcore.mul(args.map(expr_conjugate))
    @symcore.Expr::Pow(base, exp) => expr_conjugate(base) ^ exp
    @symcore.Expr::Function(name, args) if name == "conjugate" && args.length() == 1 => args[0]
    _ => @symcore.raw_function("conjugate", [expr])
  }
}

///|
pub fn dagger(
  expr : @symcore.Expr,
  evaluate? : Bool = true,
) -> @symcore.Expr {
  if !evaluate {
    return @symcore.raw_function("Dagger", [expr])
  }
  match expr {
    @symcore.Expr::Add(args) => @symcore.raw_add(args.map(arg => dagger(arg)))
    @symcore.Expr::Mul(args) => {
      let reversed : Array[@symcore.Expr] = Array::new()
      for idx in 0..<args.length() {
        reversed.push(dagger(args[args.length() - 1 - idx]))
      }
      @symcore.raw_mul(reversed)
    }
    @symcore.Expr::Pow(base, exp) => @symcore.raw_pow(dagger(base), exp)
    @symcore.Expr::Function(name, args) if name == "TensorProduct" =>
      @symcore.raw_function("TensorProduct", args.map(arg => dagger(arg)))
    @symcore.Expr::Function(name, args) if name == "Commutator" && args.length() == 2 =>
      @symcore.int(-1) *
        @symcore.raw_function("Commutator", [dagger(args[1]), dagger(args[0])])
    @symcore.Expr::Function(name, args) if name == "AntiCommutator" && args.length() == 2 =>
      @symcore.raw_function("AntiCommutator", [dagger(args[0]), dagger(args[1])])
    _ => expr_conjugate(expr)
  }
}

///|
pub fn matrix_dagger(
  matrix : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix {
  matrix.transpose().map(expr_conjugate)
}

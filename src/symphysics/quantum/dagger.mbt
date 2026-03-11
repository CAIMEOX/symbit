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
    @symcore.Expr::Function(name, args) if name == "Ket" => @symcore.raw_function("Bra", args)
    @symcore.Expr::Function(name, args) if name == "Bra" => @symcore.raw_function("Ket", args)
    @symcore.Expr::Function(name, args) if name == "TimeDepKet" => @symcore.raw_function("TimeDepBra", args)
    @symcore.Expr::Function(name, args) if name == "TimeDepBra" => @symcore.raw_function("TimeDepKet", args)
    @symcore.Expr::Function(name, args) if name == "OrthogonalKet" => @symcore.raw_function("OrthogonalBra", args)
    @symcore.Expr::Function(name, args) if name == "OrthogonalBra" => @symcore.raw_function("OrthogonalKet", args)
    @symcore.Expr::Function(name, args) if name == "Qubit" => @symcore.raw_function("QubitBra", args)
    @symcore.Expr::Function(name, args) if name == "QubitBra" => @symcore.raw_function("Qubit", args)
    @symcore.Expr::Function(name, args) if name == "IntQubit" => @symcore.raw_function("IntQubitBra", args)
    @symcore.Expr::Function(name, args) if name == "IntQubitBra" => @symcore.raw_function("IntQubit", args)
    @symcore.Expr::Function(name, args) if name == "JxKet" => @symcore.raw_function("JxBra", args)
    @symcore.Expr::Function(name, args) if name == "JxBra" => @symcore.raw_function("JxKet", args)
    @symcore.Expr::Function(name, args) if name == "JyKet" => @symcore.raw_function("JyBra", args)
    @symcore.Expr::Function(name, args) if name == "JyBra" => @symcore.raw_function("JyKet", args)
    @symcore.Expr::Function(name, args) if name == "JzKet" => @symcore.raw_function("JzBra", args)
    @symcore.Expr::Function(name, args) if name == "JzBra" => @symcore.raw_function("JzKet", args)
    @symcore.Expr::Function(name, args) if name == "XKet" => @symcore.raw_function("XBra", args)
    @symcore.Expr::Function(name, args) if name == "XBra" => @symcore.raw_function("XKet", args)
    @symcore.Expr::Function(name, args) if name == "PxKet" => @symcore.raw_function("PxBra", args)
    @symcore.Expr::Function(name, args) if name == "PxBra" => @symcore.raw_function("PxKet", args)
    @symcore.Expr::Function(name, args) if name == "PositionKet3D" =>
      @symcore.raw_function("PositionBra3D", args)
    @symcore.Expr::Function(name, args) if name == "PositionBra3D" =>
      @symcore.raw_function("PositionKet3D", args)
    @symcore.Expr::Function(name, args) if name == "PIABKet" =>
      @symcore.raw_function("PIABBra", args)
    @symcore.Expr::Function(name, args) if name == "PIABBra" =>
      @symcore.raw_function("PIABKet", args)
    @symcore.Expr::Function(name, args) if name == "SHOKet" =>
      @symcore.raw_function("SHOBra", args)
    @symcore.Expr::Function(name, args) if name == "SHOBra" =>
      @symcore.raw_function("SHOKet", args)
    @symcore.Expr::Function(name, args) if name == "SigmaZKet" => @symcore.raw_function("SigmaZBra", args)
    @symcore.Expr::Function(name, args) if name == "SigmaZBra" => @symcore.raw_function("SigmaZKet", args)
    @symcore.Expr::Function(name, args) if name == "Wavefunction" && args.length() >= 2 => {
      let out = [expr_conjugate(args[0])]
      for idx in 1..<args.length() {
        out.push(args[idx])
      }
      @symcore.raw_function("Wavefunction", out)
    }
    @symcore.Expr::Function(name, args) if name == "Operator" && args.length() == 1 =>
      @symcore.raw_function("Dagger", [args[0]])
    @symcore.Expr::Function(name, _) if name == "SigmaX" || name == "SigmaY" || name == "SigmaZ" => expr
    @symcore.Expr::Function(name, args) if name == "SigmaPlus" =>
      @symcore.raw_function("SigmaMinus", args)
    @symcore.Expr::Function(name, args) if name == "SigmaMinus" =>
      @symcore.raw_function("SigmaPlus", args)
    @symcore.Expr::Function(name, _) if name == "HermitianOperator" => expr
    @symcore.Expr::Function(name, _) if name == "IdentityOperator" => expr
    @symcore.Expr::Function(name, _) if name == "XOp" || name == "YOp" || name == "ZOp" || name == "PxOp" => expr
    @symcore.Expr::Function(name, _) if name == "PIABHamiltonian" || name == "NumberOp" || name == "Hamiltonian" => expr
    @symcore.Expr::Function(name, args) if name == "RaisingOp" =>
      @symcore.raw_function("LoweringOp", args)
    @symcore.Expr::Function(name, args) if name == "LoweringOp" =>
      @symcore.raw_function("RaisingOp", args)
    @symcore.Expr::Function(name, _) if name == "UnitaryOperator" => @symcore.raw_pow(expr, @symcore.int(-1))
    @symcore.Expr::Function(name, _) if name == "DifferentialOperator" =>
      @symcore.raw_function("Dagger", [expr])
    @symcore.Expr::Function(name, _) if name == "IdentityGate" => expr
    @symcore.Expr::Function(name, _) if name == "HadamardGate" => expr
    @symcore.Expr::Function(name, _) if name == "XGate" => expr
    @symcore.Expr::Function(name, _) if name == "YGate" => expr
    @symcore.Expr::Function(name, _) if name == "ZGate" => expr
    @symcore.Expr::Function(name, _) if name == "SwapGate" => expr
    @symcore.Expr::Function(name, _) if name == "CNotGate" => expr
    @symcore.Expr::Function("QFT", args) => @symcore.raw_function("IQFT", args)
    @symcore.Expr::Function("IQFT", args) => @symcore.raw_function("QFT", args)
    @symcore.Expr::Function("RkGate", args) if args.length() == 2 =>
      @symcore.raw_function("RkGate", [args[0], @symcore.int(-1) * args[1]])
    @symcore.Expr::Function(name, _) if name == "Gate" || name == "CGate" || name == "UGate" || name == "PhaseGate" || name == "TGate" || name == "Rotation" =>
      @symcore.raw_pow(expr, @symcore.int(-1))
    @symcore.Expr::Function(name, args) if name == "BosonOp" && args.length() == 2 =>
      @symcore.raw_function("BosonOp", [
        args[0],
        if args[1] == @symcore.int(0) { @symcore.int(1) } else { @symcore.int(0) },
      ])
    @symcore.Expr::Function(name, args) if name == "FermionOp" && args.length() == 2 =>
      @symcore.raw_function("FermionOp", [
        args[0],
        if args[1] == @symcore.int(0) { @symcore.int(1) } else { @symcore.int(0) },
      ])
    @symcore.Expr::Function(name, args) if name == "OuterProduct" && args.length() == 2 =>
      @symcore.raw_function("OuterProduct", [dagger(args[1]), dagger(args[0])])
    @symcore.Expr::Function(name, args) if name == "InnerProduct" && args.length() == 2 =>
      inner_product(dagger(args[1]), dagger(args[0]), evaluate=false)
    @symcore.Expr::Function(name, args) if name == "TensorProduct" =>
      @symcore.raw_function("TensorProduct", args.map(arg => dagger(arg)))
    @symcore.Expr::Function(name, args) if name == "Commutator" && args.length() == 2 =>
      @symcore.int(-1) *
        @symcore.raw_function("Commutator", [dagger(args[1]), dagger(args[0])])
    @symcore.Expr::Function(name, args) if name == "AntiCommutator" && args.length() == 2 =>
      @symcore.raw_function("AntiCommutator", [dagger(args[0]), dagger(args[1])])
    @symcore.Expr::Symbol(name) if name == "Jplus" || name == "Jminus" =>
      @symcore.raw_function("Dagger", [expr])
    @symcore.Expr::Symbol(name) if name == "Jx" || name == "Jy" || name == "Jz" || name == "J2" => expr
    _ => expr_conjugate(expr)
  }
}

///|
pub fn matrix_dagger(
  matrix : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix {
  matrix.transpose().map(expr_conjugate)
}

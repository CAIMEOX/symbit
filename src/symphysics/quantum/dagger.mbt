///|
/// Hermitian-conjugation helpers aligned with the matrix and symbolic subset
/// of `sympy.physics.quantum.dagger`.

///|
pub fn expr_conjugate(expr : Expr) -> Expr {
  match expr {
    Expr::Number(_) => expr
    Expr::Symbol(name) =>
      if name == "I" {
        int(-1) * expr
      } else {
        @symcore.raw_function("conjugate", [expr])
      }
    Expr::Add(args) => @symcore.add(args.map(expr_conjugate))
    Expr::Mul(args) => @symcore.mul(args.map(expr_conjugate))
    Expr::Pow(base, exp) => expr_conjugate(base) ^ exp
    Expr::Function(name, args) if name == "conjugate" && args.length() == 1 =>
      args[0]
    _ => @symcore.raw_function("conjugate", [expr])
  }
}

///|
pub fn dagger(expr : Expr, evaluate? : Bool = true) -> Expr {
  if !evaluate {
    return @symcore.raw_function("Dagger", [expr])
  }
  match expr {
    Expr::Add(args) => @symcore.raw_add(args.map(arg => dagger(arg)))
    Expr::Mul(args) => {
      let reversed : Array[Expr] = Array::new()
      for idx in 0..<args.length() {
        reversed.push(dagger(args[args.length() - 1 - idx]))
      }
      @symcore.raw_mul(reversed)
    }
    Expr::Pow(base, exp) => @symcore.raw_pow(dagger(base), exp)
    Expr::Function(name, args) if name == "Ket" =>
      @symcore.raw_function("Bra", args)
    Expr::Function(name, args) if name == "Bra" =>
      @symcore.raw_function("Ket", args)
    Expr::Function(name, args) if name == "TimeDepKet" =>
      @symcore.raw_function("TimeDepBra", args)
    Expr::Function(name, args) if name == "TimeDepBra" =>
      @symcore.raw_function("TimeDepKet", args)
    Expr::Function(name, args) if name == "OrthogonalKet" =>
      @symcore.raw_function("OrthogonalBra", args)
    Expr::Function(name, args) if name == "OrthogonalBra" =>
      @symcore.raw_function("OrthogonalKet", args)
    Expr::Function(name, args) if name == "Qubit" =>
      @symcore.raw_function("QubitBra", args)
    Expr::Function(name, args) if name == "QubitBra" =>
      @symcore.raw_function("Qubit", args)
    Expr::Function(name, args) if name == "IntQubit" =>
      @symcore.raw_function("IntQubitBra", args)
    Expr::Function(name, args) if name == "IntQubitBra" =>
      @symcore.raw_function("IntQubit", args)
    Expr::Function(name, args) if name == "JxKet" =>
      @symcore.raw_function("JxBra", args)
    Expr::Function(name, args) if name == "JxBra" =>
      @symcore.raw_function("JxKet", args)
    Expr::Function(name, args) if name == "JyKet" =>
      @symcore.raw_function("JyBra", args)
    Expr::Function(name, args) if name == "JyBra" =>
      @symcore.raw_function("JyKet", args)
    Expr::Function(name, args) if name == "JzKet" =>
      @symcore.raw_function("JzBra", args)
    Expr::Function(name, args) if name == "JzBra" =>
      @symcore.raw_function("JzKet", args)
    Expr::Function(name, args) if name == "XKet" =>
      @symcore.raw_function("XBra", args)
    Expr::Function(name, args) if name == "XBra" =>
      @symcore.raw_function("XKet", args)
    Expr::Function(name, args) if name == "PxKet" =>
      @symcore.raw_function("PxBra", args)
    Expr::Function(name, args) if name == "PxBra" =>
      @symcore.raw_function("PxKet", args)
    Expr::Function(name, args) if name == "PositionKet3D" =>
      @symcore.raw_function("PositionBra3D", args)
    Expr::Function(name, args) if name == "PositionBra3D" =>
      @symcore.raw_function("PositionKet3D", args)
    Expr::Function(name, args) if name == "PIABKet" =>
      @symcore.raw_function("PIABBra", args)
    Expr::Function(name, args) if name == "PIABBra" =>
      @symcore.raw_function("PIABKet", args)
    Expr::Function(name, args) if name == "SHOKet" =>
      @symcore.raw_function("SHOBra", args)
    Expr::Function(name, args) if name == "SHOBra" =>
      @symcore.raw_function("SHOKet", args)
    Expr::Function(name, args) if name == "SigmaZKet" =>
      @symcore.raw_function("SigmaZBra", args)
    Expr::Function(name, args) if name == "SigmaZBra" =>
      @symcore.raw_function("SigmaZKet", args)
    Expr::Function(name, args) if name == "Wavefunction" && args.length() >= 2 => {
      let out = [expr_conjugate(args[0])]
      for idx in 1..<args.length() {
        out.push(args[idx])
      }
      @symcore.raw_function("Wavefunction", out)
    }
    Expr::Function(name, args) if name == "Operator" && args.length() == 1 =>
      @symcore.raw_function("Dagger", [args[0]])
    Expr::Function(name, _) if name == "SigmaX" ||
      name == "SigmaY" ||
      name == "SigmaZ" => expr
    Expr::Function(name, args) if name == "SigmaPlus" =>
      @symcore.raw_function("SigmaMinus", args)
    Expr::Function(name, args) if name == "SigmaMinus" =>
      @symcore.raw_function("SigmaPlus", args)
    Expr::Function(name, _) if name == "HermitianOperator" => expr
    Expr::Function(name, _) if name == "IdentityOperator" => expr
    Expr::Function(name, _) if name == "XOp" ||
      name == "YOp" ||
      name == "ZOp" ||
      name == "PxOp" => expr
    Expr::Function(name, _) if name == "PIABHamiltonian" ||
      name == "NumberOp" ||
      name == "Hamiltonian" => expr
    Expr::Function(name, args) if name == "RaisingOp" =>
      @symcore.raw_function("LoweringOp", args)
    Expr::Function(name, args) if name == "LoweringOp" =>
      @symcore.raw_function("RaisingOp", args)
    Expr::Function(name, _) if name == "UnitaryOperator" =>
      @symcore.raw_pow(expr, int(-1))
    Expr::Function(name, _) if name == "DifferentialOperator" =>
      @symcore.raw_function("Dagger", [expr])
    Expr::Function(name, _) if name == "IdentityGate" => expr
    Expr::Function(name, _) if name == "HadamardGate" => expr
    Expr::Function(name, _) if name == "XGate" => expr
    Expr::Function(name, _) if name == "YGate" => expr
    Expr::Function(name, _) if name == "ZGate" => expr
    Expr::Function(name, _) if name == "SwapGate" => expr
    Expr::Function(name, _) if name == "CNotGate" => expr
    Expr::Function("QFT", args) => @symcore.raw_function("IQFT", args)
    Expr::Function("IQFT", args) => @symcore.raw_function("QFT", args)
    Expr::Function("RkGate", args) if args.length() == 2 =>
      @symcore.raw_function("RkGate", [args[0], int(-1) * args[1]])
    Expr::Function("Rotation", args) if args.length() == 3 =>
      @symcore.raw_function("Rotation", [
        int(-1) * args[2],
        int(-1) * args[1],
        int(-1) * args[0],
      ])
    Expr::Function(name, _) if name == "Gate" ||
      name == "CGate" ||
      name == "UGate" ||
      name == "PhaseGate" ||
      name == "TGate" ||
      name == "Rotation" => @symcore.raw_pow(expr, int(-1))
    Expr::Function(name, args) if name == "BosonOp" && args.length() == 2 =>
      @symcore.raw_function("BosonOp", [
        args[0],
        if args[1] == int(0) {
          int(1)
        } else {
          int(0)
        },
      ])
    Expr::Function(name, args) if name == "AnnihilateBoson" &&
      args.length() == 1 => @symcore.raw_function("CreateBoson", args)
    Expr::Function(name, args) if name == "CreateBoson" && args.length() == 1 =>
      @symcore.raw_function("AnnihilateBoson", args)
    Expr::Function(name, args) if name == "FockStateBosonKet" &&
      args.length() == 1 => @symcore.raw_function("FockStateBosonBra", args)
    Expr::Function(name, args) if name == "FockStateBosonBra" &&
      args.length() == 1 => @symcore.raw_function("FockStateBosonKet", args)
    Expr::Function(name, args) if name == "FermionOp" && args.length() == 2 =>
      @symcore.raw_function("FermionOp", [
        args[0],
        if args[1] == int(0) {
          int(1)
        } else {
          int(0)
        },
      ])
    Expr::Function(name, args) if name == "OuterProduct" && args.length() == 2 =>
      @symcore.raw_function("OuterProduct", [dagger(args[1]), dagger(args[0])])
    Expr::Function(name, args) if name == "InnerProduct" && args.length() == 2 =>
      inner_product(dagger(args[1]), dagger(args[0]), evaluate=false)
    Expr::Function(name, args) if name == "TensorProduct" =>
      @symcore.raw_function("TensorProduct", args.map(arg => dagger(arg)))
    Expr::Function(name, args) if name == "Commutator" && args.length() == 2 =>
      int(-1) *
      @symcore.raw_function("Commutator", [dagger(args[1]), dagger(args[0])])
    Expr::Function(name, args) if name == "AntiCommutator" && args.length() == 2 =>
      @symcore.raw_function("AntiCommutator", [dagger(args[0]), dagger(args[1])])
    Expr::Symbol(name) if name == "Jplus" || name == "Jminus" =>
      @symcore.raw_function("Dagger", [expr])
    Expr::Symbol(name) if name == "Jx" ||
      name == "Jy" ||
      name == "Jz" ||
      name == "J2" => expr
    _ => expr_conjugate(expr)
  }
}

///|
pub fn matrix_dagger(
  matrix : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix {
  matrix.transpose().map(expr_conjugate)
}

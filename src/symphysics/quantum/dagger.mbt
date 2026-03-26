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
    _ =>
      match @symcore.application_args(expr) {
        Some([arg]) if @symcore.application_has_name(expr, "conjugate") => arg
        _ => @symcore.raw_function("conjugate", [expr])
      }
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
    Expr::Symbol(name) if name == "Jplus" || name == "Jminus" =>
      @symcore.raw_function("Dagger", [expr])
    Expr::Symbol(name) if name == "Jx" ||
      name == "Jy" ||
      name == "Jz" ||
      name == "J2" => expr
    _ =>
      match (@symcore.application_name(expr), @symcore.application_args(expr)) {
        (Some("Ket"), Some(args)) => @symcore.raw_function("Bra", args)
        (Some("Bra"), Some(args)) => @symcore.raw_function("Ket", args)
        (Some("TimeDepKet"), Some(args)) =>
          @symcore.raw_function("TimeDepBra", args)
        (Some("TimeDepBra"), Some(args)) =>
          @symcore.raw_function("TimeDepKet", args)
        (Some("OrthogonalKet"), Some(args)) =>
          @symcore.raw_function("OrthogonalBra", args)
        (Some("OrthogonalBra"), Some(args)) =>
          @symcore.raw_function("OrthogonalKet", args)
        (Some("Qubit"), Some(args)) => @symcore.raw_function("QubitBra", args)
        (Some("QubitBra"), Some(args)) => @symcore.raw_function("Qubit", args)
        (Some("IntQubit"), Some(args)) =>
          @symcore.raw_function("IntQubitBra", args)
        (Some("IntQubitBra"), Some(args)) =>
          @symcore.raw_function("IntQubit", args)
        (Some("JxKet"), Some(args)) => @symcore.raw_function("JxBra", args)
        (Some("JxBra"), Some(args)) => @symcore.raw_function("JxKet", args)
        (Some("JyKet"), Some(args)) => @symcore.raw_function("JyBra", args)
        (Some("JyBra"), Some(args)) => @symcore.raw_function("JyKet", args)
        (Some("JzKet"), Some(args)) => @symcore.raw_function("JzBra", args)
        (Some("JzBra"), Some(args)) => @symcore.raw_function("JzKet", args)
        (Some("XKet"), Some(args)) => @symcore.raw_function("XBra", args)
        (Some("XBra"), Some(args)) => @symcore.raw_function("XKet", args)
        (Some("PxKet"), Some(args)) => @symcore.raw_function("PxBra", args)
        (Some("PxBra"), Some(args)) => @symcore.raw_function("PxKet", args)
        (Some("PositionKet3D"), Some(args)) =>
          @symcore.raw_function("PositionBra3D", args)
        (Some("PositionBra3D"), Some(args)) =>
          @symcore.raw_function("PositionKet3D", args)
        (Some("PIABKet"), Some(args)) => @symcore.raw_function("PIABBra", args)
        (Some("PIABBra"), Some(args)) => @symcore.raw_function("PIABKet", args)
        (Some("SHOKet"), Some(args)) => @symcore.raw_function("SHOBra", args)
        (Some("SHOBra"), Some(args)) => @symcore.raw_function("SHOKet", args)
        (Some("SigmaZKet"), Some(args)) =>
          @symcore.raw_function("SigmaZBra", args)
        (Some("SigmaZBra"), Some(args)) =>
          @symcore.raw_function("SigmaZKet", args)
        (Some("Wavefunction"), Some(args)) if args.length() >= 2 => {
          let out = [expr_conjugate(args[0])]
          for idx in 1..<args.length() {
            out.push(args[idx])
          }
          @symcore.raw_function("Wavefunction", out)
        }
        (Some("Operator"), Some([arg])) => @symcore.raw_function("Dagger", [arg])
        (Some(name), Some(_)) if name == "SigmaX" ||
          name == "SigmaY" ||
          name == "SigmaZ" => expr
        (Some("SigmaPlus"), Some(args)) =>
          @symcore.raw_function("SigmaMinus", args)
        (Some("SigmaMinus"), Some(args)) =>
          @symcore.raw_function("SigmaPlus", args)
        (Some("HermitianOperator"), Some(_)) => expr
        (Some("IdentityOperator"), Some(_)) => expr
        (Some(name), Some(_)) if name == "XOp" ||
          name == "YOp" ||
          name == "ZOp" ||
          name == "PxOp" => expr
        (Some(name), Some(_)) if name == "PIABHamiltonian" ||
          name == "NumberOp" ||
          name == "Hamiltonian" => expr
        (Some("RaisingOp"), Some(args)) =>
          @symcore.raw_function("LoweringOp", args)
        (Some("LoweringOp"), Some(args)) =>
          @symcore.raw_function("RaisingOp", args)
        (Some("UnitaryOperator"), Some(_)) => @symcore.raw_pow(expr, int(-1))
        (Some("DifferentialOperator"), Some(_)) =>
          @symcore.raw_function("Dagger", [expr])
        (Some("IdentityGate"), Some(_)) => expr
        (Some("HadamardGate"), Some(_)) => expr
        (Some("XGate"), Some(_)) => expr
        (Some("YGate"), Some(_)) => expr
        (Some("ZGate"), Some(_)) => expr
        (Some("SwapGate"), Some(_)) => expr
        (Some("CNotGate"), Some(_)) => expr
        (Some("QFT"), Some(args)) => @symcore.raw_function("IQFT", args)
        (Some("IQFT"), Some(args)) => @symcore.raw_function("QFT", args)
        (Some("RkGate"), Some([target, phase])) =>
          @symcore.raw_function("RkGate", [target, int(-1) * phase])
        (Some("Rotation"), Some([a, b, c])) =>
          @symcore.raw_function("Rotation", [
            int(-1) * c,
            int(-1) * b,
            int(-1) * a,
          ])
        (Some(name), Some(_)) if name == "Gate" ||
          name == "CGate" ||
          name == "UGate" ||
          name == "PhaseGate" ||
          name == "TGate" ||
          name == "Rotation" => @symcore.raw_pow(expr, int(-1))
        (Some("BosonOp"), Some([mode, kind])) =>
          @symcore.raw_function("BosonOp", [
            mode,
            if kind == int(0) {
              int(1)
            } else {
              int(0)
            },
          ])
        (Some("AnnihilateBoson"), Some(args)) if args.length() == 1 =>
          @symcore.raw_function("CreateBoson", args)
        (Some("CreateBoson"), Some(args)) if args.length() == 1 =>
          @symcore.raw_function("AnnihilateBoson", args)
        (Some("FockStateBosonKet"), Some(args)) if args.length() == 1 =>
          @symcore.raw_function("FockStateBosonBra", args)
        (Some("FockStateBosonBra"), Some(args)) if args.length() == 1 =>
          @symcore.raw_function("FockStateBosonKet", args)
        (Some("FermionOp"), Some([mode, kind])) =>
          @symcore.raw_function("FermionOp", [
            mode,
            if kind == int(0) {
              int(1)
            } else {
              int(0)
            },
          ])
        (Some("OuterProduct"), Some([lhs, rhs])) =>
          @symcore.raw_function("OuterProduct", [dagger(rhs), dagger(lhs)])
        (Some("InnerProduct"), Some([lhs, rhs])) =>
          inner_product(dagger(rhs), dagger(lhs), evaluate=false)
        (Some("TensorProduct"), Some(args)) =>
          @symcore.raw_function("TensorProduct", args.map(arg => dagger(arg)))
        (Some("Commutator"), Some([lhs, rhs])) =>
          int(-1) *
          @symcore.raw_function("Commutator", [dagger(rhs), dagger(lhs)])
        (Some("AntiCommutator"), Some([lhs, rhs])) =>
          @symcore.raw_function("AntiCommutator", [dagger(lhs), dagger(rhs)])
        _ => expr_conjugate(expr)
      }
  }
}

///|
pub fn matrix_dagger(
  matrix : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix {
  matrix.transpose().map(expr_conjugate)
}

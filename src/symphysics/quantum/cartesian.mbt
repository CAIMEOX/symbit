///|
/// One-dimensional cartesian position/momentum operators and their eigenstates.
///
/// This follows the transferable part of `sympy.physics.quantum.cartesian`:
/// `XOp`, `YOp`, `ZOp`, `PxOp`, the one-dimensional eigenstates `XKet/XBra`
/// and `PxKet/PxBra`, and the three-dimensional position eigenstates.
/// The important semantic contracts are:
///
/// - `qapply(XOp*|x>) = x*|x>` and `qapply(PxOp*|px>) = px*|px>`
/// - `<x|x'> = DiracDelta(x - x')`, `<px|px'> = DiracDelta(px - px')`
/// - `<x|px> = exp(I*x*px/hbar)/sqrt(2*pi*hbar)`
/// - `represent` can project these states/operators into the matching
///   cartesian basis without relying on SymPy at runtime.

///|
fn cartesian_default_label(name : String) -> Expr {
  Symbol(name)
}

///|
fn cartesian_delta(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.raw_function("DiracDelta", [lhs - rhs])
}

///|
fn cartesian_plane_wave(phase : Expr) -> Expr {
  let norm = @symcore.raw_function("sqrt", [int(2) * NumberSymbol(Pi) * hbar])
  @symcore.raw_function("exp", [phase]) * @symcore.raw_pow(norm, int(-1))
}

///|
fn cartesian_symbol(base : String, idx? : Int = 0) -> Expr {
  if idx <= 0 {
    Symbol(base)
  } else {
    Symbol("\{base}_\{idx.to_string()}")
  }
}

///|
pub fn x_op(label? : Expr = cartesian_default_label("X")) -> Expr {
  @symcore.raw_function("XOp", [label])
}

///|
pub fn y_op(label? : Expr = cartesian_default_label("Y")) -> Expr {
  @symcore.raw_function("YOp", [label])
}

///|
pub fn z_op(label? : Expr = cartesian_default_label("Z")) -> Expr {
  @symcore.raw_function("ZOp", [label])
}

///|
pub fn px_op(label? : Expr = cartesian_default_label("Px")) -> Expr {
  @symcore.raw_function("PxOp", [label])
}

///|
pub fn x_ket(position? : Expr = cartesian_default_label("x")) -> Expr {
  @symcore.raw_function("XKet", [position])
}

///|
pub fn x_bra(position? : Expr = cartesian_default_label("x")) -> Expr {
  @symcore.raw_function("XBra", [position])
}

///|
pub fn px_ket(momentum? : Expr = cartesian_default_label("px")) -> Expr {
  @symcore.raw_function("PxKet", [momentum])
}

///|
pub fn px_bra(momentum? : Expr = cartesian_default_label("px")) -> Expr {
  @symcore.raw_function("PxBra", [momentum])
}

///|
pub fn position_ket_3d(
  x? : Expr = cartesian_default_label("x"),
  y? : Expr = cartesian_default_label("y"),
  z? : Expr = cartesian_default_label("z"),
) -> Expr {
  @symcore.raw_function("PositionKet3D", [x, y, z])
}

///|
pub fn position_bra_3d(
  x? : Expr = cartesian_default_label("x"),
  y? : Expr = cartesian_default_label("y"),
  z? : Expr = cartesian_default_label("z"),
) -> Expr {
  @symcore.raw_function("PositionBra3D", [x, y, z])
}

///|
fn cartesian_lowercase_label(label : Expr, fallback : String) -> Expr {
  match label {
    Symbol(name) => Symbol(name.to_lower())
    _ => Symbol(fallback)
  }
}

///|
pub fn cartesian_operator_to_state(op_expr : Expr) -> Expr? {
  if quantum_expr_has_name(op_expr, "XOp") {
    let label = match quantum_expr_args(op_expr) {
      Some(args) if !args.is_empty() => cartesian_lowercase_label(args[0], "x")
      _ => cartesian_default_label("x")
    }
    return Some(x_ket(position=label))
  }
  if quantum_expr_has_name(op_expr, "PxOp") {
    let label = match quantum_expr_args(op_expr) {
      Some(args) if !args.is_empty() => cartesian_lowercase_label(args[0], "px")
      _ => cartesian_default_label("px")
    }
    return Some(px_ket(momentum=label))
  }
  None
}

///|
pub fn cartesian_state_to_operator(state_expr : Expr) -> Array[Expr]? {
  if quantum_expr_has_any_name(state_expr, ["XKet", "XBra"]) {
    return Some([x_op()])
  }
  if quantum_expr_has_any_name(state_expr, ["PxKet", "PxBra"]) {
    return Some([px_op()])
  }
  if quantum_expr_has_any_name(state_expr, ["PositionKet3D", "PositionBra3D"]) {
    return Some([x_op(), y_op(), z_op()])
  }
  None
}

///|
pub fn cartesian_apply_operator_to_ket(
  op_expr : Expr,
  ket_expr : Expr,
) -> Expr? {
  if quantum_expr_has_name(op_expr, "XOp") &&
    quantum_expr_has_name(ket_expr, "XKet") {
    match quantum_expr_args(ket_expr) {
      Some(args) if args.length() == 1 => return Some(args[0] * ket_expr)
      _ => ()
    }
  }
  if quantum_expr_has_name(op_expr, "PxOp") &&
    quantum_expr_has_name(ket_expr, "PxKet") {
    match quantum_expr_args(ket_expr) {
      Some(args) if args.length() == 1 => return Some(args[0] * ket_expr)
      _ => ()
    }
  }
  if quantum_expr_has_any_name(op_expr, ["XOp", "YOp", "ZOp"]) &&
    quantum_expr_has_name(ket_expr, "PositionKet3D") {
    match quantum_expr_args(ket_expr) {
      Some(args) if args.length() == 3 =>
        if quantum_expr_has_name(op_expr, "XOp") {
          return Some(args[0] * ket_expr)
        } else if quantum_expr_has_name(op_expr, "YOp") {
          return Some(args[1] * ket_expr)
        } else {
          return Some(args[2] * ket_expr)
        }
      _ => ()
    }
  }
  None
}

///|
pub fn cartesian_inner_product(bra_expr : Expr, ket_expr : Expr) -> Expr? {
  if quantum_expr_has_name(bra_expr, "XBra") &&
    quantum_expr_has_name(ket_expr, "XKet") {
    match (quantum_expr_args(bra_expr), quantum_expr_args(ket_expr)) {
      (Some(bargs), Some(kargs)) if bargs.length() == 1 && kargs.length() == 1 =>
        return Some(cartesian_delta(kargs[0], bargs[0]))
      _ => ()
    }
  }
  if quantum_expr_has_name(bra_expr, "PxBra") &&
    quantum_expr_has_name(ket_expr, "PxKet") {
    match (quantum_expr_args(bra_expr), quantum_expr_args(ket_expr)) {
      (Some(bargs), Some(kargs)) if bargs.length() == 1 && kargs.length() == 1 =>
        return Some(cartesian_delta(kargs[0], bargs[0]))
      _ => ()
    }
  }
  if quantum_expr_has_name(bra_expr, "XBra") &&
    quantum_expr_has_name(ket_expr, "PxKet") {
    match (quantum_expr_args(bra_expr), quantum_expr_args(ket_expr)) {
      (Some(bargs), Some(kargs)) if bargs.length() == 1 && kargs.length() == 1 =>
        return Some(
          cartesian_plane_wave(
            NumberSymbol(ImaginaryUnit) *
            bargs[0] *
            kargs[0] *
            @symcore.raw_pow(hbar, int(-1)),
          ),
        )
      _ => ()
    }
  }
  if quantum_expr_has_name(bra_expr, "PxBra") &&
    quantum_expr_has_name(ket_expr, "XKet") {
    match (quantum_expr_args(bra_expr), quantum_expr_args(ket_expr)) {
      (Some(bargs), Some(kargs)) if bargs.length() == 1 && kargs.length() == 1 =>
        return Some(
          cartesian_plane_wave(
            int(-1) *
            NumberSymbol(ImaginaryUnit) *
            kargs[0] *
            bargs[0] *
            @symcore.raw_pow(hbar, int(-1)),
          ),
        )
      _ => ()
    }
  }
  if quantum_expr_has_name(bra_expr, "PositionBra3D") &&
    quantum_expr_has_name(ket_expr, "PositionKet3D") {
    match (quantum_expr_args(bra_expr), quantum_expr_args(ket_expr)) {
      (Some(bargs), Some(kargs)) if bargs.length() == 3 && kargs.length() == 3 =>
        return Some(
          cartesian_delta(kargs[0], bargs[0]) *
          cartesian_delta(kargs[1], bargs[1]) *
          cartesian_delta(kargs[2], bargs[2]),
        )
      _ => ()
    }
  }
  None
}

///|
fn cartesian_basis_family(basis : Expr?) -> String {
  match basis {
    None => "default"
    Some(expr) =>
      if quantum_expr_has_any_name(expr, ["XOp", "XKet", "XBra"]) {
        "x"
      } else if quantum_expr_has_any_name(expr, ["PxOp", "PxKet", "PxBra"]) {
        "px"
      } else {
        "default"
      }
  }
}

///|
fn cartesian_basis_symbol(basis_name : String) -> Expr {
  match basis_name {
    "px" => cartesian_symbol("px", idx=1)
    _ => cartesian_symbol("x", idx=1)
  }
}

///|
pub fn cartesian_represent(expr : Expr, basis? : Expr? = None) -> Expr? {
  let basis_name = cartesian_basis_family(basis)
  let coord = cartesian_basis_symbol(basis_name)
  if quantum_expr_has_name(expr, "XKet") {
    match quantum_expr_args(expr) {
      Some(args) if args.length() == 1 =>
        return Some(
          if basis_name == "px" {
            cartesian_plane_wave(
              int(-1) *
              NumberSymbol(ImaginaryUnit) *
              args[0] *
              coord *
              @symcore.raw_pow(hbar, int(-1)),
            )
          } else {
            cartesian_delta(coord, args[0])
          },
        )
      _ => ()
    }
  }
  if quantum_expr_has_name(expr, "XBra") {
    match quantum_expr_args(expr) {
      Some(args) if args.length() == 1 =>
        return Some(
          if basis_name == "px" {
            cartesian_plane_wave(
              NumberSymbol(ImaginaryUnit) *
              args[0] *
              coord *
              @symcore.raw_pow(hbar, int(-1)),
            )
          } else {
            cartesian_delta(coord, args[0])
          },
        )
      _ => ()
    }
  }
  if quantum_expr_has_name(expr, "PxKet") {
    match quantum_expr_args(expr) {
      Some(args) if args.length() == 1 =>
        return Some(
          if basis_name == "x" {
            cartesian_plane_wave(
              NumberSymbol(ImaginaryUnit) *
              coord *
              args[0] *
              @symcore.raw_pow(hbar, int(-1)),
            )
          } else {
            cartesian_delta(coord, args[0])
          },
        )
      _ => ()
    }
  }
  if quantum_expr_has_name(expr, "PxBra") {
    match quantum_expr_args(expr) {
      Some(args) if args.length() == 1 =>
        return Some(
          if basis_name == "x" {
            cartesian_plane_wave(
              int(-1) *
              NumberSymbol(ImaginaryUnit) *
              coord *
              args[0] *
              @symcore.raw_pow(hbar, int(-1)),
            )
          } else {
            cartesian_delta(coord, args[0])
          },
        )
      _ => ()
    }
  }
  if quantum_expr_has_any_name(expr, ["PositionKet3D", "PositionBra3D"]) {
    match quantum_expr_args(expr) {
      Some(args) if args.length() == 3 =>
        return Some(
          cartesian_delta(cartesian_symbol("x", idx=1), args[0]) *
          cartesian_delta(cartesian_symbol("y", idx=1), args[1]) *
          cartesian_delta(cartesian_symbol("z", idx=1), args[2]),
        )
      _ => ()
    }
  }
  if quantum_expr_has_name(expr, "XOp") {
    return Some(
      if basis_name == "px" {
        let px1 = cartesian_symbol("px", idx=1)
        let px2 = cartesian_symbol("px", idx=2)
        NumberSymbol(ImaginaryUnit) * hbar * cartesian_delta(px1, px2) * px1
      } else {
        coord
      },
    )
  }
  if quantum_expr_has_name(expr, "PxOp") {
    return Some(
      if basis_name == "x" || basis_name == "default" {
        let x1 = cartesian_symbol("x", idx=1)
        let x2 = cartesian_symbol("x", idx=2)
        int(-1) *
        NumberSymbol(ImaginaryUnit) *
        hbar *
        cartesian_delta(x1, x2) *
        x1
      } else {
        coord
      },
    )
  }
  None
}

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
  symbol(name)
}

///|
fn cartesian_delta(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.raw_function("DiracDelta", [lhs - rhs])
}

///|
fn cartesian_plane_wave(phase : Expr) -> Expr {
  let norm = @symcore.raw_function("sqrt", [
    int(2) * symbol("pi") * hbar,
  ])
  @symcore.raw_function("exp", [phase]) *
  @symcore.raw_pow(norm, int(-1))
}

///|
fn cartesian_symbol(base : String, idx? : Int = 0) -> Expr {
  if idx <= 0 {
    symbol(base)
  } else {
    symbol("\{base}_\{idx.to_string()}")
  }
}

///|
pub fn x_op(
  label? : Expr = cartesian_default_label("X"),
) -> Expr {
  @symcore.raw_function("XOp", [label])
}

///|
pub fn y_op(
  label? : Expr = cartesian_default_label("Y"),
) -> Expr {
  @symcore.raw_function("YOp", [label])
}

///|
pub fn z_op(
  label? : Expr = cartesian_default_label("Z"),
) -> Expr {
  @symcore.raw_function("ZOp", [label])
}

///|
pub fn px_op(
  label? : Expr = cartesian_default_label("Px"),
) -> Expr {
  @symcore.raw_function("PxOp", [label])
}

///|
pub fn x_ket(
  position? : Expr = cartesian_default_label("x"),
) -> Expr {
  @symcore.raw_function("XKet", [position])
}

///|
pub fn x_bra(
  position? : Expr = cartesian_default_label("x"),
) -> Expr {
  @symcore.raw_function("XBra", [position])
}

///|
pub fn px_ket(
  momentum? : Expr = cartesian_default_label("px"),
) -> Expr {
  @symcore.raw_function("PxKet", [momentum])
}

///|
pub fn px_bra(
  momentum? : Expr = cartesian_default_label("px"),
) -> Expr {
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
fn cartesian_lowercase_label(
  label : Expr,
  fallback : String,
) -> Expr {
  match label {
    Expr::Symbol(name) => symbol(name.to_lower())
    _ => symbol(fallback)
  }
}

///|
pub fn cartesian_operator_to_state(op_expr : Expr) -> Expr? {
  match op_expr {
    Expr::Function("XOp", args) => {
      let label = if args.is_empty() {
        cartesian_default_label("x")
      } else {
        cartesian_lowercase_label(args[0], "x")
      }
      Some(x_ket(position=label))
    }
    Expr::Function("PxOp", args) => {
      let label = if args.is_empty() {
        cartesian_default_label("px")
      } else {
        cartesian_lowercase_label(args[0], "px")
      }
      Some(px_ket(momentum=label))
    }
    _ => None
  }
}

///|
pub fn cartesian_state_to_operator(
  state_expr : Expr,
) -> Array[Expr]? {
  match state_expr {
    Expr::Function("XKet", args)
    | Expr::Function("XBra", args) => {
      ignore(args)
      Some([x_op()])
    }
    Expr::Function("PxKet", args)
    | Expr::Function("PxBra", args) => {
      ignore(args)
      Some([px_op()])
    }
    Expr::Function("PositionKet3D", _)
    | Expr::Function("PositionBra3D", _) =>
      Some([x_op(), y_op(), z_op()])
    _ => None
  }
}

///|
pub fn cartesian_apply_operator_to_ket(
  op_expr : Expr,
  ket_expr : Expr,
) -> Expr? {
  match (op_expr, ket_expr) {
    (Expr::Function("XOp", _), Expr::Function("XKet", args)) if args.length() ==
      1 => Some(args[0] * ket_expr)
    (Expr::Function("PxOp", _), Expr::Function("PxKet", args)) if args.length() ==
      1 => Some(args[0] * ket_expr)
    (
      Expr::Function("XOp", _),
      Expr::Function("PositionKet3D", args),
    ) if args.length() == 3 => Some(args[0] * ket_expr)
    (
      Expr::Function("YOp", _),
      Expr::Function("PositionKet3D", args),
    ) if args.length() == 3 => Some(args[1] * ket_expr)
    (
      Expr::Function("ZOp", _),
      Expr::Function("PositionKet3D", args),
    ) if args.length() == 3 => Some(args[2] * ket_expr)
    _ => None
  }
}

///|
pub fn cartesian_inner_product(
  bra_expr : Expr,
  ket_expr : Expr,
) -> Expr? {
  match (bra_expr, ket_expr) {
    (
      Expr::Function("XBra", bargs),
      Expr::Function("XKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      Some(cartesian_delta(kargs[0], bargs[0]))
    (
      Expr::Function("PxBra", bargs),
      Expr::Function("PxKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      Some(cartesian_delta(kargs[0], bargs[0]))
    (
      Expr::Function("XBra", bargs),
      Expr::Function("PxKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      Some(
        cartesian_plane_wave(
          symbol("I") *
          bargs[0] *
          kargs[0] *
          @symcore.raw_pow(hbar, int(-1)),
        ),
      )
    (
      Expr::Function("PxBra", bargs),
      Expr::Function("XKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      Some(
        cartesian_plane_wave(
          int(-1) *
          symbol("I") *
          kargs[0] *
          bargs[0] *
          @symcore.raw_pow(hbar, int(-1)),
        ),
      )
    (
      Expr::Function("PositionBra3D", bargs),
      Expr::Function("PositionKet3D", kargs),
    ) if bargs.length() == 3 && kargs.length() == 3 =>
      Some(
        cartesian_delta(kargs[0], bargs[0]) *
        cartesian_delta(kargs[1], bargs[1]) *
        cartesian_delta(kargs[2], bargs[2]),
      )
    _ => None
  }
}

///|
fn cartesian_basis_family(basis : Expr?) -> String {
  match basis {
    None => "default"
    Some(expr) =>
      match expr {
        Expr::Function(name, _) if name == "XOp" ||
          name == "XKet" ||
          name == "XBra" => "x"
        Expr::Function(name, _) if name == "PxOp" ||
          name == "PxKet" ||
          name == "PxBra" => "px"
        _ => "default"
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
pub fn cartesian_represent(
  expr : Expr,
  basis? : Expr? = None,
) -> Expr? {
  let basis_name = cartesian_basis_family(basis)
  let coord = cartesian_basis_symbol(basis_name)
  match expr {
    Expr::Function("XKet", args) if args.length() == 1 =>
      Some(
        if basis_name == "px" {
          cartesian_plane_wave(
            int(-1) *
            symbol("I") *
            args[0] *
            coord *
            @symcore.raw_pow(hbar, int(-1)),
          )
        } else {
          cartesian_delta(coord, args[0])
        },
      )
    Expr::Function("XBra", args) if args.length() == 1 =>
      Some(
        if basis_name == "px" {
          cartesian_plane_wave(
            symbol("I") *
            args[0] *
            coord *
            @symcore.raw_pow(hbar, int(-1)),
          )
        } else {
          cartesian_delta(coord, args[0])
        },
      )
    Expr::Function("PxKet", args) if args.length() == 1 =>
      Some(
        if basis_name == "x" {
          cartesian_plane_wave(
            symbol("I") *
            coord *
            args[0] *
            @symcore.raw_pow(hbar, int(-1)),
          )
        } else {
          cartesian_delta(coord, args[0])
        },
      )
    Expr::Function("PxBra", args) if args.length() == 1 =>
      Some(
        if basis_name == "x" {
          cartesian_plane_wave(
            int(-1) *
            symbol("I") *
            coord *
            args[0] *
            @symcore.raw_pow(hbar, int(-1)),
          )
        } else {
          cartesian_delta(coord, args[0])
        },
      )
    Expr::Function("PositionKet3D", args) if args.length() == 3 =>
      Some(
        cartesian_delta(cartesian_symbol("x", idx=1), args[0]) *
        cartesian_delta(cartesian_symbol("y", idx=1), args[1]) *
        cartesian_delta(cartesian_symbol("z", idx=1), args[2]),
      )
    Expr::Function("PositionBra3D", args) if args.length() == 3 =>
      Some(
        cartesian_delta(cartesian_symbol("x", idx=1), args[0]) *
        cartesian_delta(cartesian_symbol("y", idx=1), args[1]) *
        cartesian_delta(cartesian_symbol("z", idx=1), args[2]),
      )
    Expr::Function("XOp", _) =>
      Some(
        if basis_name == "px" {
          let px1 = cartesian_symbol("px", idx=1)
          let px2 = cartesian_symbol("px", idx=2)
          symbol("I") * hbar * cartesian_delta(px1, px2) * px1
        } else {
          coord
        },
      )
    Expr::Function("PxOp", _) =>
      Some(
        if basis_name == "x" || basis_name == "default" {
          let x1 = cartesian_symbol("x", idx=1)
          let x2 = cartesian_symbol("x", idx=2)
          int(-1) *
          symbol("I") *
          hbar *
          cartesian_delta(x1, x2) *
          x1
        } else {
          coord
        },
      )
    _ => None
  }
}

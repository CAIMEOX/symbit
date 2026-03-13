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
fn cartesian_default_label(name : String) -> @symcore.Expr {
  @symcore.symbol(name)
}

///|
fn cartesian_delta(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("DiracDelta", [lhs - rhs])
}

///|
fn cartesian_plane_wave(phase : @symcore.Expr) -> @symcore.Expr {
  let norm = @symcore.raw_function("sqrt", [
    @symcore.int(2) * @symcore.symbol("pi") * hbar,
  ])
  @symcore.raw_function("exp", [phase]) *
  @symcore.raw_pow(norm, @symcore.int(-1))
}

///|
fn cartesian_symbol(base : String, idx? : Int = 0) -> @symcore.Expr {
  if idx <= 0 {
    @symcore.symbol(base)
  } else {
    @symcore.symbol("\{base}_\{idx.to_string()}")
  }
}

///|
pub fn x_op(
  label? : @symcore.Expr = cartesian_default_label("X"),
) -> @symcore.Expr {
  @symcore.raw_function("XOp", [label])
}

///|
pub fn y_op(
  label? : @symcore.Expr = cartesian_default_label("Y"),
) -> @symcore.Expr {
  @symcore.raw_function("YOp", [label])
}

///|
pub fn z_op(
  label? : @symcore.Expr = cartesian_default_label("Z"),
) -> @symcore.Expr {
  @symcore.raw_function("ZOp", [label])
}

///|
pub fn px_op(
  label? : @symcore.Expr = cartesian_default_label("Px"),
) -> @symcore.Expr {
  @symcore.raw_function("PxOp", [label])
}

///|
pub fn x_ket(
  position? : @symcore.Expr = cartesian_default_label("x"),
) -> @symcore.Expr {
  @symcore.raw_function("XKet", [position])
}

///|
pub fn x_bra(
  position? : @symcore.Expr = cartesian_default_label("x"),
) -> @symcore.Expr {
  @symcore.raw_function("XBra", [position])
}

///|
pub fn px_ket(
  momentum? : @symcore.Expr = cartesian_default_label("px"),
) -> @symcore.Expr {
  @symcore.raw_function("PxKet", [momentum])
}

///|
pub fn px_bra(
  momentum? : @symcore.Expr = cartesian_default_label("px"),
) -> @symcore.Expr {
  @symcore.raw_function("PxBra", [momentum])
}

///|
pub fn position_ket_3d(
  x? : @symcore.Expr = cartesian_default_label("x"),
  y? : @symcore.Expr = cartesian_default_label("y"),
  z? : @symcore.Expr = cartesian_default_label("z"),
) -> @symcore.Expr {
  @symcore.raw_function("PositionKet3D", [x, y, z])
}

///|
pub fn position_bra_3d(
  x? : @symcore.Expr = cartesian_default_label("x"),
  y? : @symcore.Expr = cartesian_default_label("y"),
  z? : @symcore.Expr = cartesian_default_label("z"),
) -> @symcore.Expr {
  @symcore.raw_function("PositionBra3D", [x, y, z])
}

///|
fn cartesian_lowercase_label(
  label : @symcore.Expr,
  fallback : String,
) -> @symcore.Expr {
  match label {
    @symcore.Expr::Symbol(name) => @symcore.symbol(name.to_lower())
    _ => @symcore.symbol(fallback)
  }
}

///|
pub fn cartesian_operator_to_state(op_expr : @symcore.Expr) -> @symcore.Expr? {
  match op_expr {
    @symcore.Expr::Function("XOp", args) => {
      let label = if args.is_empty() {
        cartesian_default_label("x")
      } else {
        cartesian_lowercase_label(args[0], "x")
      }
      Some(x_ket(position=label))
    }
    @symcore.Expr::Function("PxOp", args) => {
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
  state_expr : @symcore.Expr,
) -> Array[@symcore.Expr]? {
  match state_expr {
    @symcore.Expr::Function("XKet", args)
    | @symcore.Expr::Function("XBra", args) => {
      ignore(args)
      Some([x_op()])
    }
    @symcore.Expr::Function("PxKet", args)
    | @symcore.Expr::Function("PxBra", args) => {
      ignore(args)
      Some([px_op()])
    }
    @symcore.Expr::Function("PositionKet3D", _)
    | @symcore.Expr::Function("PositionBra3D", _) =>
      Some([x_op(), y_op(), z_op()])
    _ => None
  }
}

///|
pub fn cartesian_apply_operator_to_ket(
  op_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match (op_expr, ket_expr) {
    (@symcore.Expr::Function("XOp", _), @symcore.Expr::Function("XKet", args)) if args.length() ==
      1 => Some(args[0] * ket_expr)
    (@symcore.Expr::Function("PxOp", _), @symcore.Expr::Function("PxKet", args)) if args.length() ==
      1 => Some(args[0] * ket_expr)
    (
      @symcore.Expr::Function("XOp", _),
      @symcore.Expr::Function("PositionKet3D", args),
    ) if args.length() == 3 => Some(args[0] * ket_expr)
    (
      @symcore.Expr::Function("YOp", _),
      @symcore.Expr::Function("PositionKet3D", args),
    ) if args.length() == 3 => Some(args[1] * ket_expr)
    (
      @symcore.Expr::Function("ZOp", _),
      @symcore.Expr::Function("PositionKet3D", args),
    ) if args.length() == 3 => Some(args[2] * ket_expr)
    _ => None
  }
}

///|
pub fn cartesian_inner_product(
  bra_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match (bra_expr, ket_expr) {
    (
      @symcore.Expr::Function("XBra", bargs),
      @symcore.Expr::Function("XKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      Some(cartesian_delta(kargs[0], bargs[0]))
    (
      @symcore.Expr::Function("PxBra", bargs),
      @symcore.Expr::Function("PxKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      Some(cartesian_delta(kargs[0], bargs[0]))
    (
      @symcore.Expr::Function("XBra", bargs),
      @symcore.Expr::Function("PxKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      Some(
        cartesian_plane_wave(
          @symcore.symbol("I") *
          bargs[0] *
          kargs[0] *
          @symcore.raw_pow(hbar, @symcore.int(-1)),
        ),
      )
    (
      @symcore.Expr::Function("PxBra", bargs),
      @symcore.Expr::Function("XKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      Some(
        cartesian_plane_wave(
          @symcore.int(-1) *
          @symcore.symbol("I") *
          kargs[0] *
          bargs[0] *
          @symcore.raw_pow(hbar, @symcore.int(-1)),
        ),
      )
    (
      @symcore.Expr::Function("PositionBra3D", bargs),
      @symcore.Expr::Function("PositionKet3D", kargs),
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
fn cartesian_basis_family(basis : @symcore.Expr?) -> String {
  match basis {
    None => "default"
    Some(expr) =>
      match expr {
        @symcore.Expr::Function(name, _) if name == "XOp" ||
          name == "XKet" ||
          name == "XBra" => "x"
        @symcore.Expr::Function(name, _) if name == "PxOp" ||
          name == "PxKet" ||
          name == "PxBra" => "px"
        _ => "default"
      }
  }
}

///|
fn cartesian_basis_symbol(basis_name : String) -> @symcore.Expr {
  match basis_name {
    "px" => cartesian_symbol("px", idx=1)
    _ => cartesian_symbol("x", idx=1)
  }
}

///|
pub fn cartesian_represent(
  expr : @symcore.Expr,
  basis? : @symcore.Expr? = None,
) -> @symcore.Expr? {
  let basis_name = cartesian_basis_family(basis)
  let coord = cartesian_basis_symbol(basis_name)
  match expr {
    @symcore.Expr::Function("XKet", args) if args.length() == 1 =>
      Some(
        if basis_name == "px" {
          cartesian_plane_wave(
            @symcore.int(-1) *
            @symcore.symbol("I") *
            args[0] *
            coord *
            @symcore.raw_pow(hbar, @symcore.int(-1)),
          )
        } else {
          cartesian_delta(coord, args[0])
        },
      )
    @symcore.Expr::Function("XBra", args) if args.length() == 1 =>
      Some(
        if basis_name == "px" {
          cartesian_plane_wave(
            @symcore.symbol("I") *
            args[0] *
            coord *
            @symcore.raw_pow(hbar, @symcore.int(-1)),
          )
        } else {
          cartesian_delta(coord, args[0])
        },
      )
    @symcore.Expr::Function("PxKet", args) if args.length() == 1 =>
      Some(
        if basis_name == "x" {
          cartesian_plane_wave(
            @symcore.symbol("I") *
            coord *
            args[0] *
            @symcore.raw_pow(hbar, @symcore.int(-1)),
          )
        } else {
          cartesian_delta(coord, args[0])
        },
      )
    @symcore.Expr::Function("PxBra", args) if args.length() == 1 =>
      Some(
        if basis_name == "x" {
          cartesian_plane_wave(
            @symcore.int(-1) *
            @symcore.symbol("I") *
            coord *
            args[0] *
            @symcore.raw_pow(hbar, @symcore.int(-1)),
          )
        } else {
          cartesian_delta(coord, args[0])
        },
      )
    @symcore.Expr::Function("PositionKet3D", args) if args.length() == 3 =>
      Some(
        cartesian_delta(cartesian_symbol("x", idx=1), args[0]) *
        cartesian_delta(cartesian_symbol("y", idx=1), args[1]) *
        cartesian_delta(cartesian_symbol("z", idx=1), args[2]),
      )
    @symcore.Expr::Function("PositionBra3D", args) if args.length() == 3 =>
      Some(
        cartesian_delta(cartesian_symbol("x", idx=1), args[0]) *
        cartesian_delta(cartesian_symbol("y", idx=1), args[1]) *
        cartesian_delta(cartesian_symbol("z", idx=1), args[2]),
      )
    @symcore.Expr::Function("XOp", _) =>
      Some(
        if basis_name == "px" {
          let px1 = cartesian_symbol("px", idx=1)
          let px2 = cartesian_symbol("px", idx=2)
          @symcore.symbol("I") * hbar * cartesian_delta(px1, px2) * px1
        } else {
          coord
        },
      )
    @symcore.Expr::Function("PxOp", _) =>
      Some(
        if basis_name == "x" || basis_name == "default" {
          let x1 = cartesian_symbol("x", idx=1)
          let x2 = cartesian_symbol("x", idx=2)
          @symcore.int(-1) *
          @symcore.symbol("I") *
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

///|
/// Named matrices used in elementary quantum and mechanics formulas.

///|
pub fn msigma(i : Int) -> ExplicitMatrix raise PhysicsError {
  match i {
    1 => explicit_matrix_from_ints([[0, 1], [1, 0]])
    2 =>
      try! explicit_matrix_from_rows([
        [int(0), int(-1) * i_expr()],
        [i_expr(), int(0)],
      ])
    3 => explicit_matrix_from_ints([[1, 0], [0, -1]])
    _ => raise PhysicsError::IndexError("Invalid Pauli index")
  }
}

///|
pub fn pat_matrix(
  m : Expr,
  dx : Expr,
  dy : Expr,
  dz : Expr,
) -> ExplicitMatrix {
  let dxdy = int(-1) * dx * dy
  let dydz = int(-1) * dy * dz
  let dzdx = int(-1) * dz * dx
  let dxdx = dx ^ int(2)
  let dydy = dy ^ int(2)
  let dzdz = dz ^ int(2)
  (try! explicit_matrix_from_rows([
    [dydy + dzdz, dxdy, dzdx],
    [dxdy, dxdx + dzdz, dydz],
    [dzdx, dydz, dydy + dxdx],
  ])).scale(m)
}

///|
pub fn mgamma(
  mu : Int,
  lower? : Bool = false,
) -> ExplicitMatrix raise PhysicsError {
  let base = match mu {
    0 =>
      explicit_matrix_from_ints([
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, -1, 0],
        [0, 0, 0, -1],
      ])
    1 =>
      explicit_matrix_from_ints([
        [0, 0, 0, 1],
        [0, 0, 1, 0],
        [0, -1, 0, 0],
        [-1, 0, 0, 0],
      ])
    2 =>
      try! explicit_matrix_from_rows([
        [
          int(0),
          int(0),
          int(0),
          int(-1) * i_expr(),
        ],
        [int(0), int(0), i_expr(), int(0)],
        [int(0), i_expr(), int(0), int(0)],
        [
          int(-1) * i_expr(),
          int(0),
          int(0),
          int(0),
        ],
      ])
    3 =>
      explicit_matrix_from_ints([
        [0, 0, 1, 0],
        [0, 0, 0, -1],
        [-1, 0, 0, 0],
        [0, 1, 0, 0],
      ])
    5 =>
      explicit_matrix_from_ints([
        [0, 0, 1, 0],
        [0, 0, 0, 1],
        [1, 0, 0, 0],
        [0, 1, 0, 0],
      ])
    _ => raise PhysicsError::IndexError("Invalid Dirac index")
  }
  if lower && (mu == 1 || mu == 2 || mu == 3 || mu == 5) {
    base.neg()
  } else {
    base
  }
}

///|
pub let minkowski_tensor : ExplicitMatrix = explicit_matrix_from_ints([
  [1, 0, 0, 0],
  [0, -1, 0, 0],
  [0, 0, -1, 0],
  [0, 0, 0, -1],
])

///|
pub fn mdft(n : Int) -> ExplicitMatrix raise PhysicsError {
  if n <= 0 {
    raise PhysicsError::ValueError("n must be positive")
  }
  let scale = @symelem.sqrt(int(n)) ^ int(-1)
  let coeff = expr_div(int(-2) * pi_expr() * i_expr(), int(n))
  let rows : Array[Array[Expr]] = Array::new()
  for j in 0..<n {
    let row : Array[Expr] = Array::new()
    for k in 0..<n {
      let exponent = coeff * int(j * k)
      row.push(scale * @symelem.exp(exponent))
    }
    rows.push(row)
  }
  explicit_matrix_from_rows(rows)
}

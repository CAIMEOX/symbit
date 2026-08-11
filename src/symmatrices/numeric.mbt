///|
/// Numeric evaluation helpers for dense and sparse matrices.
///
/// Current Limits:
/// - This layer focuses on numeric coercion and helper arithmetic, not matrix decompositions.
/// - Sparse numeric evaluation currently materializes a dense matrix result.
fn expr_numeric_prec(expr : Expr) -> Int {
  match @symcore.number_symbol_kind(expr) {
    Some(ImaginaryUnit | Pi | Exp1 | EulerGamma | GoldenRatio | Catalan) => 80
    _ =>
      match expr {
        Float(f) => f.precision()
        ComplexFloat(z) => z.precision()
        Number(_) => 80
        Add(args) | Mul(args) => {
          let mut best = 0
          for arg in args {
            let p = expr_numeric_prec(arg)
            if p > best {
              best = p
            }
          }
          best
        }
        Pow(base, exp) => {
          let pb = expr_numeric_prec(base)
          let pe = expr_numeric_prec(exp)
          if pb > pe {
            pb
          } else {
            pe
          }
        }
        _ => {
          let mut best = 0
          for arg in @symcore.args(expr) {
            let p = expr_numeric_prec(arg)
            if p > best {
              best = p
            }
          }
          best
        }
      }
  }
}

///|
fn expr_has_floating_leaf(expr : Expr) -> Bool {
  match expr {
    Float(_) | ComplexFloat(_) => true
    Add(args) | Mul(args) => args.any(expr_has_floating_leaf)
    Pow(base, exp) =>
      expr_has_floating_leaf(base) || expr_has_floating_leaf(exp)
    _ => @symcore.args(expr).any(expr_has_floating_leaf)
  }
}

///|
fn matrix_has_floating_leaf(rows : Array[Array[Expr]]) -> Bool {
  for row in rows {
    for value in row {
      if expr_has_floating_leaf(value) {
        return true
      }
    }
  }
  false
}

///|
fn expr_numeric_precision(rows : Array[Array[Expr]]) -> Int {
  let mut best = 0
  for row in rows {
    for value in row {
      let p = expr_numeric_prec(value)
      if p > best {
        best = p
      }
    }
  }
  if best > 0 {
    best
  } else {
    80
  }
}

///|
fn expr_to_numeric_complex(expr : Expr, prec : Int) -> @symcore.ComplexFloat? {
  match @symcore.evalf(expr_simplify(expr), prec~) {
    Number(n) =>
      Some(
        @symcore.ComplexFloat::from_exact_parts(
          n,
          @symnum.BigRational::zero(),
          prec~,
        ),
      )
    Float(f) => Some(@symcore.ComplexFloat::from_real(f))
    ComplexFloat(z) => Some(z)
    _ => None
  }
}

///|
fn expr_from_numeric_complex(value : @symcore.ComplexFloat) -> Expr {
  if @symnum.is_zero(value.to_mpc().imag) {
    Float(value.real_part())
  } else {
    ComplexFloat(value)
  }
}

///|
fn expr_numeric_abs(expr : Expr, prec : Int) -> @symnum.Mpf? {
  expr_to_numeric_complex(expr, prec).map(z => {
    @symnum.mpc_abs(z.to_mpc(), prec, @symnum.round_nearest)
  })
}

///|
fn expr_numeric_zero(expr : Expr, prec : Int) -> Bool {
  match expr_numeric_abs(expr, prec) {
    Some(value) => {
      let tol_exp = if prec / 2 > 4 { -(prec / 2) } else { -4 }
      let tol = @symnum.from_man_exp(
        1N,
        tol_exp,
        prec~,
        rnd=@symnum.round_nearest,
      )
      @symnum.mpf_cmp(value, tol) <= 0
    }
    None => false
  }
}

///|
fn expr_numeric_sub(lhs : Expr, rhs : Expr, prec : Int) -> Expr {
  match
    (expr_to_numeric_complex(lhs, prec), expr_to_numeric_complex(rhs, prec)) {
    (Some(l), Some(r)) => expr_from_numeric_complex(l + -r)
    _ =>
      @symcore.evalf(
        @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])]),
        prec~,
      )
  }
}

///|
fn expr_numeric_mul(lhs : Expr, rhs : Expr, prec : Int) -> Expr {
  match
    (expr_to_numeric_complex(lhs, prec), expr_to_numeric_complex(rhs, prec)) {
    (Some(l), Some(r)) => expr_from_numeric_complex(l * r)
    _ => @symcore.evalf(@symcore.mul([lhs, rhs]), prec~)
  }
}

///|
fn expr_numeric_div(lhs : Expr, rhs : Expr, prec : Int) -> Expr {
  match
    (expr_to_numeric_complex(lhs, prec), expr_to_numeric_complex(rhs, prec)) {
    (Some(l), Some(r)) if !expr_numeric_zero(expr_from_numeric_complex(r), prec) =>
      expr_from_numeric_complex(l * r.reciprocal())
    _ =>
      @symcore.evalf(
        @symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))]),
        prec~,
      )
  }
}

///|
fn expr_numeric_sqrt(expr : Expr, prec : Int) -> Expr {
  match expr_to_numeric_complex(expr, prec) {
    Some(value) =>
      expr_from_numeric_complex(
        @symcore.ComplexFloat::from_mpc(
          @symnum.mpc_sqrt(value.to_mpc(), prec, @symnum.round_nearest),
          prec~,
        ),
      )
    None => @symcore.evalf(@symcore.function("sqrt", [expr]), prec~)
  }
}

///|
fn matrix_all_numeric(rows : Array[Array[Expr]], prec : Int) -> Bool {
  for row in rows {
    for value in row {
      if expr_to_numeric_complex(value, prec) is None {
        return false
      }
    }
  }
  true
}

///|
/// Numerically evaluate every entry of a dense matrix.
///
/// - Does: Calls `@symcore.evalf` on each entry with the requested precision.
/// - Input: A dense `Matrix` and optional binary precision `prec`.
/// - Returns: A dense `Matrix` whose entries are numeric expressions when evaluation succeeds.
/// - Limits: Non-numeric subexpressions can remain symbolic if `evalf` cannot reduce them further.
pub fn Matrix::evalf(self : Matrix, prec? : Int = 53) -> Matrix {
  let out : Array[Array[Expr]] = []
  for row in self.data {
    let converted : Array[Expr] = []
    for value in row {
      converted.push(@symcore.evalf(value, prec~))
    }
    out.push(converted)
  }
  { rows: self.rows, cols: self.cols, data: out }
}

///|
/// Numerically evaluate every entry of a sparse matrix.
///
/// - Does: Converts the sparse matrix to dense form and then applies dense `evalf`.
/// - Input: A `SparseMatrix` and optional binary precision `prec`.
/// - Returns: A dense `Matrix`.
/// - Limits: The return type is dense, so sparsity is not preserved.
pub fn SparseMatrix::evalf(self : SparseMatrix, prec? : Int = 53) -> Matrix {
  self.to_dense().evalf(prec~)
}

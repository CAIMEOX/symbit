///|
fn expr_numeric_prec(expr : Expr) -> Int {
  match expr {
    Expr::Float(f) => f.precision()
    Expr::ComplexFloat(z) => z.precision()
    Expr::Number(_) | Expr::Symbol("I") | Expr::Symbol("pi") | Expr::Symbol("Pi")
    | Expr::Symbol("E") | Expr::Symbol("EulerGamma") | Expr::Symbol("GoldenRatio")
    | Expr::Symbol("Catalan") => 80
    Expr::Add(args) | Expr::Mul(args) | Expr::Function(_, args) => {
      let mut best = 0
      for arg in args {
        let p = expr_numeric_prec(arg)
        if p > best {
          best = p
        }
      }
      best
    }
    Expr::Pow(base, exp) => {
      let pb = expr_numeric_prec(base)
      let pe = expr_numeric_prec(exp)
      if pb > pe { pb } else { pe }
    }
    _ => 0
  }
}

///|
fn expr_has_floating_leaf(expr : Expr) -> Bool {
  match expr {
    Expr::Float(_) | Expr::ComplexFloat(_) => true
    Expr::Add(args) | Expr::Mul(args) | Expr::Function(_, args) =>
      args.any(expr_has_floating_leaf)
    Expr::Pow(base, exp) =>
      expr_has_floating_leaf(base) || expr_has_floating_leaf(exp)
    _ => false
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
  if best > 0 { best } else { 80 }
}

///|
fn expr_to_numeric_complex(
  expr : Expr,
  prec : Int,
) -> @symcore.ComplexFloat? {
  match @symcore.evalf(expr_simplify(expr), prec=prec) {
    Expr::Number(n) =>
      Some(
        @symcore.ComplexFloat::from_exact_parts(
          n,
          @symnum.BigRational::zero(),
          prec=prec,
        ),
      )
    Expr::Float(f) => Some(@symcore.ComplexFloat::from_real(f))
    Expr::ComplexFloat(z) => Some(z)
    _ => None
  }
}

///|
fn expr_from_numeric_complex(value : @symcore.ComplexFloat) -> Expr {
  if @symnum.is_zero(value.to_mpc().imag) {
    @symcore.float(value.real_part())
  } else {
    @symcore.complex_float(value)
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
        prec=prec,
        rnd=@symnum.round_nearest,
      )
      @symnum.mpf_cmp(value, tol) <= 0
    }
    None => false
  }
}

///|
fn expr_numeric_add(lhs : Expr, rhs : Expr, prec : Int) -> Expr {
  match (expr_to_numeric_complex(lhs, prec), expr_to_numeric_complex(rhs, prec)) {
    (Some(l), Some(r)) => expr_from_numeric_complex(l + r)
    _ => @symcore.evalf(@symcore.add([lhs, rhs]), prec=prec)
  }
}

///|
fn expr_numeric_sub(lhs : Expr, rhs : Expr, prec : Int) -> Expr {
  match (expr_to_numeric_complex(lhs, prec), expr_to_numeric_complex(rhs, prec)) {
    (Some(l), Some(r)) => expr_from_numeric_complex(l + -r)
    _ =>
      @symcore.evalf(
        @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])]),
        prec=prec,
      )
  }
}

///|
fn expr_numeric_mul(lhs : Expr, rhs : Expr, prec : Int) -> Expr {
  match (expr_to_numeric_complex(lhs, prec), expr_to_numeric_complex(rhs, prec)) {
    (Some(l), Some(r)) => expr_from_numeric_complex(l * r)
    _ => @symcore.evalf(@symcore.mul([lhs, rhs]), prec=prec)
  }
}

///|
fn expr_numeric_div(lhs : Expr, rhs : Expr, prec : Int) -> Expr {
  match (expr_to_numeric_complex(lhs, prec), expr_to_numeric_complex(rhs, prec)) {
    (Some(l), Some(r)) if !expr_numeric_zero(expr_from_numeric_complex(r), prec) =>
      expr_from_numeric_complex(l * r.reciprocal())
    _ =>
      @symcore.evalf(
        @symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))]),
        prec=prec,
      )
  }
}

///|
fn expr_numeric_sqrt(expr : Expr, prec : Int) -> Expr {
  match expr_to_numeric_complex(expr, prec) {
    Some(value) =>
      expr_from_numeric_complex(
        @symcore.ComplexFloat::from_mpc(
          @symnum.mpc_sqrt(
            value.to_mpc(),
            prec,
            @symnum.round_nearest,
          ),
          prec=prec,
        ),
      )
    None => @symcore.evalf(@symcore.function("sqrt", [expr]), prec=prec)
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
pub fn Matrix::evalf(self : Matrix, prec? : Int = 53) -> Matrix {
  let out : Array[Array[Expr]] = []
  for row in self.data {
    let converted : Array[Expr] = []
    for value in row {
      converted.push(@symcore.evalf(value, prec=prec))
    }
    out.push(converted)
  }
  { rows: self.rows, cols: self.cols, data: out }
}

///|
pub fn SparseMatrix::evalf(self : SparseMatrix, prec? : Int = 53) -> Matrix {
  self.to_dense().evalf(prec~)
}

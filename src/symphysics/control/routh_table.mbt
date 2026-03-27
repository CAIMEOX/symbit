///|
/// Routh-Hurwitz table construction for univariate polynomials.

///|
pub struct RouthHurwitz {
  table : @symphysics.ExplicitMatrix
  variable : String
  polynomial : @symcore.Expr
  zero_row_case : Bool
  zero_col_infos : Array[(Int, Int)]
  auxiliary_polynomials : Array[@symcore.Expr]
} derive(Eq)

///|
fn bigint_pow(base : BigInt, exp : Int) -> BigInt {
  let mut out = BigInt::from_int(1)
  for _ in 0..<exp {
    out = out * base
  }
  out
}

///|
fn rational_pow(value : @symnum.BigRational, exp : Int) -> @symnum.BigRational? {
  if exp >= 0 {
    try
      @symnum.BigRational::new(
        bigint_pow(value.numerator(), exp),
        bigint_pow(value.denominator(), exp),
      )
    catch {
      _ => None
    } noraise {
      result => Some(result)
    }
  } else {
    try
      @symnum.BigRational::new(
        bigint_pow(value.denominator(), -exp),
        bigint_pow(value.numerator(), -exp),
      )
    catch {
      _ => None
    } noraise {
      result => Some(result)
    }
  }
}

///|
fn control_normalize(expr : @symcore.Expr) -> @symcore.Expr {
  match @symcore.application_parts(expr) {
    Some((head, args)) => {
      let normalized_args = args.map(control_normalize)
      let folded = match @symcore.raw_apply(head, normalized_args) {
        Some(applied) => applied
        None => expr
      }
      return @symsimplify.ratsimp(
        @symsimplify.simplify(folded, max_passes=4),
        max_passes=4,
      )
    }
    None => ()
  }
  let folded = match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_)
    | @symcore.ExprForm::Float(_)
    | @symcore.ExprForm::ComplexFloat(_)
    | @symcore.ExprForm::NumberSymbol(_)
    | @symcore.ExprForm::Symbol(_)
    | @symcore.ExprForm::Dummy(_, _)
    | @symcore.ExprForm::Wild(_)
    | @symcore.ExprForm::FunctionHead(_)
    | @symcore.ExprForm::UndefinedFunction(_)
    | @symcore.ExprForm::Boolean(_) => expr
    @symcore.ExprForm::Add(args) => @symcore.add(args.map(control_normalize))
    @symcore.ExprForm::Mul(args) => @symcore.mul(args.map(control_normalize))
    @symcore.ExprForm::Pow(base, exp_expr) => {
      let base_norm = control_normalize(base)
      let exp_norm = control_normalize(exp_expr)
      match (base_norm, exp_norm) {
        (@symcore.Expr::Number(base_value), @symcore.Expr::Number(exp_value)) if exp_value.is_integral() =>
          match rational_pow(base_value, exp_value.numerator().to_int()) {
            Some(value) => @symcore.Expr::Number(value)
            None => @symcore.pow(base_norm, exp_norm)
          }
        _ => @symcore.pow(base_norm, exp_norm)
      }
    }
    @symcore.ExprForm::Mod(lhs, rhs) =>
      @symcore.mod_expr(control_normalize(lhs), control_normalize(rhs))
    @symcore.ExprForm::Tuple(args) =>
      @symcore.Expr::Tuple(args.map(control_normalize))
    @symcore.ExprForm::Dict(items) => {
      let out : Array[(@symcore.Expr, @symcore.Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((control_normalize(key), control_normalize(value)))
      }
      @symcore.Expr::Dict(out)
    }
    @symcore.ExprForm::Relational(op, lhs, rhs) =>
      match op {
        @symcore.RelOp::Eq =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            control_normalize(lhs),
            control_normalize(rhs),
          )
        @symcore.RelOp::Ne =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Ne,
            control_normalize(lhs),
            control_normalize(rhs),
          )
        @symcore.RelOp::Lt =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Lt,
            control_normalize(lhs),
            control_normalize(rhs),
          )
        @symcore.RelOp::Le =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Le,
            control_normalize(lhs),
            control_normalize(rhs),
          )
        @symcore.RelOp::Gt =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Gt,
            control_normalize(lhs),
            control_normalize(rhs),
          )
        @symcore.RelOp::Ge =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Ge,
            control_normalize(lhs),
            control_normalize(rhs),
          )
      }
    @symcore.ExprForm::Derivative(inner, deriv_args) => {
      let args : Array[@symcore.Expr] = [control_normalize(inner)]
      for arg in deriv_args {
        args.push(control_normalize(arg))
      }
      @symcore.raw_derivative(args[0], args[1:])
    }
    @symcore.ExprForm::Subs(inner, variable, value) =>
      @symcore.subs_expr(
        control_normalize(inner),
        control_normalize(variable),
        control_normalize(value),
      )
    @symcore.ExprForm::Lambda(vars, body) =>
      @symcore.lambda_expr(control_normalize(vars), control_normalize(body))
    _ => expr
  }
  @symsimplify.ratsimp(
    @symsimplify.simplify(folded, max_passes=4),
    max_passes=4,
  )
}

///|
fn expr_depends_on(expr : @symcore.Expr, variable : String) -> Bool {
  match @symcore.application_args(expr) {
    Some(call_args) => return call_args.any(arg => expr_depends_on(arg, variable))
    None => ()
  }
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Symbol(name) => name == variable
    @symcore.ExprForm::Add(args)
    | @symcore.ExprForm::Mul(args)
    | @symcore.ExprForm::Tuple(args) =>
      args.any(arg => expr_depends_on(arg, variable))
    @symcore.ExprForm::Pow(base, exp) =>
      expr_depends_on(base, variable) || expr_depends_on(exp, variable)
    @symcore.ExprForm::Relational(_, lhs, rhs) =>
      expr_depends_on(lhs, variable) || expr_depends_on(rhs, variable)
    @symcore.ExprForm::Derivative(inner, deriv_args) =>
      if expr_depends_on(inner, variable) {
        true
      } else {
        deriv_args.any(arg => expr_depends_on(arg, variable))
      }
    @symcore.ExprForm::Subs(inner, sub_var, value) =>
      expr_depends_on(inner, variable) ||
      expr_depends_on(sub_var, variable) ||
      expr_depends_on(value, variable)
    @symcore.ExprForm::Lambda(vars, body) =>
      expr_depends_on(vars, variable) || expr_depends_on(body, variable)
    _ => false
  }
}

///|
fn poly_zero() -> Map[Int, @symcore.Expr] {
  {}
}

///|
fn poly_const(expr : @symcore.Expr) -> Map[Int, @symcore.Expr] {
  { 0: expr }
}

///|
fn poly_var() -> Map[Int, @symcore.Expr] {
  { 1: @symcore.int(1) }
}

///|
fn add_coeff(
  coeffs : Map[Int, @symcore.Expr],
  degree : Int,
  coeff : @symcore.Expr,
) -> Unit {
  let next = match coeffs.get(degree) {
    Some(prev) => prev + coeff
    None => coeff
  }
  if next == @symcore.int(0) {
    ignore(coeffs.remove(degree))
  } else {
    coeffs.set(degree, next)
  }
}

///|
fn poly_add(
  lhs : Map[Int, @symcore.Expr],
  rhs : Map[Int, @symcore.Expr],
) -> Map[Int, @symcore.Expr] {
  let out = lhs.copy()
  for degree, coeff in rhs {
    add_coeff(out, degree, coeff)
  }
  out
}

///|
fn poly_mul(
  lhs : Map[Int, @symcore.Expr],
  rhs : Map[Int, @symcore.Expr],
) -> Map[Int, @symcore.Expr] {
  let out = poly_zero()
  for deg_lhs, coeff_lhs in lhs {
    for deg_rhs, coeff_rhs in rhs {
      add_coeff(out, deg_lhs + deg_rhs, coeff_lhs * coeff_rhs)
    }
  }
  out
}

///|
fn poly_pow(
  base : Map[Int, @symcore.Expr],
  exp : Int,
) -> Map[Int, @symcore.Expr] {
  let mut out = poly_const(@symcore.int(1))
  for _ in 0..<exp {
    out = poly_mul(out, base)
  }
  out
}

///|
fn poly_from_expr(
  expr : @symcore.Expr,
  variable : String,
) -> Map[Int, @symcore.Expr] raise @symphysics.PhysicsError {
  match expr {
    @symcore.Expr::Number(_) => poly_const(expr)
    @symcore.Expr::Symbol(name) =>
      if name == variable {
        poly_var()
      } else {
        poly_const(expr)
      }
    @symcore.Expr::Add(args) => {
      let mut out = poly_zero()
      for arg in args {
        out = poly_add(out, poly_from_expr(arg, variable))
      }
      out
    }
    @symcore.Expr::Mul(args) => {
      let mut out = poly_const(@symcore.int(1))
      for arg in args {
        out = poly_mul(out, poly_from_expr(arg, variable))
      }
      out
    }
    @symcore.Expr::Pow(base, exp_expr) => {
      let exp = match exp_expr {
        @symcore.Expr::Number(n) if n.is_integral() => n.numerator().to_int()
        _ =>
          raise @symphysics.PhysicsError::ValueError(
            "RouthHurwitz expects a polynomial with nonnegative integer exponents",
          )
      }
      guard exp >= 0 else {
        raise @symphysics.PhysicsError::ValueError(
          "RouthHurwitz expects a polynomial with nonnegative integer exponents",
        )
      }
      poly_pow(poly_from_expr(base, variable), exp)
    }
    _ =>
      if !expr_depends_on(expr, variable) {
        poly_const(expr)
      } else {
        raise @symphysics.PhysicsError::ValueError(
          "RouthHurwitz expects a univariate polynomial",
        )
      }
  }
}

///|
fn coeff_array(
  polynomial : Map[Int, @symcore.Expr],
) -> (Int, Array[@symcore.Expr]) {
  let mut degree = 0
  for deg, coeff in polynomial {
    if coeff != @symcore.int(0) && deg > degree {
      degree = deg
    }
  }
  let coeffs : Array[@symcore.Expr] = Array::new()
  let mut exp = degree
  while exp >= 0 {
    match polynomial.get(exp) {
      Some(coeff) => coeffs.push(control_normalize(coeff))
      None => coeffs.push(@symcore.int(0))
    }
    exp -= 1
  }
  (degree, coeffs)
}

///|
fn table_entry(
  rows : Array[Array[@symcore.Expr]],
  row : Int,
  col : Int,
) -> @symcore.Expr {
  if row < 0 || row >= rows.length() || col < 0 || col >= rows[row].length() {
    @symcore.int(0)
  } else {
    rows[row][col]
  }
}

///|
fn row_is_zero(
  rows : Array[Array[@symcore.Expr]],
  row : Int,
  active_len : Int,
) -> Bool {
  for col in 0..<active_len {
    if table_entry(rows, row, col) != @symcore.int(0) {
      return false
    }
  }
  true
}

///|
fn count_consecutive_zeros(
  rows : Array[Array[@symcore.Expr]],
  row : Int,
) -> Int {
  let mut count = 0
  for col in 0..<rows[row].length() {
    if rows[row][col] != @symcore.int(0) {
      break
    }
    count += 1
  }
  count
}

///|
fn build_auxiliary_polynomial(
  rows : Array[Array[@symcore.Expr]],
  poly_degree : Int,
  aux_poly_degree : Int,
  variable : String,
) -> @symcore.Expr {
  let aux_row = poly_degree - aux_poly_degree
  let variable_expr = @symcore.Expr::Symbol(variable)
  let terms : Array[@symcore.Expr] = Array::new()
  let mut exp = aux_poly_degree
  let mut col = 0
  while exp >= 0 {
    let coeff = table_entry(rows, aux_row, col)
    terms.push(control_normalize(coeff * (variable_expr ^ @symcore.int(exp))))
    exp -= 2
    col += 1
  }
  if terms.is_empty() {
    @symcore.int(0)
  } else if terms.length() == 1 {
    terms[0]
  } else {
    control_normalize(@symcore.add(terms))
  }
}

///|
pub fn routh_hurwitz(
  polynomial : @symcore.Expr,
  variable_expr : @symcore.Expr,
) -> RouthHurwitz raise @symphysics.PhysicsError {
  let variable = match variable_expr {
    @symcore.Expr::Symbol(name) => name
    _ => raise @symphysics.PhysicsError::ValueError("var must be a Symbol")
  }
  let poly = poly_from_expr(polynomial, variable)
  let (degree, coeffs) = coeff_array(poly)
  let cols = degree / 2 + 1
  let rows : Array[Array[@symcore.Expr]] = Array::new()
  for _ in 0..<=degree {
    rows.push(Array::make(cols, @symcore.int(0)))
  }
  let zero_col_infos : Array[(Int, Int)] = Array::new()
  let aux_poly_degrees : Array[Int] = Array::new()
  let mut zero_row_case = false

  if degree < 1 {
    rows[0][0] = coeffs[0]
  } else {
    let mut row = 0
    let mut col = 0
    for coeff in coeffs {
      rows[row][col] = control_normalize(coeff)
      row = (row + 1) % 2
      col = col + 1 - row
    }

    if rows[1][0] == @symcore.int(0) {
      let active_len = cols
      if row_is_zero(rows, 1, active_len) {
        zero_row_case = true
        let aux_degree = degree
        aux_poly_degrees.push(aux_degree)
        for j in 0..<cols {
          let coeff_degree = aux_degree - 2 * j
          if coeff_degree >= 0 {
            rows[1][j] = control_normalize(
              rows[0][j] * @symcore.int(coeff_degree),
            )
          }
        }
      } else {
        let n_zeros = count_consecutive_zeros(rows, 1)
        zero_col_infos.push((1, n_zeros))
        for k in 0..<(active_len - n_zeros) {
          let sign = if n_zeros % 2 == 0 {
            @symcore.int(1)
          } else {
            @symcore.int(-1)
          }
          rows[1][k] = control_normalize(
            rows[1][k] + sign * rows[1][n_zeros + k],
          )
        }
      }
    }

    for i in 2..<=degree {
      let active_len = cols - i / 2
      for j in 0..<active_len {
        let num = table_entry(rows, i - 1, 0) * table_entry(rows, i - 2, j + 1) -
          table_entry(rows, i - 2, 0) * table_entry(rows, i - 1, j + 1)
        let den = table_entry(rows, i - 1, 0)
        rows[i][j] = control_normalize(num * (den ^ @symcore.int(-1)))
      }

      if row_is_zero(rows, i, active_len) {
        zero_row_case = true
        let aux_degree = degree - i + 1
        aux_poly_degrees.push(aux_degree)
        for j in 0..<cols {
          let coeff_degree = aux_degree - 2 * j
          if coeff_degree >= 0 {
            rows[i][j] = control_normalize(
              rows[i - 1][j] * @symcore.int(coeff_degree),
            )
          }
        }
        continue
      }

      if rows[i][0] == @symcore.int(0) {
        let n_zeros = count_consecutive_zeros(rows, i)
        zero_col_infos.push((i, n_zeros))
        for k in 0..<(active_len - n_zeros) {
          let sign = if n_zeros % 2 == 0 {
            @symcore.int(1)
          } else {
            @symcore.int(-1)
          }
          rows[i][k] = control_normalize(
            rows[i][k] + sign * rows[i][n_zeros + k],
          )
        }
      }
    }
  }

  let auxiliary_polynomials : Array[@symcore.Expr] = Array::new()
  for aux_degree in aux_poly_degrees {
    auxiliary_polynomials.push(
      build_auxiliary_polynomial(rows, degree, aux_degree, variable),
    )
  }

  RouthHurwitz::{
    table: @symphysics.explicit_matrix_from_rows(rows),
    variable,
    polynomial,
    zero_row_case,
    zero_col_infos,
    auxiliary_polynomials,
  }
}

///|
pub fn RouthHurwitz::matrix(self : RouthHurwitz) -> @symphysics.ExplicitMatrix {
  self.table
}

///|
pub fn RouthHurwitz::zero_row_case(self : RouthHurwitz) -> Bool {
  self.zero_row_case
}

///|
pub fn RouthHurwitz::zero_col_infos(self : RouthHurwitz) -> Array[(Int, Int)] {
  self.zero_col_infos
}

///|
pub fn RouthHurwitz::auxiliary_polynomials(
  self : RouthHurwitz,
) -> Array[@symcore.Expr] {
  self.auxiliary_polynomials
}

///|
pub fn RouthHurwitz::rows(self : RouthHurwitz) -> Int {
  self.table.height()
}

///|
pub fn RouthHurwitz::cols(self : RouthHurwitz) -> Int {
  self.table.width()
}

///|
pub fn RouthHurwitz::get(
  self : RouthHurwitz,
  row : Int,
  col : Int,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  self.table.get(row, col)
}

///|
pub fn RouthHurwitz::first_column(
  self : RouthHurwitz,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let rows : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<self.rows() {
    rows.push([self.get(i, 0)])
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

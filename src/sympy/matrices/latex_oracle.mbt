///|
using @symcore {type Expr}

///|
using @symmatrices {type Matrix, type SparseMatrix}

///|
fn py_expr(expr : Expr) -> String {
  @symprint.pretty_string(expr)
}

///|
fn py_matrix_text(m : Matrix) -> String {
  let rows : Array[String] = []
  for row in m.to_list() {
    rows.push("[" + row.map(py_expr).join(", ") + "]")
  }
  "sympy.Matrix([" + rows.join(", ") + "])"
}

///|
fn py_matrix_expr_text(expr : @symmatrices.MatrixExpr) -> String {
  match expr {
    Concrete(m) => py_matrix_text(m)
    Symbol(name, rows, cols) =>
      "sympy.MatrixSymbol('" +
      name +
      "', " +
      rows.to_string() +
      ", " +
      cols.to_string() +
      ")"
    Identity(n) => "sympy.Identity(" + n.to_string() + ")"
    Zero(rows, cols) =>
      "sympy.ZeroMatrix(" + rows.to_string() + ", " + cols.to_string() + ")"
    Add(items) => "(" + items.map(py_matrix_expr_text).join(" + ") + ")"
    Mul(items) => "(" + items.map(py_matrix_expr_text).join(" * ") + ")"
    BlockDiag(items) =>
      "sympy.BlockDiagMatrix(" + items.map(py_matrix_expr_text).join(", ") + ")"
    Block(rows) =>
      "sympy.BlockMatrix([" +
      rows
      .map(row => "[" + row.map(py_matrix_expr_text).join(", ") + "]")
      .join(", ") +
      "])"
    Transpose(inner) => "sympy.Transpose(" + py_matrix_expr_text(inner) + ")"
    Inverse(inner) => "sympy.Inverse(" + py_matrix_expr_text(inner) + ")"
    Pow(inner, exp) =>
      "sympy.MatPow(" +
      py_matrix_expr_text(inner) +
      ", " +
      exp.to_string() +
      ")"
  }
}

///|
pub fn matrix_latex(m : Matrix) -> String raise {
  @sympy_utilities.utilities_eval_str("sympy.latex(" + py_matrix_text(m) + ")")
}

///|
pub fn sparse_matrix_latex(m : SparseMatrix) -> String raise {
  matrix_latex(m.to_dense())
}

///|
pub fn matrix_expr_latex(expr : @symmatrices.MatrixExpr) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "sympy.latex(" + py_matrix_expr_text(expr) + ")",
  )
}

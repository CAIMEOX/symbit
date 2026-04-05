///|
fn latex_parens(s : String) -> String {
  "\\left(\{s}\\right)"
}

///|
fn latex_matrix_contents(rows : Array[Array[String]]) -> String {
  let lines = rows.map(row => row.join(" & "))
  let body = lines.join("\\\\")
  "\\begin{matrix}\{body}\\end{matrix}"
}

///|
fn latex_wrap_matrix(rows : Array[Array[String]]) -> String {
  "\\left[\{latex_matrix_contents(rows)}\\right]"
}

///|
fn latex_expr_cell(
  expr : @symcore.Expr,
  settings : @symprint.LatexSettings,
) -> String {
  @symprint.latex_with_settings(expr, settings)
}

///|
pub fn Matrix::latex(
  self : Matrix,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  let rows = self.data.map(row => {
    row.map(expr => latex_expr_cell(expr, settings))
  })
  latex_wrap_matrix(rows)
}

///|
pub fn SparseMatrix::latex(
  self : SparseMatrix,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  self.to_dense().latex(settings~)
}

///|
fn matrix_expr_prec(expr : MatrixExpr) -> Int {
  match expr {
    MatrixExpr::Add(_) => 1
    MatrixExpr::Mul(_) => 2
    _ => 3
  }
}

///|
fn matrix_expr_needs_parens(expr : MatrixExpr) -> Bool {
  match expr {
    MatrixExpr::Add(_) | MatrixExpr::Mul(_) => true
    _ => false
  }
}

///|
fn matrix_symbol_latex(
  name : String,
  settings : @symprint.LatexSettings,
) -> String {
  @symprint.latex_with_settings(@symcore.Expr::Symbol(name), settings)
}

///|
fn latex_matrix_expr_block_diag(
  items : Array[MatrixExpr],
  settings : @symprint.LatexSettings,
) -> String {
  let rows : Array[Array[String]] = []
  for i in 0..<items.length() {
    let row : Array[String] = []
    for j in 0..<items.length() {
      row.push(if i == j { items[i].latex(settings~) } else { "0" })
    }
    rows.push(row)
  }
  latex_wrap_matrix(rows)
}

///|
fn latex_matrix_expr_block(
  rows : Array[Array[MatrixExpr]],
  settings : @symprint.LatexSettings,
) -> String {
  let rendered = rows.map(row => row.map(item => item.latex(settings~)))
  latex_wrap_matrix(rendered)
}

///|
fn latex_matrix_expr_format(
  expr : MatrixExpr,
  parent_prec : Int,
  settings : @symprint.LatexSettings,
) -> String {
  let prec = matrix_expr_prec(expr)
  let body = match expr {
    MatrixExpr::Concrete(m) => m.latex(settings~)
    MatrixExpr::Symbol(name, _, _) => matrix_symbol_latex(name, settings)
    MatrixExpr::Identity(_) => "\\mathbb{I}"
    MatrixExpr::Zero(_, _) => "0"
    MatrixExpr::Add(items) =>
      items
      .map(item => latex_matrix_expr_format(item, prec, settings))
      .join(" + ")
    MatrixExpr::Mul(items) => {
      let rendered : Array[String] = []
      for item in items {
        let tex = latex_matrix_expr_format(item, prec, settings)
        rendered.push(
          if matrix_expr_needs_parens(item) {
            latex_parens(tex)
          } else {
            tex
          },
        )
      }
      rendered.join(" ")
    }
    MatrixExpr::BlockDiag(items) =>
      latex_matrix_expr_block_diag(items, settings)
    MatrixExpr::Block(rows) => latex_matrix_expr_block(rows, settings)
    MatrixExpr::Transpose(inner) => {
      let inner_tex = inner.latex(settings~)
      match inner {
        MatrixExpr::Symbol(_, _, _) => "\{inner_tex}^{T}"
        _ => "\\left(\{inner_tex}\\right)^{T}"
      }
    }
    MatrixExpr::Inverse(inner) => {
      let inner_tex = inner.latex(settings~)
      match inner {
        MatrixExpr::Symbol(_, _, _) => "\{inner_tex}^{-1}"
        _ => "\\left(\{inner_tex}\\right)^{-1}"
      }
    }
    MatrixExpr::Pow(inner, exp) => {
      let inner_tex = inner.latex(settings~)
      match inner {
        MatrixExpr::Symbol(_, _, _) => "\{inner_tex}^{\{exp.to_string()}}"
        _ => "\\left(\{inner_tex}\\right)^{\{exp.to_string()}}"
      }
    }
  }
  if prec < parent_prec {
    latex_parens(body)
  } else {
    body
  }
}

///|
pub fn MatrixExpr::latex(
  self : MatrixExpr,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  latex_matrix_expr_format(self, 0, settings)
}

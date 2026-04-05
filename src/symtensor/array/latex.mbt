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
fn array_expr_part(
  expr : @symcore.Expr,
  settings : @symprint.LatexSettings,
) -> String {
  @symprint.latex_with_settings(expr, settings)
}

///|
fn dense_array_latex_at(
  data : Array[@symcore.Expr],
  shape : Array[Int],
  strides : Array[Int],
  dim : Int,
  offset : Int,
  settings : @symprint.LatexSettings,
) -> String {
  if shape.is_empty() {
    return if data.is_empty() { "" } else { array_expr_part(data[0], settings) }
  }
  let remaining = shape.length() - dim
  if remaining == 1 {
    let row : Array[String] = []
    for i in 0..<shape[dim] {
      row.push(array_expr_part(data[offset + i], settings))
    }
    return latex_wrap_matrix([row])
  }
  if remaining == 2 {
    let rows : Array[Array[String]] = []
    let row_stride = strides[dim]
    let col_stride = strides[dim + 1]
    for i in 0..<shape[dim] {
      let row : Array[String] = []
      for j in 0..<shape[dim + 1] {
        row.push(array_expr_part(data[offset + i * row_stride + j * col_stride], settings))
      }
      rows.push(row)
    }
    return latex_wrap_matrix(rows)
  }
  let row : Array[String] = []
  let stride = strides[dim]
  for i in 0..<shape[dim] {
    row.push(dense_array_latex_at(data, shape, strides, dim + 1, offset + i * stride, settings))
  }
  latex_wrap_matrix([row])
}

///|
pub fn NDimArray::latex(
  self : NDimArray,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  let dense = dense_data(self)
  if dense.shape.is_empty() {
    return if dense.data.is_empty() { "" } else { array_expr_part(dense.data[0], settings) }
  }
  let strides = compute_strides(dense.shape)
  dense_array_latex_at(dense.data, dense.shape, strides, 0, 0, settings)
}

///|
fn axis_pair_latex(pair : (Int, Int), settings : @symprint.LatexSettings) -> String {
  @symprint.latex_with_settings(
    @symcore.Expr::Tuple([@symcore.int(pair.0), @symcore.int(pair.1)]),
    settings,
  )
}

///|
fn array_expr_prec(expr : ArrayExpr) -> Int {
  match expr {
    ArrayExpr::Add(_) => 1
    ArrayExpr::Mul(_) => 2
    _ => 3
  }
}

///|
fn array_expr_atomish(
  expr : ArrayExpr,
  settings : @symprint.LatexSettings,
) -> String {
  match expr {
    ArrayExpr::Symbol(name, _) =>
      @symprint.latex_with_settings(@symcore.Expr::Symbol(name), settings)
    ArrayExpr::Element(base, indices) => {
      let base_tex = array_expr_atomish(base, settings)
      let indices_tex = indices.map(idx => array_expr_part(idx, settings)).join(", ")
      "{{\{base_tex}}_{\{indices_tex}}}"
    }
    ArrayExpr::TensorProduct(items) => {
      let args_tex = items.map(item => item.latex(settings~)).join(", ")
      "\\operatorname{ArrayTensorProduct}\\left(\{args_tex}\\right)"
    }
    ArrayExpr::Contraction(base, axes) => {
      let parts : Array[String] = [base.latex(settings~)]
      for pair in axes {
        parts.push(axis_pair_latex(pair, settings))
      }
      let parts_tex = parts.join(", ")
      "\\operatorname{ArrayContraction}\\left(\{parts_tex}\\right)"
    }
    ArrayExpr::Add(_) | ArrayExpr::Mul(_) => abort("array_expr_atomish")
  }
}

///|
fn array_expr_format(
  expr : ArrayExpr,
  parent_prec : Int,
  settings : @symprint.LatexSettings,
) -> String {
  let prec = array_expr_prec(expr)
  let body = match expr {
    ArrayExpr::Add(items) =>
      items.map(item => array_expr_format(item, prec, settings)).join(" + ")
    ArrayExpr::Mul(items) => {
      let rendered : Array[String] = []
      for item in items {
        let tex = array_expr_format(item, prec, settings)
        rendered.push(
          match item {
            ArrayExpr::Add(_) => latex_parens(tex)
            _ => tex
          },
        )
      }
      rendered.join(" ")
    }
    _ => array_expr_atomish(expr, settings)
  }
  if prec < parent_prec {
    latex_parens(body)
  } else {
    body
  }
}

///|
pub fn ArrayExpr::latex(
  self : ArrayExpr,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  array_expr_format(self, 0, settings)
}

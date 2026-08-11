///|
fn tensor_expr_part(
  expr : @symcore.Expr,
  settings : @symprint.LatexSettings,
) -> String {
  @symprint.latex_with_settings(expr, settings)
}

///|
fn latex_parens(s : String) -> String {
  "\\left(\{s}\\right)"
}

///|
pub fn TensorIndexType::latex(
  self : TensorIndexType,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  tensor_expr_part(Symbol(self.name), settings)
}

///|
pub fn TensorHead::latex(
  self : TensorHead,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  tensor_expr_part(Symbol(self.name), settings)
}

///|
fn tensor_index_fragment(
  index : TensorIndex,
  settings : @symprint.LatexSettings,
) -> String {
  let name_tex = tensor_expr_part(Symbol(index.name), settings)
  if index.is_up {
    "{}^{\{name_tex}}"
  } else {
    "{}_{\{name_tex}}"
  }
}

///|
fn tensor_expr_prec(expr : TensorExpr) -> Int {
  match expr {
    Add(_) => 1
    Mul(_) => 2
    _ => 3
  }
}

///|
fn tensor_expr_format(
  expr : TensorExpr,
  parent_prec : Int,
  settings : @symprint.LatexSettings,
) -> String {
  let prec = tensor_expr_prec(expr)
  let body = match expr {
    Scalar(e) => tensor_expr_part(e, settings)
    Tensor(head, indices) => {
      let mut out = head.latex(settings~)
      for index in indices {
        out += tensor_index_fragment(index, settings)
      }
      out
    }
    Add(items) =>
      items.map(item => tensor_expr_format(item, prec, settings)).join(" + ")
    Mul(items) => {
      let ordered : Array[TensorExpr] = []
      for item in items {
        match item {
          Scalar(_) => ordered.push(item)
          _ => ()
        }
      }
      for item in items {
        match item {
          Scalar(_) => ()
          _ => ordered.push(item)
        }
      }
      let rendered : Array[String] = []
      for item in ordered {
        let tex = tensor_expr_format(item, prec, settings)
        rendered.push(
          match item {
            Add(_) => latex_parens(tex)
            _ => tex
          },
        )
      }
      rendered.join("")
    }
  }
  if prec < parent_prec {
    latex_parens(body)
  } else {
    body
  }
}

///|
pub fn TensorExpr::latex(
  self : TensorExpr,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  tensor_expr_format(self, 0, settings)
}

///|
pub fn PartialDerivative::latex(
  self : PartialDerivative,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  let expr_tex = self.expr.latex(settings~)
  if self.variables.length() == 1 {
    let var_tex = self.variables[0].latex(settings~)
    return "\\frac{\\partial}{\\partial {\{var_tex}}}{\{expr_tex}}"
  }
  let parts = self.variables.map(v => "\\partial {\{v.latex(settings~)}}")
  let parts_tex = parts.join(" ")
  "\\frac{\\partial^{\{self.variables.length().to_string()}}}{\{parts_tex}}{\{expr_tex}}"
}

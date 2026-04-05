///|
fn index_expr_latex(
  expr : @symcore.Expr,
  settings : @symprint.LatexSettings,
) -> String {
  @symprint.latex_with_settings(expr, settings)
}

///|
fn index_latex(index : Index, settings : @symprint.LatexSettings) -> String {
  match index {
    Index::Expr(expr) => index_expr_latex(expr, settings)
    Index::Idx(item) => item.latex(settings~)
  }
}

///|
pub fn Idx::latex(
  self : Idx,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  let name_tex = index_expr_latex(@symcore.Expr::Symbol(self.name), settings)
  match self.upper {
    None => name_tex
    Some(upper) => {
      let lower_tex = index_expr_latex(self.lower, settings)
      let upper_tex = if self.lower == @symcore.int(0) {
        index_expr_latex(upper + @symcore.int(-1), settings)
      } else {
        index_expr_latex(upper, settings)
      }
      "{\{name_tex}}_{\{lower_tex}\\mathrel{..}\\nobreak \{upper_tex}}"
    }
  }
}

///|
pub fn IndexedBase::latex(
  self : IndexedBase,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  index_expr_latex(@symcore.Expr::Symbol(self.name), settings)
}

///|
pub fn Indexed::latex(
  self : Indexed,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  let base_tex = self.base.latex(settings~)
  let indices_tex = self.indices.map(index => index_latex(index, settings)).join(",")
  "{\{base_tex}}_{\{indices_tex}}"
}

///|
fn indexed_expr_prec(expr : IndexedExpr) -> Int {
  match expr {
    IndexedExpr::Add(_) => 1
    IndexedExpr::Mul(_) => 2
    _ => 3
  }
}

///|
fn latex_parens(s : String) -> String {
  "\\left(\{s}\\right)"
}

///|
fn indexed_expr_format(
  expr : IndexedExpr,
  parent_prec : Int,
  settings : @symprint.LatexSettings,
) -> String {
  let prec = indexed_expr_prec(expr)
  let body = match expr {
    IndexedExpr::Scalar(e) => @symprint.latex_with_settings(e, settings)
    IndexedExpr::Atom(item) => item.latex(settings~)
    IndexedExpr::Add(items) =>
      items.map(item => indexed_expr_format(item, prec, settings)).join(" + ")
    IndexedExpr::Mul(items) => {
      let ordered : Array[IndexedExpr] = []
      for item in items {
        match item {
          IndexedExpr::Scalar(_) => ordered.push(item)
          _ => ()
        }
      }
      for item in items {
        match item {
          IndexedExpr::Scalar(_) => ()
          _ => ordered.push(item)
        }
      }
      let rendered : Array[String] = []
      for item in ordered {
        let tex = indexed_expr_format(item, prec, settings)
        rendered.push(
          match item {
            IndexedExpr::Add(_) => latex_parens(tex)
            _ => tex
          },
        )
      }
      rendered.join(" ")
    }
  }
  if prec < parent_prec {
    latex_parens(body)
  } else {
    body
  }
}

///|
pub fn IndexedExpr::latex(
  self : IndexedExpr,
  settings? : @symprint.LatexSettings = @symprint.latex_settings(),
) -> String {
  indexed_expr_format(self, 0, settings)
}

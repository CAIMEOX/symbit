///|
/// Matrix distribution and random matrix model starter APIs.

///|
pub fn wishart_rv(
  name : String,
  df : @symcore.Expr,
  scale : @symcore.Expr,
) -> RandomVar {
  random_var(name, RVKind::Matrix(MatrixKind::Wishart(df~, scale~)))
}

///|
pub fn matrix_normal_rv(
  name : String,
  mean : @symcore.Expr,
  rowcov : @symcore.Expr,
  colcov : @symcore.Expr,
) -> RandomVar {
  random_var(name, RVKind::Matrix(MatrixKind::MatrixNormal(mean~, rowcov~, colcov~)))
}

///|
pub fn goe_matrix(name : String, size : @symcore.Expr) -> RandomVar {
  random_var(name, RVKind::Matrix(MatrixKind::GOE(size~)))
}

///|
pub fn gue_matrix(name : String, size : @symcore.Expr) -> RandomVar {
  random_var(name, RVKind::Matrix(MatrixKind::GUE(size~)))
}

///|
pub fn matrix_density(rv : RandomVar, x : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Matrix(MatrixKind::Wishart(df~, scale~)) =>
      Some(@symcore.function("WishartDensity", [x, df, scale]))
    RVKind::Matrix(MatrixKind::MatrixNormal(mean~, rowcov~, colcov~)) =>
      Some(@symcore.function("MatrixNormalDensity", [x, mean, rowcov, colcov]))
    RVKind::Matrix(MatrixKind::GOE(size~)) =>
      Some(@symcore.function("GOEDensity", [x, size]))
    RVKind::Matrix(MatrixKind::GUE(size~)) =>
      Some(@symcore.function("GUEDensity", [x, size]))
    RVKind::Symbolic(tag~, params~) => {
      let name = symbolic_tag_name(tag)
      let family = symbolic_tag_family(tag)
      match name {
        "MatrixStudentT" =>
          Some(@symcore.function("MatrixStudentTDensity", [x, @symcore.symbol(rv.name)]))
        "MatrixGamma" =>
          Some(@symcore.function("MatrixGammaDensity", [x, @symcore.symbol(rv.name)]))
        _ =>
          if family == "M" {
            let args : Array[@symcore.Expr] = [x]
            for p in params {
              args.push(p)
            }
            Some(@symcore.function("\{name}Density", args))
          } else {
            None
          }
      }
    }
    _ => None
  }
}

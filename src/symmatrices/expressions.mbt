///|
pub enum MatrixExpr {
  Concrete(Matrix)
  Symbol(String, Int, Int)
  Identity(Int)
  Zero(Int, Int)
  Add(Array[MatrixExpr])
  Mul(Array[MatrixExpr])
  BlockDiag(Array[MatrixExpr])
  Block(Array[Array[MatrixExpr]])
  Transpose(MatrixExpr)
  Inverse(MatrixExpr)
  Pow(MatrixExpr, Int)
}

///|
fn reverse_matrix_exprs(items : Array[MatrixExpr]) -> Array[MatrixExpr] {
  let out : Array[MatrixExpr] = []
  for i in 0..<items.length() {
    out.push(items[items.length() - 1 - i])
  }
  out
}

///|
fn transpose_block_rows(
  rows : Array[Array[MatrixExpr]],
) -> Array[Array[MatrixExpr]] {
  if rows.is_empty() {
    return []
  }
  let cols = rows[0].length()
  let out : Array[Array[MatrixExpr]] = []
  for j in 0..<cols {
    let row : Array[MatrixExpr] = []
    for i in 0..<rows.length() {
      row.push(matrix_expr_transpose(rows[i][j]))
    }
    out.push(row)
  }
  out
}

///|
fn block_same_layout(
  lhs : Array[Array[MatrixExpr]],
  rhs : Array[Array[MatrixExpr]],
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for i in 0..<lhs.length() {
    if lhs[i].length() != rhs[i].length() {
      return false
    }
    for j in 0..<lhs[i].length() {
      if (try! lhs[i][j].shape()) != (try! rhs[i][j].shape()) {
        return false
      }
    }
  }
  true
}

///|
fn block_mul_compatible(
  lhs : Array[Array[MatrixExpr]],
  rhs : Array[Array[MatrixExpr]],
) -> Bool {
  if lhs.is_empty() || rhs.is_empty() || lhs[0].length() != rhs.length() {
    return false
  }
  for k in 0..<rhs.length() {
    let left_shape = try! lhs[0][k].shape()
    let right_shape = try! rhs[k][0].shape()
    if left_shape.1 != right_shape.0 {
      return false
    }
  }
  true
}

///|
fn block_add_rows(
  lhs : Array[Array[MatrixExpr]],
  rhs : Array[Array[MatrixExpr]],
) -> Array[Array[MatrixExpr]] {
  let out : Array[Array[MatrixExpr]] = []
  for i in 0..<lhs.length() {
    let row : Array[MatrixExpr] = []
    for j in 0..<lhs[i].length() {
      row.push(mat_add([lhs[i][j], rhs[i][j]]))
    }
    out.push(row)
  }
  out
}

///|
fn block_mul_rows(
  lhs : Array[Array[MatrixExpr]],
  rhs : Array[Array[MatrixExpr]],
) -> Array[Array[MatrixExpr]] {
  let out : Array[Array[MatrixExpr]] = []
  for i in 0..<lhs.length() {
    let row : Array[MatrixExpr] = []
    for j in 0..<rhs[0].length() {
      let terms : Array[MatrixExpr] = []
      for k in 0..<lhs[i].length() {
        terms.push(mat_mul([lhs[i][k], rhs[k][j]]))
      }
      row.push(mat_add(terms))
    }
    out.push(row)
  }
  out
}

///|
fn normalize_add_items(items : Array[MatrixExpr]) -> Array[MatrixExpr] {
  let out : Array[MatrixExpr] = []
  for item in items {
    match item {
      MatrixExpr::Add(inner) =>
        for nested in normalize_add_items(inner) {
          out.push(nested)
        }
      MatrixExpr::Zero(_, _) => ()
      _ => out.push(item)
    }
  }
  out
}

///|
fn normalize_mul_items(items : Array[MatrixExpr]) -> Array[MatrixExpr] {
  let out : Array[MatrixExpr] = []
  for item in items {
    match item {
      MatrixExpr::Mul(inner) =>
        for nested in normalize_mul_items(inner) {
          out.push(nested)
        }
      MatrixExpr::Identity(_) => ()
      _ => out.push(item)
    }
  }
  out
}

///|
fn normalize_block_diag_items(items : Array[MatrixExpr]) -> Array[MatrixExpr] {
  let out : Array[MatrixExpr] = []
  for item in items {
    match item {
      MatrixExpr::BlockDiag(inner) =>
        for nested in normalize_block_diag_items(inner) {
          out.push(nested)
        }
      _ => out.push(item)
    }
  }
  out
}

///|
fn all_concrete(items : Array[MatrixExpr]) -> Bool {
  items.all(fn(item) {
    match item {
      MatrixExpr::Concrete(_) => true
      _ => false
    }
  })
}

///|
fn concrete_add(items : Array[MatrixExpr]) -> MatrixExpr {
  let mut acc = match items[0] {
    MatrixExpr::Concrete(m) => m
    _ => abort("unreachable")
  }
  for item in items[1:] {
    match item {
      MatrixExpr::Concrete(m) => acc = acc + m
      _ => abort("unreachable")
    }
  }
  MatrixExpr::Concrete(acc)
}

///|
fn concrete_mul(items : Array[MatrixExpr]) -> MatrixExpr {
  let mut acc = match items[0] {
    MatrixExpr::Concrete(m) => m
    _ => abort("unreachable")
  }
  for item in items[1:] {
    match item {
      MatrixExpr::Concrete(m) => acc = acc * m
      _ => abort("unreachable")
    }
  }
  MatrixExpr::Concrete(acc)
}

///|
fn blockdiag_identity_like(items : Array[MatrixExpr]) -> MatrixExpr? {
  let identities : Array[MatrixExpr] = []
  for item in items {
    let shape = try? item.shape()
    match shape {
      Ok((rows, cols)) => {
        if rows != cols {
          return None
        }
        identities.push(identity_expr(rows))
      }
      Err(_) => return None
    }
  }
  Some(block_diag_matrix_expr(identities))
}

///|
fn block_identity_like(rows : Array[Array[MatrixExpr]]) -> MatrixExpr? {
  if rows.is_empty() {
    return Some(zero_matrix_expr(0, 0))
  }
  if rows.length() != rows[0].length() {
    return None
  }
  let heights : Array[Int] = []
  let widths : Array[Int] = []
  for i in 0..<rows.length() {
    let mut height = 0
    for item in rows[i] {
      let shape = try? item.shape()
      match shape {
        Ok((rows0, _)) =>
          if height == 0 {
            height = rows0
          } else if height != rows0 {
            return None
          }
        Err(_) => return None
      }
    }
    heights.push(height)
  }
  for j in 0..<rows[0].length() {
    let mut width = 0
    for i in 0..<rows.length() {
      let shape = try? rows[i][j].shape()
      match shape {
        Ok((_, cols0)) =>
          if width == 0 {
            width = cols0
          } else if width != cols0 {
            return None
          }
        Err(_) => return None
      }
    }
    widths.push(width)
  }
  for i in 0..<heights.length() {
    if heights[i] != widths[i] {
      return None
    }
  }
  let identity_rows : Array[Array[MatrixExpr]] = []
  for i in 0..<heights.length() {
    let row : Array[MatrixExpr] = []
    for j in 0..<widths.length() {
      row.push(
        if i == j {
          identity_expr(heights[i])
        } else {
          zero_matrix_expr(heights[i], widths[j])
        },
      )
    }
    identity_rows.push(row)
  }
  Some(block_matrix_expr(identity_rows))
}

///|
pub fn matrix_symbol(name : String, rows : Int, cols : Int) -> MatrixExpr {
  MatrixExpr::Symbol(name, rows, cols)
}

///|
pub fn matrix_expr(m : Matrix) -> MatrixExpr {
  MatrixExpr::Concrete(m)
}

///|
pub fn identity_expr(n : Int) -> MatrixExpr {
  MatrixExpr::Identity(n)
}

///|
pub fn zero_matrix_expr(rows : Int, cols : Int) -> MatrixExpr {
  MatrixExpr::Zero(rows, cols)
}

///|
pub fn matrix_expr_add(items : Array[MatrixExpr]) -> MatrixExpr {
  if items.is_empty() {
    return MatrixExpr::Zero(0, 0)
  }
  let normalized = normalize_add_items(items)
  if normalized.length() > 1 && all_concrete(normalized) {
    return concrete_add(normalized)
  }
  match normalized.length() {
    0 =>
      match items[0] {
        MatrixExpr::Zero(rows, cols) => MatrixExpr::Zero(rows, cols)
        _ => items[0]
      }
    1 => normalized[0]
    _ => MatrixExpr::Add(normalized)
  }
}

///|
pub fn matrix_expr_mul(items : Array[MatrixExpr]) -> MatrixExpr {
  if items.is_empty() {
    return MatrixExpr::Identity(0)
  }
  let normalized = normalize_mul_items(items)
  if normalized.length() > 1 && all_concrete(normalized) {
    return concrete_mul(normalized)
  }
  if normalized.any(fn(item) {
      match item {
        MatrixExpr::Zero(_, _) => true
        _ => false
      }
    }) {
    let shape = try? MatrixExpr::Mul(normalized).shape()
    match shape {
      Ok((rows, cols)) => return MatrixExpr::Zero(rows, cols)
      Err(_) => ()
    }
  }
  match normalized.length() {
    0 =>
      match items[0] {
        MatrixExpr::Identity(n) => MatrixExpr::Identity(n)
        _ => items[0]
      }
    1 => normalized[0]
    _ => MatrixExpr::Mul(normalized)
  }
}

///|
pub fn matrix_expr_block_diag(items : Array[MatrixExpr]) -> MatrixExpr {
  if items.is_empty() {
    return MatrixExpr::Zero(0, 0)
  }
  let normalized = normalize_block_diag_items(items)
  match normalized.length() {
    0 =>
      match items[0] {
        MatrixExpr::Zero(rows, cols) => MatrixExpr::Zero(rows, cols)
        _ => items[0]
      }
    1 => normalized[0]
    _ => MatrixExpr::BlockDiag(normalized)
  }
}

///|
pub fn matrix_expr_block(rows : Array[Array[MatrixExpr]]) -> MatrixExpr {
  if rows.length() == 1 && rows[0].length() == 1 {
    return rows[0][0]
  }
  MatrixExpr::Block(rows)
}

///|
pub fn mat_add(items : Array[MatrixExpr]) -> MatrixExpr {
  matrix_expr_add(items)
}

///|
pub fn mat_mul(items : Array[MatrixExpr]) -> MatrixExpr {
  matrix_expr_mul(items)
}

///|
pub fn block_matrix_expr(rows : Array[Array[MatrixExpr]]) -> MatrixExpr {
  matrix_expr_block(rows)
}

///|
pub fn block_diag_matrix_expr(items : Array[MatrixExpr]) -> MatrixExpr {
  matrix_expr_block_diag(items)
}

///|
pub fn matrix_expr_transpose(expr : MatrixExpr) -> MatrixExpr {
  match expr {
    MatrixExpr::Transpose(inner) => inner
    MatrixExpr::Identity(n) => MatrixExpr::Identity(n)
    MatrixExpr::Zero(rows, cols) => MatrixExpr::Zero(cols, rows)
    MatrixExpr::Add(items) =>
      mat_add(items.map(fn(item) { matrix_expr_transpose(item) }))
    MatrixExpr::Mul(items) =>
      mat_mul(
        reverse_matrix_exprs(items).map(fn(item) { matrix_expr_transpose(item) }),
      )
    MatrixExpr::BlockDiag(items) =>
      block_diag_matrix_expr(
        items.map(fn(item) { matrix_expr_transpose(item) }),
      )
    MatrixExpr::Block(rows) => block_matrix_expr(transpose_block_rows(rows))
    _ => MatrixExpr::Transpose(expr)
  }
}

///|
pub fn matrix_expr_inverse(expr : MatrixExpr) -> MatrixExpr {
  match expr {
    MatrixExpr::Identity(n) => MatrixExpr::Identity(n)
    MatrixExpr::Inverse(inner) => inner
    MatrixExpr::Transpose(inner) =>
      matrix_expr_transpose(matrix_expr_inverse(inner))
    MatrixExpr::BlockDiag(items) =>
      block_diag_matrix_expr(items.map(fn(item) { matrix_expr_inverse(item) }))
    MatrixExpr::Block(rows) =>
      if rows.length() == 1 && rows[0].length() == 1 {
        matrix_expr_inverse(rows[0][0])
      } else {
        MatrixExpr::Inverse(expr)
      }
    MatrixExpr::Mul(items) =>
      mat_mul(
        reverse_matrix_exprs(items).map(fn(item) { matrix_expr_inverse(item) }),
      )
    MatrixExpr::Pow(inner, exp) => matrix_expr_pow(inner, -exp)
    _ => MatrixExpr::Inverse(expr)
  }
}

///|
pub fn matrix_expr_pow(expr : MatrixExpr, exp : Int) -> MatrixExpr {
  if exp == 0 {
    let shape = try? expr.shape()
    match shape {
      Ok((rows, cols)) => if rows == cols { return identity_expr(rows) }
      Err(_) => ()
    }
  }
  if exp == 1 {
    return expr
  }
  if exp == -1 {
    return matrix_expr_inverse(expr)
  }
  match expr {
    MatrixExpr::Identity(n) => MatrixExpr::Identity(n)
    MatrixExpr::Zero(rows, cols) if rows == cols && exp > 0 =>
      MatrixExpr::Zero(rows, cols)
    MatrixExpr::Transpose(inner) =>
      matrix_expr_transpose(matrix_expr_pow(inner, exp))
    MatrixExpr::Pow(inner, inner_exp) => MatrixExpr::Pow(inner, inner_exp * exp)
    MatrixExpr::BlockDiag(items) if exp > 0 =>
      block_diag_matrix_expr(items.map(fn(item) { matrix_expr_pow(item, exp) }))
    _ => MatrixExpr::Pow(expr, exp)
  }
}

///|
pub fn MatrixExpr::shape(self : MatrixExpr) -> (Int, Int) raise MatrixError {
  match self {
    MatrixExpr::Concrete(m) => m.shape()
    MatrixExpr::Symbol(_, rows, cols) => (rows, cols)
    MatrixExpr::Identity(n) => (n, n)
    MatrixExpr::Zero(rows, cols) => (rows, cols)
    MatrixExpr::Add(items) => {
      guard !items.is_empty() else {
        raise MatrixError::ShapeError("empty MatrixExpr Add")
      }
      let shape = items[0].shape()
      for item in items[1:] {
        if item.shape() != shape {
          raise MatrixError::ShapeError(
            "matrix expression add expects equal shapes",
          )
        }
      }
      shape
    }
    MatrixExpr::Mul(items) => {
      guard !items.is_empty() else {
        raise MatrixError::ShapeError("empty MatrixExpr Mul")
      }
      let first = items[0].shape()
      let mut last = first
      for item in items[1:] {
        let current = item.shape()
        if last.1 != current.0 {
          raise MatrixError::ShapeError(
            "matrix expression mul expects aligned dimensions",
          )
        }
        last = current
      }
      (first.0, last.1)
    }
    MatrixExpr::BlockDiag(items) => {
      let mut rows = 0
      let mut cols = 0
      for item in items {
        let shape = item.shape()
        rows += shape.0
        cols += shape.1
      }
      (rows, cols)
    }
    MatrixExpr::Block(rows0) => {
      guard !rows0.is_empty() else { return (0, 0) }
      let mut rows = 0
      let col_widths : Array[Int] = []
      let first_width = rows0[0].length()
      for row in rows0 {
        if row.length() != first_width {
          raise MatrixError::ShapeError(
            "block matrix expression expects rectangular block layout",
          )
        }
      }
      for j in 0..<first_width {
        let mut width = 0
        for i in 0..<rows0.length() {
          let shape = rows0[i][j].shape()
          if i == 0 {
            width = shape.1
          } else if width != shape.1 {
            raise MatrixError::ShapeError(
              "blocks in the same column must have equal widths",
            )
          }
        }
        col_widths.push(width)
      }
      for row in rows0 {
        let mut height = 0
        for item in row {
          let shape = item.shape()
          if height == 0 {
            height = shape.0
          } else if height != shape.0 {
            raise MatrixError::ShapeError(
              "blocks in the same row must have equal heights",
            )
          }
        }
        rows += height
      }
      let cols = col_widths.fold(init=0, fn(acc, v) { acc + v })
      (rows, cols)
    }
    MatrixExpr::Transpose(inner) => {
      let shape = inner.shape()
      (shape.1, shape.0)
    }
    MatrixExpr::Inverse(inner) | MatrixExpr::Pow(inner, _) => inner.shape()
  }
}

///|
pub fn MatrixExpr::to_string(self : MatrixExpr) -> String {
  match self {
    MatrixExpr::Concrete(m) => m.to_string()
    MatrixExpr::Symbol(name, _, _) => name
    MatrixExpr::Identity(n) => "Identity(" + n.to_string() + ")"
    MatrixExpr::Zero(rows, cols) =>
      "ZeroMatrix(" + rows.to_string() + ", " + cols.to_string() + ")"
    MatrixExpr::Add(items) =>
      "(" + items.map(fn(item) { item.to_string() }).join(" + ") + ")"
    MatrixExpr::Mul(items) =>
      "(" + items.map(fn(item) { item.to_string() }).join(" * ") + ")"
    MatrixExpr::BlockDiag(items) =>
      "BlockDiag(" + items.map(fn(item) { item.to_string() }).join(", ") + ")"
    MatrixExpr::Block(rows) =>
      "Block(" +
      rows
      .map(fn(row) {
        "[" + row.map(fn(item) { item.to_string() }).join(", ") + "]"
      })
      .join(", ") +
      ")"
    MatrixExpr::Transpose(inner) => inner.to_string() + ".T"
    MatrixExpr::Inverse(inner) => inner.to_string() + "^-1"
    MatrixExpr::Pow(inner, exp) => inner.to_string() + "^" + exp.to_string()
  }
}

///|
pub fn MatrixExpr::eval(
  self : MatrixExpr,
  env : Map[String, Matrix],
) -> Matrix raise MatrixError {
  match self {
    MatrixExpr::Concrete(m) => m
    MatrixExpr::Symbol(name, rows, cols) =>
      match env.get(name) {
        Some(value) => {
          if value.shape() != (rows, cols) {
            raise MatrixError::ShapeError(
              "matrix symbol binding has wrong shape",
            )
          }
          value
        }
        None => raise MatrixError::ValueError("missing matrix symbol binding")
      }
    MatrixExpr::Identity(n) => eye(n)
    MatrixExpr::Zero(rows, cols) => zeros(rows, cols=Some(cols))
    MatrixExpr::Add(items) => {
      guard !items.is_empty() else { return zeros(0, cols=Some(0)) }
      let mut acc = items[0].eval(env)
      for item in items[1:] {
        let next = item.eval(env)
        if acc.shape() != next.shape() {
          raise MatrixError::ShapeError(
            "matrix expression add expects equal shapes",
          )
        }
        acc = acc + next
      }
      acc
    }
    MatrixExpr::Mul(items) => {
      guard !items.is_empty() else { return zeros(0, cols=Some(0)) }
      let mut acc = items[0].eval(env)
      for item in items[1:] {
        let next = item.eval(env)
        if acc.cols != next.rows {
          raise MatrixError::ShapeError(
            "matrix expression mul expects aligned dimensions",
          )
        }
        acc = acc * next
      }
      acc
    }
    MatrixExpr::BlockDiag(items) => {
      let mats : Array[Matrix] = []
      for item in items {
        mats.push(item.eval(env))
      }
      block_diag(mats)
    }
    MatrixExpr::Block(rows) => {
      let mats : Array[Array[Matrix]] = []
      for row in rows {
        let mat_row : Array[Matrix] = []
        for item in row {
          mat_row.push(item.eval(env))
        }
        mats.push(mat_row)
      }
      block_matrix(mats)
    }
    MatrixExpr::Transpose(inner) => inner.eval(env).transpose()
    MatrixExpr::Inverse(inner) => inner.eval(env).inv()
    MatrixExpr::Pow(inner, exp) => {
      let base = inner.eval(env)
      if !base.is_square() {
        raise MatrixError::NonSquareMatrixError(
          "matrix power requires a square matrix",
        )
      }
      if exp == 0 {
        return eye(base.rows)
      }
      if exp < 0 {
        let inv = base.inv()
        let mut out = inv
        for _ in 1..<-exp {
          out = out * inv
        }
        return out
      }
      let mut out = base
      for _ in 1..<exp {
        out = out * base
      }
      out
    }
  }
}

///|
pub fn MatrixExpr::doit(
  self : MatrixExpr,
  env : Map[String, Matrix],
) -> Matrix raise MatrixError {
  self.eval(env)
}

///|
pub fn MatrixExpr::as_explicit(
  self : MatrixExpr,
  env : Map[String, Matrix],
) -> Matrix raise MatrixError {
  self.eval(env)
}

///|
pub fn MatrixExpr::block_collapse(self : MatrixExpr) -> MatrixExpr {
  match self {
    MatrixExpr::Add(items) => {
      let collapsed = items.map(fn(item) { item.block_collapse() })
      if collapsed.any(fn(item) {
          match item {
            MatrixExpr::BlockDiag(_) => true
            _ => false
          }
        }) {
        let normalized : Array[MatrixExpr] = []
        let mut changed = false
        let mut template : MatrixExpr? = None
        for item in collapsed {
          match item {
            MatrixExpr::BlockDiag(_) => {
              template = Some(item)
              break
            }
            _ => ()
          }
        }
        match template {
          Some(MatrixExpr::BlockDiag(parts)) =>
            for item in collapsed {
              match item {
                MatrixExpr::Identity(_) =>
                  match blockdiag_identity_like(parts) {
                    Some(identity) => {
                      normalized.push(identity)
                      changed = true
                    }
                    None => normalized.push(item)
                  }
                _ => normalized.push(item)
              }
            }
          _ => ()
        }
        if changed {
          return mat_add(normalized).block_collapse()
        }
      }
      if collapsed.all(fn(item) {
          match item {
            MatrixExpr::BlockDiag(_) => true
            _ => false
          }
        }) {
        let first = match collapsed[0] {
          MatrixExpr::BlockDiag(items) => items
          _ => []
        }
        let aligned = collapsed.all(fn(item) {
          match item {
            MatrixExpr::BlockDiag(parts) => parts.length() == first.length()
            _ => false
          }
        })
        if aligned {
          let blocks : Array[MatrixExpr] = []
          for i in 0..<first.length() {
            let pieces : Array[MatrixExpr] = []
            for item in collapsed {
              match item {
                MatrixExpr::BlockDiag(parts) => pieces.push(parts[i])
                _ => ()
              }
            }
            blocks.push(mat_add(pieces))
          }
          return block_diag_matrix_expr(blocks)
        }
      }
      if collapsed.all(fn(item) {
          match item {
            MatrixExpr::Block(_) => true
            _ => false
          }
        }) {
        let rows = match collapsed[0] {
          MatrixExpr::Block(rows) => rows
          _ => []
        }
        let aligned = collapsed.all(fn(item) {
          match item {
            MatrixExpr::Block(other) => block_same_layout(rows, other)
            _ => false
          }
        })
        if aligned {
          let mut acc = rows
          for item in collapsed[1:] {
            match item {
              MatrixExpr::Block(other) => acc = block_add_rows(acc, other)
              _ => ()
            }
          }
          return block_matrix_expr(acc)
        }
      }
      if collapsed.any(fn(item) {
          match item {
            MatrixExpr::Block(_) => true
            _ => false
          }
        }) {
        let normalized : Array[MatrixExpr] = []
        let mut changed = false
        let mut template : MatrixExpr? = None
        for item in collapsed {
          match item {
            MatrixExpr::Block(_) => {
              template = Some(item)
              break
            }
            _ => ()
          }
        }
        match template {
          Some(MatrixExpr::Block(rows)) =>
            for item in collapsed {
              match item {
                MatrixExpr::Identity(_) =>
                  match block_identity_like(rows) {
                    Some(identity) => {
                      normalized.push(identity)
                      changed = true
                    }
                    None => normalized.push(item)
                  }
                _ => normalized.push(item)
              }
            }
          _ => ()
        }
        if changed {
          return mat_add(normalized).block_collapse()
        }
      }
      matrix_expr_add(collapsed)
    }
    MatrixExpr::Mul(items) => {
      let collapsed = items.map(fn(item) { item.block_collapse() })
      guard !collapsed.is_empty() else { return MatrixExpr::Identity(0) }
      let mut acc = collapsed[0]
      for item in collapsed[1:] {
        acc = match (acc, item) {
          (MatrixExpr::BlockDiag(lhs), MatrixExpr::BlockDiag(rhs)) =>
            if lhs.length() == rhs.length() {
              block_diag_matrix_expr(
                Array::makei(lhs.length(), fn(i) { mat_mul([lhs[i], rhs[i]]) }),
              )
            } else {
              mat_mul([MatrixExpr::BlockDiag(lhs), MatrixExpr::BlockDiag(rhs)])
            }
          (MatrixExpr::Block(lhs), MatrixExpr::Block(rhs)) =>
            if block_mul_compatible(lhs, rhs) {
              block_matrix_expr(block_mul_rows(lhs, rhs))
            } else {
              mat_mul([MatrixExpr::Block(lhs), MatrixExpr::Block(rhs)])
            }
          (MatrixExpr::BlockDiag(lhs), MatrixExpr::Block(rhs)) =>
            if lhs.length() == rhs.length() {
              let rows : Array[Array[MatrixExpr]] = []
              for i in 0..<rhs.length() {
                let row : Array[MatrixExpr] = []
                for j in 0..<rhs[i].length() {
                  row.push(mat_mul([lhs[i], rhs[i][j]]))
                }
                rows.push(row)
              }
              block_matrix_expr(rows)
            } else {
              mat_mul([MatrixExpr::BlockDiag(lhs), MatrixExpr::Block(rhs)])
            }
          (MatrixExpr::Block(lhs), MatrixExpr::BlockDiag(rhs)) =>
            if !lhs.is_empty() && lhs[0].length() == rhs.length() {
              let rows : Array[Array[MatrixExpr]] = []
              for i in 0..<lhs.length() {
                let row : Array[MatrixExpr] = []
                for j in 0..<lhs[i].length() {
                  row.push(mat_mul([lhs[i][j], rhs[j]]))
                }
                rows.push(row)
              }
              block_matrix_expr(rows)
            } else {
              mat_mul([MatrixExpr::Block(lhs), MatrixExpr::BlockDiag(rhs)])
            }
          (left, right) => mat_mul([left, right])
        }
      }
      acc
    }
    MatrixExpr::BlockDiag(items) =>
      matrix_expr_block_diag(items.map(fn(item) { item.block_collapse() }))
    MatrixExpr::Block(rows) => {
      let collapsed = rows.map(fn(row) {
        row.map(fn(item) { item.block_collapse() })
      })
      matrix_expr_block(collapsed)
    }
    MatrixExpr::Transpose(inner) =>
      matrix_expr_transpose(inner.block_collapse())
    MatrixExpr::Inverse(inner) => matrix_expr_inverse(inner.block_collapse())
    MatrixExpr::Pow(inner, exp) => matrix_expr_pow(inner.block_collapse(), exp)
    _ => self
  }
}

///|
/// Block assembly front doors for dense matrices.
///
/// Current Limits:
/// - These helpers only materialize explicit dense block layouts.
/// - They do not preserve symbolic block structure; use `MatrixExpr` for unevaluated block syntax.
///
/// Assemble a block-diagonal dense matrix.
///
/// - Does: Places each block on the main block diagonal and fills all off-diagonal regions with exact zero.
/// - Input: An `Array[Matrix]` whose items can have different shapes.
/// - Returns: One dense `Matrix` whose shape is the sum of all block heights and widths.
/// - Limits: Raises any `MatrixError` emitted by the delegated dense zero-matrix construction.
pub fn block_diag(blocks : Array[Matrix]) -> Matrix raise MatrixError {
  let mut total_rows = 0
  let mut total_cols = 0
  for block in blocks {
    total_rows += block.rows
    total_cols += block.cols
  }
  let out = zeros(total_rows, cols=Some(total_cols))
  let data = clone_expr_rows(out.data)
  let mut row_offset = 0
  let mut col_offset = 0
  for block in blocks {
    for i in 0..<block.rows {
      for j in 0..<block.cols {
        data[row_offset + i][col_offset + j] = block.data[i][j]
      }
    }
    row_offset += block.rows
    col_offset += block.cols
  }
  { rows: total_rows, cols: total_cols, data }
}

///|
/// Assemble a dense block matrix from a rectangular grid of blocks.
///
/// - Does: Concatenates the provided blocks into one dense matrix after checking row-wise heights and column-wise widths.
/// - Input: `Array[Array[Matrix]]` describing a rectangular block grid.
/// - Returns: One dense `Matrix`.
/// - Limits: Raises `MatrixError::ShapeError` when the block grid is jagged or when blocks disagree on a shared row height or column width.
pub fn block_matrix(rows : Array[Array[Matrix]]) -> Matrix raise MatrixError {
  if rows.is_empty() {
    return zeros(0, cols=Some(0))
  }
  let row_heights : Array[Int] = []
  let col_widths : Array[Int] = []
  let first_width = rows[0].length()
  for row in rows {
    if row.length() != first_width {
      raise ShapeError("block_matrix expects rectangular block layout")
    }
  }
  for row in rows {
    let height = if row.is_empty() { 0 } else { row[0].rows }
    for block in row {
      if block.rows != height {
        raise ShapeError("blocks in the same row must have equal heights")
      }
    }
    row_heights.push(height)
  }
  for j in 0..<first_width {
    let width = if rows[0].is_empty() { 0 } else { rows[0][j].cols }
    for i in 0..<rows.length() {
      if rows[i][j].cols != width {
        raise ShapeError("blocks in the same column must have equal widths")
      }
    }
    col_widths.push(width)
  }
  let total_rows = row_heights.fold(init=0, fn(acc, v) { acc + v })
  let total_cols = col_widths.fold(init=0, fn(acc, v) { acc + v })
  let out = zeros(total_rows, cols=Some(total_cols))
  let data = clone_expr_rows(out.data)
  let mut row_offset = 0
  for i in 0..<rows.length() {
    let mut col_offset = 0
    for j in 0..<rows[i].length() {
      let block = rows[i][j]
      for r in 0..<block.rows {
        for c in 0..<block.cols {
          data[row_offset + r][col_offset + c] = block.data[r][c]
        }
      }
      col_offset += block.cols
    }
    row_offset += row_heights[i]
  }
  { rows: total_rows, cols: total_cols, data }
}

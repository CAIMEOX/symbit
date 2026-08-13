///|
fn domainmatrix_structural_source() -> String {
  (
    #|def _symbit_domainmatrix_matrix_text(matrix):
    #|    return str(matrix.to_Matrix())
    #|
    #|def _symbit_domainmatrix_summary(matrix):
    #|    return (
    #|        str(matrix.to_Matrix())
    #|        + "@" + str(matrix.domain)
    #|        + "|" + str(matrix.rep.fmt)
    #|    )
    #|
    #|def _symbit_domainmatrix_unify_text(result):
    #|    if not isinstance(result, (list, tuple)) or len(result) < 2:
    #|        raise ValueError("domainmatrix-unify")
    #|    return (
    #|        _symbit_domainmatrix_summary(result[0])
    #|        + "||"
    #|        + _symbit_domainmatrix_summary(result[1])
    #|    )
    #|
    #|def _symbit_domainmatrix_text(value):
    #|    if value is None:
    #|        raise ValueError("domainmatrix-none")
    #|    return str(value)
    #|
    #|def _symbit_domainmatrix_tuple(result, minimum, message):
    #|    if not isinstance(result, (list, tuple)) or len(result) < minimum:
    #|        raise ValueError(message)
    #|    return result
    #|
    #|def _symbit_domainmatrix_pivots(pivots):
    #|    if not isinstance(pivots, (list, tuple)):
    #|        raise ValueError("domainmatrix-pivots")
    #|    return "[" + ",".join(str(int(str(pivot))) for pivot in pivots) + "]"
    #|
    #|def _symbit_domainmatrix_rref_text(result):
    #|    matrix, pivots = _symbit_domainmatrix_tuple(
    #|        result, 2, "domainmatrix-rref-tuple"
    #|    )[:2]
    #|    return (
    #|        _symbit_domainmatrix_matrix_text(matrix)
    #|        + "||" + _symbit_domainmatrix_pivots(pivots)
    #|    )
    #|
    #|def _symbit_domainmatrix_rref_den_text(result):
    #|    matrix, denominator, pivots = _symbit_domainmatrix_tuple(
    #|        result, 3, "domainmatrix-rref-den-tuple"
    #|    )[:3]
    #|    return (
    #|        _symbit_domainmatrix_matrix_text(matrix)
    #|        + "||" + str(denominator)
    #|        + "||" + _symbit_domainmatrix_pivots(pivots)
    #|    )
    #|
    #|def _symbit_domainmatrix_lu_text(result):
    #|    lower, upper, swaps = _symbit_domainmatrix_tuple(
    #|        result, 3, "domainmatrix-lu-tuple"
    #|    )[:3]
    #|    return (
    #|        _symbit_domainmatrix_matrix_text(lower)
    #|        + "||" + _symbit_domainmatrix_matrix_text(upper)
    #|        + "||" + str(swaps)
    #|    )
    #|
    #|def _symbit_domainmatrix_qr_text(result):
    #|    orthogonal, upper = _symbit_domainmatrix_tuple(
    #|        result, 2, "domainmatrix-qr-tuple"
    #|    )[:2]
    #|    return (
    #|        _symbit_domainmatrix_matrix_text(orthogonal)
    #|        + "||" + _symbit_domainmatrix_matrix_text(upper)
    #|    )
    #|
    #|def _symbit_domainmatrix_fflu_text(result):
    #|    permutation, lower, diagonal, upper = _symbit_domainmatrix_tuple(
    #|        result, 4, "domainmatrix-fflu-tuple"
    #|    )[:4]
    #|    return "||".join(
    #|        _symbit_domainmatrix_matrix_text(matrix)
    #|        for matrix in (permutation, lower, diagonal, upper)
    #|    )
    #|
    #|def _symbit_domainmatrix_domain_text(value, message):
    #|    try:
    #|        return str(value.domain)
    #|    except Exception as error:
    #|        raise ValueError(message) from error
    #|
    #|def _symbit_domainmatrix_advanced_text(kind, result):
    #|    if kind in ("clear_denoms", "clear_denoms_expr"):
    #|        if kind == "clear_denoms":
    #|            tuple_message = "domainmatrix-clear-denoms-tuple"
    #|            domain_message = "domainmatrix-clear-denoms-domain"
    #|            num_domain_message = "domainmatrix-clear-denoms-num-domain"
    #|        else:
    #|            tuple_message = "domainmatrix-clear-denoms-expr-tuple"
    #|            domain_message = "domainmatrix-clear-denoms-expr-domain"
    #|            num_domain_message = "domainmatrix-clear-denoms-expr-num-domain"
    #|        denominator, numerator = _symbit_domainmatrix_tuple(
    #|            result, 2, tuple_message
    #|        )[:2]
    #|        return (
    #|            str(denominator)
    #|            + "@" + _symbit_domainmatrix_domain_text(
    #|                denominator, domain_message
    #|            )
    #|            + "||" + _symbit_domainmatrix_matrix_text(numerator)
    #|            + "@" + _symbit_domainmatrix_domain_text(
    #|                numerator, num_domain_message
    #|            )
    #|        )
    #|    if kind == "clear_denoms_rowwise_expr":
    #|        denominator, numerator = _symbit_domainmatrix_tuple(
    #|            result, 2, "domainmatrix-clear-denoms-rowwise-tuple"
    #|        )[:2]
    #|        return (
    #|            _symbit_domainmatrix_matrix_text(denominator)
    #|            + "@" + _symbit_domainmatrix_domain_text(
    #|                denominator, "domainmatrix-clear-denoms-rowwise-domain"
    #|            )
    #|            + "||" + _symbit_domainmatrix_matrix_text(numerator)
    #|            + "@" + _symbit_domainmatrix_domain_text(
    #|                numerator,
    #|                "domainmatrix-clear-denoms-rowwise-num-domain",
    #|            )
    #|        )
    #|    matrix_scalar_messages = {
    #|        "adj_det": "domainmatrix-adj-det-tuple",
    #|        "inv_den": "domainmatrix-inv-den-tuple",
    #|        "solve_den": "domainmatrix-solve-den-tuple",
    #|        "solve_den_rref": "domainmatrix-solve-den-rref-tuple",
    #|        "cancel_denom": "domainmatrix-cancel-denom-tuple",
    #|        "solve_den_charpoly": "domainmatrix-solve-den-charpoly-tuple",
    #|    }
    #|    if kind in matrix_scalar_messages:
    #|        matrix, scalar = _symbit_domainmatrix_tuple(
    #|            result, 2, matrix_scalar_messages[kind]
    #|        )[:2]
    #|        return _symbit_domainmatrix_matrix_text(matrix) + "||" + str(scalar)
    #|    if kind == "primitive":
    #|        scalar, matrix = _symbit_domainmatrix_tuple(
    #|            result, 2, "domainmatrix-primitive-tuple"
    #|        )[:2]
    #|        return str(scalar) + "||" + _symbit_domainmatrix_matrix_text(matrix)
    #|    matrix_matrix_messages = {
    #|        "cancel_denom_elementwise":
    #|            "domainmatrix-cancel-denom-elementwise-tuple",
    #|        "lll_transform": "domainmatrix-lll-transform",
    #|        "internal_solve": "domainmatrix-_solve",
    #|    }
    #|    if kind in matrix_matrix_messages:
    #|        left, right = _symbit_domainmatrix_tuple(
    #|            result, 2, matrix_matrix_messages[kind]
    #|        )[:2]
    #|        return (
    #|            _symbit_domainmatrix_matrix_text(left)
    #|            + "||" + _symbit_domainmatrix_matrix_text(right)
    #|        )
    #|    if kind == "adj_poly_det":
    #|        left, right = _symbit_domainmatrix_tuple(
    #|            result, 2, "domainmatrix-adj-poly-det-tuple"
    #|        )[:2]
    #|        return str(left) + "||" + str(right)
    #|    if kind == "smith_normal_decomp":
    #|        smith, left, right = _symbit_domainmatrix_tuple(
    #|            result, 3, "domainmatrix-smith-normal-decomp"
    #|        )[:3]
    #|        return "||".join(
    #|            _symbit_domainmatrix_matrix_text(matrix)
    #|            for matrix in (smith, left, right)
    #|        )
    #|    raise ValueError("domainmatrix-advanced-kind:" + str(kind))
    #|
    #|def _symbit_domainmatrix_int_rows(matrix):
    #|    return [
    #|        [int(str(value)) for value in row]
    #|        for row in matrix.to_Matrix().tolist()
    #|    ]
    #|
    #|def _symbit_domainmatrix_normalize_smith_rows(matrix):
    #|    rows = _symbit_domainmatrix_int_rows(matrix)
    #|    for index in range(min(len(rows), len(rows[0]) if rows else 0)):
    #|        if rows[index][index] < 0:
    #|            rows[index][index] = -rows[index][index]
    #|    return rows
    #|
    #|def _symbit_domainmatrix_smith_text(kind, original, smith):
    #|    normalized = _symbit_domainmatrix_normalize_smith_rows(smith)
    #|    if kind == "invariant_factors":
    #|        limit = min(len(normalized), len(normalized[0]) if normalized else 0)
    #|        return str(tuple(normalized[index][index] for index in range(limit)))
    #|    if kind == "is_smith_normal_form":
    #|        return _symbit_domainmatrix_normalize_smith_rows(original) == normalized
    #|    if kind == "smith_normal_form":
    #|        return str(sympy.Matrix(normalized))
    #|    raise ValueError("domainmatrix-smith-kind:" + str(kind))
    #|
    #|def _symbit_domainmatrix_eigen_text(result):
    #|    groups = _symbit_domainmatrix_tuple(
    #|        result, 2, "domainmatrix-dom-eigenvects"
    #|    )
    #|    parts = []
    #|    for item in groups[0]:
    #|        fields = _symbit_domainmatrix_tuple(
    #|            item, 4, "domainmatrix-dom-eigenvects-rational"
    #|        )
    #|        parts.append(
    #|            "r:" + str(fields[1])
    #|            + ":" + str(int(str(fields[2])))
    #|            + ":" + _symbit_domainmatrix_matrix_text(fields[3])
    #|        )
    #|    for item in groups[1]:
    #|        fields = _symbit_domainmatrix_tuple(
    #|            item, 4, "domainmatrix-dom-eigenvects-algebraic"
    #|        )
    #|        parts.append(
    #|            "a:" + str(fields[1].as_expr())
    #|            + ":" + str(int(str(fields[2])))
    #|            + ":" + _symbit_domainmatrix_matrix_text(fields[3])
    #|        )
    #|    return "||".join(sorted(parts))
  )
}

///|
priv struct DomainMatrixRecipe {
  domain_recipe : DomainRecipe
  domainmatrix_class : @recipe.ValueRef
  matrix_renderer : @recipe.ValueRef
  summary_renderer : @recipe.ValueRef
  unify_renderer : @recipe.ValueRef
  text_renderer : @recipe.ValueRef
  rref_renderer : @recipe.ValueRef
  rref_den_renderer : @recipe.ValueRef
  lu_renderer : @recipe.ValueRef
  qr_renderer : @recipe.ValueRef
  fflu_renderer : @recipe.ValueRef
  advanced_renderer : @recipe.ValueRef
  smith_renderer : @recipe.ValueRef
  eigen_renderer : @recipe.ValueRef
}

///|
fn DomainMatrixRecipe::new() -> DomainMatrixRecipe raise {
  let domain_recipe = DomainRecipe::new()
  let matrices = domain_recipe.builder.import_module("sympy.polys.matrices")
  let domainmatrix_class = domain_recipe.builder.getattr(
    matrices, "DomainMatrix",
  )
  let scope = domain_recipe.builder.exec(
    domain_recipe.scope,
    domainmatrix_structural_source(),
  )
  let matrix_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_matrix_text"),
  )
  let summary_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_summary"),
  )
  let unify_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_unify_text"),
  )
  let text_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_text"),
  )
  let rref_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_rref_text"),
  )
  let rref_den_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_rref_den_text"),
  )
  let lu_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_lu_text"),
  )
  let qr_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_qr_text"),
  )
  let fflu_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_fflu_text"),
  )
  let advanced_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_advanced_text"),
  )
  let smith_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_smith_text"),
  )
  let eigen_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_eigen_text"),
  )
  {
    domain_recipe,
    domainmatrix_class,
    matrix_renderer,
    summary_renderer,
    unify_renderer,
    text_renderer,
    rref_renderer,
    rref_den_renderer,
    lu_renderer,
    qr_renderer,
    fflu_renderer,
    advanced_renderer,
    smith_renderer,
    eigen_renderer,
  }
}

///|
fn rectangular_expr_shape(
  rows : Array[Array[String]],
  error_message : String,
) -> (Int, Int) raise {
  let row_count = rows.length()
  let column_count = if row_count == 0 { 0 } else { rows[0].length() }
  for row in rows {
    if row.length() != column_count {
      fail(error_message)
    }
  }
  (row_count, column_count)
}

///|
fn DomainMatrixRecipe::domain(
  self : DomainMatrixRecipe,
  domain_spec : String,
) -> @recipe.ValueRef raise {
  self.domain_recipe.domain(domain_spec)
}

///|
fn DomainMatrixRecipe::shape(
  self : DomainMatrixRecipe,
  row_count : Int,
  column_count : Int,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.tuple([
    DecimalInt(Show::to_string(row_count)),
    DecimalInt(Show::to_string(column_count)),
  ])
}

///|
fn DomainMatrixRecipe::domain_int(
  self : DomainMatrixRecipe,
  domain : @recipe.ValueRef,
  value : Int,
) -> @recipe.ValueRef raise {
  let convert = self.domain_recipe.builder.getattr(domain, "convert")
  self.domain_recipe.builder.call(convert, [DecimalInt(Show::to_string(value))])
}

///|
fn DomainMatrixRecipe::domain_expr(
  self : DomainMatrixRecipe,
  domain : @recipe.ValueRef,
  source : String,
) -> @recipe.ValueRef raise {
  let convert = self.domain_recipe.builder.getattr(domain, "convert")
  let expression = self.domain_recipe.sympify(source)
  let result = self.domain_recipe.builder.call(convert, [Ref(expression)])
  self.domain_recipe.builder.require_non_none(
    result,
    message="domainmatrix-domain-convert-none",
  )
}

///|
fn DomainMatrixRecipe::domain_int_list(
  self : DomainMatrixRecipe,
  values : Array[Int],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let encoded : Array[@recipe.RecipeArg] = []
  for value in values {
    encoded.push(Ref(self.domain_int(domain, value)))
  }
  self.domain_recipe.builder.list(encoded)
}

///|
fn DomainMatrixRecipe::domain_int_rows(
  self : DomainMatrixRecipe,
  rows : Array[Array[Int]],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let encoded_rows : Array[@recipe.RecipeArg] = []
  for row in rows {
    encoded_rows.push(Ref(self.domain_int_list(row, domain)))
  }
  self.domain_recipe.builder.list(encoded_rows)
}

///|
fn DomainMatrixRecipe::domain_expr_rows(
  self : DomainMatrixRecipe,
  rows : Array[Array[String]],
  domain : @recipe.ValueRef,
) -> (@recipe.ValueRef, Int, Int) raise {
  let (row_count, column_count) = rectangular_expr_shape(
    rows, "domainmatrix-expr-ragged",
  )
  let encoded_rows : Array[@recipe.RecipeArg] = []
  for row in rows {
    let encoded_row : Array[@recipe.RecipeArg] = []
    for value in row {
      encoded_row.push(Ref(self.domain_expr(domain, value)))
    }
    encoded_rows.push(Ref(self.domain_recipe.builder.list(encoded_row)))
  }
  (self.domain_recipe.builder.list(encoded_rows), row_count, column_count)
}

///|
fn DomainMatrixRecipe::domain_expr_list(
  self : DomainMatrixRecipe,
  values : Array[String],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let encoded : Array[@recipe.RecipeArg] = []
  for value in values {
    encoded.push(Ref(self.domain_expr(domain, value)))
  }
  self.domain_recipe.builder.list(encoded)
}

///|
fn DomainMatrixRecipe::flat_domain_ints(
  self : DomainMatrixRecipe,
  rows : Array[Array[Int]],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let encoded : Array[@recipe.RecipeArg] = []
  for row in rows {
    for value in row {
      encoded.push(Ref(self.domain_int(domain, value)))
    }
  }
  self.domain_recipe.builder.list(encoded)
}

///|
fn DomainMatrixRecipe::domainmatrix(
  self : DomainMatrixRecipe,
  rows : Array[Array[Int]],
  domain : @recipe.ValueRef,
  fmt? : String = "dense",
) -> @recipe.ValueRef raise {
  let (row_count, column_count) = rectangular_shape(rows, "domainmatrix-ragged")
  let data = self.domain_int_rows(rows, domain)
  let shape = self.shape(row_count, column_count)
  let dense = self.domain_recipe.builder.call(self.domainmatrix_class, [
    Ref(data),
    Ref(shape),
    Ref(domain),
  ])
  match fmt {
    "dense" => dense
    "sparse" => self.call_method(dense, "to_sparse", [])
    _ => fail("domainmatrix-fmt")
  }
}

///|
fn DomainMatrixRecipe::domainmatrix_expr(
  self : DomainMatrixRecipe,
  rows : Array[Array[String]],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let (data, row_count, column_count) = self.domain_expr_rows(rows, domain)
  let shape = self.shape(row_count, column_count)
  self.domain_recipe.builder.call(self.domainmatrix_class, [
    Ref(data),
    Ref(shape),
    Ref(domain),
  ])
}

///|
fn DomainMatrixRecipe::expr_rows(
  self : DomainMatrixRecipe,
  rows : Array[Array[String]],
  error_message : String,
) -> (@recipe.ValueRef, Int, Int) raise {
  let (row_count, column_count) = rectangular_expr_shape(rows, error_message)
  let encoded_rows : Array[@recipe.RecipeArg] = []
  for row in rows {
    let encoded_row : Array[@recipe.RecipeArg] = []
    for value in row {
      encoded_row.push(Ref(self.domain_recipe.sympify(value)))
    }
    encoded_rows.push(Ref(self.domain_recipe.builder.list(encoded_row)))
  }
  (self.domain_recipe.builder.list(encoded_rows), row_count, column_count)
}

///|
fn DomainMatrixRecipe::matrix_from_exprs(
  self : DomainMatrixRecipe,
  rows : Array[Array[String]],
) -> @recipe.ValueRef raise {
  let (data, _, _) = self.expr_rows(rows, "domainmatrix-from-matrix-ragged")
  let matrix_class = self.domain_recipe.builder.getattr(
    self.domain_recipe.sympy,
    "Matrix",
  )
  self.domain_recipe.builder.call(matrix_class, [Ref(data)])
}

///|
fn DomainMatrixRecipe::scalar_expr(
  self : DomainMatrixRecipe,
  source : String,
) -> @recipe.ValueRef raise {
  try @string.parse_int(source.trim()) catch {
    _ => self.domain_recipe.sympify(source)
  } noraise {
    value =>
      self.domain_recipe.builder.value(DecimalInt(Show::to_string(value)))
  }
}

///|
fn DomainMatrixRecipe::call_method(
  self : DomainMatrixRecipe,
  object : @recipe.ValueRef,
  name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let callable = self.domain_recipe.builder.getattr(object, name)
  let result = self.domain_recipe.builder.call(callable, args, kwargs~)
  self.domain_recipe.builder.require_non_none(
    result,
    message="domainmatrix-method-none:" + name,
  )
}

///|
fn DomainMatrixRecipe::call_class_method(
  self : DomainMatrixRecipe,
  name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  self.call_method(self.domainmatrix_class, name, args, kwargs~)
}

///|
fn DomainMatrixRecipe::call_path(
  self : DomainMatrixRecipe,
  path : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let callable = recipe_sympy_callable(self.domain_recipe.builder, path)
  let result = self.domain_recipe.builder.call(callable, args, kwargs~)
  self.domain_recipe.builder.require_non_none(
    result,
    message="sympy-call-none:" + path,
  )
}

///|
fn DomainMatrixRecipe::render_matrix(
  self : DomainMatrixRecipe,
  matrix : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.matrix_renderer, [Ref(matrix)])
}

///|
fn DomainMatrixRecipe::render_summary(
  self : DomainMatrixRecipe,
  matrix : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.summary_renderer, [Ref(matrix)])
}

///|
fn DomainMatrixRecipe::render_unify(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.unify_renderer, [Ref(result)])
}

///|
fn DomainMatrixRecipe::render_text(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.text_renderer, [Ref(result)])
}

///|
fn DomainMatrixRecipe::render_rref(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.rref_renderer, [Ref(result)])
}

///|
fn DomainMatrixRecipe::render_rref_den(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.rref_den_renderer, [Ref(result)])
}

///|
fn DomainMatrixRecipe::render_lu(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.lu_renderer, [Ref(result)])
}

///|
fn DomainMatrixRecipe::render_qr(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.qr_renderer, [Ref(result)])
}

///|
fn DomainMatrixRecipe::render_fflu(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.fflu_renderer, [Ref(result)])
}

///|
fn DomainMatrixRecipe::render_advanced(
  self : DomainMatrixRecipe,
  kind : String,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.advanced_renderer, [
    Str(kind),
    Ref(result),
  ])
}

///|
fn DomainMatrixRecipe::render_smith(
  self : DomainMatrixRecipe,
  kind : String,
  original : @recipe.ValueRef,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.smith_renderer, [
    Str(kind),
    Ref(original),
    Ref(result),
  ])
}

///|
fn DomainMatrixRecipe::render_eigen(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.eigen_renderer, [Ref(result)])
}

///|
fn DomainMatrixRecipe::request_str(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  self.domain_recipe.builder.request_str(result)
}

///|
fn DomainMatrixRecipe::request_int(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> Int raise {
  parse_domain_int(self.domain_recipe.builder.request_int(result))
}

///|
fn DomainMatrixRecipe::request_bool(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> Bool raise {
  self.domain_recipe.builder.request_bool(result)
}

///|
fn structural_domain_options(
  field : Bool,
  gaussian : Bool,
  modulus : Int?,
) -> Map[String, @recipe.RecipeArg] {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if field {
    kwargs["field"] = Bool(true)
  }
  if gaussian {
    kwargs["gaussian"] = Bool(true)
  }
  match modulus {
    Some(value) => kwargs["modulus"] = DecimalInt(Show::to_string(value))
    None => ()
  }
  kwargs
}

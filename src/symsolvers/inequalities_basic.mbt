///|
/// Public rational-inequality tuple used by inequality solvers.
///
/// - Does: Encodes one rational inequality as polynomial numerator,
///   polynomial denominator, and a relation string.
/// - Input: `((Poly, Poly), String)`.
/// - Returns: A type alias used by `solve_rational_inequalities`.
/// - Limits: The relation string must still be one of the supported operator
///   spellings at the public front door.
pub type RationalInequality = ((@sympolys.Poly, @sympolys.Poly), String)

///|
/// Result of an inequality solve request.
///
/// - Does: Encodes either a set-valued answer or a rebuilt relational answer.
/// - Input: Produced by public inequality front doors.
/// - Returns: `Set(Set)` or `Relational(Expr)`.
/// - Limits: Callers must branch on the variant because not every inequality
///   API returns a `Set` directly.
pub enum InequalityResult {
  Set(Set)
  Relational(Expr)
}

///|
fn solver_infinity() -> Expr {
  Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
}

///|
fn solver_negative_infinity() -> Expr {
  Expr::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity)
}

///|
fn solver_is_positive_infinity(expr : Expr) -> Bool {
  @symcore.compare_expr(expr, solver_infinity()) == 0
}

///|
fn solver_is_negative_infinity(expr : Expr) -> Bool {
  @symcore.compare_expr(expr, solver_negative_infinity()) == 0
}

///|
fn solver_exact_number_expr(num : @bigint.BigInt, den : @bigint.BigInt) -> Expr {
  Expr::Number(
    @symnum.BigRational::new(num, den) catch {
      _ => @symnum.BigRational::zero()
    },
  )
}

///|
fn solver_numeric_compare(lhs : Expr, rhs : Expr) -> Int? {
  if solver_is_negative_infinity(lhs) {
    return if solver_is_negative_infinity(rhs) { Some(0) } else { Some(-1) }
  }
  if solver_is_positive_infinity(lhs) {
    return if solver_is_positive_infinity(rhs) { Some(0) } else { Some(1) }
  }
  if solver_is_negative_infinity(rhs) {
    return Some(1)
  }
  if solver_is_positive_infinity(rhs) {
    return Some(-1)
  }
  match exact_compare(lhs, rhs) {
    Some(cmp) => Some(cmp)
    None => {
      let lhs_eval = @symcore.evalf(lhs, prec=80)
      let rhs_eval = @symcore.evalf(rhs, prec=80)
      match (lhs_eval, rhs_eval) {
        (Expr::Number(_) | Expr::Float(_), Expr::Number(_) | Expr::Float(_)) =>
          Some(@symcore.compare_expr(lhs_eval, rhs_eval))
        _ =>
          match
            @symcore.bool_value(
              Expr::Relational(@symcore.RelOp::Lt, lhs_eval, rhs_eval),
            ) {
            Some(true) => Some(-1)
            Some(false) =>
              match
                @symcore.bool_value(
                  Expr::Relational(@symcore.RelOp::Gt, lhs_eval, rhs_eval),
                ) {
                Some(true) => Some(1)
                Some(false) =>
                  match
                    @symcore.bool_value(
                      Expr::Relational(@symcore.RelOp::Eq, lhs_eval, rhs_eval),
                    ) {
                    Some(true) => Some(0)
                    _ => None
                  }
                None => None
              }
            None => None
          }
      }
    }
  }
}

///|
fn solver_sort_numeric_exprs(items : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  for item in items {
    let mut inserted = false
    for i in 0..<out.length() {
      match solver_numeric_compare(item, out[i]) {
        Some(cmp) =>
          if cmp == 0 {
            inserted = true
            break
          } else if cmp < 0 {
            out.insert(i, item)
            inserted = true
            break
          }
        None => ()
      }
    }
    if !inserted {
      out.push(item)
    }
  }
  out
}

///|
fn solver_midpoint(lhs : Expr, rhs : Expr) -> Expr? {
  match
    (
      @symcore.exact_numeric_expr_num_den(lhs),
      @symcore.exact_numeric_expr_num_den(rhs),
    ) {
    (Some((ln, ld)), Some((rn, rd))) => {
      let num = ln * rd + rn * ld
      let den = ld * rd * 2N
      Some(solver_exact_number_expr(num, den))
    }
    _ => None
  }
}

///|
fn solver_interval_sample(left : Expr, right : Expr) -> Expr? {
  if solver_is_negative_infinity(left) {
    if solver_is_positive_infinity(right) {
      return Some(@symcore.int(0))
    }
    match @symcore.exact_numeric_expr_num_den(right) {
      Some((num, den)) => return Some(solver_exact_number_expr(num - den, den))
      None => return None
    }
  }
  if solver_is_positive_infinity(right) {
    match @symcore.exact_numeric_expr_num_den(left) {
      Some((num, den)) => return Some(solver_exact_number_expr(num + den, den))
      None => return None
    }
  }
  solver_midpoint(left, right)
}

///|
fn solver_interval_contains_expr(interval_set : Set, elem : Expr) -> Bool {
  match interval_set {
    @symsets.Set::Interval(left~, right~, left_open~, right_open~) =>
      match
        (
          solver_numeric_compare(left, elem),
          solver_numeric_compare(elem, right),
        ) {
        (Some(lcmp), Some(rcmp)) =>
          (if left_open { lcmp < 0 } else { lcmp <= 0 }) &&
          (if right_open { rcmp < 0 } else { rcmp <= 0 })
        _ => false
      }
    _ => false
  }
}

///|
fn solver_interval_set(
  left : Expr,
  right : Expr,
  left_open : Bool,
  right_open : Bool,
) -> Set {
  @symsets.interval(
    left,
    right,
    left_open=if solver_is_negative_infinity(left) {
      right_open
    } else {
      left_open
    },
    right_open=if solver_is_positive_infinity(right) {
      left_open
    } else {
      right_open
    },
  )
}

///|
fn solver_sign_at(
  expr : Expr,
  symbol : Expr,
  point : Expr,
) -> Int? raise SolverError {
  let env : Map[String, Expr] = {}
  env[symbol_name(symbol)] = point
  let value = canonical_expr(@symcore.subst(normalize_equation(expr), env))
  if expr_is_zeroish(value) == Some(true) {
    return Some(0)
  }
  match @symcore.exact_numeric_expr_num_den(value) {
    Some((num, _)) =>
      if num.compare(0N) < 0 {
        Some(-1)
      } else if num.compare(0N) > 0 {
        Some(1)
      } else {
        Some(0)
      }
    None =>
      match
        @symcore.bool_value(
          Expr::Relational(
            @symcore.RelOp::Gt,
            @symcore.evalf(value, prec=80),
            @symcore.int(0),
          ),
        ) {
        Some(true) => Some(1)
        Some(false) =>
          match
            @symcore.bool_value(
              Expr::Relational(
                @symcore.RelOp::Lt,
                @symcore.evalf(value, prec=80),
                @symcore.int(0),
              ),
            ) {
            Some(true) => Some(-1)
            Some(false) => Some(0)
            None => None
          }
        None => None
      }
  }
}

///|
fn solver_collect_free_symbols(exprs : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  for expr in exprs {
    for symbol in @symcore.free_symbols(expr) {
      out.push(symbol)
    }
  }
  out
}

///|
fn solver_relation_holds(rel : String, sign : Int) -> Bool raise SolverError {
  match rel {
    "==" => sign == 0
    "!=" => sign != 0
    ">" => sign > 0
    ">=" => sign >= 0
    "<" => sign < 0
    "<=" => sign <= 0
    _ => raise SolverError::ValueError("invalid relation: " + rel)
  }
}

///|
fn solver_expr_and(items : Array[Expr]) -> Expr {
  let kept : Array[Expr] = []
  for item in items {
    if @symcore.is_false(item) {
      return Expr::Boolean(false)
    }
    if !@symcore.is_true(item) {
      kept.push(item)
    }
  }
  if kept.is_empty() {
    Expr::Boolean(true)
  } else if kept.length() == 1 {
    kept[0]
  } else {
    @symcore.function("And", kept)
  }
}

///|
fn solver_expr_or(items : Array[Expr]) -> Expr {
  let kept : Array[Expr] = []
  for item in items {
    if @symcore.is_true(item) {
      return Expr::Boolean(true)
    }
    if !@symcore.is_false(item) {
      kept.push(item)
    }
  }
  if kept.is_empty() {
    Expr::Boolean(false)
  } else if kept.length() == 1 {
    kept[0]
  } else {
    @symcore.function("Or", kept)
  }
}

///|
fn solver_set_to_relational_expr(set : Set, symbol : Expr) -> Expr {
  match set {
    @symsets.Set::EmptySet => Expr::Boolean(false)
    @symsets.Set::UniversalSet
    | @symsets.Set::Reals
    | @symsets.Set::Complexes => Expr::Boolean(true)
    @symsets.Set::FiniteSet(items) =>
      solver_expr_or(
        items.map(item => Expr::Relational(@symcore.RelOp::Eq, symbol, item)),
      )
    @symsets.Set::Interval(left~, right~, left_open~, right_open~) => {
      let pieces : Array[Expr] = []
      if !solver_is_negative_infinity(left) {
        pieces.push(
          Expr::Relational(
            if left_open {
              @symcore.RelOp::Lt
            } else {
              @symcore.RelOp::Le
            },
            left,
            symbol,
          ),
        )
      }
      if !solver_is_positive_infinity(right) {
        pieces.push(
          Expr::Relational(
            if right_open {
              @symcore.RelOp::Lt
            } else {
              @symcore.RelOp::Le
            },
            symbol,
            right,
          ),
        )
      }
      solver_expr_and(pieces)
    }
    @symsets.Set::Union(items) =>
      solver_expr_or(
        items.map(item => solver_set_to_relational_expr(item, symbol)),
      )
    @symsets.Set::Intersection(items) =>
      solver_expr_and(
        items.map(item => solver_set_to_relational_expr(item, symbol)),
      )
    _ =>
      @symcore.function("Contains", [
        symbol,
        Expr::Symbol(@symsets.to_string(set)),
      ])
  }
}

///|
fn solver_union_pieces(set : Set) -> Array[Set] {
  match set {
    @symsets.Set::EmptySet => []
    @symsets.Set::Union(items) => {
      let out : Array[Set] = []
      for item in items {
        for inner in solver_union_pieces(item) {
          out.push(inner)
        }
      }
      out
    }
    _ => [set]
  }
}

///|
fn solver_normalize_union(parts : Array[Set]) -> Set {
  let expanded = solver_union_pieces(@symsets.union(parts))
  let intervals : Array[Set] = []
  let points : Array[Expr] = []
  for part in expanded {
    match part {
      @symsets.Set::FiniteSet(items) =>
        for item in items {
          points.push(item)
        }
      _ => intervals.push(part)
    }
  }
  let consumed : Array[Bool] = []
  for _ in 0..<points.length() {
    consumed.push(false)
  }
  let merged : Array[Set] = []
  for interval_set in intervals {
    match interval_set {
      @symsets.Set::Interval(left~, right~, left_open~, right_open~) => {
        let mut new_left_open = left_open
        let mut new_right_open = right_open
        for i in 0..<points.length() {
          if consumed[i] {
            continue
          }
          let point = points[i]
          if solver_interval_contains_expr(interval_set, point) {
            consumed[i] = true
            continue
          }
          match solver_numeric_compare(point, left) {
            Some(0) if new_left_open => {
              new_left_open = false
              consumed[i] = true
            }
            _ => ()
          }
          match solver_numeric_compare(point, right) {
            Some(0) if new_right_open => {
              new_right_open = false
              consumed[i] = true
            }
            _ => ()
          }
        }
        merged.push(
          @symsets.interval(
            left,
            right,
            left_open=new_left_open,
            right_open=new_right_open,
          ),
        )
      }
      _ => merged.push(interval_set)
    }
  }
  let leftovers : Array[Expr] = []
  for i in 0..<points.length() {
    if !consumed[i] {
      leftovers.push(points[i])
    }
  }
  if !leftovers.is_empty() {
    merged.push(@symsets.finite_set(leftovers))
  }
  @symsets.union(
    merged.map(fn(set) {
      match set {
        @symsets.Set::Interval(left~, right~, left_open~, right_open~) =>
          solver_interval_set(left, right, left_open, right_open)
        _ => set
      }
    }),
  )
}

///|
fn solver_set_intersection(lhs : Set, rhs : Set) -> Set {
  let parts : Array[Set] = []
  for a in solver_union_pieces(lhs) {
    for b in solver_union_pieces(rhs) {
      let piece = match (a, b) {
        (@symsets.Set::UniversalSet, other) | (@symsets.Set::Reals, other) =>
          other
        (other, @symsets.Set::UniversalSet) | (other, @symsets.Set::Reals) =>
          other
        (
          @symsets.Set::Interval(
            left=al,
            right=ar,
            left_open=alo,
            right_open=aro
          ),
          @symsets.Set::Interval(
            left=bl,
            right=br,
            left_open=blo,
            right_open=bro
          ),
        ) =>
          match
            (solver_numeric_compare(al, bl), solver_numeric_compare(ar, br)) {
            (Some(left_cmp), Some(right_cmp)) => {
              let (left, left_open) = if left_cmp > 0 {
                (al, alo)
              } else if left_cmp < 0 {
                (bl, blo)
              } else {
                (al, alo || blo)
              }
              let (right, right_open) = if right_cmp < 0 {
                (ar, aro)
              } else if right_cmp > 0 {
                (br, bro)
              } else {
                (ar, aro || bro)
              }
              solver_interval_set(left, right, left_open, right_open)
            }
            _ => @symsets.intersection([a, b])
          }
        (@symsets.Set::Interval(..), @symsets.Set::FiniteSet(items)) => {
          let kept : Array[Expr] = []
          for item in items {
            if solver_interval_contains_expr(a, item) {
              kept.push(item)
            }
          }
          @symsets.finite_set(kept)
        }
        (@symsets.Set::FiniteSet(items), @symsets.Set::Interval(..)) => {
          let kept : Array[Expr] = []
          for item in items {
            if solver_interval_contains_expr(b, item) {
              kept.push(item)
            }
          }
          @symsets.finite_set(kept)
        }
        _ => @symsets.intersection([a, b])
      }
      if piece != @symsets.empty_set() {
        parts.push(piece)
      }
    }
  }
  solver_normalize_union(parts)
}

///|
fn solver_interval_minus_points(
  interval_set : Set,
  points : Array[Expr],
) -> Set {
  match interval_set {
    @symsets.Set::Interval(left~, right~, left_open~, right_open~) => {
      let kept_points : Array[Expr] = []
      for point in solver_sort_numeric_exprs(points) {
        if solver_interval_contains_expr(interval_set, point) {
          kept_points.push(point)
        }
      }
      if kept_points.is_empty() {
        return interval_set
      }
      let parts : Array[Set] = []
      let boundaries = [left, ..kept_points, right]
      for i in 0..<(boundaries.length() - 1) {
        let a = boundaries[i]
        let b = boundaries[i + 1]
        let open_left = if i == 0 { left_open } else { true }
        let open_right = if i == boundaries.length() - 2 {
          right_open
        } else {
          true
        }
        let piece = solver_interval_set(a, b, open_left, open_right)
        if piece != @symsets.empty_set() {
          parts.push(piece)
        }
      }
      solver_normalize_union(parts)
    }
    _ => @symsets.complement(interval_set, @symsets.finite_set(points))
  }
}

///|
fn solver_set_difference(lhs : Set, rhs : Set) -> Set {
  let rhs_parts = solver_union_pieces(rhs)
  let out : Array[Set] = []
  for piece in solver_union_pieces(lhs) {
    let mut current = piece
    for rhs_piece in rhs_parts {
      current = match (current, rhs_piece) {
        (@symsets.Set::Interval(..), @symsets.Set::FiniteSet(points)) =>
          solver_interval_minus_points(current, points)
        _ => @symsets.complement(current, rhs_piece)
      }
    }
    if current != @symsets.empty_set() {
      out.push(current)
    }
  }
  solver_normalize_union(out)
}

///|
/// Solve a univariate polynomial inequality and return its solution pieces.
///
/// - Does: Solves one univariate polynomial relation by sign analysis and root
///   splitting.
/// - Input: A univariate `Poly` and a relation string such as `==`, `!=`, `<`,
///   `<=`, `>`, or `>=`.
/// - Returns: `Array[Set]`.
/// - Limits: The polynomial must be univariate; multivariate input raises
///   `SolverError::ValueError`.
pub fn solve_poly_inequality(
  poly : @sympolys.Poly,
  rel : String,
) -> Array[Set] raise SolverError {
  let expr = poly.to_expr()
  if poly.is_zero() {
    return if solver_relation_holds(rel, 0) {
      [@symsets.reals()]
    } else {
      [@symsets.empty_set()]
    }
  }
  if poly.gens.length() != 1 {
    raise SolverError::ValueError(
      "solve_poly_inequality expects a univariate Poly",
    )
  }
  let symbol = Expr::Symbol(poly.gens[0])
  let roots = solver_sort_numeric_exprs(
    (@sympolys.roots(poly) catch {
      err => raise wrap_poly_error("solve_poly_inequality", err)
    }).map(canonical_expr),
  )
  if rel == "==" {
    return roots.map(root => @symsets.finite_set([root]))
  }
  let points = [solver_negative_infinity(), ..roots, solver_infinity()]
  let pieces : Array[Set] = []
  for i in 0..<(points.length() - 1) {
    let left = points[i]
    let right = points[i + 1]
    match solver_interval_sample(left, right) {
      Some(sample) =>
        match solver_sign_at(expr, symbol, sample) {
          Some(sign) if solver_relation_holds(rel, sign) =>
            pieces.push(solver_interval_set(left, right, true, true))
          _ => ()
        }
      None => ()
    }
  }
  if rel == "!=" {
    return pieces
  }
  if rel == ">=" || rel == "<=" {
    for root in roots {
      pieces.push(@symsets.finite_set([root]))
    }
  }
  pieces
}

///|
/// Solve a disjunction of conjunctions of rational inequalities.
///
/// - Does: Treats each inner array as a conjunction and unions the resulting
///   solution sets across the outer array.
/// - Input: `Array[Array[RationalInequality]]`.
/// - Returns: A `@symsets.Set`.
/// - Limits: This front door assumes polynomial numerators and denominators
///   have already been built.
pub fn solve_rational_inequalities(
  eqs : Array[Array[RationalInequality]],
) -> Set raise SolverError {
  let mut result = @symsets.empty_set()
  for group in eqs {
    if group.is_empty() {
      continue
    }
    let mut current : Set = @symsets.reals()
    for entry in group {
      let ((numer, denom), rel) = entry
      let product = numer.mul(denom) catch {
        err => raise wrap_poly_error("solve_rational_inequalities", err)
      }
      let numer_set = @symsets.union(solve_poly_inequality(product, rel))
      let denom_zeros = @symsets.union(solve_poly_inequality(denom, "=="))
      current = solver_set_intersection(current, numer_set)
      current = solver_set_difference(current, denom_zeros)
    }
    result = solver_normalize_union([result, current])
  }
  result
}

///|
fn solver_relation_expr(expr : Expr) -> (Expr, String) {
  match @symcore.relational_parts(expr) {
    Some((op, lhs, rhs)) =>
      (
        canonical_expr(
          @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])]),
        ),
        match op {
          @symcore.RelOp::Eq => "=="
          @symcore.RelOp::Ne => "!="
          @symcore.RelOp::Lt => "<"
          @symcore.RelOp::Le => "<="
          @symcore.RelOp::Gt => ">"
          @symcore.RelOp::Ge => ">="
        },
      )
    None => (normalize_equation(expr), "==")
  }
}

///|
fn solver_exact_sign(expr : Expr) -> Int? {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, _)) =>
      if num.compare(0N) < 0 {
        Some(-1)
      } else if num.compare(0N) > 0 {
        Some(1)
      } else {
        Some(0)
      }
    None => None
  }
}

///|
fn solver_univariate_inequality_set(
  expr : Expr,
  gen : Expr,
  domain : Set,
) -> Set raise SolverError {
  let (target, rel) = solver_relation_expr(expr)
  let name = symbol_name(gen)
  let rational_target = canonical_expr(
    @symsimplify.ratsimp(target, max_passes=4),
  )
  let (numer, denom) = @symsimplify.fraction(rational_target)
  let numer_poly = @sympolys.Poly::from_expr_defaults(numer, gens=[name]) catch {
    err => raise wrap_poly_error("solve_univariate_inequality", err)
  }
  let denom_poly = @sympolys.Poly::from_expr_defaults(denom, gens=[name]) catch {
    err => raise wrap_poly_error("solve_univariate_inequality", err)
  }
  let full = if rel == "==" || rel == "!=" {
    @symsets.union(solve_poly_inequality(numer_poly, rel))
  } else {
    solve_rational_inequalities([[((numer_poly, denom_poly), rel)]])
  }
  solver_set_intersection(full, domain)
}

///|
/// Solve a single-variable inequality over a set domain.
///
/// - Does: Solves one inequality over a domain and optionally rebuilds the
///   answer as a relational expression.
/// - Input: One inequality expression, one symbol, and optional result/domain
///   flags.
/// - Returns: An `InequalityResult`.
/// - Limits: The current front door is univariate and treats `continuous` as a
///   compatibility flag rather than a full continuity analysis switch.
///
/// ```mbt check
/// test "symsolvers solve_univariate_inequality returns a set when requested" {
///   let x = @symcore.Expr::Symbol("x")
///   match
///     solve_univariate_inequality(
///       @symcore.Expr::Relational(@symcore.RelOp::Gt, x, @symcore.int(0)),
///       x,
///       relational=false,
///     ) {
///     InequalityResult::Set(set) =>
///       inspect(@symsets.to_string(set), content="Interval.open(0, oo)")
///     _ => fail("expected a set-valued inequality result")
///   }
/// }
/// ```
pub fn solve_univariate_inequality(
  expr : Expr,
  gen : Expr,
  relational? : Bool = true,
  domain? : Set = @symsets.reals(),
  continuous? : Bool = false,
) -> InequalityResult raise SolverError {
  ignore(continuous)
  let set = solver_univariate_inequality_set(expr, gen, domain)
  if relational {
    InequalityResult::Relational(solver_set_to_relational_expr(set, gen))
  } else {
    InequalityResult::Set(set)
  }
}

///|
fn solver_single_abs_term(expr : Expr) -> (Expr, Expr)? {
  if @symcore.application_has_name(expr, "Abs", arity=1) {
    return Some((@symcore.int(1), @symcore.args(expr)[0]))
  }
  match expr {
    Expr::Mul(args) if args.length() == 2 &&
      @symcore.application_has_name(args[1], "Abs", arity=1) =>
      Some((args[0], @symcore.args(args[1])[0]))
    Expr::Mul(args) if args.length() == 2 &&
      @symcore.application_has_name(args[0], "Abs", arity=1) =>
      Some((args[1], @symcore.args(args[0])[0]))
    _ => None
  }
}

///|
fn solver_abs_equality_set(
  arg : Expr,
  bound : Expr,
  gen : Expr,
) -> Set raise SolverError {
  match solver_exact_sign(bound) {
    Some(sign) if sign < 0 => @symsets.empty_set()
    _ => {
      let left = match
        solve_univariate_inequality(
          Expr::Relational(
            @symcore.RelOp::Eq,
            arg,
            @symcore.mul([@symcore.int(-1), bound]),
          ),
          gen,
          relational=false,
        ) {
        InequalityResult::Set(set) => set
        _ => @symsets.empty_set()
      }
      let right = match
        solve_univariate_inequality(
          Expr::Relational(@symcore.RelOp::Eq, arg, bound),
          gen,
          relational=false,
        ) {
        InequalityResult::Set(set) => set
        _ => @symsets.empty_set()
      }
      @symsets.union([left, right])
    }
  }
}

///|
/// Reduce an inequality with one absolute-value term to a relational condition.
///
/// - Does: Converts one `Abs`-based inequality into an equivalent relational
///   expression over one symbol.
/// - Input: One expression, one relation string, and one symbol.
/// - Returns: An `Expr`.
/// - Limits: The input must contain exactly one supported `Abs` term or the
///   solver raises `SolverError::ValueError`.
pub fn reduce_abs_inequality(
  expr : Expr,
  rel : String,
  gen : Expr,
) -> Expr raise SolverError {
  let terms = match canonical_expr(expr) {
    Expr::Add(args) => args
    other => [other]
  }
  let mut abs_coeff : Expr? = None
  let mut inner : Expr? = None
  let rest : Array[Expr] = []
  for term in terms {
    match solver_single_abs_term(term) {
      Some((coeff, arg)) if abs_coeff is None => {
        abs_coeff = Some(coeff)
        inner = Some(arg)
      }
      _ => rest.push(term)
    }
  }
  guard abs_coeff is Some(coeff) && inner is Some(arg) else {
    raise SolverError::ValueError(
      "reduce_abs_inequality expects a single Abs term",
    )
  }
  let bound = canonical_expr(
    @symcore.mul([
      @symcore.int(-1),
      solver_add_all(rest),
      coeff ^ @symcore.int(-1),
    ]),
  )
  let solution = match rel {
    "==" => solver_abs_equality_set(arg, bound, gen)
    "!=" =>
      match solver_exact_sign(bound) {
        Some(sign) if sign < 0 => @symsets.reals()
        _ =>
          solver_set_difference(
            @symsets.reals(),
            solver_abs_equality_set(arg, bound, gen),
          )
      }
    "<" | "<=" => {
      let left = match
        solve_univariate_inequality(
          Expr::Relational(
            if rel == "<" {
              @symcore.RelOp::Gt
            } else {
              @symcore.RelOp::Ge
            },
            arg,
            @symcore.mul([@symcore.int(-1), bound]),
          ),
          gen,
          relational=false,
        ) {
        InequalityResult::Set(set) => set
        _ => @symsets.empty_set()
      }
      let right = match
        solve_univariate_inequality(
          Expr::Relational(
            if rel == "<" {
              @symcore.RelOp::Lt
            } else {
              @symcore.RelOp::Le
            },
            arg,
            bound,
          ),
          gen,
          relational=false,
        ) {
        InequalityResult::Set(set) => set
        _ => @symsets.empty_set()
      }
      @symsets.intersection([left, right])
    }
    ">" | ">=" => {
      let left = match
        solve_univariate_inequality(
          Expr::Relational(
            if rel == ">" {
              @symcore.RelOp::Lt
            } else {
              @symcore.RelOp::Le
            },
            arg,
            @symcore.mul([@symcore.int(-1), bound]),
          ),
          gen,
          relational=false,
        ) {
        InequalityResult::Set(set) => set
        _ => @symsets.empty_set()
      }
      let right = match
        solve_univariate_inequality(
          Expr::Relational(
            if rel == ">" {
              @symcore.RelOp::Gt
            } else {
              @symcore.RelOp::Ge
            },
            arg,
            bound,
          ),
          gen,
          relational=false,
        ) {
        InequalityResult::Set(set) => set
        _ => @symsets.empty_set()
      }
      @symsets.union([left, right])
    }
    _ => raise SolverError::ValueError("invalid absolute relation: " + rel)
  }
  solver_set_to_relational_expr(solution, gen)
}

///|
/// Conjoin multiple absolute-value inequalities after reducing each one.
///
/// - Does: Applies `reduce_abs_inequality` to each item and combines the
///   results with logical `And`.
/// - Input: `Array[(Expr, String)]` plus one symbol.
/// - Returns: An `Expr`.
/// - Limits: Each item must satisfy the single-`Abs` assumptions enforced by
///   `reduce_abs_inequality`.
pub fn reduce_abs_inequalities(
  exprs : Array[(Expr, String)],
  gen : Expr,
) -> Expr raise SolverError {
  solver_expr_and(
    exprs.map(entry => reduce_abs_inequality(entry.0, entry.1, gen)),
  )
}

///|
fn solver_reduce_inequalities_single(
  inequalities : Array[Expr],
  symbol : Expr,
) -> Expr raise SolverError {
  let mut current : Set = @symsets.reals()
  for inequality in inequalities {
    let next = match @symcore.relational_parts(inequality) {
      Some((_, lhs, rhs)) =>
        if @symcore.has(lhs, @symcore.function("Abs", [])) ||
          @symcore.has(rhs, @symcore.function("Abs", [])) {
          let (_, rel) = solver_relation_expr(inequality)
          let expr = canonical_expr(
            @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])]),
          )
          match
            solve_univariate_inequality(
              reduce_abs_inequality(expr, rel, symbol),
              symbol,
              relational=false,
            ) {
            InequalityResult::Set(set) => set
            _ => @symsets.empty_set()
          }
        } else {
          solver_univariate_inequality_set(inequality, symbol, @symsets.reals())
        }
      None =>
        solver_univariate_inequality_set(inequality, symbol, @symsets.reals())
    }
    current = @symsets.intersection([current, next])
  }
  solver_set_to_relational_expr(current, symbol)
}

///|
fn solver_relevant_symbols(expr : Expr, symbols : Array[Expr]) -> Array[Expr] {
  let free = @symcore.free_symbols(expr)
  let out : Array[Expr] = []
  for symbol in symbols {
    if solver_expr_in_list(free, symbol) {
      out.push(symbol)
    }
  }
  out
}

///|
/// Reduce a collection of independent inequalities.
///
/// - Does: Solves a list of inequalities and combines the result into one
///   relational expression.
/// - Input: `Array[Expr]` and an optional tracked symbol list.
/// - Returns: An `Expr`.
/// - Limits: With more than one tracked symbol, each inequality must depend on
///   at most one tracked symbol or the solver raises `SolverError::ValueError`.
///
/// ```mbt check
/// test "symsolvers reduce_inequalities combines simple one-symbol constraints" {
///   let x = @symcore.Expr::Symbol("x")
///   inspect(
///     @symprint.to_string(
///       reduce_inequalities(
///         [
///           @symcore.Expr::Relational(@symcore.RelOp::Gt, x, @symcore.int(0)),
///           @symcore.Expr::Relational(@symcore.RelOp::Lt, x, @symcore.int(2)),
///         ],
///         symbols=[x],
///       ),
///     ),
///     content="And(0 < x, x < 2)",
///   )
/// }
/// ```
pub fn reduce_inequalities(
  inequalities : Array[Expr],
  symbols? : Array[Expr] = [],
) -> Expr raise SolverError {
  let tracked = if symbols.is_empty() {
    sorted_unique_symbols(solver_collect_free_symbols(inequalities))
  } else {
    sorted_unique_symbols(symbols)
  }
  if tracked.is_empty() {
    return solver_expr_and(inequalities)
  }
  if tracked.length() == 1 {
    return solver_reduce_inequalities_single(inequalities, tracked[0])
  }
  let grouped : Map[String, Array[Expr]] = {}
  let passthrough : Array[Expr] = []
  for inequality in inequalities {
    let relevant = solver_relevant_symbols(inequality, tracked)
    if relevant.is_empty() {
      passthrough.push(inequality)
    } else if relevant.length() == 1 {
      let name = symbol_name(relevant[0])
      let existing = grouped.get(name).unwrap_or([])
      grouped[name] = [..existing, inequality]
    } else {
      raise SolverError::ValueError(
        "reduce_inequalities expects each inequality to depend on at most one symbol",
      )
    }
  }
  let parts = passthrough
  for symbol in tracked {
    let name = symbol_name(symbol)
    match grouped.get(name) {
      Some(group) if !group.is_empty() =>
        parts.push(solver_reduce_inequalities_single(group, symbol))
      _ => ()
    }
  }
  solver_expr_and(parts)
}

///|
fn solver_factor_options(
  eq : Expr,
  gens : Array[Expr],
) -> Array[Array[Expr]] raise SolverError {
  let normalized = normalize_equation(eq)
  if expr_is_zeroish(normalized) == Some(true) {
    return [[]]
  }
  match canonical_expr(normalized) {
    Expr::Mul(args) if args.length() > 1 => {
      let pieces : Array[Array[Expr]] = []
      for arg in args {
        if !@symcore.is_zero(arg) &&
          @symcore.compare_expr(arg, @symcore.int(1)) != 0 &&
          @symcore.compare_expr(arg, @symcore.int(-1)) != 0 {
          pieces.push([canonical_expr(arg)])
        }
      }
      if !pieces.is_empty() {
        return pieces
      }
    }
    _ => ()
  }
  let poly = @sympolys.Poly::from_expr_defaults(
    normalized,
    gens=gens.map(symbol_name),
  ) catch {
    _ => return [[normalized]]
  }
  let (_, factors) = poly.factor_list() catch {
    err => raise wrap_poly_error("factor_system", err)
  }
  if factors.is_empty() {
    [[normalized]]
  } else {
    factors.map(factor => [canonical_expr(factor.0.to_expr())])
  }
}

///|
/// Factor a system of equations into alternative subsystem branches.
///
/// Each returned inner array is one branch that can be solved independently.
/// This is primarily useful as a preprocessing step before nonlinear solving.
pub fn factor_system(
  eqs : Array[Expr],
  gens? : Array[Expr] = [],
) -> Array[Array[Expr]] raise SolverError {
  let inferred = if gens.is_empty() {
    sorted_unique_symbols(solver_collect_free_symbols(eqs))
  } else {
    sorted_unique_symbols(gens)
  }
  let mut products : Array[Array[Expr]] = [[]]
  for eq in eqs {
    let options = solver_factor_options(eq, inferred)
    let next_products : Array[Array[Expr]] = []
    for prefix in products {
      for option in options {
        next_products.push([..prefix, ..option])
      }
    }
    products = next_products
  }
  products
}

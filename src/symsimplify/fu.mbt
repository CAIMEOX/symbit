///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR0`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR0` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr0(expr : Expr) -> Expr {
  simplify(expr)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR1`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR1` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr1(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr1)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR2`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR2` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr2(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr2)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR2I`.
/// - Input: Any `Expr` plus optional `half`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR2I` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr2i(expr : Expr, half? : Bool = false) -> Expr {
  fixpoint_fu(
    expr,
    node => rewrite_bottom_up_fu(node, x => rewrite_tr2i(x, half~)),
    max_passes=6,
  )
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR3`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR3` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr3(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr3)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR4`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR4` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr4(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr4)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR5`.
/// - Input: Any `Expr` plus optional `max` and `pow`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR5` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr5(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  rewrite_bottom_up_fu(expr, node => {
    rewrite_tr56(node, "sin", "cos", max~, pow~, plus=false)
  })
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR6`.
/// - Input: Any `Expr` plus optional `max` and `pow`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR6` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr6(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  rewrite_bottom_up_fu(expr, node => {
    rewrite_tr56(node, "cos", "sin", max~, pow~, plus=false)
  })
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR7`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR7` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr7(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr7)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR8`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR8` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr8(expr : Expr) -> Expr {
  fixpoint_fu(
    expr,
    node => rewrite_bottom_up_fu(node, rewrite_tr8),
    max_passes=6,
  )
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR9`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR9` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr9(expr : Expr) -> Expr {
  fixpoint_fu(
    expr,
    node => rewrite_bottom_up_fu(node, rewrite_tr9),
    max_passes=6,
  )
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR10`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR10` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr10(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr10)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR10I`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR10I` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr10i(expr : Expr) -> Expr {
  fixpoint_fu(
    expr,
    node => rewrite_bottom_up_fu(node, rewrite_tr10i),
    max_passes=6,
  )
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR11`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR11` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr11(expr : Expr) -> Expr {
  fixpoint_fu(
    expr,
    node => rewrite_bottom_up_fu(node, rewrite_tr11),
    max_passes=4,
  )
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR12`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR12` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr12(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr12)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR12I`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR12I` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr12i(expr : Expr) -> Expr {
  fixpoint_fu(
    expr,
    node => rewrite_bottom_up_fu(node, rewrite_tr12i),
    max_passes=6,
  )
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR13`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR13` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr13(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr13)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR14`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR14` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr14(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr14)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR15`.
/// - Input: Any `Expr` plus optional `max` and `pow`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR15` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr15(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  rewrite_bottom_up_fu(expr, node => rewrite_tr15(node, max~, pow~))
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR16`.
/// - Input: Any `Expr` plus optional `max` and `pow`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR16` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr16(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  rewrite_bottom_up_fu(expr, node => rewrite_tr16(node, max~, pow~))
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR111`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR111` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr111(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_tr111)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TR22`.
/// - Input: Any `Expr` plus optional `max` and `pow`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TR22` rule family is applied, so unsupported shapes are returned unchanged.
pub fn tr22(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  rewrite_bottom_up_fu(expr, node => rewrite_tr22(node, max~, pow~))
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TRPOWER`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TRPOWER` rule family is applied, so unsupported shapes are returned unchanged.
pub fn trpower(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_trpower)
}

///|
/// - Does: Applies the Fu trigonometric rewrite rule `TRMORRIE`.
/// - Input: Any `Expr`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the local `TRMORRIE` rule family is applied, so unsupported shapes are returned unchanged.
pub fn trmorrie(expr : Expr) -> Expr {
  rewrite_bottom_up_fu(expr, rewrite_trmorrie)
}

///|
/// - Does: Runs the Fu trigonometric simplification strategy without the final general simplify pass.
/// - Input: Any `Expr` plus optional `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Uses the bounded Fu rule schedule implemented in this package only.
pub fn futrig(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_fu(expr, futrig_once, max_passes~)
}

///|
/// - Does: Runs the Fu trigonometric simplification strategy and then a final general simplify pass.
/// - Input: Any `Expr` plus optional `max_passes`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Uses the bounded Fu rule schedule implemented in this package only.
pub fn fu(expr : Expr, max_passes? : Int = 8) -> Expr {
  simplify(futrig(expr, max_passes~))
}

///|
fn futrig_once(expr : Expr) -> Expr {
  tr0(
    tr4(
      tr13(
        tr12i(
          tr16(
            tr15(
              tr8(
                tr10i(
                  tr6(tr11(tr10(tr5(tr14(tr2i(tr2(tr12(tr1(tr3(expr)))))))))),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  )
}

///|
fn rewrite_bottom_up_fu(expr : Expr, rule : (Expr) -> Expr) -> Expr {
  let rewritten = @symcore.map_children(expr, child => {
    rewrite_bottom_up_fu(child, rule)
  })
  rule(rewritten)
}

///|
fn fixpoint_fu(expr : Expr, f : (Expr) -> Expr, max_passes? : Int = 8) -> Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  let mut cur = expr
  for _ in 0..<passes {
    let next = f(cur)
    if next == cur {
      return next
    }
    cur = next
  }
  cur
}

///|
fn rewrite_tr1(expr : Expr) -> Expr {
  match named_unary_application(expr) {
    Some((name, arg)) if name == "sec" =>
      @symcore.pow(@symcore.function("cos", [arg]), int(-1))
    Some((name, arg)) if name == "csc" =>
      @symcore.pow(@symcore.function("sin", [arg]), int(-1))
    _ => expr
  }
}

///|
fn rewrite_tr2(expr : Expr) -> Expr {
  match named_unary_application(expr) {
    Some((name, arg)) if name == "tan" =>
      @symcore.mul([
        @symcore.function("sin", [arg]),
        @symcore.pow(@symcore.function("cos", [arg]), int(-1)),
      ])
    Some((name, arg)) if name == "cot" =>
      @symcore.mul([
        @symcore.function("cos", [arg]),
        @symcore.pow(@symcore.function("sin", [arg]), int(-1)),
      ])
    _ => expr
  }
}

///|
fn rewrite_tr2i(expr : Expr, half? : Bool = false) -> Expr {
  match expr {
    Expr::Mul(args) => {
      let sin_exp : Map[String, Int] = {}
      let cos_exp : Map[String, Int] = {}
      let plus_exp : Map[String, Int] = {}
      let arg_of : Map[String, Expr] = {}
      let others : Array[Expr] = Array::new()
      for arg in args {
        match parse_tr2i_factor(arg) {
          Some(Tr2iFactor::Sin(key, arg_expr, exp)) => {
            arg_of[key] = arg_expr
            map_add_int(sin_exp, key, exp)
          }
          Some(Tr2iFactor::Cos(key, arg_expr, exp)) => {
            arg_of[key] = arg_expr
            map_add_int(cos_exp, key, exp)
          }
          Some(Tr2iFactor::OnePlusCos(key, arg_expr, exp)) => {
            arg_of[key] = arg_expr
            map_add_int(plus_exp, key, exp)
          }
          None => others.push(arg)
        }
      }

      let tan_terms : Array[Expr] = Array::new()
      for key, arg_expr in arg_of {
        let mut s = map_get_int(sin_exp, key)
        let mut c = map_get_int(cos_exp, key)
        let mut p = map_get_int(plus_exp, key)
        if s > 0 && c < 0 {
          let take = min_int(s, -c)
          tan_terms.push(make_pow(@symcore.function("tan", [arg_expr]), take))
          s = s - take
          c = c + take
        }
        if c > 0 && s < 0 {
          let take = min_int(c, -s)
          tan_terms.push(make_pow(@symcore.function("tan", [arg_expr]), -take))
          c = c - take
          s = s + take
        }
        if half && s > 0 && p < 0 {
          let take = min_int(s, -p)
          tan_terms.push(
            make_pow(
              @symcore.function("tan", [@symcore.mul([half_const(), arg_expr])]),
              take,
            ),
          )
          s = s - take
          p = p + take
        }
        if s != 0 {
          tan_terms.push(make_pow(@symcore.function("sin", [arg_expr]), s))
        }
        if c != 0 {
          tan_terms.push(make_pow(@symcore.function("cos", [arg_expr]), c))
        }
        if p != 0 {
          tan_terms.push(
            make_pow(
              @symcore.add([int(1), @symcore.function("cos", [arg_expr])]),
              p,
            ),
          )
        }
      }
      @symcore.mul(others + tan_terms)
    }
    _ => expr
  }
}

///|
fn rewrite_tr3(expr : Expr) -> Expr {
  match named_unary_application(expr) {
    Some((name, arg)) if is_trig_name(name) =>
      match extract_minus(arg) {
        Some(positive) =>
          if trig_is_odd(name) {
            @symcore.mul([int(-1), @symcore.function(name, [positive])])
          } else {
            @symcore.function(name, [positive])
          }
        None => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr4(expr : Expr) -> Expr {
  match named_unary_application(expr) {
    Some((name, arg)) if is_trig_name(name) =>
      match parse_pi_fraction(arg) {
        Some((p, q)) =>
          match special_trig_value(name, p, q) {
            Some(v) => v
            None => expr
          }
        None => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr56(
  expr : Expr,
  src : String,
  dst : String,
  max? : Int = 4,
  pow? : Bool = false,
  plus? : Bool = false,
) -> Expr {
  match pow_named_unary_application(expr) {
    Some((name, arg, exp_expr)) if name == src =>
      match parse_int(exp_expr) {
        Some(e) if e >= 2 && e <= max => {
          if pow && !is_power_of_two(e) {
            return expr
          }
          if e == 2 {
            let base = @symcore.pow(@symcore.function(dst, [arg]), int(2))
            if plus {
              @symcore.add([int(1), base])
            } else {
              @symcore.add([int(1), @symcore.mul([int(-1), base])])
            }
          } else if e % 2 == 0 {
            let inner = rewrite_tr56(
              @symcore.pow(@symcore.function(src, [arg]), int(2)),
              src,
              dst,
              max~,
              pow~,
              plus~,
            )
            @symcore.pow(inner, int(e / 2))
          } else {
            let inner = rewrite_tr56(
              @symcore.pow(@symcore.function(src, [arg]), int(2)),
              src,
              dst,
              max~,
              pow~,
              plus~,
            )
            @symcore.mul([
              @symcore.function(src, [arg]),
              @symcore.pow(inner, int((e - 1) / 2)),
            ])
          }
        }
        _ => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr7(expr : Expr) -> Expr {
  match pow_named_unary_application(expr) {
    Some((name, arg, exp_expr)) if name == "cos" &&
      parse_int(exp_expr) == Some(2) =>
      @symcore.mul([
        half_const(),
        @symcore.add([
          int(1),
          @symcore.function("cos", [@symcore.mul([int(2), arg])]),
        ]),
      ])
    _ => expr
  }
}

///|
fn rewrite_tr8(expr : Expr) -> Expr {
  match expr {
    Expr::Mul(args) => {
      let trig_indices : Array[Int] = Array::new()
      for i in 0..<args.length() {
        if is_sin_or_cos(args[i]) {
          trig_indices.push(i)
        }
      }
      if trig_indices.length() < 2 {
        return expr
      }
      let i1 = trig_indices[0]
      let i2 = trig_indices[1]
      let a = args[i1]
      let b = args[i2]
      match tr8_pair(a, b) {
        Some(pair_expr) => {
          let factors : Array[Expr] = Array::new()
          for i in 0..<args.length() {
            if i != i1 && i != i2 {
              factors.push(args[i])
            }
          }
          factors.push(pair_expr)
          expand_mul_fu(@symcore.mul(factors))
        }
        None => expr
      }
    }
    _ => expr
  }
}

///|
fn rewrite_tr9(expr : Expr) -> Expr {
  match expr {
    Expr::Add([a, b]) =>
      match (split_num_coeff_trig(a), split_num_coeff_trig(b)) {
        (Some((c1, t1, x1)), Some((c2, t2, x2))) => {
          if !coeff_eq(c1, c2) && !coeff_eq(c1, c2.neg_r()) {
            return expr
          }
          if t1 == "cos" && t2 == "cos" {
            if coeff_eq(c1, c2) {
              @symcore.mul([
                @symcore.Expr::Number(
                  c1.mul_r(@symnum.BigRational::from_int(2)),
                ),
                @symcore.function("cos", [
                  @symcore.mul([half_const(), @symcore.add([x1, x2])]),
                ]),
                @symcore.function("cos", [
                  @symcore.mul([half_const(), @symcore.add([x1, neg_expr(x2)])]),
                ]),
              ])
            } else {
              @symcore.mul([
                @symcore.Expr::Number(
                  c1.mul_r(@symnum.BigRational::from_int(-2)),
                ),
                @symcore.function("sin", [
                  @symcore.mul([half_const(), @symcore.add([x1, x2])]),
                ]),
                @symcore.function("sin", [
                  @symcore.mul([half_const(), @symcore.add([x1, neg_expr(x2)])]),
                ]),
              ])
            }
          } else if t1 == "sin" && t2 == "sin" {
            if coeff_eq(c1, c2) {
              @symcore.mul([
                @symcore.Expr::Number(
                  c1.mul_r(@symnum.BigRational::from_int(2)),
                ),
                @symcore.function("sin", [
                  @symcore.mul([half_const(), @symcore.add([x1, x2])]),
                ]),
                @symcore.function("cos", [
                  @symcore.mul([half_const(), @symcore.add([x1, neg_expr(x2)])]),
                ]),
              ])
            } else {
              @symcore.mul([
                @symcore.Expr::Number(
                  c1.mul_r(@symnum.BigRational::from_int(2)),
                ),
                @symcore.function("cos", [
                  @symcore.mul([half_const(), @symcore.add([x1, x2])]),
                ]),
                @symcore.function("sin", [
                  @symcore.mul([half_const(), @symcore.add([x1, neg_expr(x2)])]),
                ]),
              ])
            }
          } else {
            expr
          }
        }
        _ => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr10(expr : Expr) -> Expr {
  match named_unary_application(expr) {
    Some((name, arg)) if name == "sin" || name == "cos" =>
      match arg {
        Expr::Add(args) if args.length() >= 2 => expand_trig_sum(name, args)
        _ => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr10i(expr : Expr) -> Expr {
  match expr {
    Expr::Add([a, b]) =>
      match (parse_trig_product_term(a), parse_trig_product_term(b)) {
        (Some((c1, n11, x11, n12, x12)), Some((c2, n21, x21, n22, x22))) => {
          if !coeff_eq(c1, c2) && !coeff_eq(c1, c2.neg_r()) {
            return expr
          }
          if n11 == "cos" && n12 == "cos" && n21 == "sin" && n22 == "sin" {
            if x11 == x21 && x12 == x22 {
              if coeff_eq(c1, c2) {
                @symcore.mul([
                  @symcore.Expr::Number(c1),
                  @symcore.function("cos", [@symcore.add([x11, neg_expr(x12)])]),
                ])
              } else {
                @symcore.mul([
                  @symcore.Expr::Number(c1),
                  @symcore.function("cos", [@symcore.add([x11, x12])]),
                ])
              }
            } else {
              expr
            }
          } else if n11 == "sin" && n12 == "cos" && n21 == "cos" && n22 == "sin" {
            if x11 == x22 && x12 == x21 {
              if coeff_eq(c1, c2) {
                @symcore.mul([
                  @symcore.Expr::Number(c1),
                  @symcore.function("sin", [@symcore.add([x11, x12])]),
                ])
              } else {
                @symcore.mul([
                  @symcore.Expr::Number(c1),
                  @symcore.function("sin", [@symcore.add([x11, neg_expr(x12)])]),
                ])
              }
            } else {
              expr
            }
          } else {
            expr
          }
        }
        _ => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr11(expr : Expr) -> Expr {
  match named_unary_application(expr) {
    Some((name, arg)) if name == "sin" =>
      match extract_mul_coeff(arg, 2) {
        Some(inner) =>
          @symcore.mul([
            int(2),
            @symcore.function("sin", [inner]),
            @symcore.function("cos", [inner]),
          ])
        None => expr
      }
    Some((name, arg)) if name == "cos" =>
      match extract_mul_coeff(arg, 2) {
        Some(inner) =>
          @symcore.add([
            @symcore.pow(@symcore.function("cos", [inner]), int(2)),
            neg_expr(@symcore.pow(@symcore.function("sin", [inner]), int(2))),
          ])
        None => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr12(expr : Expr) -> Expr {
  match named_unary_application(expr) {
    Some((name, arg)) if name == "tan" =>
      match arg {
        Expr::Add(args) if args.length() >= 2 => expand_tan_sum(args)
        _ => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr12i(expr : Expr) -> Expr {
  let (num, den) = split_fraction_fu(expr)
  match (parse_tan_sum(num), parse_tan_den(den)) {
    (Some((ns, a, b)), Some((ds, x, y))) => {
      if !((a == x && b == y) || (a == y && b == x)) {
        return expr
      }
      let sign = ns * ds
      if sign == 1 {
        @symcore.function("tan", [@symcore.add([a, b])])
      } else {
        neg_expr(@symcore.function("tan", [@symcore.add([a, b])]))
      }
    }
    _ => expr
  }
}

///|
fn rewrite_tr13(expr : Expr) -> Expr {
  match expr {
    Expr::Mul(args) => {
      let tans : Array[Expr] = Array::new()
      let cots : Array[Expr] = Array::new()
      let others : Array[Expr] = Array::new()
      for arg in args {
        match named_unary_application(arg) {
          Some((name, a)) if name == "tan" => tans.push(a)
          Some((name, a)) if name == "cot" => cots.push(a)
          _ => others.push(arg)
        }
      }
      if tans.length() >= 2 {
        let a = tans[0]
        let b = tans[1]
        others.push(
          @symcore.add([
            int(1),
            neg_expr(
              @symcore.mul([
                @symcore.function("tan", [a]),
                @symcore.pow(
                  @symcore.function("tan", [@symcore.add([a, b])]),
                  int(-1),
                ),
              ]),
            ),
            neg_expr(
              @symcore.mul([
                @symcore.function("tan", [b]),
                @symcore.pow(
                  @symcore.function("tan", [@symcore.add([a, b])]),
                  int(-1),
                ),
              ]),
            ),
          ]),
        )
        for i in 2..<tans.length() {
          others.push(@symcore.function("tan", [tans[i]]))
        }
        for c in cots {
          others.push(@symcore.function("cot", [c]))
        }
        @symcore.mul(others)
      } else if cots.length() >= 2 {
        let a = cots[0]
        let b = cots[1]
        others.push(
          @symcore.add([
            int(1),
            @symcore.mul([
              @symcore.function("cot", [a]),
              @symcore.function("cot", [@symcore.add([a, b])]),
            ]),
            @symcore.mul([
              @symcore.function("cot", [b]),
              @symcore.function("cot", [@symcore.add([a, b])]),
            ]),
          ]),
        )
        for i in 2..<cots.length() {
          others.push(@symcore.function("cot", [cots[i]]))
        }
        for t in tans {
          others.push(@symcore.function("tan", [t]))
        }
        @symcore.mul(others)
      } else {
        expr
      }
    }
    _ => expr
  }
}

///|
fn rewrite_tr14(expr : Expr) -> Expr {
  match expr {
    Expr::Mul(args) => {
      let used : Array[Bool] = Array::make(args.length(), false)
      let out : Array[Expr] = Array::new()
      let mut changed = false
      for i in 0..<args.length() {
        if used[i] {
          continue
        }
        let ai = args[i]
        let mut matched = false
        match parse_trig_pm_one(ai) {
          Some((name_i, arg_i, sign_i)) =>
            for j in (i + 1)..<args.length() {
              if used[j] {
                continue
              }
              match parse_trig_pm_one(args[j]) {
                Some((name_j, arg_j, sign_j)) if name_i == name_j &&
                  arg_i == arg_j &&
                  sign_i != sign_j => {
                  used[j] = true
                  used[i] = true
                  changed = true
                  matched = true
                  if name_i == "cos" {
                    out.push(
                      neg_expr(
                        @symcore.pow(@symcore.function("sin", [arg_i]), int(2)),
                      ),
                    )
                  } else {
                    out.push(
                      neg_expr(
                        @symcore.pow(@symcore.function("cos", [arg_i]), int(2)),
                      ),
                    )
                  }
                  break
                }
                _ => ()
              }
            }
          None => ()
        }
        if !matched {
          out.push(ai)
          used[i] = true
        }
      }
      if changed {
        @symcore.mul(out)
      } else {
        expr
      }
    }
    _ => expr
  }
}

///|
fn rewrite_tr15(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  match pow_named_unary_application(expr) {
    Some((name, arg, exp_expr)) if name == "sin" =>
      match parse_int(exp_expr) {
        Some(e) if e < 0 => {
          let pe = -e
          if pe % 2 == 0 && pe <= max * 2 {
            let k = pe / 2
            if pow && !is_power_of_two(k * 2) {
              return expr
            }
            let inner = @symcore.add([
              int(1),
              @symcore.pow(@symcore.function("cot", [arg]), int(2)),
            ])
            if k == 1 {
              inner
            } else {
              @symcore.pow(inner, int(k))
            }
          } else if pe % 2 == 1 {
            @symcore.mul([
              rewrite_tr15(
                @symcore.pow(@symcore.function("sin", [arg]), int(e + 1)),
                max~,
                pow~,
              ),
              @symcore.pow(@symcore.function("sin", [arg]), int(-1)),
            ])
          } else {
            expr
          }
        }
        _ => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr16(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  match pow_named_unary_application(expr) {
    Some((name, arg, exp_expr)) if name == "cos" =>
      match parse_int(exp_expr) {
        Some(e) if e < 0 => {
          let pe = -e
          if pe % 2 == 0 && pe <= max * 2 {
            let k = pe / 2
            if pow && !is_power_of_two(k * 2) {
              return expr
            }
            let inner = @symcore.add([
              int(1),
              @symcore.pow(@symcore.function("tan", [arg]), int(2)),
            ])
            if k == 1 {
              inner
            } else {
              @symcore.pow(inner, int(k))
            }
          } else if pe % 2 == 1 {
            @symcore.mul([
              rewrite_tr16(
                @symcore.pow(@symcore.function("cos", [arg]), int(e + 1)),
                max~,
                pow~,
              ),
              @symcore.pow(@symcore.function("cos", [arg]), int(-1)),
            ])
          } else {
            expr
          }
        }
        _ => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr111(expr : Expr) -> Expr {
  match pow_named_unary_application(expr) {
    Some((name, arg, exp_expr)) =>
      match parse_int(exp_expr) {
        Some(e) if e < 0 =>
          match name {
            "tan" => make_pow(@symcore.function("cot", [arg]), -e)
            "sin" => make_pow(@symcore.function("csc", [arg]), -e)
            "cos" => make_pow(@symcore.function("sec", [arg]), -e)
            _ => expr
          }
        _ => expr
      }
    _ => expr
  }
}

///|
fn rewrite_tr22(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  match pow_named_unary_application(expr) {
    Some((name, arg, exp_expr)) if name == "tan" || name == "cot" =>
      match parse_int(exp_expr) {
        Some(e) if e >= 2 && e <= max => {
          if pow && !is_power_of_two(e) {
            return expr
          }
          let dst = if name == "tan" { "sec" } else { "csc" }
          let sq = @symcore.add([
            @symcore.pow(@symcore.function(dst, [arg]), int(2)),
            int(-1),
          ])
          if e == 2 {
            sq
          } else if e % 2 == 0 {
            @symcore.pow(sq, int(e / 2))
          } else {
            @symcore.mul([
              @symcore.function(name, [arg]),
              @symcore.pow(sq, int((e - 1) / 2)),
            ])
          }
        }
        _ => expr
      }
    _ => expr
  }
}

///|
fn rewrite_trpower(expr : Expr) -> Expr {
  match pow_named_unary_application(expr) {
    Some((name, x, exp_expr)) if name == "sin" || name == "cos" =>
      match parse_int(exp_expr) {
        Some(n) if n > 1 => trpower_expand(name, x, n)
        _ => expr
      }
    _ => expr
  }
}

///|
fn trpower_expand(trig : String, x : Expr, n : Int) -> Expr {
  let terms : Array[Expr] = Array::new()
  let odd = n % 2 == 1
  let denom = pow2_bigint(n - 1)
  if odd {
    let pref_sign = if trig == "sin" { minus_one_pow((n - 1) / 2) } else { 1 }
    for k in 0..<((n + 1) / 2) {
      let m = n - 2 * k
      let mut sign = pref_sign
      if trig == "sin" {
        sign = sign * minus_one_pow(k)
      }
      let coeff = make_signed_rational(binomial_bigint(n, k), denom, sign)
      let term = @symcore.function(trig, [scaled_angle(x, m)])
      terms.push(scale_expr_rational(coeff, term))
    }
  } else {
    let pref_sign = if trig == "sin" { minus_one_pow(n / 2) } else { 1 }
    for k in 0..<(n / 2) {
      let m = n - 2 * k
      let mut sign = pref_sign
      if trig == "sin" {
        sign = sign * minus_one_pow(k)
      }
      let coeff = make_signed_rational(binomial_bigint(n, k), denom, sign)
      let term = @symcore.function("cos", [scaled_angle(x, m)])
      terms.push(scale_expr_rational(coeff, term))
    }
    let c = make_signed_rational(binomial_bigint(n, n / 2), pow2_bigint(n), 1)
    terms.push(@symcore.Expr::Number(c))
  }
  @symcore.add(terms)
}

///|
fn rewrite_trmorrie(expr : Expr) -> Expr {
  match expr {
    Expr::Mul(args) => {
      let grouped : Map[String, Array[MorrieFactor]] = {}
      let others : Array[Expr] = Array::new()
      for arg in args {
        match parse_morrie_factor(arg) {
          Some(factor) =>
            match grouped.get(factor.core_key) {
              Some(bucket) => bucket.push(factor)
              None => grouped[factor.core_key] = [factor]
            }
          None => others.push(arg)
        }
      }

      let out : Array[Expr] = others.copy()
      let mut changed = false
      for _, bucket in grouped {
        let (rewritten, group_changed) = rewrite_morrie_bucket(bucket)
        if group_changed {
          changed = true
        }
        for term in rewritten {
          out.push(term)
        }
      }
      if changed {
        @symcore.mul(out)
      } else {
        expr
      }
    }
    _ => expr
  }
}

///|
fn parse_morrie_factor(expr : Expr) -> MorrieFactor? {
  match named_unary_application(expr) {
    Some((name, arg)) if name == "cos" => make_morrie_factor(arg, 1)
    _ =>
      match pow_named_unary_application(expr) {
        Some((name, arg, exp_expr)) if name == "cos" =>
          match parse_int(exp_expr) {
            Some(e) if e > 0 => make_morrie_factor(arg, e)
            _ => None
          }
        _ => None
      }
  }
}

///|
fn make_morrie_factor(arg : Expr, exp : Int) -> MorrieFactor? {
  let (coeff_raw, factors) = split_numeric_coeff(arg)
  if coeff_raw.is_zero() {
    return None
  }
  let coeff = if coeff_raw.compare(@symnum.BigRational::zero()) < 0 {
    coeff_raw.neg_r()
  } else {
    coeff_raw
  }
  let core = if factors.is_empty() {
    int(1)
  } else if factors.length() == 1 {
    factors[0]
  } else {
    @symcore.mul(factors)
  }
  let core_key = to_repr(core).to_string()
  Some(MorrieFactor::{ core_key, core, coeff, exp })
}

///|
fn rewrite_morrie_bucket(bucket : Array[MorrieFactor]) -> (Array[Expr], Bool) {
  let powers : Map[String, MorrieCoeff] = {}
  let core = bucket[0].core
  for factor in bucket {
    let key = rational_key(factor.coeff)
    match powers.get(key) {
      Some(cur) =>
        powers[key] = MorrieCoeff::{
          coeff: cur.coeff,
          exp: cur.exp + factor.exp,
        }
      None =>
        powers[key] = MorrieCoeff::{ coeff: factor.coeff, exp: factor.exp }
    }
  }

  let out : Array[Expr] = Array::new()
  let mut changed = false
  while true {
    match find_morrie_chain(powers) {
      Some((start, chain_len)) => {
        let take = morrie_chain_take(powers, start, chain_len)
        if take <= 0 {
          break
        }
        changed = true
        out.push(make_pow(morrie_factor(core, start, chain_len), take))
        let mut coeff = start
        let two = @symnum.BigRational::from_int(2)
        for _ in 0..<chain_len {
          let key = rational_key(coeff)
          match powers.get(key) {
            Some(cur) =>
              powers[key] = MorrieCoeff::{
                coeff: cur.coeff,
                exp: cur.exp - take,
              }
            None => ()
          }
          coeff = coeff.mul_r(two)
        }
      }
      None => break
    }
  }

  for _, v in powers {
    if v.exp <= 0 {
      continue
    }
    let arg = scale_arg_with_coeff(core, v.coeff)
    out.push(make_pow(@symcore.function("cos", [arg]), v.exp))
  }
  (out, changed)
}

///|
fn find_morrie_chain(
  powers : Map[String, MorrieCoeff],
) -> (@symnum.BigRational, Int)? {
  let mut has_best = false
  let mut best_coeff = @symnum.BigRational::one()
  let mut best_len = 0
  for _, entry in powers {
    if entry.exp <= 0 {
      continue
    }
    let len = morrie_chain_len(powers, entry.coeff)
    if len <= 1 {
      continue
    }
    if !has_best || entry.coeff.compare(best_coeff) < 0 {
      has_best = true
      best_coeff = entry.coeff
      best_len = len
    }
  }
  if has_best {
    Some((best_coeff, best_len))
  } else {
    None
  }
}

///|
fn morrie_chain_len(
  powers : Map[String, MorrieCoeff],
  start : @symnum.BigRational,
) -> Int {
  let mut len = 1
  let two = @symnum.BigRational::from_int(2)
  let mut coeff = start.mul_r(two)
  while true {
    let key = rational_key(coeff)
    match powers.get(key) {
      Some(cur) if cur.exp > 0 => {
        len = len + 1
        coeff = coeff.mul_r(two)
      }
      _ => break
    }
  }
  len
}

///|
fn morrie_chain_take(
  powers : Map[String, MorrieCoeff],
  start : @symnum.BigRational,
  chain_len : Int,
) -> Int {
  let mut take = 0
  let two = @symnum.BigRational::from_int(2)
  let mut coeff = start
  for i in 0..<chain_len {
    let key = rational_key(coeff)
    match powers.get(key) {
      Some(cur) => if i == 0 || cur.exp < take { take = cur.exp }
      None => return 0
    }
    coeff = coeff.mul_r(two)
  }
  take
}

///|
fn morrie_factor(
  core : Expr,
  start : @symnum.BigRational,
  chain_len : Int,
) -> Expr {
  let numer_coeff = scale_rational_pow2(start, chain_len)
  let numer_arg = scale_arg_with_coeff(core, numer_coeff)
  let denom_arg = scale_arg_with_coeff(core, start)
  @symcore.mul([
    pow2_inv_expr(chain_len),
    @symcore.function("sin", [numer_arg]),
    @symcore.pow(@symcore.function("sin", [denom_arg]), int(-1)),
  ])
}

///|
fn scale_arg_with_coeff(core : Expr, coeff : @symnum.BigRational) -> Expr {
  if coeff.is_one() {
    core
  } else {
    @symcore.mul([@symcore.Expr::Number(coeff), core])
  }
}

///|
fn scale_rational_pow2(
  coeff : @symnum.BigRational,
  pow : Int,
) -> @symnum.BigRational {
  if pow <= 0 {
    return coeff
  }
  let mut out = coeff
  let two = @symnum.BigRational::from_int(2)
  for _ in 0..<pow {
    out = out.mul_r(two)
  }
  out
}

///|
fn pow2_inv_expr(pow : Int) -> Expr {
  if pow <= 0 {
    return int(1)
  }
  @symcore.Expr::Number(
    make_signed_rational(BigInt::from_int(1), pow2_bigint(pow), 1),
  )
}

///|
fn make_signed_rational(
  numer : BigInt,
  denom : BigInt,
  sign : Int,
) -> @symnum.BigRational {
  let signed = if sign < 0 { numer.neg() } else { numer }
  @symnum.BigRational::new(signed, denom) catch {
    _ => abort("invalid exact rational in trigonometric expansion")
  }
}

///|
fn scale_expr_rational(coeff : @symnum.BigRational, expr : Expr) -> Expr {
  if coeff.is_zero() {
    int(0)
  } else if coeff.is_one() {
    expr
  } else if coeff.compare(@symnum.BigRational::from_int(-1)) == 0 {
    neg_expr(expr)
  } else {
    @symcore.mul([@symcore.Expr::Number(coeff), expr])
  }
}

///|
fn scaled_angle(arg : Expr, k : Int) -> Expr {
  if k == 1 {
    arg
  } else {
    @symcore.mul([int(k), arg])
  }
}

///|
fn binomial_bigint(n : Int, k : Int) -> BigInt {
  if k < 0 || k > n {
    return BigInt::from_int(0)
  }
  let kk = if k < n - k { k } else { n - k }
  let mut out = BigInt::from_int(1)
  for i in 1..<(kk + 1) {
    out = out.mul(BigInt::from_int(n - kk + i))
    out = out.div(BigInt::from_int(i))
  }
  out
}

///|
fn pow2_bigint(n : Int) -> BigInt {
  let mut out = BigInt::from_int(1)
  for _ in 0..<n {
    out = out.mul(BigInt::from_int(2))
  }
  out
}

///|
fn minus_one_pow(n : Int) -> Int {
  if n % 2 == 0 {
    1
  } else {
    -1
  }
}

///|
fn rational_key(r : @symnum.BigRational) -> String {
  "\{r.numerator().to_string()}/\{r.denominator().to_string()}"
}

///|
fn split_fraction_fu(expr : Expr) -> (Expr, Expr) {
  match expr {
    Expr::Pow(base, exp_expr) =>
      match parse_int(exp_expr) {
        Some(e) if e < 0 => (int(1), @symcore.pow(base, int(-e)))
        _ => (expr, int(1))
      }
    Expr::Mul(args) => {
      let num : Array[Expr] = Array::new()
      let den : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Pow(base, exp_expr) =>
            match parse_int(exp_expr) {
              Some(e) if e < 0 => den.push(@symcore.pow(base, int(-e)))
              _ => num.push(arg)
            }
          _ => num.push(arg)
        }
      }
      (@symcore.mul(num), @symcore.mul(den))
    }
    _ => (expr, int(1))
  }
}

///|
fn expand_trig_sum(name : String, args : Array[Expr]) -> Expr {
  if args.length() == 1 {
    return @symcore.function(name, [args[0]])
  }
  let a = args[0]
  let rest : Array[Expr] = Array::new()
  for i in 1..<args.length() {
    rest.push(args[i])
  }
  let b_expr = @symcore.add(rest)
  let sin_a = @symcore.function("sin", [a])
  let cos_a = @symcore.function("cos", [a])
  let sin_b = match b_expr {
    Expr::Add(bs) => expand_trig_sum("sin", bs)
    _ => @symcore.function("sin", [b_expr])
  }
  let cos_b = match b_expr {
    Expr::Add(bs) => expand_trig_sum("cos", bs)
    _ => @symcore.function("cos", [b_expr])
  }
  if name == "sin" {
    @symcore.add([@symcore.mul([sin_a, cos_b]), @symcore.mul([cos_a, sin_b])])
  } else {
    @symcore.add([
      @symcore.mul([cos_a, cos_b]),
      neg_expr(@symcore.mul([sin_a, sin_b])),
    ])
  }
}

///|
fn expand_tan_sum(args : Array[Expr]) -> Expr {
  if args.length() == 1 {
    return @symcore.function("tan", [args[0]])
  }
  let a = args[0]
  let rest : Array[Expr] = Array::new()
  for i in 1..<args.length() {
    rest.push(args[i])
  }
  let b_expr = @symcore.add(rest)
  let tan_b = match b_expr {
    Expr::Add(bs) => expand_tan_sum(bs)
    _ => @symcore.function("tan", [b_expr])
  }
  let tan_a = @symcore.function("tan", [a])
  @symcore.mul([
    @symcore.add([tan_a, tan_b]),
    @symcore.pow(
      @symcore.add([int(1), neg_expr(@symcore.mul([tan_a, tan_b]))]),
      int(-1),
    ),
  ])
}

///|
fn tr8_pair(a : Expr, b : Expr) -> Expr? {
  match (as_sin_or_cos(a), as_sin_or_cos(b)) {
    (Some(("cos", x)), Some(("cos", y))) =>
      Some(
        @symcore.mul([
          half_const(),
          @symcore.add([
            @symcore.function("cos", [@symcore.add([x, y])]),
            @symcore.function("cos", [@symcore.add([x, neg_expr(y)])]),
          ]),
        ]),
      )
    (Some(("sin", x)), Some(("sin", y))) =>
      Some(
        @symcore.mul([
          half_const(),
          @symcore.add([
            neg_expr(@symcore.function("cos", [@symcore.add([x, y])])),
            @symcore.function("cos", [@symcore.add([x, neg_expr(y)])]),
          ]),
        ]),
      )
    (Some(("sin", x)), Some(("cos", y))) =>
      Some(
        @symcore.mul([
          half_const(),
          @symcore.add([
            @symcore.function("sin", [@symcore.add([x, y])]),
            @symcore.function("sin", [@symcore.add([x, neg_expr(y)])]),
          ]),
        ]),
      )
    (Some(("cos", x)), Some(("sin", y))) =>
      Some(
        @symcore.mul([
          half_const(),
          @symcore.add([
            @symcore.function("sin", [@symcore.add([x, y])]),
            neg_expr(@symcore.function("sin", [@symcore.add([x, neg_expr(y)])])),
          ]),
        ]),
      )
    _ => None
  }
}

///|
fn parse_tan_sum(expr : Expr) -> (Int, Expr, Expr)? {
  match expr {
    Expr::Add([a, b]) =>
      match (as_tan(a), as_tan(b)) {
        (Some(x), Some(y)) => Some((1, x, y))
        _ =>
          match (as_tan(neg_term(a)), as_tan(neg_term(b))) {
            (Some(x), Some(y)) => Some((-1, x, y))
            _ => None
          }
      }
    _ => None
  }
}

///|
fn parse_tan_den(expr : Expr) -> (Int, Expr, Expr)? {
  match expr {
    Expr::Add(args) if args.length() == 2 => {
      let one_first = is_one_expr(args[0])
      let one_second = is_one_expr(args[1])
      if one_first {
        match parse_neg_tan_mul(args[1]) {
          Some((a, b)) => Some((1, a, b))
          None =>
            match parse_pos_tan_mul(args[1]) {
              Some((a, b)) => Some((-1, a, b))
              None => None
            }
        }
      } else if one_second {
        match parse_neg_tan_mul(args[0]) {
          Some((a, b)) => Some((1, a, b))
          None =>
            match parse_pos_tan_mul(args[0]) {
              Some((a, b)) => Some((-1, a, b))
              None => None
            }
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn parse_neg_tan_mul(expr : Expr) -> (Expr, Expr)? {
  let (coeff, factors) = split_numeric_coeff(expr)
  if coeff.compare(@symnum.BigRational::from_int(-1)) != 0 ||
    factors.length() != 2 {
    return None
  }
  match (as_tan(factors[0]), as_tan(factors[1])) {
    (Some(x), Some(y)) => Some((x, y))
    _ => None
  }
}

///|
fn parse_pos_tan_mul(expr : Expr) -> (Expr, Expr)? {
  let (coeff, factors) = split_numeric_coeff(expr)
  if coeff.compare(@symnum.BigRational::one()) != 0 || factors.length() != 2 {
    return None
  }
  match (as_tan(factors[0]), as_tan(factors[1])) {
    (Some(x), Some(y)) => Some((x, y))
    _ => None
  }
}

///|
fn parse_trig_product_term(
  expr : Expr,
) -> (@symnum.BigRational, String, Expr, String, Expr)? {
  let (coeff, factors) = split_numeric_coeff(expr)
  if factors.length() != 2 {
    return None
  }
  match (as_sin_or_cos(factors[0]), as_sin_or_cos(factors[1])) {
    (Some((n1, x1)), Some((n2, x2))) => Some((coeff, n1, x1, n2, x2))
    _ => None
  }
}

///|
fn split_num_coeff_trig(expr : Expr) -> (@symnum.BigRational, String, Expr)? {
  let (coeff, factors) = split_numeric_coeff(expr)
  if factors.length() != 1 {
    return None
  }
  match as_sin_or_cos(factors[0]) {
    Some((name, arg)) => Some((coeff, name, arg))
    None => None
  }
}

///|
fn split_numeric_coeff(expr : Expr) -> (@symnum.BigRational, Array[Expr]) {
  match expr {
    Expr::Number(n) => (n, [])
    Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Number(n) => coeff = coeff.mul_r(n)
          _ => rest.push(arg)
        }
      }
      (coeff, rest)
    }
    _ => (@symnum.BigRational::one(), [expr])
  }
}

///|
fn parse_trig_pm_one(expr : Expr) -> (String, Expr, Int)? {
  match expr {
    Expr::Add(args) if args.length() == 2 => {
      let mut trig_name = ""
      let mut trig_arg = int(0)
      let mut has_trig = false
      let mut sign = 0
      for arg in args {
        match named_unary_application(arg) {
          Some((name, inner)) if name == "sin" || name == "cos" => {
            trig_name = name
            trig_arg = inner
            has_trig = true
          }
          _ =>
            match arg {
              Expr::Number(n) if n.is_one() => sign = 1
              Expr::Number(n) if n.compare(@symnum.BigRational::from_int(-1)) ==
                0 => sign = -1
              _ => ()
            }
        }
      }
      if has_trig && sign != 0 {
        Some((trig_name, trig_arg, sign))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn parse_tr2i_factor(expr : Expr) -> Tr2iFactor? {
  match named_unary_application(expr) {
    Some((name, arg)) if name == "sin" =>
      Some(Tr2iFactor::Sin(to_repr(arg).to_string(), arg, 1))
    Some((name, arg)) if name == "cos" =>
      Some(Tr2iFactor::Cos(to_repr(arg).to_string(), arg, 1))
    _ =>
      match pow_named_unary_application(expr) {
        Some((name, arg, exp_expr)) =>
          match parse_int(exp_expr) {
            Some(e) =>
              match name {
                "sin" => Some(Tr2iFactor::Sin(to_repr(arg).to_string(), arg, e))
                "cos" => Some(Tr2iFactor::Cos(to_repr(arg).to_string(), arg, e))
                _ =>
                  match
                    parse_one_plus_cos(
                      @symcore.pow(@symcore.function(name, [arg]), exp_expr),
                    ) {
                    Some(inner) =>
                      Some(
                        Tr2iFactor::OnePlusCos(
                          to_repr(inner).to_string(),
                          inner,
                          e,
                        ),
                      )
                    None => None
                  }
              }
            None => None
          }
        _ =>
          match parse_one_plus_cos(expr) {
            Some(arg) =>
              Some(Tr2iFactor::OnePlusCos(to_repr(arg).to_string(), arg, 1))
            None => None
          }
      }
  }
}

///|
fn parse_one_plus_cos(expr : Expr) -> Expr? {
  match expr {
    Expr::Add(args) if args.length() == 2 => {
      let mut has_one = false
      let mut arg = int(0)
      let mut has_cos = false
      for item in args {
        match item {
          Expr::Number(n) if n.is_one() => has_one = true
          _ if unary_application_arg(item, "cos") is Some(x) => {
            has_cos = true
            arg = x
          }
          _ => ()
        }
      }
      if has_one && has_cos {
        Some(arg)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn parse_pi_fraction(expr : Expr) -> (Int, Int)? {
  match expr {
    Expr::Number(n) if n.is_zero() => Some((0, 1))
    _ =>
      match @symcore.number_symbol_kind(expr) {
        Some(@symcore.NumberSymbolKind::Pi) => Some((1, 1))
        _ =>
          match expr {
            Expr::Mul(args) => {
              let mut coeff = @symnum.BigRational::one()
              let mut has_pi = false
              for arg in args {
                match arg {
                  Expr::Number(n) => coeff = coeff.mul_r(n)
                  _ =>
                    match @symcore.number_symbol_kind(arg) {
                      Some(@symcore.NumberSymbolKind::Pi) => has_pi = true
                      _ => return None
                    }
                }
              }
              if !has_pi {
                return None
              }
              Some((coeff.numerator().to_int(), coeff.denominator().to_int()))
            }
            _ => None
          }
      }
  }
}

///|
fn special_trig_value(name : String, p_raw : Int, q : Int) -> Expr? {
  let period = if name == "tan" || name == "cot" { q } else { 2 * q }
  let p = mod_pos(p_raw, period)
  if name == "sin" {
    return special_sin(p, q)
  }
  if name == "cos" {
    return special_cos(p, q)
  }
  if name == "tan" {
    match (special_sin(p, q), special_cos(p, q)) {
      (Some(s), Some(c)) if !is_zero_expr(c) =>
        Some(@symcore.mul([s, @symcore.pow(c, int(-1))]))
      _ => None
    }
  } else if name == "cot" {
    match (special_sin(p, q), special_cos(p, q)) {
      (Some(s), Some(c)) if !is_zero_expr(s) =>
        Some(@symcore.mul([c, @symcore.pow(s, int(-1))]))
      _ => None
    }
  } else if name == "sec" {
    match special_cos(p, q) {
      Some(c) if !is_zero_expr(c) => Some(@symcore.pow(c, int(-1)))
      _ => None
    }
  } else if name == "csc" {
    match special_sin(p, q) {
      Some(s) if !is_zero_expr(s) => Some(@symcore.pow(s, int(-1)))
      _ => None
    }
  } else {
    None
  }
}

///|
fn special_sin(p : Int, q : Int) -> Expr? {
  if q == 1 {
    return if p % 2 == 0 { Some(int(0)) } else { Some(int(0)) }
  }
  if q == 2 {
    return match p {
      0 => Some(int(0))
      1 => Some(int(1))
      2 => Some(int(0))
      3 => Some(int(-1))
      _ => None
    }
  }
  if q == 3 {
    return match p {
      0 => Some(int(0))
      1 => Some(sqrt3_over_2())
      2 => Some(sqrt3_over_2())
      3 => Some(int(0))
      4 => Some(neg_expr(sqrt3_over_2()))
      5 => Some(neg_expr(sqrt3_over_2()))
      _ => None
    }
  }
  if q == 4 {
    return match p {
      0 => Some(int(0))
      1 => Some(sqrt2_over_2())
      2 => Some(int(1))
      3 => Some(sqrt2_over_2())
      4 => Some(int(0))
      5 => Some(neg_expr(sqrt2_over_2()))
      6 => Some(int(-1))
      7 => Some(neg_expr(sqrt2_over_2()))
      _ => None
    }
  }
  if q == 6 {
    return match p {
      0 => Some(int(0))
      1 => Some(half_const())
      2 => Some(sqrt3_over_2())
      3 => Some(int(1))
      4 => Some(sqrt3_over_2())
      5 => Some(half_const())
      6 => Some(int(0))
      7 => Some(neg_expr(half_const()))
      8 => Some(neg_expr(sqrt3_over_2()))
      9 => Some(int(-1))
      10 => Some(neg_expr(sqrt3_over_2()))
      11 => Some(neg_expr(half_const()))
      _ => None
    }
  }
  None
}

///|
fn special_cos(p : Int, q : Int) -> Expr? {
  if q == 1 {
    return if p % 2 == 0 { Some(int(1)) } else { Some(int(-1)) }
  }
  if q == 2 {
    return match p {
      0 => Some(int(1))
      1 => Some(int(0))
      2 => Some(int(-1))
      3 => Some(int(0))
      _ => None
    }
  }
  if q == 3 {
    return match p {
      0 => Some(int(1))
      1 => Some(half_const())
      2 => Some(neg_expr(half_const()))
      3 => Some(int(-1))
      4 => Some(neg_expr(half_const()))
      5 => Some(half_const())
      _ => None
    }
  }
  if q == 4 {
    return match p {
      0 => Some(int(1))
      1 => Some(sqrt2_over_2())
      2 => Some(int(0))
      3 => Some(neg_expr(sqrt2_over_2()))
      4 => Some(int(-1))
      5 => Some(neg_expr(sqrt2_over_2()))
      6 => Some(int(0))
      7 => Some(sqrt2_over_2())
      _ => None
    }
  }
  if q == 6 {
    return match p {
      0 => Some(int(1))
      1 => Some(sqrt3_over_2())
      2 => Some(half_const())
      3 => Some(int(0))
      4 => Some(neg_expr(half_const()))
      5 => Some(neg_expr(sqrt3_over_2()))
      6 => Some(int(-1))
      7 => Some(neg_expr(sqrt3_over_2()))
      8 => Some(neg_expr(half_const()))
      9 => Some(int(0))
      10 => Some(half_const())
      11 => Some(sqrt3_over_2())
      _ => None
    }
  }
  None
}

///|
fn as_sin_or_cos(expr : Expr) -> (String, Expr)? {
  match named_unary_application(expr) {
    Some((name, arg)) if name == "sin" || name == "cos" => Some((name, arg))
    _ => None
  }
}

///|
fn as_tan(expr : Expr) -> Expr? {
  unary_application_arg(expr, "tan")
}

///|
fn is_trig_name(name : String) -> Bool {
  name == "sin" ||
  name == "cos" ||
  name == "tan" ||
  name == "cot" ||
  name == "sec" ||
  name == "csc"
}

///|
fn trig_is_odd(name : String) -> Bool {
  name == "sin" || name == "tan" || name == "cot" || name == "csc"
}

///|
fn is_sin_or_cos(expr : Expr) -> Bool {
  match named_unary_application(expr) {
    Some((name, _)) => name == "sin" || name == "cos"
    None => false
  }
}

///|
fn parse_int(expr : Expr) -> Int? {
  match expr {
    Expr::Number(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn extract_mul_coeff(expr : Expr, k : Int) -> Expr? {
  match expr {
    Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Number(n) => coeff = coeff.mul_r(n)
          _ => rest.push(arg)
        }
      }
      if coeff.compare(@symnum.BigRational::from_int(k)) == 0 {
        Some(@symcore.mul(rest))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn extract_minus(expr : Expr) -> Expr? {
  match expr {
    Expr::Number(n) if n.compare(@symnum.BigRational::zero()) < 0 =>
      Some(@symcore.Expr::Number(n.neg_r()))
    Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Number(n) => coeff = coeff.mul_r(n)
          _ => rest.push(arg)
        }
      }
      if coeff.compare(@symnum.BigRational::zero()) < 0 {
        let abs_coeff = coeff.neg_r()
        if abs_coeff.is_one() {
          Some(@symcore.mul(rest))
        } else {
          Some(
            @symcore.mul([@symcore.Expr::Number(abs_coeff), @symcore.mul(rest)]),
          )
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn make_pow(base : Expr, exp : Int) -> Expr {
  if exp == 0 {
    int(1)
  } else if exp == 1 {
    base
  } else {
    @symcore.pow(base, int(exp))
  }
}

///|
fn neg_expr(expr : Expr) -> Expr {
  @symcore.mul([int(-1), expr])
}

///|
fn neg_term(expr : Expr) -> Expr {
  let (coeff, factors) = split_numeric_coeff(expr)
  if coeff.compare(@symnum.BigRational::from_int(-1)) == 0 {
    @symcore.mul(factors)
  } else {
    neg_expr(expr)
  }
}

///|
fn is_zero_expr(expr : Expr) -> Bool {
  numeric_zero_pred(expr)
}

///|
fn is_one_expr(expr : Expr) -> Bool {
  numeric_one_pred(expr)
}

///|
fn mod_pos(x : Int, m : Int) -> Int {
  let r = x % m
  if r < 0 {
    r + m
  } else {
    r
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn is_power_of_two(n : Int) -> Bool {
  if n <= 0 {
    return false
  }
  let mut x = n
  while x % 2 == 0 {
    x = x / 2
  }
  x == 1
}

///|
fn coeff_eq(a : @symnum.BigRational, b : @symnum.BigRational) -> Bool {
  a.compare(b) == 0
}

///|
fn half_const() -> Expr {
  @symcore.rational_from_ints(1, 2) catch {
    _ => @symcore.int(1) * (@symcore.int(2) ^ @symcore.int(-1))
  }
}

///|
fn sqrt2_over_2() -> Expr {
  @symcore.mul([half_const(), @symcore.function("sqrt", [int(2)])])
}

///|
fn sqrt3_over_2() -> Expr {
  @symcore.mul([half_const(), @symcore.function("sqrt", [int(3)])])
}

///|
fn map_get_int(m : Map[String, Int], key : String) -> Int {
  match m.get(key) {
    Some(v) => v
    None => 0
  }
}

///|
fn map_add_int(m : Map[String, Int], key : String, delta : Int) -> Unit {
  let cur = map_get_int(m, key)
  m[key] = cur + delta
}

///|
fn expand_mul_fu(expr : Expr) -> Expr {
  match expr {
    Expr::Mul(args) => {
      let mut terms : Array[Expr] = [int(1)]
      for arg in args {
        match arg {
          Expr::Add(parts) => {
            let next : Array[Expr] = Array::new()
            for t in terms {
              for p in parts {
                next.push(@symcore.mul([t, p]))
              }
            }
            terms = next
          }
          _ =>
            for i in 0..<terms.length() {
              terms[i] = @symcore.mul([terms[i], arg])
            }
        }
      }
      if terms.length() == 1 {
        terms[0]
      } else {
        @symcore.add(terms)
      }
    }
    _ => expr
  }
}

///|
priv struct MorrieFactor {
  core_key : String
  core : Expr
  coeff : @symnum.BigRational
  exp : Int
}

///|
priv struct MorrieCoeff {
  coeff : @symnum.BigRational
  exp : Int
}

///|
priv enum Tr2iFactor {
  Sin(String, Expr, Int)
  Cos(String, Expr, Int)
  OnePlusCos(String, Expr, Int)
}

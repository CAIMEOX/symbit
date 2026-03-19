///|
/// Run the CSE pre-pass that prepares subtree structure.
pub fn sub_pre(expr : Expr) -> Expr {
  rewrite_bottom_up_cseopts(expr, rewrite_sub_pre)
}

///|
/// Run the CSE post-pass cleanup transformation.
pub fn sub_post(expr : Expr) -> Expr {
  rewrite_bottom_up_cseopts(expr, rewrite_sub_post)
}

///|
fn rewrite_bottom_up_cseopts(
  expr : Expr,
  rule : (Expr) -> Expr,
) -> Expr {
  let rewritten = @symcore.map_children(expr, child => {
    rewrite_bottom_up_cseopts(child, rule)
  })
  rule(rewritten)
}

///|
fn rewrite_sub_pre(expr : Expr) -> Expr {
  match expr {
    Expr::Add([a, b]) => {
      let (sa, pa) = split_sign(a)
      let (sb, pb) = split_sign(b)
      if sa < 0 && sb > 0 {
        @symcore.mul([
          int(-1),
          @symcore.add([pa, @symcore.mul([int(-1), pb])]),
        ])
      } else if sb < 0 && sa > 0 {
        @symcore.mul([
          int(-1),
          @symcore.add([pb, @symcore.mul([int(-1), pa])]),
        ])
      } else {
        expr
      }
    }
    _ => expr
  }
}

///|
fn rewrite_sub_post(expr : Expr) -> Expr {
  match expr {
    Expr::Mul(args) => {
      if args.length() < 2 {
        return expr
      }
      let filtered : Array[Expr] = Array::new()
      let mut neg_count = 0
      for arg in args {
        match arg {
          Expr::Number(n) if n.is_one() => ()
          Expr::Number(n) if n.compare(
              @symnum.BigRational::from_int(-1),
            ) ==
            0 => neg_count = neg_count + 1
          _ => filtered.push(arg)
        }
      }
      let out = @symcore.mul(filtered)
      if neg_count % 2 == 1 {
        @symcore.mul([int(-1), out])
      } else {
        out
      }
    }
    _ => expr
  }
}

///|
fn split_sign(expr : Expr) -> (Int, Expr) {
  match expr {
    Expr::Number(n) =>
      if n.compare(@symnum.BigRational::zero()) < 0 {
        (-1, @symcore.number(n.neg_r()))
      } else {
        (1, expr)
      }
    Expr::Mul(args) => {
      let mut sign = 1
      let factors : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Number(n) if n.compare(@symnum.BigRational::zero()) < 0 => {
            sign = -sign
            factors.push(@symcore.number(n.neg_r()))
          }
          _ => factors.push(arg)
        }
      }
      (sign, @symcore.mul(factors))
    }
    _ => (1, expr)
  }
}

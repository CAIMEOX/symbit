///|
/// Fourier series with symbolic coefficient projection for polynomial/trig inputs.

///|
pub enum FourierSeriesResult {
  Expr(@symcore.Expr)
  Series(FourierSeries)
}

///|
pub struct FourierSeries {
  expr : @symcore.Expr
  x : @symcore.Expr
  a : @symcore.Expr
  b : @symcore.Expr
}

///|
priv enum AtomKind {
  Sin
  Cos
  Exp
  Sinh
  Cosh
}

///|
priv struct LinearForm {
  coeff : @symcore.Expr
  shift : @symcore.Expr
}

///|
priv struct LinearAtom {
  kind : AtomKind
  form : LinearForm
}

///|
fn depends_on(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(s) => s == name
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(child => depends_on(child, name))
    @symcore.Expr::Pow(base, exp) =>
      depends_on(base, name) || depends_on(exp, name)
    @symcore.Expr::Function(_, args) =>
      args.any(child => depends_on(child, name))
    _ => false
  }
}

///|
fn expr_div(num : @symcore.Expr, den : @symcore.Expr) -> @symcore.Expr {
  expr_mul(num, @symcore.pow(den, @symcore.int(-1)))
}

///|
fn subst_var(
  expr : @symcore.Expr,
  var_name : String,
  value : @symcore.Expr,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = value
  @symcore.subst(expr, env)
}

///|
fn split_linear_x_term(
  term : @symcore.Expr,
  x : @symcore.Expr,
  var_name : String,
) -> @symcore.Expr? {
  if term == x {
    return Some(@symcore.int(1))
  }
  match term {
    @symcore.Expr::Mul(args) => {
      let mut seen_x = false
      let coeff_args : Array[@symcore.Expr] = Array::new()
      for factor in args {
        if factor == x {
          if seen_x {
            return None
          }
          seen_x = true
        } else if contains_symbol(factor, var_name) {
          return None
        } else {
          coeff_args.push(factor)
        }
      }
      if !seen_x {
        None
      } else if coeff_args.is_empty() {
        Some(@symcore.int(1))
      } else {
        Some(@symcore.mul(coeff_args))
      }
    }
    _ => None
  }
}

///|
fn parse_linear_form(
  arg : @symcore.Expr,
  x : @symcore.Expr,
  var_name : String,
) -> LinearForm? {
  if !contains_symbol(arg, var_name) {
    return Some(LinearForm::{ coeff: @symcore.int(0), shift: arg })
  }
  match arg {
    @symcore.Expr::Add(args) => {
      let mut coeff = @symcore.int(0)
      let const_terms : Array[@symcore.Expr] = Array::new()
      for term in args {
        if contains_symbol(term, var_name) {
          match split_linear_x_term(term, x, var_name) {
            Some(c) => coeff = expr_add(coeff, c)
            None => return None
          }
        } else {
          const_terms.push(term)
        }
      }
      let shift = if const_terms.is_empty() {
        @symcore.int(0)
      } else {
        @symcore.add(const_terms)
      }
      Some(LinearForm::{ coeff, shift })
    }
    _ =>
      match split_linear_x_term(arg, x, var_name) {
        Some(c) => Some(LinearForm::{ coeff: c, shift: @symcore.int(0) })
        None => None
      }
  }
}

///|
fn linear_arg(form : LinearForm, x : @symcore.Expr) -> @symcore.Expr {
  expr_add(expr_mul(form.coeff, x), form.shift)
}

///|
fn atom_expr(atom : LinearAtom, x : @symcore.Expr) -> @symcore.Expr {
  let arg = linear_arg(atom.form, x)
  let name = match atom.kind {
    AtomKind::Sin => "sin"
    AtomKind::Cos => "cos"
    AtomKind::Exp => "exp"
    AtomKind::Sinh => "sinh"
    AtomKind::Cosh => "cosh"
  }
  @symcore.function(name, [arg])
}

///|
fn parse_linear_atom(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  var_name : String,
) -> LinearAtom? {
  match expr {
    @symcore.Expr::Function(name, args) if args.length() == 1 => {
      let kind = match name {
        "sin" => Some(AtomKind::Sin)
        "cos" => Some(AtomKind::Cos)
        "exp" => Some(AtomKind::Exp)
        "sinh" => Some(AtomKind::Sinh)
        "cosh" => Some(AtomKind::Cosh)
        _ => None
      }
      match kind {
        Some(k) =>
          match parse_linear_form(args[0], x, var_name) {
            Some(form) => Some(LinearAtom::{ kind: k, form })
            None => None
          }
        None => None
      }
    }
    _ => None
  }
}

///|
fn form_add(a : LinearForm, b : LinearForm) -> LinearForm {
  LinearForm::{
    coeff: expr_add(a.coeff, b.coeff),
    shift: expr_add(a.shift, b.shift),
  }
}

///|
fn form_sub(a : LinearForm, b : LinearForm) -> LinearForm {
  LinearForm::{
    coeff: expr_sub(a.coeff, b.coeff),
    shift: expr_sub(a.shift, b.shift),
  }
}

///|
fn form_neg(a : LinearForm) -> LinearForm {
  LinearForm::{ coeff: expr_neg(a.coeff), shift: expr_neg(a.shift) }
}

///|
fn eval_at(
  expr : @symcore.Expr,
  var_name : String,
  value : @symcore.Expr,
) -> @symcore.Expr {
  subst_var(expr, var_name, value)
}

///|
fn definite_integral_expr(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Integral", [expr, @symcore.function("Tuple", [x, a, b])])
}

///|
fn integral_poly(
  poly : Array[@symcore.Expr],
  x : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  let mut acc = @symcore.int(0)
  for i in 0..<poly.length() {
    let coeff = poly[i]
    if is_zero_expr(coeff) {
      continue
    }
    let p = i + 1
    let anti_term =
      expr_mul(coeff, expr_div(@symcore.pow(x, @symcore.int(p)), @symcore.int(p)))
    let at_b = eval_at(anti_term, var_name, b)
    let at_a = eval_at(anti_term, var_name, a)
    acc = expr_add(acc, expr_sub(at_b, at_a))
  }
  acc
}

///|
fn integrate_linear_atom_antiderivative(
  atom : LinearAtom,
  x : @symcore.Expr,
) -> @symcore.Expr {
  let c = atom.form.coeff
  let arg = linear_arg(atom.form, x)
  if is_zero_expr(c) {
    return expr_mul(atom_expr(atom, x), x)
  }
  match atom.kind {
    AtomKind::Sin => expr_neg(expr_div(@symcore.function("cos", [arg]), c))
    AtomKind::Cos => expr_div(@symcore.function("sin", [arg]), c)
    AtomKind::Exp => expr_div(@symcore.function("exp", [arg]), c)
    AtomKind::Sinh => expr_div(@symcore.function("cosh", [arg]), c)
    AtomKind::Cosh => expr_div(@symcore.function("sinh", [arg]), c)
  }
}

///|
fn integrate_linear_atom(
  atom : LinearAtom,
  x : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  let anti = integrate_linear_atom_antiderivative(atom, x)
  expr_sub(eval_at(anti, var_name, b), eval_at(anti, var_name, a))
}

///|
fn int_pow_sin_form(m : Int, form : LinearForm, x : @symcore.Expr) -> @symcore.Expr {
  let c = form.coeff
  if is_zero_expr(c) {
    return expr_mul(
      @symcore.function("sin", [form.shift]),
      expr_div(@symcore.pow(x, @symcore.int(m + 1)), @symcore.int(m + 1)),
    )
  }
  let arg = linear_arg(form, x)
  if m == 0 {
    return expr_neg(expr_div(@symcore.function("cos", [arg]), c))
  }
  let xm = @symcore.pow(x, @symcore.int(m))
  let head = expr_neg(expr_div(expr_mul(xm, @symcore.function("cos", [arg])), c))
  let tail = expr_mul(expr_div(@symcore.int(m), c), int_pow_cos_form(m - 1, form, x))
  expr_add(head, tail)
}

///|
fn int_pow_cos_form(m : Int, form : LinearForm, x : @symcore.Expr) -> @symcore.Expr {
  let c = form.coeff
  if is_zero_expr(c) {
    return expr_mul(
      @symcore.function("cos", [form.shift]),
      expr_div(@symcore.pow(x, @symcore.int(m + 1)), @symcore.int(m + 1)),
    )
  }
  let arg = linear_arg(form, x)
  if m == 0 {
    return expr_div(@symcore.function("sin", [arg]), c)
  }
  let xm = @symcore.pow(x, @symcore.int(m))
  let head = expr_div(expr_mul(xm, @symcore.function("sin", [arg])), c)
  let tail = expr_mul(expr_div(@symcore.int(m), c), int_pow_sin_form(m - 1, form, x))
  expr_sub(head, tail)
}

///|
fn int_pow_exp_form(m : Int, form : LinearForm, x : @symcore.Expr) -> @symcore.Expr {
  let c = form.coeff
  if is_zero_expr(c) {
    return expr_mul(
      @symcore.function("exp", [form.shift]),
      expr_div(@symcore.pow(x, @symcore.int(m + 1)), @symcore.int(m + 1)),
    )
  }
  let arg = linear_arg(form, x)
  if m == 0 {
    return expr_div(@symcore.function("exp", [arg]), c)
  }
  let xm = @symcore.pow(x, @symcore.int(m))
  let head = expr_div(expr_mul(xm, @symcore.function("exp", [arg])), c)
  let tail = expr_mul(expr_div(@symcore.int(m), c), int_pow_exp_form(m - 1, form, x))
  expr_sub(head, tail)
}

///|
fn int_pow_sinh_form(m : Int, form : LinearForm, x : @symcore.Expr) -> @symcore.Expr {
  let c = form.coeff
  if is_zero_expr(c) {
    return expr_mul(
      @symcore.function("sinh", [form.shift]),
      expr_div(@symcore.pow(x, @symcore.int(m + 1)), @symcore.int(m + 1)),
    )
  }
  let arg = linear_arg(form, x)
  if m == 0 {
    return expr_div(@symcore.function("cosh", [arg]), c)
  }
  let xm = @symcore.pow(x, @symcore.int(m))
  let head = expr_div(expr_mul(xm, @symcore.function("cosh", [arg])), c)
  let tail = expr_mul(
    expr_div(@symcore.int(m), c),
    int_pow_cosh_form(m - 1, form, x),
  )
  expr_sub(head, tail)
}

///|
fn int_pow_cosh_form(m : Int, form : LinearForm, x : @symcore.Expr) -> @symcore.Expr {
  let c = form.coeff
  if is_zero_expr(c) {
    return expr_mul(
      @symcore.function("cosh", [form.shift]),
      expr_div(@symcore.pow(x, @symcore.int(m + 1)), @symcore.int(m + 1)),
    )
  }
  let arg = linear_arg(form, x)
  if m == 0 {
    return expr_div(@symcore.function("sinh", [arg]), c)
  }
  let xm = @symcore.pow(x, @symcore.int(m))
  let head = expr_div(expr_mul(xm, @symcore.function("sinh", [arg])), c)
  let tail = expr_mul(
    expr_div(@symcore.int(m), c),
    int_pow_sinh_form(m - 1, form, x),
  )
  expr_sub(head, tail)
}

///|
fn integral_poly_atom(
  poly : Array[@symcore.Expr],
  atom : LinearAtom,
  x : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  let mut acc = @symcore.int(0)
  for i in 0..<poly.length() {
    let coeff = poly[i]
    if is_zero_expr(coeff) {
      continue
    }
    let anti = match atom.kind {
      AtomKind::Sin => int_pow_sin_form(i, atom.form, x)
      AtomKind::Cos => int_pow_cos_form(i, atom.form, x)
      AtomKind::Exp => int_pow_exp_form(i, atom.form, x)
      AtomKind::Sinh => int_pow_sinh_form(i, atom.form, x)
      AtomKind::Cosh => int_pow_cosh_form(i, atom.form, x)
    }
    let scaled = expr_mul(coeff, anti)
    let at_b = eval_at(scaled, var_name, b)
    let at_a = eval_at(scaled, var_name, a)
    acc = expr_add(acc, expr_sub(at_b, at_a))
  }
  acc
}

///|
fn expand_atom_pair(
  left : LinearAtom,
  right : LinearAtom,
  x : @symcore.Expr,
) -> @symcore.Expr? {
  let half = rational_expr(1, 2)
  match (left.kind, right.kind) {
    (AtomKind::Sin, AtomKind::Sin) => {
      let diff = form_sub(left.form, right.form)
      let sum = form_add(left.form, right.form)
      Some(expr_mul(
        half,
        expr_sub(
          @symcore.function("cos", [linear_arg(diff, x)]),
          @symcore.function("cos", [linear_arg(sum, x)]),
        ),
      ))
    }
    (AtomKind::Cos, AtomKind::Cos) => {
      let diff = form_sub(left.form, right.form)
      let sum = form_add(left.form, right.form)
      Some(expr_mul(
        half,
        expr_add(
          @symcore.function("cos", [linear_arg(diff, x)]),
          @symcore.function("cos", [linear_arg(sum, x)]),
        ),
      ))
    }
    (AtomKind::Sin, AtomKind::Cos) => {
      let diff = form_sub(left.form, right.form)
      let sum = form_add(left.form, right.form)
      Some(expr_mul(
        half,
        expr_add(
          @symcore.function("sin", [linear_arg(sum, x)]),
          @symcore.function("sin", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Cos, AtomKind::Sin) => {
      let diff = form_sub(left.form, right.form)
      let sum = form_add(left.form, right.form)
      Some(expr_mul(
        half,
        expr_sub(
          @symcore.function("sin", [linear_arg(sum, x)]),
          @symcore.function("sin", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Exp, AtomKind::Exp) => {
      let form = form_add(left.form, right.form)
      Some(@symcore.function("exp", [linear_arg(form, x)]))
    }
    (AtomKind::Exp, AtomKind::Sinh) => {
      let sum = form_add(left.form, right.form)
      let diff = form_sub(left.form, right.form)
      Some(expr_mul(
        half,
        expr_sub(
          @symcore.function("exp", [linear_arg(sum, x)]),
          @symcore.function("exp", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Exp, AtomKind::Cosh) => {
      let sum = form_add(left.form, right.form)
      let diff = form_sub(left.form, right.form)
      Some(expr_mul(
        half,
        expr_add(
          @symcore.function("exp", [linear_arg(sum, x)]),
          @symcore.function("exp", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Sinh, AtomKind::Exp) => {
      let sum = form_add(left.form, right.form)
      let diff = form_sub(right.form, left.form)
      Some(expr_mul(
        half,
        expr_sub(
          @symcore.function("exp", [linear_arg(sum, x)]),
          @symcore.function("exp", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Cosh, AtomKind::Exp) => {
      let sum = form_add(left.form, right.form)
      let diff = form_sub(right.form, left.form)
      Some(expr_mul(
        half,
        expr_add(
          @symcore.function("exp", [linear_arg(sum, x)]),
          @symcore.function("exp", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Sinh, AtomKind::Sinh) => {
      let diff = form_sub(left.form, right.form)
      let sum = form_add(left.form, right.form)
      Some(expr_mul(
        half,
        expr_sub(
          @symcore.function("cosh", [linear_arg(sum, x)]),
          @symcore.function("cosh", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Cosh, AtomKind::Cosh) => {
      let diff = form_sub(left.form, right.form)
      let sum = form_add(left.form, right.form)
      Some(expr_mul(
        half,
        expr_add(
          @symcore.function("cosh", [linear_arg(sum, x)]),
          @symcore.function("cosh", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Sinh, AtomKind::Cosh) => {
      let diff = form_sub(left.form, right.form)
      let sum = form_add(left.form, right.form)
      Some(expr_mul(
        half,
        expr_add(
          @symcore.function("sinh", [linear_arg(sum, x)]),
          @symcore.function("sinh", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Cosh, AtomKind::Sinh) => {
      let diff = form_sub(left.form, right.form)
      let sum = form_add(left.form, right.form)
      Some(expr_mul(
        half,
        expr_sub(
          @symcore.function("sinh", [linear_arg(sum, x)]),
          @symcore.function("sinh", [linear_arg(diff, x)]),
        ),
      ))
    }
    (AtomKind::Sinh, AtomKind::Sin) => {
      let plus = @symcore.function("exp", [linear_arg(left.form, x)])
      let minus = @symcore.function("exp", [linear_arg(form_neg(left.form), x)])
      let trig = @symcore.function("sin", [linear_arg(right.form, x)])
      Some(expr_mul(half, expr_sub(expr_mul(plus, trig), expr_mul(minus, trig))))
    }
    (AtomKind::Sinh, AtomKind::Cos) => {
      let plus = @symcore.function("exp", [linear_arg(left.form, x)])
      let minus = @symcore.function("exp", [linear_arg(form_neg(left.form), x)])
      let trig = @symcore.function("cos", [linear_arg(right.form, x)])
      Some(expr_mul(half, expr_sub(expr_mul(plus, trig), expr_mul(minus, trig))))
    }
    (AtomKind::Cosh, AtomKind::Sin) => {
      let plus = @symcore.function("exp", [linear_arg(left.form, x)])
      let minus = @symcore.function("exp", [linear_arg(form_neg(left.form), x)])
      let trig = @symcore.function("sin", [linear_arg(right.form, x)])
      Some(expr_mul(half, expr_add(expr_mul(plus, trig), expr_mul(minus, trig))))
    }
    (AtomKind::Cosh, AtomKind::Cos) => {
      let plus = @symcore.function("exp", [linear_arg(left.form, x)])
      let minus = @symcore.function("exp", [linear_arg(form_neg(left.form), x)])
      let trig = @symcore.function("cos", [linear_arg(right.form, x)])
      Some(expr_mul(half, expr_add(expr_mul(plus, trig), expr_mul(minus, trig))))
    }
    (AtomKind::Sin, AtomKind::Sinh) => {
      let plus = @symcore.function("exp", [linear_arg(right.form, x)])
      let minus = @symcore.function("exp", [linear_arg(form_neg(right.form), x)])
      let trig = @symcore.function("sin", [linear_arg(left.form, x)])
      Some(expr_mul(half, expr_sub(expr_mul(plus, trig), expr_mul(minus, trig))))
    }
    (AtomKind::Cos, AtomKind::Sinh) => {
      let plus = @symcore.function("exp", [linear_arg(right.form, x)])
      let minus = @symcore.function("exp", [linear_arg(form_neg(right.form), x)])
      let trig = @symcore.function("cos", [linear_arg(left.form, x)])
      Some(expr_mul(half, expr_sub(expr_mul(plus, trig), expr_mul(minus, trig))))
    }
    (AtomKind::Sin, AtomKind::Cosh) => {
      let plus = @symcore.function("exp", [linear_arg(right.form, x)])
      let minus = @symcore.function("exp", [linear_arg(form_neg(right.form), x)])
      let trig = @symcore.function("sin", [linear_arg(left.form, x)])
      Some(expr_mul(half, expr_add(expr_mul(plus, trig), expr_mul(minus, trig))))
    }
    (AtomKind::Cos, AtomKind::Cosh) => {
      let plus = @symcore.function("exp", [linear_arg(right.form, x)])
      let minus = @symcore.function("exp", [linear_arg(form_neg(right.form), x)])
      let trig = @symcore.function("cos", [linear_arg(left.form, x)])
      Some(expr_mul(half, expr_add(expr_mul(plus, trig), expr_mul(minus, trig))))
    }
    _ => None
  }
}

///|
fn integrate_exp_trig_pair(
  exp_atom : LinearAtom,
  trig_atom : LinearAtom,
  x : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  let ea = exp_atom.form.coeff
  let tc = trig_atom.form.coeff
  let exp_part = @symcore.function("exp", [linear_arg(exp_atom.form, x)])
  let trig_arg = linear_arg(trig_atom.form, x)
  let denom = expr_add(
    @symcore.pow(ea, @symcore.int(2)),
    @symcore.pow(tc, @symcore.int(2)),
  )
  let comb = match trig_atom.kind {
    AtomKind::Sin =>
      expr_sub(
        expr_mul(ea, @symcore.function("sin", [trig_arg])),
        expr_mul(tc, @symcore.function("cos", [trig_arg])),
      )
    AtomKind::Cos =>
      expr_add(
        expr_mul(ea, @symcore.function("cos", [trig_arg])),
        expr_mul(tc, @symcore.function("sin", [trig_arg])),
      )
    _ => @symcore.int(0)
  }
  let anti = expr_div(expr_mul(exp_part, comb), denom)
  expr_sub(eval_at(anti, var_name, b), eval_at(anti, var_name, a))
}

///|
fn integrate_expr(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Add(args) => {
      let mut acc = @symcore.int(0)
      for term in args {
        match integrate_expr(term, x, var_name, a, b) {
          Some(v) => acc = expr_add(acc, v)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      for i in 0..<args.length() {
        match args[i] {
          @symcore.Expr::Add(terms) => {
            let mut acc = @symcore.int(0)
            for term in terms {
              let factors = args.copy()
              factors[i] = term
              match integrate_expr(@symcore.mul(factors), x, var_name, a, b) {
                Some(v) => acc = expr_add(acc, v)
                None => return None
              }
            }
            return Some(acc)
          }
          _ => ()
        }
      }
      let const_factors : Array[@symcore.Expr] = Array::new()
      let dep_poly_exprs : Array[@symcore.Expr] = Array::new()
      let dep_atoms : Array[LinearAtom] = Array::new()
      for factor in args {
        if contains_symbol(factor, var_name) {
          match poly_from_expr(factor, x) {
            Some(_) => dep_poly_exprs.push(factor)
            None =>
              match parse_linear_atom(factor, x, var_name) {
                Some(atom) => dep_atoms.push(atom)
                None => return None
              }
          }
        } else {
          const_factors.push(factor)
        }
      }
      let coeff = if const_factors.is_empty() {
        @symcore.int(1)
      } else {
        @symcore.mul(const_factors)
      }
      let poly_expr = if dep_poly_exprs.is_empty() {
        @symcore.int(1)
      } else {
        @symcore.mul(dep_poly_exprs)
      }
      let poly = match poly_from_expr(poly_expr, x) {
        Some(p) => p
        None => return None
      }
      if dep_atoms.is_empty() {
        return Some(expr_mul(coeff, integral_poly(poly, x, var_name, a, b)))
      }
      if dep_atoms.length() == 1 {
        if dep_poly_exprs.is_empty() {
          return Some(
            expr_mul(
              coeff,
              integrate_linear_atom(dep_atoms[0], x, var_name, a, b),
            ),
          )
        }
        return Some(
          expr_mul(
            coeff,
            integral_poly_atom(poly, dep_atoms[0], x, var_name, a, b),
          ),
        )
      }
      if dep_atoms.length() == 2 && dep_poly_exprs.is_empty() {
        let left = dep_atoms[0]
        let right = dep_atoms[1]
        match (left.kind, right.kind) {
          (AtomKind::Exp, AtomKind::Sin) | (AtomKind::Exp, AtomKind::Cos) =>
            return Some(
              expr_mul(coeff, integrate_exp_trig_pair(left, right, x, var_name, a, b)),
            )
          (AtomKind::Sin, AtomKind::Exp) | (AtomKind::Cos, AtomKind::Exp) =>
            return Some(
              expr_mul(
                coeff,
                integrate_exp_trig_pair(right, left, x, var_name, a, b),
              ),
            )
          _ => ()
        }
      }
      let pair_expr = match expand_atom_pair(dep_atoms[0], dep_atoms[1], x) {
        Some(v) => v
        None => return None
      }
      let rest_factors : Array[@symcore.Expr] = Array::new()
      if !dep_poly_exprs.is_empty() {
        rest_factors.push(poly_expr)
      }
      for i in 2..<dep_atoms.length() {
        rest_factors.push(atom_expr(dep_atoms[i], x))
      }
      rest_factors.push(pair_expr)
      let merged = expr_mul(coeff, @symcore.mul(rest_factors))
      integrate_expr(merged, x, var_name, a, b)
    }
    _ =>
      match poly_from_expr(expr, x) {
        Some(poly) => Some(integral_poly(poly, x, var_name, a, b))
        None =>
          match parse_linear_atom(expr, x, var_name) {
            Some(atom) => Some(integrate_linear_atom(atom, x, var_name, a, b))
            None => None
          }
      }
  }
}

///|
pub fn fourier_series(
  expr : @symcore.Expr,
  limits? : Array[@symcore.Expr] = [],
  finite? : Bool = true,
) -> FourierSeriesResult raise {
  let _ = finite
  if limits.is_empty() {
    return FourierSeriesResult::Expr(expr)
  }
  if limits.length() != 3 {
    fail("fourier_series requires limits (x, a, b)")
  }
  let x = limits[0]
  let a = limits[1]
  let b = limits[2]
  let var_name = match x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fourier variable must be a Symbol")
  }
  if !depends_on(expr, var_name) {
    return FourierSeriesResult::Expr(expr)
  }
  FourierSeriesResult::Series(FourierSeries::{ expr, x, a, b })
}

///|
pub fn FourierSeries::function(self : FourierSeries) -> @symcore.Expr {
  self.expr
}

///|
pub fn FourierSeries::x(self : FourierSeries) -> @symcore.Expr {
  self.x
}

///|
pub fn FourierSeries::period(self : FourierSeries) -> @symcore.Expr {
  expr_sub(self.b, self.a)
}

///|
fn FourierSeries::norm_factor(self : FourierSeries) -> @symcore.Expr {
  expr_div(@symcore.int(2), self.period())
}

///|
fn FourierSeries::omega(self : FourierSeries, n : Int) -> @symcore.Expr {
  let pi = @symcore.symbol("pi")
  let minus_pi = @symcore.mul([@symcore.int(-1), pi])
  let two_pi = @symcore.mul([@symcore.int(2), pi])
  if (self.a == minus_pi && self.b == pi) ||
    (self.a == @symcore.int(0) && self.b == two_pi) {
    return @symcore.int(n)
  }
  let two_n_pi = @symcore.mul([
    @symcore.int(2 * n),
    pi,
  ])
  expr_div(two_n_pi, self.period())
}

///|
pub fn FourierSeries::a0(self : FourierSeries) -> @symcore.Expr raise {
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fourier variable must be a Symbol")
  }
  match integrate_expr(self.expr, self.x, var_name, self.a, self.b) {
    Some(v) => expr_mul(self.norm_factor(), v)
    None =>
      expr_mul(
        self.norm_factor(),
        definite_integral_expr(self.expr, self.x, self.a, self.b),
      )
  }
}

///|
pub fn FourierSeries::an(self : FourierSeries, n : Int) -> @symcore.Expr raise {
  if n <= 0 {
    return @symcore.int(0)
  }
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fourier variable must be a Symbol")
  }
  let basis = @symcore.function("cos", [expr_mul(self.omega(n), self.x)])
  let integrand = expr_mul(self.expr, basis)
  match integrate_expr(integrand, self.x, var_name, self.a, self.b) {
    Some(v) => expr_mul(self.norm_factor(), v)
    None =>
      expr_mul(
        self.norm_factor(),
        definite_integral_expr(integrand, self.x, self.a, self.b),
      )
  }
}

///|
pub fn FourierSeries::bn(self : FourierSeries, n : Int) -> @symcore.Expr raise {
  if n <= 0 {
    return @symcore.int(0)
  }
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("fourier variable must be a Symbol")
  }
  let basis = @symcore.function("sin", [expr_mul(self.omega(n), self.x)])
  let integrand = expr_mul(self.expr, basis)
  match integrate_expr(integrand, self.x, var_name, self.a, self.b) {
    Some(v) => expr_mul(self.norm_factor(), v)
    None =>
      expr_mul(
        self.norm_factor(),
        definite_integral_expr(integrand, self.x, self.a, self.b),
      )
  }
}

///|
pub fn FourierSeries::term(
  self : FourierSeries,
  n : Int,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("fourier term requires non-negative index")
  }
  if n == 0 {
    return expr_mul(rational_expr(1, 2), self.a0())
  }
  let wnx = expr_mul(self.omega(n), self.x)
  let cos_part = expr_mul(self.an(n), @symcore.function("cos", [wnx]))
  let sin_part = expr_mul(self.bn(n), @symcore.function("sin", [wnx]))
  expr_add(cos_part, sin_part)
}

///|
pub fn FourierSeries::as_leading_term(
  self : FourierSeries,
  x : @symcore.Expr,
) -> @symcore.Expr raise {
  if x != self.x {
    fail("fourier leading term variable mismatch")
  }
  self.term(1)
}

///|
pub fn FourierSeries::truncate(
  self : FourierSeries,
  n? : Int = 6,
) -> @symcore.Expr raise {
  if n < 0 {
    fail("fourier truncate requires non-negative n")
  }
  let mut acc = @symcore.int(0)
  let mut i = 0
  while i < n {
    acc = expr_add(acc, self.term(i))
    i += 1
  }
  acc
}

///|
pub fn FourierSeries::sigma_approximation(
  self : FourierSeries,
  n : Int,
) -> @symcore.Expr raise {
  if n <= 0 {
    return @symcore.int(0)
  }
  let mut acc = @symcore.int(0)
  let pi = @symcore.symbol("pi")
  let mut i = 0
  while i < n {
    let term = self.term(i)
    if !is_zero_expr(term) {
      let factor = if i == 0 {
        @symcore.int(1)
      } else {
        @symcore.function("sinc", [expr_mul(pi, rational_expr(i, n))])
      }
      acc = expr_add(acc, expr_mul(factor, term))
    }
    i += 1
  }
  acc
}

///|
pub fn FourierSeries::shift(
  self : FourierSeries,
  amount : @symcore.Expr,
) -> FourierSeries {
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => ""
  }
  if var_name == "" {
    return self
  }
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = @symcore.add([self.x, amount])
  let new_expr = @symcore.subst(self.expr, env)
  FourierSeries::{ expr: new_expr, x: self.x, a: self.a, b: self.b }
}

///|
pub fn FourierSeries::shiftx(
  self : FourierSeries,
  amount : @symcore.Expr,
) -> FourierSeries {
  self.shift(amount)
}

///|
pub fn FourierSeries::scale(
  self : FourierSeries,
  factor : @symcore.Expr,
) -> FourierSeries {
  let new_expr = expr_mul(factor, self.expr)
  FourierSeries::{ expr: new_expr, x: self.x, a: self.a, b: self.b }
}

///|
pub fn FourierSeries::scalex(
  self : FourierSeries,
  factor : @symcore.Expr,
) -> FourierSeries {
  let var_name = match self.x {
    @symcore.Expr::Symbol(name) => name
    _ => ""
  }
  if var_name == "" {
    return self
  }
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = expr_mul(factor, self.x)
  let new_expr = @symcore.subst(self.expr, env)
  FourierSeries::{ expr: new_expr, x: self.x, a: self.a, b: self.b }
}

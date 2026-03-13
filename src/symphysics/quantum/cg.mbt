///|
/// Symbolic wrappers for `sympy.physics.quantum.cg`.

///|
fn quantum_all_numeric(args : Array[@symcore.Expr]) -> Bool {
  for arg in args {
    match arg {
      @symcore.Expr::Number(_) => ()
      _ => return false
    }
  }
  true
}

///|
pub struct Wigner3j {
  j1 : @symcore.Expr
  m1 : @symcore.Expr
  j2 : @symcore.Expr
  m2 : @symcore.Expr
  j3 : @symcore.Expr
  m3 : @symcore.Expr
} derive(Eq)

///|
pub fn wigner3j(
  j1 : @symcore.Expr,
  m1 : @symcore.Expr,
  j2 : @symcore.Expr,
  m2 : @symcore.Expr,
  j3 : @symcore.Expr,
  m3 : @symcore.Expr,
) -> Wigner3j {
  Wigner3j::{ j1, m1, j2, m2, j3, m3 }
}

///|
pub fn Wigner3j::as_expr(self : Wigner3j) -> @symcore.Expr {
  @symcore.function("Wigner3j", [
    self.j1,
    self.m1,
    self.j2,
    self.m2,
    self.j3,
    self.m3,
  ])
}

///|
pub fn Wigner3j::is_symbolic(self : Wigner3j) -> Bool {
  !quantum_all_numeric([self.j1, self.m1, self.j2, self.m2, self.j3, self.m3])
}

///|
pub fn Wigner3j::doit(
  self : Wigner3j,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  guard !self.is_symbolic() else {
    raise @symphysics.PhysicsError::ValueError("Coefficients must be numerical")
  }
  try! @symphysics.wigner_3j(
    self.j1,
    self.j2,
    self.j3,
    self.m1,
    self.m2,
    self.m3,
  )
}

///|
pub struct CG {
  j1 : @symcore.Expr
  m1 : @symcore.Expr
  j2 : @symcore.Expr
  m2 : @symcore.Expr
  j3 : @symcore.Expr
  m3 : @symcore.Expr
} derive(Eq)

///|
pub fn cg(
  j1 : @symcore.Expr,
  m1 : @symcore.Expr,
  j2 : @symcore.Expr,
  m2 : @symcore.Expr,
  j3 : @symcore.Expr,
  m3 : @symcore.Expr,
) -> CG {
  CG::{ j1, m1, j2, m2, j3, m3 }
}

///|
pub fn CG::as_expr(self : CG) -> @symcore.Expr {
  @symcore.function("CG", [self.j1, self.m1, self.j2, self.m2, self.j3, self.m3])
}

///|
pub fn CG::is_symbolic(self : CG) -> Bool {
  !quantum_all_numeric([self.j1, self.m1, self.j2, self.m2, self.j3, self.m3])
}

///|
pub fn CG::doit(self : CG) -> @symcore.Expr raise @symphysics.PhysicsError {
  guard !self.is_symbolic() else {
    raise @symphysics.PhysicsError::ValueError("Coefficients must be numerical")
  }
  try! @symphysics.clebsch_gordan(
    self.j1,
    self.j2,
    self.j3,
    self.m1,
    self.m2,
    self.m3,
  )
}

///|
pub struct Wigner6j {
  j1 : @symcore.Expr
  j2 : @symcore.Expr
  j12 : @symcore.Expr
  j3 : @symcore.Expr
  j : @symcore.Expr
  j23 : @symcore.Expr
} derive(Eq)

///|
pub fn wigner6j(
  j1 : @symcore.Expr,
  j2 : @symcore.Expr,
  j12 : @symcore.Expr,
  j3 : @symcore.Expr,
  j : @symcore.Expr,
  j23 : @symcore.Expr,
) -> Wigner6j {
  Wigner6j::{ j1, j2, j12, j3, j, j23 }
}

///|
pub fn Wigner6j::as_expr(self : Wigner6j) -> @symcore.Expr {
  @symcore.function("Wigner6j", [
    self.j1,
    self.j2,
    self.j12,
    self.j3,
    self.j,
    self.j23,
  ])
}

///|
pub fn Wigner6j::is_symbolic(self : Wigner6j) -> Bool {
  !quantum_all_numeric([self.j1, self.j2, self.j12, self.j3, self.j, self.j23])
}

///|
pub fn Wigner6j::doit(
  self : Wigner6j,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  guard !self.is_symbolic() else {
    raise @symphysics.PhysicsError::ValueError("Coefficients must be numerical")
  }
  try! @symphysics.wigner_6j(
    self.j1,
    self.j2,
    self.j12,
    self.j3,
    self.j,
    self.j23,
  )
}

///|
pub struct Wigner9j {
  j1 : @symcore.Expr
  j2 : @symcore.Expr
  j12 : @symcore.Expr
  j3 : @symcore.Expr
  j4 : @symcore.Expr
  j34 : @symcore.Expr
  j13 : @symcore.Expr
  j24 : @symcore.Expr
  j : @symcore.Expr
} derive(Eq)

///|
pub fn wigner9j(
  j1 : @symcore.Expr,
  j2 : @symcore.Expr,
  j12 : @symcore.Expr,
  j3 : @symcore.Expr,
  j4 : @symcore.Expr,
  j34 : @symcore.Expr,
  j13 : @symcore.Expr,
  j24 : @symcore.Expr,
  j : @symcore.Expr,
) -> Wigner9j {
  Wigner9j::{ j1, j2, j12, j3, j4, j34, j13, j24, j }
}

///|
pub fn Wigner9j::as_expr(self : Wigner9j) -> @symcore.Expr {
  @symcore.function("Wigner9j", [
    self.j1,
    self.j2,
    self.j12,
    self.j3,
    self.j4,
    self.j34,
    self.j13,
    self.j24,
    self.j,
  ])
}

///|
pub fn Wigner9j::is_symbolic(self : Wigner9j) -> Bool {
  !quantum_all_numeric([
    self.j1,
    self.j2,
    self.j12,
    self.j3,
    self.j4,
    self.j34,
    self.j13,
    self.j24,
    self.j,
  ])
}

///|
pub fn Wigner9j::doit(
  self : Wigner9j,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  guard !self.is_symbolic() else {
    raise @symphysics.PhysicsError::ValueError("Coefficients must be numerical")
  }
  try! @symphysics.wigner_9j(
    self.j1,
    self.j2,
    self.j12,
    self.j3,
    self.j4,
    self.j34,
    self.j13,
    self.j24,
    self.j,
  )
}

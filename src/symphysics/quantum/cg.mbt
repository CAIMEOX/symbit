///|
/// Symbolic wrappers for `sympy.physics.quantum.cg`.

///|
fn quantum_all_numeric(args : Array[Expr]) -> Bool {
  for arg in args {
    match arg {
      Expr::Number(_) => ()
      _ => return false
    }
  }
  true
}

///|
pub struct Wigner3j {
  j1 : Expr
  m1 : Expr
  j2 : Expr
  m2 : Expr
  j3 : Expr
  m3 : Expr
} derive(Eq)

///|
pub fn wigner3j(
  j1 : Expr,
  m1 : Expr,
  j2 : Expr,
  m2 : Expr,
  j3 : Expr,
  m3 : Expr,
) -> Wigner3j {
  Wigner3j::{ j1, m1, j2, m2, j3, m3 }
}

///|
pub fn Wigner3j::as_expr(self : Wigner3j) -> Expr {
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
) -> Expr raise @symphysics.PhysicsError {
  guard !self.is_symbolic() else {
    raise @symphysics.PhysicsError::ValueError("Coefficients must be numerical")
  }
  @symphysics.wigner_3j(
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
  j1 : Expr
  m1 : Expr
  j2 : Expr
  m2 : Expr
  j3 : Expr
  m3 : Expr
} derive(Eq)

///|
pub fn cg(
  j1 : Expr,
  m1 : Expr,
  j2 : Expr,
  m2 : Expr,
  j3 : Expr,
  m3 : Expr,
) -> CG {
  CG::{ j1, m1, j2, m2, j3, m3 }
}

///|
pub fn CG::as_expr(self : CG) -> Expr {
  @symcore.function("CG", [self.j1, self.m1, self.j2, self.m2, self.j3, self.m3])
}

///|
pub fn CG::is_symbolic(self : CG) -> Bool {
  !quantum_all_numeric([self.j1, self.m1, self.j2, self.m2, self.j3, self.m3])
}

///|
pub fn CG::doit(self : CG) -> Expr raise @symphysics.PhysicsError {
  guard !self.is_symbolic() else {
    raise @symphysics.PhysicsError::ValueError("Coefficients must be numerical")
  }
  @symphysics.clebsch_gordan(
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
  j1 : Expr
  j2 : Expr
  j12 : Expr
  j3 : Expr
  j : Expr
  j23 : Expr
} derive(Eq)

///|
pub fn wigner6j(
  j1 : Expr,
  j2 : Expr,
  j12 : Expr,
  j3 : Expr,
  j : Expr,
  j23 : Expr,
) -> Wigner6j {
  Wigner6j::{ j1, j2, j12, j3, j, j23 }
}

///|
pub fn Wigner6j::as_expr(self : Wigner6j) -> Expr {
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
) -> Expr raise @symphysics.PhysicsError {
  guard !self.is_symbolic() else {
    raise @symphysics.PhysicsError::ValueError("Coefficients must be numerical")
  }
  @symphysics.wigner_6j(
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
  j1 : Expr
  j2 : Expr
  j12 : Expr
  j3 : Expr
  j4 : Expr
  j34 : Expr
  j13 : Expr
  j24 : Expr
  j : Expr
} derive(Eq)

///|
pub fn wigner9j(
  j1 : Expr,
  j2 : Expr,
  j12 : Expr,
  j3 : Expr,
  j4 : Expr,
  j34 : Expr,
  j13 : Expr,
  j24 : Expr,
  j : Expr,
) -> Wigner9j {
  Wigner9j::{ j1, j2, j12, j3, j4, j34, j13, j24, j }
}

///|
pub fn Wigner9j::as_expr(self : Wigner9j) -> Expr {
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
) -> Expr raise @symphysics.PhysicsError {
  guard !self.is_symbolic() else {
    raise @symphysics.PhysicsError::ValueError("Coefficients must be numerical")
  }
  @symphysics.wigner_9j(
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

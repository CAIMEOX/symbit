///|
/// Named transitive subgroups used by Galois-group computations.
///
/// SymPy represents many low-degree Galois groups as explicit transitive permutation groups.
/// This file exposes those standard models together with enums that classify transitive
/// subgroups of `S_n` for `n <= 6`.

///|
fn perm(
  cycles : Array[Array[Int]],
  size~ : Int,
) -> Permutation raise CombinatoricsError {
  Permutation::from_cycles(cycles, size~)
}

///|
fn set_alternating_group_properties(
  g : PermutationGroup,
  n : Int,
  degree : Int,
) -> Unit {
  if n < 3 {
    g.order_cache = Some(1)
  }
  if n < 4 {
    g.is_abelian_cache = Some(true)
    g.is_nilpotent_cache = Some(true)
  } else {
    g.is_abelian_cache = Some(false)
    g.is_nilpotent_cache = Some(false)
  }
  if n < 5 {
    g.is_solvable_cache = Some(true)
  } else {
    g.is_solvable_cache = Some(false)
  }
  let _ = degree
  if n == 2 {
    g.is_transitive_cache = Some(false)
  } else {
    g.is_transitive_cache = Some(true)
  }
  g.is_dihedral_cache = Some(false)
}

///|
fn set_symmetric_group_properties(
  g : PermutationGroup,
  n : Int,
  degree : Int,
) -> Unit {
  if n < 3 {
    g.is_abelian_cache = Some(true)
    g.is_nilpotent_cache = Some(true)
  } else {
    g.is_abelian_cache = Some(false)
    g.is_nilpotent_cache = Some(false)
  }
  if n < 5 {
    g.is_solvable_cache = Some(true)
  } else {
    g.is_solvable_cache = Some(false)
  }
  let _ = degree
  g.is_transitive_cache = Some(true)
  g.is_dihedral_cache = Some(n == 2 || n == 3)
}

///|
pub(all) enum S1TransitiveSubgroups {
  S1
} derive(Eq)

///|
/// Materialize the transitive subgroup of `S_1` represented by this enum value.
pub fn S1TransitiveSubgroups::get_perm_group(
  self : S1TransitiveSubgroups,
) -> PermutationGroup raise CombinatoricsError {
  match self {
    S1 => symmetric_group(1)
  }
}

///|
pub(all) enum S2TransitiveSubgroups {
  S2
} derive(Eq)

///|
/// Materialize the transitive subgroup of `S_2` represented by this enum value.
pub fn S2TransitiveSubgroups::get_perm_group(
  self : S2TransitiveSubgroups,
) -> PermutationGroup raise CombinatoricsError {
  match self {
    S2 => symmetric_group(2)
  }
}

///|
pub(all) enum S3TransitiveSubgroups {
  A3
  S3
} derive(Eq)

///|
/// Materialize the transitive subgroup of `S_3` represented by this enum value.
pub fn S3TransitiveSubgroups::get_perm_group(
  self : S3TransitiveSubgroups,
) -> PermutationGroup raise CombinatoricsError {
  match self {
    A3 => alternating_group(3)
    S3 => symmetric_group(3)
  }
}

///|
pub(all) enum S4TransitiveSubgroups {
  C4
  V
  D4
  A4
  S4
} derive(Eq)

///|
/// Materialize the transitive subgroup of `S_4` represented by this enum value.
pub fn S4TransitiveSubgroups::get_perm_group(
  self : S4TransitiveSubgroups,
) -> PermutationGroup raise CombinatoricsError {
  match self {
    C4 => cyclic_group(4)
    V => four_group()
    D4 => dihedral_group(4)
    A4 => alternating_group(4)
    S4 => symmetric_group(4)
  }
}

///|
pub(all) enum S5TransitiveSubgroups {
  C5
  D5
  M20
  A5
  S5
} derive(Eq)

///|
/// Materialize the transitive subgroup of `S_5` represented by this enum value.
pub fn S5TransitiveSubgroups::get_perm_group(
  self : S5TransitiveSubgroups,
) -> PermutationGroup raise CombinatoricsError {
  match self {
    C5 => cyclic_group(5)
    D5 => dihedral_group(5)
    M20 => m20()
    A5 => alternating_group(5)
    S5 => symmetric_group(5)
  }
}

///|
pub(all) enum S6TransitiveSubgroups {
  C6
  S3
  D6
  A4
  G18
  A4xC2
  S4m
  S4p
  G36m
  G36p
  S4xC2
  PSL2F5
  G72
  PGL2F5
  A6
  S6
} derive(Eq)

///|
/// Materialize the transitive subgroup of `S_6` represented by this enum value.
pub fn S6TransitiveSubgroups::get_perm_group(
  self : S6TransitiveSubgroups,
) -> PermutationGroup raise CombinatoricsError {
  match self {
    C6 => cyclic_group(6)
    S3 => s3_in_s6()
    D6 => dihedral_group(6)
    A4 => a4_in_s6()
    G18 => g18()
    A4xC2 => a4xc2()
    S4m => s4m()
    S4p => s4p()
    G36m => g36m()
    G36p => g36p()
    S4xC2 => s4xc2()
    PSL2F5 => psl2f5()
    G72 => g72()
    PGL2F5 => pgl2f5()
    A6 => alternating_group(6)
    S6 => symmetric_group(6)
  }
}

///|
/// Return the Klein four group in its degree-4 transitive action.
pub fn four_group() -> PermutationGroup raise CombinatoricsError {
  PermutationGroup::new([
    perm([[0, 1], [2, 3]], size=4),
    perm([[0, 2], [1, 3]], size=4),
  ])
}

///|
/// Return the transitive degree-5 Frobenius group `M20`.
pub fn m20() -> PermutationGroup raise CombinatoricsError {
  let g = PermutationGroup::new([
    perm([[0, 1, 2, 3, 4]], size=5),
    perm([[1, 2, 4, 3]], size=5),
  ])
  g.order_cache = Some(20)
  g.is_transitive_cache = Some(true)
  g.is_symmetric_cache = Some(false)
  g.is_alternating_cache = Some(false)
  g.is_cyclic_cache = Some(false)
  g.is_dihedral_cache = Some(false)
  g
}

///|
/// Return the degree-6 transitive copy of `S_3` used in SymPy's Galois tables.
pub fn s3_in_s6() -> PermutationGroup raise CombinatoricsError {
  let g = PermutationGroup::new([
    perm([[0, 1, 2], [3, 4, 5]], size=6),
    perm([[0, 3], [2, 4], [1, 5]], size=6),
  ])
  set_symmetric_group_properties(g, 3, 6)
  g.is_symmetric_cache = Some(true)
  g.is_alternating_cache = Some(false)
  g
}

///|
/// Return the degree-6 transitive copy of `A_4` used in SymPy's Galois tables.
pub fn a4_in_s6() -> PermutationGroup raise CombinatoricsError {
  let g = PermutationGroup::new([
    perm([[0, 4, 5], [1, 3, 2]], size=6),
    perm([[0, 1, 2], [3, 5, 4]], size=6),
  ])
  set_alternating_group_properties(g, 4, 6)
  g.is_alternating_cache = Some(true)
  g
}

///|
/// Return one of the two standard degree-6 transitive copies of `S_4`.
pub fn s4m() -> PermutationGroup raise CombinatoricsError {
  let g = PermutationGroup::new([
    perm([[1, 4, 5, 3]], size=6),
    perm([[0, 4], [1, 5], [2, 3]], size=6),
  ])
  set_symmetric_group_properties(g, 4, 6)
  g.is_symmetric_cache = Some(true)
  g.is_alternating_cache = Some(false)
  g
}

///|
/// Return the second standard degree-6 transitive copy of `S_4`.
pub fn s4p() -> PermutationGroup raise CombinatoricsError {
  let g = PermutationGroup::new([
    perm([[0, 2, 4, 1], [3, 5]], size=6),
    perm([[0, 3], [4, 5]], size=6),
  ])
  set_symmetric_group_properties(g, 4, 6)
  g.is_symmetric_cache = Some(true)
  g.is_alternating_cache = Some(false)
  g
}

///|
/// Return the transitive degree-6 group `A_4 x C_2`.
pub fn a4xc2() -> PermutationGroup raise CombinatoricsError {
  PermutationGroup::new([
    perm([[0, 4, 5], [1, 3, 2]], size=6),
    perm([[0, 1, 2], [3, 5, 4]], size=6),
    perm([[2, 4]], size=6),
  ])
}

///|
/// Return the transitive degree-6 group `S_4 x C_2`.
pub fn s4xc2() -> PermutationGroup raise CombinatoricsError {
  PermutationGroup::new([
    perm([[1, 4, 5, 3]], size=6),
    perm([[0, 4], [1, 5], [2, 3]], size=6),
    perm([[1, 4], [3, 5]], size=6),
  ])
}

///|
/// Return the degree-6 transitive group of order 18 appearing in the Galois classification.
pub fn g18() -> PermutationGroup raise CombinatoricsError {
  PermutationGroup::new([
    perm([[0, 1, 2]], size=6),
    perm([[3, 4, 5]], size=6),
    perm([[0, 4], [1, 5], [2, 3]], size=6),
  ])
}

///|
/// Return the first degree-6 transitive group of order 36 from SymPy's tables.
pub fn g36m() -> PermutationGroup raise CombinatoricsError {
  PermutationGroup::new([
    perm([[0, 1, 2]], size=6),
    perm([[3, 4, 5]], size=6),
    perm([[1, 2], [3, 5]], size=6),
    perm([[0, 4], [1, 5], [2, 3]], size=6),
  ])
}

///|
/// Return the second degree-6 transitive group of order 36 from SymPy's tables.
pub fn g36p() -> PermutationGroup raise CombinatoricsError {
  PermutationGroup::new([
    perm([[0, 1, 2]], size=6),
    perm([[3, 4, 5]], size=6),
    perm([[0, 5, 2, 3], [1, 4]], size=6),
  ])
}

///|
/// Return the standard degree-6 transitive group of order 72.
pub fn g72() -> PermutationGroup raise CombinatoricsError {
  PermutationGroup::new([
    perm([[0, 1, 2]], size=6),
    perm([[0, 4, 1, 3], [2, 5]], size=6),
    perm([[0, 3], [1, 4], [2, 5]], size=6),
  ])
}

///|
/// Return the degree-6 action of `PSL(2, 5)`, isomorphic to `A_5`.
pub fn psl2f5() -> PermutationGroup raise CombinatoricsError {
  let g = PermutationGroup::new([
    perm([[0, 4, 5], [1, 3, 2]], size=6),
    perm([[0, 4, 3, 1, 5]], size=6),
  ])
  set_alternating_group_properties(g, 5, 6)
  g.is_alternating_cache = Some(true)
  g
}

///|
/// Return the degree-6 action of `PGL(2, 5)`, isomorphic to `S_5`.
pub fn pgl2f5() -> PermutationGroup raise CombinatoricsError {
  let g = PermutationGroup::new([
    perm([[0, 1, 2, 3, 4]], size=6),
    perm([[0, 5], [1, 2], [3, 4]], size=6),
  ])
  set_symmetric_group_properties(g, 5, 6)
  g.is_symmetric_cache = Some(true)
  g.is_alternating_cache = Some(false)
  g
}

///|
/// Materialize a list of chosen transitive subgroups of `S_6`.
///
/// `print_report` is kept for parity with SymPy's debugging-oriented helper but is not used
/// in this MoonBit port.
pub fn find_transitive_subgroups_of_S6(
  targets : Array[S6TransitiveSubgroups],
  print_report? : Bool = false,
) -> Array[(S6TransitiveSubgroups, PermutationGroup)] raise CombinatoricsError {
  let _ = print_report
  let out : Array[(S6TransitiveSubgroups, PermutationGroup)] = Array::new()
  for t in targets {
    out.push((t, t.get_perm_group()))
  }
  out
}

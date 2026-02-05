///|
test "homomorphism trivial and isomorphism" {
  let c3 = cyclic_group(3)
  let gens = c3.generators()
  let hom_triv = homomorphism(
    HomGroup::PermGroup(c3),
    HomGroup::PermGroup(c3),
    [HomElement::Perm(gens[0])],
    images=[],
    check=true,
  )
  assert_true(hom_triv.is_trivial())

  let image = gens[0].pow(2)
  let hom_auto = homomorphism(
    HomGroup::PermGroup(c3),
    HomGroup::PermGroup(c3),
    [HomElement::Perm(gens[0])],
    images=[HomElement::Perm(image)],
    check=true,
  )
  assert_true(hom_auto.is_isomorphism() == Some(true))
}

///|
test "orbit homomorphism for S3" {
  let s3 = symmetric_group(3)
  let hom = orbit_homomorphism(s3, [0, 1, 2])
  assert_true(hom.is_isomorphism() == Some(true))
}

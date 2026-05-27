///|
test "groundtypes frontdoors wb: gcd lcm and gcdex" {
  inspect(python_gcd(30, 12), content="6")
  inspect(python_gcd(-30, 12), content="6")
  inspect(python_lcm(30, 12), content="60")
  inspect(python_lcm(-30, 12), content="60")
  inspect(python_lcm(0, 5), content="0")
  debug_inspect(python_gcdex(30, 12), content="(1, -2, 6)")
  debug_inspect(python_gcdex(-30, 12), content="(-1, -2, 6)")
  debug_inspect(python_gcdex(0, 5), content="(0, 1, 5)")
  debug_inspect(python_gcdex(0, 0), content="(0, 1, 0)")
}

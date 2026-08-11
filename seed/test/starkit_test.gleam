//// The gleeunit runner. Every `*_test.gleam` module in test/ is discovered automatically, so this
//// file exists only to give `gleam test` something to call.
////
//// The Script suites arrive with the Scripts themselves: youtube at T5.2, clean at T4.1 — that
//// one before Clean ever ran for real, because Kill never asks — and link at T6.1.

import gleeunit

pub fn main() {
  gleeunit.main()
}

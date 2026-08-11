//// The gleeunit runner. Every `*_test.gleam` module in test/ is discovered automatically, so this
//// file exists only to give `gleam test` something to call.
////
//// The Script suites arrive with the Scripts themselves: clean at T4.1 (written before Clean ever
//// runs for real, because Kill never asks), youtube at T5.2, link at T6.1.

import gleeunit

pub fn main() {
  gleeunit.main()
}

//// Which side Monitor seats the screen on, given what was typed.
////
//// A wrong side does not look like a failure: the screen moves, macOS saves the arrangement, and
//// the pointer leaves by the wrong edge at that desk until somebody drags it back.

import scripts/monitor
import starkit.{Bottom, Left, Notify, Right, Seat, Top}

pub fn each_side_is_seated_on_the_side_it_names_test() {
  assert monitor.seats("left") == [Seat(Left)]
  assert monitor.seats("top") == [Seat(Top)]
  assert monitor.seats("right") == [Seat(Right)]
  assert monitor.seats("bottom") == [Seat(Bottom)]
}

/// Typed in a hurry, on the Keyword's own line, with whatever case and spacing came out.
pub fn a_side_is_read_however_it_was_typed_test() {
  assert monitor.seats("  LEFT  ") == [Seat(Left)]
  assert monitor.seats("l") == [Seat(Left)]
  assert monitor.seats("above") == [Seat(Top)]
  assert monitor.seats("below") == [Seat(Bottom)]
}

/// Monitor Decides, so ↩ on the Keyword alone arrives here with nothing typed. It has to say what
/// to type instead of picking a side.
pub fn nothing_typed_moves_no_screen_test() {
  assert monitor.seats("")
    == [Notify("monitor takes a side: left, top, right or bottom.")]
}

pub fn a_word_that_is_not_a_side_moves_no_screen_test() {
  assert monitor.seats("laft")
    == [Notify("\"laft\" is not a side. Try left, top, right or bottom.")]
}

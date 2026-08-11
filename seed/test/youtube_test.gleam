//// What `youtube` gets right about a YouTube URL, and where it stops.
////
//// Only the pure half is tested: extracting the ID and building the markdown. The fetch is not —
//// a test that reaches YouTube fails on a train, and what it would be checking is oEmbed's
//// behaviour rather than this Script's. What *is* worth pinning is the ID, because every shape
//// below is one a person actually copies and a wrong ID pastes a link to the wrong video without
//// ever looking like a failure.

import scripts/youtube

// The six shapes. Every one of these is something YouTube's own share menu, address bar or embed
// dialog will hand you.

pub fn watch_url_test() {
  assert youtube.video_id("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    == Ok("dQw4w9WgXcQ")
}

pub fn short_url_test() {
  assert youtube.video_id("https://youtu.be/dQw4w9WgXcQ") == Ok("dQw4w9WgXcQ")
}

pub fn shorts_url_test() {
  assert youtube.video_id("https://www.youtube.com/shorts/dQw4w9WgXcQ")
    == Ok("dQw4w9WgXcQ")
}

pub fn embed_url_test() {
  assert youtube.video_id("https://www.youtube.com/embed/dQw4w9WgXcQ")
    == Ok("dQw4w9WgXcQ")
}

pub fn live_url_test() {
  assert youtube.video_id("https://www.youtube.com/live/dQw4w9WgXcQ")
    == Ok("dQw4w9WgXcQ")
}

pub fn old_embed_url_test() {
  assert youtube.video_id("https://www.youtube.com/v/dQw4w9WgXcQ")
    == Ok("dQw4w9WgXcQ")
}

pub fn bare_id_test() {
  assert youtube.video_id("dQw4w9WgXcQ") == Ok("dQw4w9WgXcQ")
}

// The decorations real URLs arrive wearing.

pub fn timestamp_is_not_part_of_the_id_test() {
  assert youtube.video_id("https://youtu.be/dQw4w9WgXcQ?t=42")
    == Ok("dQw4w9WgXcQ")
}

pub fn share_tracking_is_not_part_of_the_id_test() {
  assert youtube.video_id("https://youtu.be/dQw4w9WgXcQ?si=aBcDeFgHiJkLmNoP")
    == Ok("dQw4w9WgXcQ")
}

pub fn fragment_is_not_part_of_the_id_test() {
  assert youtube.video_id("https://www.youtube.com/watch?v=dQw4w9WgXcQ#t=1m")
    == Ok("dQw4w9WgXcQ")
}

pub fn mobile_host_test() {
  assert youtube.video_id("https://m.youtube.com/watch?v=dQw4w9WgXcQ")
    == Ok("dQw4w9WgXcQ")
}

pub fn no_scheme_test() {
  assert youtube.video_id("youtube.com/watch?v=dQw4w9WgXcQ")
    == Ok("dQw4w9WgXcQ")
}

pub fn surrounding_whitespace_test() {
  assert youtube.video_id("  https://youtu.be/dQw4w9WgXcQ\n")
    == Ok("dQw4w9WgXcQ")
}

/// The parameter that would fool a search for `v=`. `sv=` ends in `v=` and its value is not an ID,
/// so a Script reading the query as text rather than as parameters pastes the wrong link.
pub fn a_parameter_ending_in_v_is_not_the_id_test() {
  assert youtube.video_id(
      "https://www.youtube.com/watch?sv=nonsense&v=dQw4w9WgXcQ",
    )
    == Ok("dQw4w9WgXcQ")
}

pub fn v_after_other_parameters_test() {
  assert youtube.video_id(
      "https://www.youtube.com/watch?app=desktop&v=dQw4w9WgXcQ&feature=share",
    )
    == Ok("dQw4w9WgXcQ")
}

// What it declines. Every one of these is a Notify rather than a paste, and the Script cannot tell
// the difference between them — which is why the message says what it looked at.

pub fn empty_input_test() {
  assert youtube.video_id("") == Error(Nil)
}

pub fn not_youtube_test() {
  assert youtube.video_id("https://vimeo.com/123456789") == Error(Nil)
}

pub fn a_youtube_page_that_is_not_a_video_test() {
  assert youtube.video_id("https://www.youtube.com/feed/subscriptions")
    == Error(Nil)
}

pub fn too_short_to_be_an_id_test() {
  assert youtube.video_id("dQw4w9WgX") == Error(Nil)
}

pub fn too_long_to_be_an_id_test() {
  assert youtube.video_id("dQw4w9WgXcQtoolong") == Error(Nil)
}

/// Eleven characters, but one of them cannot appear in an ID — so this is prose, not a video.
pub fn eleven_characters_is_not_enough_test() {
  assert youtube.video_id("hello world") == Error(Nil)
}

// The note. Its shape is inherited from the Script Kit script this replaces, so these tests are
// pinning a decision made elsewhere — which is exactly why they are worth having: notes written
// before today and notes written after it have to read as one set.

pub fn markdown_is_an_embed_then_a_titled_line_test() {
  assert youtube.markdown(
      "Never Gonna Give You Up",
      "Rick Astley",
      "dQw4w9WgXcQ",
    )
    == "@[youtube](dQw4w9WgXcQ)\n\n- Never Gonna Give You Up | Rick Astley"
}

/// Brackets in a title are left alone. `@[youtube](…)` carries the ID, not the title, so there is
/// nothing for them to break.
pub fn a_title_keeps_its_own_brackets_test() {
  assert youtube.markdown(
      "[Official Video] Never",
      "Rick Astley",
      "abc_-123XYZ",
    )
    == "@[youtube](abc_-123XYZ)\n\n- [Official Video] Never | Rick Astley"
}

/// The title is normalised on its way into the note and the channel is not, which is what the
/// Script Kit lib did — pinned here because it is the sort of asymmetry a later reader would tidy.
pub fn the_title_is_normalised_and_the_channel_is_not_test() {
  assert youtube.markdown(
      "Don\u{2019}t Stop",
      "Bob\u{2019}s Channel",
      "dQw4w9WgXcQ",
    )
    == "@[youtube](dQw4w9WgXcQ)\n\n- Don't Stop | Bob\u{2019}s Channel"
}

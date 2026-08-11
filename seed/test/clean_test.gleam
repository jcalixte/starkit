//// Which applications Clean closes, given what is running.
////
//// Written before the filter it tests, which is true of nothing else in this project. Kill never
//// asks: an application that should have been kept is closed with whatever was unsaved in it, and
//// there is no dialog on the way and no undo afterwards. Everywhere else a bug is a wrong result
//// you can look at; here it is a result you cannot get back. So the list is pinned first and the
//// Script is written to match it.
////
//// The tests pass their own keep list rather than reading the shipped one, because that list is
//// yours to edit and a suite that asserted its contents would fail on every machine but this one.
//// What is asserted about the shipped Script is only what must hold on all of them: Starkit
//// survives, and the Need is declared.

import scripts/clean
import starkit.{Context, Kill, RunningApps, Script}

/// An empty keep list, which is what the seed ships and what the tests below use whenever the
/// question is about the filter rather than about anyone's preferences.
const nothing_kept: List(String) = []

// Clean is all or nothing (DESIGN.md §9, T4). With nothing kept, everything running dies.

pub fn everything_running_is_killed_test() {
  assert clean.kills(["Safari", "Slack", "Zed"], nothing_kept)
    == [Kill("Safari"), Kill("Slack"), Kill("Zed")]
}

pub fn nothing_running_is_nothing_to_kill_test() {
  assert clean.kills([], nothing_kept) == []
}

pub fn the_order_the_shelf_gathered_them_in_is_kept_test() {
  assert clean.kills(["Zed", "Safari"], nothing_kept)
    == [Kill("Zed"), Kill("Safari")]
}

// The keep list.

pub fn a_kept_application_is_not_killed_test() {
  assert clean.kills(["Safari", "Slack"], ["Slack"]) == [Kill("Safari")]
}

pub fn keeping_everything_that_runs_kills_nothing_test() {
  assert clean.kills(["Safari", "Slack"], ["Slack", "Safari"]) == []
}

pub fn a_kept_application_that_is_not_running_changes_nothing_test() {
  assert clean.kills(["Safari"], ["Photoshop"]) == [Kill("Safari")]
}

/// Case is not what a person is thinking about while editing a list of application names, and
/// getting it wrong here closes the application they wrote down to save.
pub fn the_keep_list_is_not_case_sensitive_test() {
  assert clean.kills(["Safari"], ["safari"]) == []
}

pub fn a_kept_name_written_with_stray_spaces_still_keeps_test() {
  assert clean.kills(["Safari"], [" Safari "]) == []
}

/// Whole names, not prefixes. `Safari` does not keep `Safari Technology Preview`, and by the same
/// rule `Chrome` does not keep `Google Chrome` — write the name macOS shows for the application.
/// A rule that matched loosely would be kinder to a typo and would also mean nobody can predict
/// what a keep list keeps, which is a bad trade for the one Effect that cannot be undone.
pub fn a_longer_name_is_a_different_application_test() {
  assert clean.kills(["Safari Technology Preview"], ["Safari"])
    == [Kill("Safari Technology Preview")]
}

// Starkit itself, which is not a preference.

pub fn starkit_is_never_killed_test() {
  assert clean.kills(["Starkit"], nothing_kept) == []
}

pub fn starkit_survives_a_screen_full_of_applications_test() {
  assert clean.kills(["Safari", "Starkit", "Slack"], nothing_kept)
    == [Kill("Safari"), Kill("Slack")]
}

pub fn starkit_is_never_killed_however_it_is_spelled_test() {
  assert clean.kills(["starkit"], nothing_kept) == []
}

// The shipped Script, through the same door the Shelf uses.

pub fn the_script_declares_the_running_apps_it_filters_test() {
  let assert Script(needs:, ..) = clean.script()
  assert needs == [RunningApps]
}

pub fn the_script_kills_what_the_shelf_handed_it_test() {
  let assert Script(run:, ..) = clean.script()
  assert run("", Context(running_apps: ["Safari", "Starkit"]))
    == [Kill("Safari")]
}

/// Clean Decides, so there is nothing to type after the Keyword and nothing typed there is read.
pub fn anything_typed_after_the_keyword_is_ignored_test() {
  let assert Script(run:, ..) = clean.script()
  assert run("everything", Context(running_apps: ["Safari"]))
    == [Kill("Safari")]
}

/// The one name the seed ships in the keep list, and the reason it is a preference rather than a
/// guarantee: killing Finder only makes macOS start it again.
pub fn the_shipped_keep_list_spares_finder_test() {
  let assert Script(run:, ..) = clean.script()
  assert run("", Context(running_apps: ["Finder", "Safari"]))
    == [Kill("Safari")]
}

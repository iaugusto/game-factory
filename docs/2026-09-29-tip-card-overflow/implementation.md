# Tip card overflow ("black screen" after a card): a small fix

A lightweight note in place of research, plan and log: this was a small, obvious fix
(CLAUDE.md §3).

## 2026-09-29 — the bug, the cause, the fix

**Report (the user):** "when closing the last card, a black screen pops up and I need to
click again to go back to the game", and "it takes up the whole screen, top to bottom".

**Reproduced** with a throwaway scene test. It played a hand-picked run with tips on, rendered
real frames, turned every card and logged the card's rect each frame.
- The special-attack tutorial's first card was 435 px tall and on screen.
- Its second card ("How to use it") was **1222 px tall at y = −342**. It covered the whole
  screen with the dim and the card's empty middle, and its text was off screen, so it looked
  black and needed another tap.

**Cause:** that card's extra line ("Ready when each wave starts, then reloads in N s.") is a
wrapping `Label` with no minimum width (`RunController.ability_pages`). Inside the card's
containers a width-less wrapping label wraps at almost zero width: one word per line. The body
label never had the problem, because it has `custom_minimum_size.x`.

**Fix (`ui/tip_layer.gd`):**
- `_fit_text` gives every wrapping label in a card's extra slot the text column's width
  (`TEXT_WIDTH`, now shared with the body). Future wrapping extras are covered too, not just
  this one. The card is now 222 px.
- The dim now fades with `freeze` (`_dim.modulate.a`). It used to stay fully dark for the
  0.15 s after a tip closed and then vanish at once.

**Test:** `run_scene_test.test_every_special_attack_tutorial_card_fits_on_screen` checks every
attack's tutorial cards stay under 60% of the screen height, using `TipLayer.card_height()`.

**Result:** 271/271 game tests. Not checked by hand here: the fix on the user's machine. They
should replay the first pick of a new special attack.

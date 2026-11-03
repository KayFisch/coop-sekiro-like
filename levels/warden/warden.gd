extends Node2D
## Columna Bifrons, the Warden of the Threshold (docs/boss_bifrons_warden.md), until he's built as
## a boss of his own: the try-out boss on Bifrons's stage (an inherited scene of
## levels/threshold/threshold.tscn), set up as the Warden. The switches that make him that are
## held here for as long as the room is there (Moves.fix()), whatever F1 says; the saved ones are
## left alone. His numbers on F2 are the try-out boss's (page "bifrons"): tuning one tunes both.

# What makes the try-out boss the Warden (the Moves switches, "Bifrons" tab).
const SWITCHES = {
	"bifrons_mode": "chains",  # a motif repeated, a finale by what he sees, a breath
	"bifrons_guard_break": "motif_end",  # his guard breaks only at a motif's end, all of it parried
	"bifrons_coop_windows": true,  # a co-op parry opens a window for each
	"bifrons_blade_parries": true,  # one parry per blade: two on one place, parry together
	"bifrons_throw_by_outcome": true,  # parried, thrown part way; blocked or hit, all the way
	"bifrons_chain_stagger": true,  # a co-op parried finale staggers him the longer, the more parried
	"bifrons_face": true,  # the players face him
}


func _enter_tree():
	Moves.fix(SWITCHES)  # before he and the players are ready


func _exit_tree():
	Moves.unfix()

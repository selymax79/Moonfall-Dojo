extends "res://scripts/run_records.gd"
var save_calls := 0
func save_records():
	save_calls += 1
	super.save_records()

extends RefCounted
var rng := RandomNumberGenerator.new()
var second: Array = []
const PAIRS = [[0,1],[2,3],[1,0],[3,2],[0,3],[1,2],[2,0],[3,1]]
func pick(level_value: int) -> Array:
	if not second.is_empty():
		var result = second
		second=[]
		return result
	var chance: float = 0 if level_value<4 else (0.1 if level_value<6 else (0.15 if level_value<10 else (0.2 if level_value<15 else (0.22 if level_value<20 else 0.25))))
	if level_value>=4 and rng.randf()<chance:
		var pool: int=2 if level_value<7 else (4 if level_value<10 else 8)
		var pair: int=rng.randi_range(0,pool-1)
		var side: int=1 if rng.randi_range(0,1)==0 else -1
		second=[PAIRS[pair][1],-side,pair,1]
		return [PAIRS[pair][0],side,pair,0]
	return [rng.randi_range(0,3),1 if rng.randi_range(0,1)==0 else -1,-1,-1]

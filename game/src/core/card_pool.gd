class_name CardPool
extends RefCounted
## Draws the pick-1-of-3 offer: weighted, no duplicates within an offer, never a card the run
## has already taken `max_stacks` times, never a card with weight 0.


static func draw(cards: Array[CardDef], taken: Dictionary[StringName, int], count: int,
		rng: RandomNumberGenerator) -> Array[CardDef]:
	var pool: Array[CardDef] = []
	for card: CardDef in cards:
		if card.weight > 0.0 and taken.get(card.id, 0) < card.max_stacks:
			pool.append(card)
	var offer: Array[CardDef] = []
	while offer.size() < count and not pool.is_empty():
		var total: float = 0.0
		for card: CardDef in pool:
			total += card.weight
		var roll: float = rng.randf() * total
		var picked: int = pool.size() - 1
		for i: int in pool.size():
			roll -= pool[i].weight
			if roll < 0.0:
				picked = i
				break
		offer.append(pool[picked])
		pool.remove_at(picked)
	return offer

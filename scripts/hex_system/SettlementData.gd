class_name SettlementData
extends RefCounted

var coordinates: HexCoordinates
var settlement_type: String # "village", "town", "city", "capital"
var size: int # Number of hexes
var specialization: String # "mining", "trading", "farming", "general"
var occupied_hexes: Array = []

func _init(coords: HexCoordinates, type: String, settlement_size: int):
	coordinates = coords
	settlement_type = type
	size = settlement_size
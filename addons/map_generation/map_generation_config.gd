class_name MapGenerationConfig
extends Resource

@export var width := 333
@export var height := 333
# The lower the number, the bigger the features
@export var terrain_scale := 0.081
# High number for ore so we get lots of little pockets (big number = small features)
@export var ore_scale := 0.181
# Similar to conway's game of life, but with different parameters
# Populated tiles with fewer neighbours than the death_limit will die
# Empty tiles with more neighbours than the birth_limit will spawn in
# Serves to smooth out the caves after generating them from the height map
@export var simulation_steps := 4
@export var death_limit := 5
@export var birth_limit := 6

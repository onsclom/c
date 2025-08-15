package game

Particle :: struct {
	x:                f32,
	y:                f32,
	dx:               f32,
	dy:               f32,
	life:             f32,
	lifespan:         f32,
	shrink_with_life: bool,
	active:           bool,
}

MAX_PARTICLES :: 1024

Particles :: struct {
	particles: [MAX_PARTICLES]Particle,
	capacity:  i32,
	count:     i32,
}

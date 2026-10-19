extends RefCounted
## The same triangles are used for rendering and small-animal support.
static func height_at(x: float, z: float) -> float:
	var wash: float = exp(-pow((x-8.0-3.0*sin(z*.055))/5.2,2.0))
	# Broad, synthetic basin shoulders make the low wash read in the middle
	# distance. The shared height function keeps every planted root and animal
	# support on the same triangles; these are not surveyed landforms.
	var west: float = 4.7*exp(-pow((x+43.0)/27.0,2.0)-pow((z+46.0)/63.0,2.0))
	var east: float = 3.4*exp(-pow((x-47.0)/29.0,2.0)-pow((z+52.0)/72.0,2.0))
	return .40*sin(x*.045)+.26*cos(z*.063)+.12*sin((x+z)*.14)-.74*wash+west+east

static func surface_at(x: float, z: float) -> Dictionary:
	var x0: float = floor(x/2.)*2.
	var z0: float = floor(z/2.)*2.
	var u: float = (x-x0)/2.
	var v: float = (z-z0)/2.
	var a: float = height_at(x0,z0)
	var b: float = height_at(x0+2.,z0)
	var c: float = height_at(x0,z0+2.)
	var d: float = height_at(x0+2.,z0+2.)
	var dx: float = (b-a)/2. if u+v<=1. else (d-c)/2.
	var dz: float = (c-a)/2. if u+v<=1. else (d-b)/2.
	var y: float = a+u*(b-a)+v*(c-a) if u+v<=1. else d+(1.-u)*(c-d)+(1.-v)*(b-d)
	return {"height":y,"normal":Vector3(-dx,1.,-dz).normalized()}

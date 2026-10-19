extends RefCounted
## Adapted position-only ERFA Moon98 / Pfw06, v2.0.1; not IAU endorsed.
## Copyright (C) 2013-2023, NumFOCUS Foundation; full terms assets/licenses/ERFA.txt.
## Read-only TT/TDB dynamical date; no world clock or integration state.
const Data = preload("res://scripts/data/lunar_coefficients.gd")
const START_JD: float=2378496.5
const END_JD: float=2469807.5
const OBLIQUITY: float=23.439291111

static func polynomial(t: float, coefficients: Array) -> float:
	var result: float=0.
	for i: int in range(coefficients.size()-1,-1,-1): result=result*t+float(coefficients[i])
	return result

static func argument(t: float, coefficients: Array) -> float:
	return deg_to_rad(fposmod(polynomial(t,coefficients),360.))

static func rotate_z(v: Array[float], angle: float) -> Array[float]:
	var c: float=cos(angle); var s: float=sin(angle)
	return [c*v[0]+s*v[1],-s*v[0]+c*v[1],v[2]]

static func rotate_x(v: Array[float], angle: float) -> Array[float]:
	var c: float=cos(angle); var s: float=sin(angle)
	return [v[0],c*v[1]+s*v[2],-s*v[1]+c*v[2]]

static func sample(jd: float) -> Dictionary:
	if not is_finite(jd) or jd<START_JD or jd>END_JD: return {"valid":false}
	var t: float=(jd-2451545.)/36525.
	var lp: float=argument(t,[218.31665436,481267.88123421,-.0015786,1./538841.,-1./65194000.])
	var d: float=argument(t,[297.8501921,445267.1114034,-.0018819,1./545868.,1./113065000.])
	var m: float=argument(t,[357.5291092,35999.0502909,-.0001536,1./24490000.])
	var mp: float=argument(t,[134.9633964,477198.8675055,.0087414,1./69699.,-1./14712000.])
	var f: float=argument(t,[93.2720950,483202.0175233,-.0036539,1./3526000.,1./863310000.])
	var a1: float=argument(t,[119.75,131.849])
	var a2: float=argument(t,[53.09,479264.290])
	var a3: float=argument(t,[313.45,481266.484])
	var eccentricity: float=1.+(-.002516-.0000074*t)*t
	var longitude: float=.003958*sin(a1)+.001962*sin(lp-f)+.000318*sin(a2)
	var radius: float=0.
	var latitude: float=-.002235*sin(lp)+.000382*sin(a3)+.000175*sin(a1-f)+.000175*sin(a1+f)+.000127*sin(lp-mp)-.000115*sin(lp+mp)
	for i: int in range(Data.LONGITUDE_DISTANCE.size()-1,-1,-1):
		var row: Array=Data.LONGITUDE_DISTANCE[i]
		var angle: float=row[0]*d+row[1]*m+row[2]*mp+row[3]*f
		var factor: float=pow(eccentricity,absi(int(row[1])))
		longitude+=row[4]*sin(angle)*factor
		radius+=row[5]*cos(angle)*factor
	for i: int in range(Data.LATITUDE.size()-1,-1,-1):
		var row: Array=Data.LATITUDE[i]
		var angle: float=row[0]*d+row[1]*m+row[2]*mp+row[3]*f
		latitude+=row[4]*sin(angle)*pow(eccentricity,absi(int(row[1])))
	longitude=lp+deg_to_rad(longitude); latitude=deg_to_rad(latitude)
	radius=(radius+385000560.)/1000.
	var v: Array[float]=[radius*cos(latitude)*cos(longitude),radius*cos(latitude)*sin(longitude),radius*sin(latitude)]
	# F-W mean ecliptic of date -> GCRS, matching ERFA's passive rotations.
	var gamma: float=deg_to_rad(polynomial(t,[-.052928,10.556378,.4932044,-.00031238,-.000002788,.0000000260])/3600.)
	var phi: float=deg_to_rad(polynomial(t,[84381.412819,-46.811016,.0511268,.00053289,-.000000440,-.0000000176])/3600.)
	var psi: float=deg_to_rad(polynomial(t,[-.041775,5038.481484,1.5584175,-.00018522,-.000026452,-.0000000148])/3600.)
	v=rotate_z(rotate_x(rotate_z(v,psi),-phi),-gamma)
	var tilt: float=deg_to_rad(OBLIQUITY)
	var world: Array[float]=[v[0],-sin(tilt)*v[1]+cos(tilt)*v[2],-cos(tilt)*v[1]-sin(tilt)*v[2]]
	return {"valid":true,"gcrs_km":v,"world_components_km":world,"world_km":Vector3(world[0],world[1],world[2]),"distance_km":radius}

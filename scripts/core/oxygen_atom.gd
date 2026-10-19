extends RefCounted
## Normalized hydrogenic reference shapes, not a neutral-oxygen wavefunction.
const ATOMIC_NUMBER: int = 8
const MASS_NUMBER: int = 16
const OCCUPANCIES: Array[int] = [2,2,4]
const SCALE: float = 0.35 # Authored display unit, NOT an oxygen radius or Bohr radius.
const SOURCE: String = "https://physics.nist.gov/PhysRefData/Handbook/Tables/oxygentable1.htm"
const ISOTOPE_SOURCE: String = "https://physics.nist.gov/cgi-bin/Compositions/stand_alone.pl?ele=O"
const SHAPE_SOURCE: String = "https://ocw.mit.edu/courses/8-04-quantum-physics-i-spring-2016/e34ceed6a6ec944a3c761fcbbf48be5f_MIT8_04S16_LecNotes22.pdf"
const LABELS: Array[String] = ["电子组态 · 2 / 2 / 4", "1s · 球对称", "2s · 径向节点", "2p · 两瓣与节点平面", "原子核 · 单独放大"]
const NOTES: Array[String] = [
	"中性氧有8个电子：1s² 2s² 2p⁴。这里按2:2:4混合参考密度，2p取方向平均；不是氧原子的精确密度。",
	"1s有球对称的概率密度，没有径向节点。图中连续云表示分布，不是一个电子绕核飞行。",
	"2s有一个球形径向节点。开启剖面，观察内外两片分布之间的暗环；节点处概率密度为零。",
	"这里选一个2p方向展示两瓣；中间平面是节点。两瓣是同一个轨道，不是两个电子。方向为显示选择，未给氧原子指定固定朝向。",
	"选用氧-16说明组成：8个质子、8个中子。橙色表示质子，蓝色表示中子；小球排布和尺寸为示意，不是核内部照片。核已单独放大，不能与电子云比较大小。"
]

static func density(point: Vector3, mode: int) -> float:
	var u: float=point.length()/SCALE
	var volume: float=PI*pow(SCALE,3)
	var s1: float=exp(-2*u)/volume
	var s2: float=pow(2-u,2)*exp(-u)/(32*volume)
	var p_average: float=u*u*exp(-u)/(96*volume)
	var py: float=pow(point.y/SCALE,2)*exp(-u)/(32*volume)
	match mode:
		1: return s1
		2: return s2
		3: return py
		0: return (2*s1+2*s2+4*p_average)/8
	return 0.0

static func radial_probability(radius: float, mode: int) -> float:
	# Angle-integrated density; py has the same radial PDF as direction-averaged p.
	var u: float=radius/SCALE
	match mode:
		1: return 4*u*u*exp(-2*u)/SCALE
		2: return u*u*pow(2-u,2)*exp(-u)/(8*SCALE)
		3: return pow(u,4)*exp(-u)/(24*SCALE)
		0: return (2*radial_probability(radius,1)+2*radial_probability(radius,2)+4*radial_probability(radius,3))/8
	return 0.0

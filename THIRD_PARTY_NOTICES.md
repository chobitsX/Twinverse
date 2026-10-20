# 第三方署名与来源 / Third-party notices

这是运行内容的归属索引，不把不同来源合并为同一种许可。[逐文件清单与哈希](docs/community/ASSET_INVENTORY.json)标明当前公开候选包含的内容；原始来源记录中的历史路径可能指向单独保留的制作资料。

| 内容 | 署名与依据 | 范围 |
|---|---|---|
| 地球历史地表与云图 | NASA Earth Observatory / Blue Marble: Next Generation；NASA GSFC / Reto Stöckli、Robert Simmon；[NASA媒体政策](https://www.nasa.gov/nasa-brand-center/images-and-media/) | 2004-01地表与2002年发布云合成，非实时天气；保留署名，不表示NASA背书 |
| 木星Hubble历史图 | NASA, ESA, A. Simon (GSFC), M. Wong (UC Berkeley), G. Orton (JPL-Caltech)；[具体来源](https://svs.gsfc.nasa.gov/12021/) | 2015合成图，PNG转换及作者极区边缘延展有记录 |
| 土星与月球表面图 | NASA/JPL-Caltech；NASA/GSFC/Arizona State University；[来源元数据](assets/textures/cosmos/) | 具体图像按各自媒体页/来源记录，不整体改授MIT或CC0 |
| 火星/水星及木星主要卫星图 | NASA Ames / Viking / USGS；MESSENGER Team / ASU / ACT / USGS；NASA/JPL/USGS | 官方历史拼接图，运行版本缩小；覆盖掩膜为处理输出，原机构署名保留 |
| 行星与天然卫星数据 | NASA/JPL Solar System Dynamics、Horizons、NAIF；[Horizons](https://ssd.jpl.nasa.gov/horizons/) | 冻结的有限日期几何数据与派生缓存；原始核/响应不全量放入源码快照 |
| 参考恒星目录 | Hoffleit & Warren，NASA HEASARC BSC5P；[目录说明](https://heasarc.gsfc.nasa.gov/W3Browse/star-catalog/bsc5p.html) | 8404颗固定J2000方向参考，见[原记录](assets/licenses/ground_sky262.txt) |
| 地面观星银河图 | **ESA/Gaia/DPAC；Acknowledgement: A. Moitinho**；[CC BY-SA 3.0 IGO](https://creativecommons.org/licenses/by-sa/3.0/igo/) | 原4000×2000 PNG及图像改编保留该许可；不表示ESA背书 |
| 岩石/海床/林地表面 | Rob Tuytel及各元数据所列作者 / Poly Haven；[CC0](https://polyhaven.com/license) | Coast Rocks 05、Coral Ground 02、Forest Ground、Bark等；项目有重拓扑、烘焙、缩小或材质调节 |
| Pocillopora参考扫描 | Smithsonian Institution, NMNH Invertebrate Zoology, **USNM44359**；J. I. Tracey，1946，Bikini Atoll；[特定3D媒体](https://3d.si.edu/es/object/3d/pocillopora-damicornis%3A5dbbb9af-2a48-4665-839e-e66faf13ff85) | 该媒体记录为公共领域；项目修改大小、几何与外观，不代表当地活体标本 |
| 月球位置/姿态计算派生内容 | Copyright NumFOCUS Foundation；ERFA，源自SOFA；[完整条款](assets/licenses/ERFA.txt) | `scripts/core/lunar_ephemeris.gd`、`scripts/data/lunar_coefficients.gd`中的派生内容，不表示IAU认可 |
| 区域环境数据 | NOAA NCEI / World Ocean Atlas 2023，DOI **10.25921/va26-hv25** | `data/environment/`保留具体文件URL、SHA与历史年均数据边界 |
| 生态生成模型/表面 | Twinverse contributors；使用Tripo Studio H3.1，项目原创几何与局部后处理；[Tripo条款](https://www.tripo3d.ai/terms) | 维护者已确认生成时付费；自有可授权部分按CC BY 4.0，第三方输入/原料不因此改变许可 |
| 原创程序模型、材质与声音 | Twinverse contributors；部分二维素材使用生成工具辅助 | 运行代码按MIT，清单中可授权美术按CC BY 4.0；程序声景不是现场录音 |
| 引擎 | Godot Engine contributors；[MIT许可](https://godotengine.org/license/) | 源码不含Godot二进制；预览包附带[引擎与完整组件许可](LICENSES/GODOT-NOTICES.txt)，由同版本官方引擎API导出，可能含仅编辑器使用的组件条目。分发应用时保留这些说明 |

模型属于教学参考，不能因其生成方式或视觉精细度推定解剖精度。运行时使用系统字体，没有单独捆绑字体文件。

## Maintainer confirmation

2026-10-19：项目所有者确认Tripo相关模型生成时已付费，并为其有权授权的自有/生成美术选择CC BY 4.0。早期`tripo268.txt`和`tripo269.txt`中的“账户档位未独立核实”描述的是当时记录状态；本说明补充当前所有者确认，不伪造历史账单或平台出具的证明。

Source and license URLs were checked during open-source preparation. This index does not grant rights belonging to the listed institutions; keep each asset's notices when redistributing or adapting it.

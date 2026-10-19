# Twinverse 应用翻译

应用文字采用中文源码消息和本地 `localization/en.json` 英文目录。两种语言均离线运行，不使用在线翻译。资源文本沿用项目代码/文字的 MIT 许可。0.4.188候选已具备中英文功能，集中视觉评阅另行记录；后续新增内容的缺项以检查器为准。

工具菜单提供跟随系统、简体中文和 English。中文系统语言（含地区/文字变体）选择简体中文，其他系统语言回退英文。`AppLanguage` 将偏好保存在独立的 `user://language.cfg`；语言不进入世界存档，不改变存档保护策略。`--language=en` / `--language=zh_CN` 是不写盘的诊断启动覆盖。仅在`--no-save`诊断下可用`--language-config=...`指定隔离配置，供跨进程和导出包检查，避免改用户偏好。

## 添加或修改文字

1. 对完整消息添加英文，源文和译文都保持真实的换行。动态消息先调用 `I18n.text("…%s…")`，再用 `%` 填入数值。保留占位符的类型、精度、顺序以及 `%%`。
2. 常量中的显示文字通过 `I18n.dictionary` / `strings` / `dictionaries` 获取展示副本；动态对象列表用 `present_dictionaries`。字典键、对象 ID、存档字段、资源路径和科学数值保持原值。不要把译文反写到权威数据。
3. 场景初始化构造期间 `VisualStage` 使用原文作用域，保留可跨语言复用的元数据。界面读取时本地化，不为换语言重建世界或模拟。HUD 切换重建仅刷新文字，恢复面板、查询、筛选、主题和观察状态；新增暂态控件时应补充状态保留。初始化的`content_summary`、`scientific_label`和`scientific_note`用`AppText.set_meta_text`保存：原字段仍为原文字符串，场景另持有由`parts`或`format/args`组成的消息描述；UI用`meta_text`读取。这样组合长文和数值模板可按当前语言重绘，消息描述随场景释放，不引入另一份模拟。
4. 静态文字、标签与工具提示都要覆盖。`AppText.text` 先翻译完整消息，必要时再按段落处理组合元数据；带变量的句子应使用完整模板，不靠替换单词重组语序。
5. 运行 `python3 tools/check_localization.py --write-audit`。正式检查不加 `--allow-missing`；该选项仅用于实施中的检查点。检查器审计脚本、场景及冻结卫星名录，核对缺项、格式化占位符和富文本标记。原生语言选择名的例外记录在 `localization/exclusions.json`，必须给出原因。
6. 用真实场景检查已显示内容、新建动态内容、中英往返、菜单和偏好重启；检查英文长文本和窄窗，不缩小字体掩盖溢出。无界面检查不能证明视觉排版合格。

卫星名录已有标准英文 `name`；目录的对应翻译来自这一字段，保留中文 `display_name` 和原科学数据。更新冻结名录时同时核对翻译，不在线更新或重算星历。

## 术语与科学边界

- 主要导航使用 Explore（导览）、Learn（知识）、Clean view（纯净观察）；正式说明使用 scientific illustration（科学示意）、reference model（参考模型）、authored（作者设置）。
- 同一物种统一英文名并保留拉丁学名；物种 ID、个体 ID、教学目标 ID 不翻译。图鉴名称应与近景、导览和生态关系一致。
- 天文正文使用 natural satellite，简短控件和已命名天体可用 moon。orbit / orbital period 与 rotation / sidereal rotation 分别表达公转与自转。
- 保留真实单位、有效日期、未知值与数据来源；unknown / not modeled / uncalibrated / not measured 等限制不得省略。显示放大、距离压缩和识别点不代表真实大小等说明同样是翻译内容。
- ref_O、ref_ATP、ref_E 等参考单位不能改写成真实耗氧、浓度或焦耳。节点、轨道云形、热压力教学和生态反馈的科学边界沿用原文。

## 相称验证

语言服务的隔离检查为 `tests/core/test_app_language.gd`；真实世界/HUD 的有限短检查为 `tests/integration/i18n_smoke.gd`，使用 `--no-save`。通过 `tools/godot.sh` 启动，沿用全项目共享运行锁、nice10 和两工作线程。执行前核对实际项目进程，全部引擎检查串行；不增加性能长测。

当前证据与未完成范围记在 `STATE.md`、`PLAN.md` 和 `docs/evidence/I18N-001`。导出时必须包含 `localization/*.json`，并在导出包实际复查语言偏好和展示内容。

## English quick start

Add authored English messages to `localization/en.json`, using the original Chinese message as the key. Translate a complete format template before interpolation. Preserve placeholders, rich-text markup, scientific limits, units and citations. Keep IDs and numerical data outside translation. `AppText` localizes presentation copies; language changes must retain the same world and scene. Run `python3 tools/check_localization.py --write-audit`, then bounded real-scene checks for switching, persistence and narrow-window layout. Use the shared launch guard and resource budget. In the maintainer workspace, `STATE.md` records ongoing work. Public checkouts use check output and release notes. A partial catalog is not a finished English release.

# 参与 Twinverse / Contributing

感谢你帮助更多人通过观察理解世界。欢迎中文或英文的Issue和Pull Request，也欢迎科学审校、翻译、美术和测试贡献。

## 第一份贡献

先阅读[运行指南](docs/community/DEVELOPMENT.md)，再从[具体的小任务](docs/community/FIRST_CONTRIBUTIONS.md)选择一项。报告问题不要求你先修复代码。较大改动先开Issue说明教育目的、现有问题与范围，便于协调。

## 修改流程

1. Fork仓库并创建描述工作内容的分支。
2. 保持改动集中；在PR中说明问题、结果和验证方法。
3. 文档/模板改动运行`python3 tools/check_community.py`。运行代码改动再做相称的核心测试或短场景检查，见[开发指南](docs/community/DEVELOPMENT.md)。
4. 画面或操作变化附截图/短说明。说明哪些硬件、场景和输入实际测过；未测内容直接写明。
5. 提交PR，等待维护者讨论与审阅。新贡献者不必提交内部开发历史或已有的大型诊断目录。

## 项目约定

- 应用翻译先看[本地化说明](docs/LOCALIZATION.md)，保留科学边界、占位符与稳定ID；在真实场景验证语言切换和排版。
- 使用typed GDScript。保持唯一世界时间与明确的场景资源所有权。
- 画质、帧率和演示倍率不得偷偷改变科学运行规律。显示放大、距离压缩和教学近似需要在界面说明。
- 天文/生物知识变化提供可核对的主要来源，优先机构资料、研究论文及数据集；区分事实、模型假设和美术表现。
- 科学数据更新要记录来源、有效时间、坐标/单位和再生成方式，并保留误差或缺测说明。
- 新资产注明作者、工具、来源URL、许可与改动。生成模型也需要形态核查，不能当作测量或扫描。
- 默认只运行一个本项目3D实例；保持30/5 FPS、两共享工作线程。短检查足以证明改动时，不要求贡献者跑长压力测试。
- 友善、具体地讨论问题。尊重不同语言、知识背景和可用设备，避免针对个人的攻击。

## 素材与署名

自有代码/文字贡献按MIT；自有美术贡献按CC BY 4.0。提交第三方或派生内容时必须明确其原许可和范围，不能仅勾选“原创”。不要求转让版权；请确认你有权提供相应贡献。[完整许可范围](LICENSING.md)

不上传账号凭据、带访问令牌的下载地址、用户存档或未经检查的整份设备日志。设备反馈只需系统版本、CPU/GPU、内存、画质与复现步骤，无需机器序列号。

## English summary

Issues and PRs are welcome in Chinese or English. Pick a small task, describe the user-visible result, and report only validation you actually performed. Use typed GDScript and preserve shared world time. Science changes need primary references and explicit assumptions. Assets need source, credit, license and modification records. Project-owned code/docs are MIT; project-owned artwork is CC BY 4.0. Third-party terms remain in force. Keep feedback respectful and remove credentials or private details from reports.

Application translation guidance: [Localizing Twinverse](docs/LOCALIZATION.md). Keep scientific limitations, placeholders, IDs and numeric data intact; verify language switching and layout in real scenes.

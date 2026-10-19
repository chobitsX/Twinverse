# 第一份贡献 / First contributions

以下是可以转为Issue的具体任务草案。开始前先查看已有Issue和PR，避免重复；当前文档不是已自动创建的远程Issue列表。

| 任务 | 范围与入口 | 完成标准 |
|---|---|---|
| 新机器第一次运行报告 | Windows集显、入门独显或8GB Mac；按开发指南操作 | 记录系统/GPU/内存、导入结果、质量档与一条可复现路径；成功和失败都有价值 |
| 改进一处操作说明 | `docs/community/GETTING_STARTED.md` | 找一位首次使用者，记录一个真实困惑，修改对应说明并解释解决了什么 |
| 英文术语核对 | `README.en.md`与`docs/community/SCIENCE.md` | 对一个领域提出少量有依据的术语/表达修正，保留原科学范围 |
| 核对一个知识主题的来源 | `scripts/experience/learning_topics.gd`或`science_reference.gd` | 指出主题、具体句子与主要来源；提出文本更正，不扩大模型已经实现的能力 |
| 一处窄窗可读性问题 | 在实际窗口中复现后定位对应界面脚本 | 提供分辨率/缩放、前后截图，修复截断或重叠且保留3D观察入口 |
| 改善一个物种的局部外观 | 先与维护者讨论，再修改对应运行GLB | 保留身份/行为与尺寸关系，附来源、许可、面数/贴图/体积和同机位对照；不默认标作新手任务 |

文档/来源核对适合小PR；模型和渲染改动通常需要更多沟通。提出任务时写清楚“完成后用户能看到什么”，避免以“整体重构”“全部优化”作为第一项。

## 建议标签

维护者建立仓库后可使用`good first issue`、`help wanted`、`science`、`documentation`、`art`和`platform-test`。只给边界清楚、确实适合首次参与的任务加新手标签。

## English

Good starting points include a first-run device report, one confusing instruction, a small terminology correction, one science-source check, or a reproducible narrow-window UI issue. Asset work needs prior discussion and is not automatically a beginner task. These are local task drafts, not remotely created issues.

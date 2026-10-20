# Building Twinverse with AI / 使用 AI 共建 Twinverse

Twinverse has been developed entirely through an **AI Coding** workflow, using
tools such as **Codex** and **Claude Code**. The creator directs the work and
reviews the results. We welcome contributors who use coding agents to maintain
and improve the project, as well as science, translation, art and testing
contributions. Choose the tools that work for you.

The existing application runs without an AI subscription, model API key, Tripo
account or Blender installation. Godot and the development prerequisites are
described in [Development](DEVELOPMENT.md).

## Give your agent a useful starting point

Open the repository root in your coding tool and start with a small Issue or a
specific change. The shared rules live in [AGENTS.md](../../AGENTS.md):

- Codex discovers repository AGENTS.md instructions. Confirm the repository
  root and instruction sources in your session.
- [CLAUDE.md](../../CLAUDE.md) imports `@AGENTS.md`, providing the same rules in
  Claude Code sessions that load CLAUDE.md. Recent Claude Code versions also
  support AGENTS.md directly. Check `/context` rather than assuming the active
  session loaded the intended project instructions.
- With another agent, explicitly ask it to read AGENTS.md and the linked guides
  if it does not discover them itself.

These loading rules follow [official OpenAI documentation](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
and [Claude Code's project memory documentation](https://code.claude.com/docs/en/memory).
Tool settings, versions and organization policy can affect what is loaded.
The repository does not change your account permissions or agent configuration.

The optional `AGENTS.maintainer.md` and the maintainer's state/history files are
local maintenance context. A public clone needs only the shared files linked
here; their absence does not prevent contribution.

## A practical contribution loop

1. Fork the repository, create a branch and choose a bounded task from an Issue
   or [First contributions](FIRST_CONTRIBUTIONS.md). Describe the educational or
   user-visible outcome and the expected check.
2. Ask the agent to inspect the affected code, repository rules and existing
   tests before proposing a small implementation. Keep world state/time, science
   data, IDs and resource budgets intact.
3. Review the diff and run relevant checks. Documentation changes need the
   community check; text changes also need localization checks. Application
   changes need a relevant core test or short scene run. Keep the single-job
   and bounded hardware rules from AGENTS.md.
4. For visual or input changes, inspect the real engine result. For science or
   assets, verify the source, model boundaries, units and license. Explain an
   uncertainty instead of filling it with a generated fact.
5. Summarize the problem, result, evidence and remaining limits in a PR. Leave a
   short next-step note when handing work to another person or agent. Using AI
   does not replace a reproducible verification record.

The tool/model used can be useful context in a PR, but full prompts, private
chats, API keys and account data are not needed. Contributors remain responsible
for the submitted change and its licensing. See [Contributing](../../CONTRIBUTING.md).

## Starter prompt

```text
Read AGENTS.md, CONTRIBUTING.md and docs/community/DEVELOPMENT.md.
Inspect the current Git status and preserve existing work.
For Issue <number> / <specific problem>, explain the affected path and expected
result, make the smallest useful change, and run the relevant documented checks.
Preserve shared world time/state, scientific boundaries and resource limits.
Report the diff, checks actually run, remaining limits and the next step.
Follow my existing authorization for commits and publication.
```

No paid generation service is needed for routine code, documentation, translation
or testing work. Obtain the user's authorization when a task actually requires
spending credits or publishing externally.

## 中文说明

Twinverse 从一开始就以 **AI Coding** 方式进行开发，使用 Codex、Claude Code 等
工具完成实现，由发起者提出目标、指导并核查结果。我们欢迎其他贡献者继续用 AI
一起维护项目，也欢迎科学审校、翻译、美术与测试等参与方式。

把仓库根目录交给你的工具，先读 AGENTS.md、贡献指南和开发指南，再选一个范围小、
结果可验证的问题。CLAUDE.md 使用 @AGENTS.md 共享规则；其他工具可手动读取这些文件。
无需维护者的私人聊天、状态历史、账号或生成服务密钥，就能运行现有内容、开始贡献。

请保留唯一世界时间/状态、科学数据与稳定ID；画面与交互要看真实引擎结果，科学结论和
素材许可要核对来源。完成后用 PR 说明目标、改动和实际验证，方便下一个人或 AI 接着做。

# Codex model and execution adapter

Use the user's assigned roles and preserve the selected primary model/effort.
The installed local profiles are Sol Medium (gpt-5.6-sol, sol_worker) and read-only
Astra High (gpt-6-astra, astra). Every collaboration dispatch explicitly pins model
and effort with fork_turns none and a self-contained bounded brief. Workers do not
spawn workers. Routine docs/implementation/QA stay with Sol; consequential judgment
stays with Astra. Searches, builds, tests, Git and tracker actions use direct tools
by the responsible agent; raw output is not passed through a separate LLM runner.

The explicit final architecture recovery uses read-only Astra Max. The optional
asset `assets/agents/graph-astra-max.toml` declares model gpt-6-astra, effort max
and sandbox_mode read-only. Reconcile/install that repo-local custom role only where
the runtime supports it; preserve existing custom profiles. With the collaboration
adapter, a supported default role plus explicit model/effort override can express
this route, but role prose alone is not sandbox enforcement. Read back effective
settings/capability. Never override the High-fixed native astra role and claim Max.
Do not add or weaken global permissions, change the user's primary, or install an
LLM runner. If the adapter rejects the route, record a capability blocker.

Astra advisors return design and repair guidance read-only. Sol or the lead records
design documents and Sol implements the adopted repairs; independent approval is
separate from both authors. Follow RETRY-ESCALATION.md for the two coding stages,
persisted budgets/counters, independent Max review/redesign and no unbounded retries.

Source: [official subagent configuration](https://learn.chatgpt.com/docs/agent-configuration/subagents).
The local role files and current tool adapter establish this installation's actual
role pins; documentation alone does not attest backend routing or a successful run.
No Max dispatch or autonomous controller is exercised by copying this skill.

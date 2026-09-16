# Phase 9A — Audit-to-Work Mapping

| Audit finding | Phase 9 work |
|---|---|
| Missing verification engine/contract | 9A defines boundary; 9B implements it and tests mandatory verification. |
| Missing post-install reconciliation declaration/mechanism | 9A defines authority boundary; 9C implements dedicated reconciliation contract. |
| Installer request helper creates fresh OperationId | 9F classifies actual call path and corrects only if active. |
| Seven-stage plan ends at Installation | 9D composes reconciliation after installation using the existing generic orchestration lifecycle. |
| State writer only persists observations | 9E makes reconciliation evidence the prerequisite for authoritative persistence. |

No Phase 1–8 redesign is assumed by these findings.
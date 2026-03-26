# iOS/Web Parity Tracker

Last updated: 2026-03-26

## Objective
Keep a single source of truth for features that must ship in parity between iOS and web.

## Delivery Matrix

| Feature | iOS | Web | Notes |
|---|---|---|---|
| Logistics linked to gig + finance handoff | Done | Done | Gig-linked logistics and break-even handoff available on both sides. |
| Break-even linked to gigs | Done | Done | iOS Finances and Web Finances aligned with gig context. |
| Booking advisor persistence to manager memory | Done | Done | Advisor insights persist and feed manager context. |
| Content plan unified (backlog + calendar flow) | Done | Done | Web unified flow + iOS creation plan parity in linked gig metadata. |
| Predictive alerts (72h logistics + cash risk) | Done | Done | Smart warnings + quick navigation shortcuts in both platforms. |
| Next gig playbook (D-3 / D-1 / D0) | Done | Done | Stage detection, checklist card, and one-click task creation. |
| Post-show playbook (D+1) | Done | Done | New checklist for financial close, promoter follow-up, and recap content. |
| Auto trigger for post-show playbook (D+1) | Done | Done | Runs once per day per recent gig, no duplicate task insertion. |
| KPI card for playbook execution | Done | Done | Completion rate by stage (D-3, D-1, D0, D+1) and overall progress. |
| Reminder when playbook has no tasks | Done | Done | In-app reminder on both platforms; web also sends browser push when enabled. |
| Playbook trendline (4-week history) | Done | Done | Bar chart per week (D-3 to D+1 combined) using gig dueDate/dateISO bucketing. |

## Current Sprint Log

### 2026-03-26
- Added next gig playbook parity in iOS dashboard.
- Added post-show D+1 playbook parity in iOS and web dashboards.
- Included smart alerts and one-click task generation for both playbooks.
- Added automatic D+1 checklist generation on dashboard load with anti-duplication guards.
- Added KPI dashboard card for playbook execution with per-stage completion metrics.
- Added reminders when a playbook exists but tasks were not generated yet (web + iOS).
- Added 4-week playbook execution trendline (CSS bar chart on web, SwiftUI Chart on iOS).

## Next Candidates (Parity Required)
- Score de saúde operacional (aggregate de gigs, conteúdo, financeiro, booking em % únicos).
- Resumo semanal automático em texto para o Manager IA usar como contexto.

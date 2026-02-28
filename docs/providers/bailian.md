---
summary: "bailian provider data sources: API token in config/env and quota API response parsing."
read_when:
  - Debugging bailian token storage or quota parsing
  - Updating bailian API endpoints
---

# bailian provider

bailian is API-token based. No browser cookies.

## Setup

1. Open **Settings → Providers**.
2. Enable **Bailian**.
3. Enter your API token in **Preferences → Providers → Bailian → API token** or set `BAILIAN_API_KEY` environment variable.

### Manual cookie import (optional)

1. Open `https://ollama.com/settings` in your browser.
2. Copy a `Cookie:` header from the Network tab.
3. Paste it into **Bailian → Cookie source → Manual**.
<!--
## Token sources (fallback order)
1) Config token (`~/.codexbar/config.json` → `providers[].apiKey`).
2) Environment variable `BAILIAN_API_KEY`.-->

### Config location
- `~/.codexbar/config.json`

## API endpoint
- `POST https://bailian-cs.console.aliyun.com/data/api.json?action=BroadScopeAspnGateway&product=sfm_bailian&api=zeldaEasy.broadscope-bailian.codingPlan.queryCodingPlanInstanceInfoV2&_v=undefined`
- Bailian host: `https://bailian-cs.console.aliyun.com`
- Override host via Providers → bailian → *API region* or `BAILIAN_API_HOST=bailian-cs.console.aliyun.com`.
- Override the full quota URL (e.g. coding plan endpoint) via `bailian_QUOTA_URL=https://bailian-cs.console.aliyun.com/data/api.json?action=BroadScopeAspnGateway&product=sfm_bailian&api=zeldaEasy.broadscope-bailian.codingPlan.queryCodingPlanInstanceInfoV2&_v=undefined`.
- Headers:
  - `accept: application/json`
  - `x-ca-key: <api_key>`

## Parsing + mapping
- Response fields:
  - `data.DataV2.data.data.codingPlanInstanceInfos[]` → coding plan instance informations
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo` → coding plan instance information
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo.per5HourUsedQuota` → used requessts count (number)
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo.per5HourTotalQuota` → total requests can be used (number)
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo.per5HourQuotaNextRefreshTime` → used monitor reset time (number)
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo.perWeekUsedQuota` → used requessts count (number)
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo.perWeekTotalQuota` → total requests can be used (number)
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo.perWeekQuotaNextRefreshTime` → used monitor reset time (number)
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo.perBillMonthUsedQuota` → used requessts count (number)
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo.perBillMonthTotalQuota` → total requests can be used (number)
  - `data.DataV2.data.data.codingPlanInstanceInfos[0].codingPlanQuotaInfo.perBillMonthQuotaNextRefreshTime` → used monitor reset time (number)
- Limit types:
  - `Session usage` → primary (used requests count and reset timestamp).
  - `Weekly usage` → secondary (used requests count and reset timestamp).
  - `Monthly usage` → third (used requests count and reset timestamp).
- Window duration:
  - Unit + number → minutes/hours/days.
- Reset:
  - `nextResetTime` (epoch ms) → date.
- Usage details:
  - `Resultt.QuotaUsage[]` per level (usage list).

## Key files
- `Sources/CodexBarCore/Providers/bailian/bailianUsageStats.swift`
- `Sources/CodexBarCore/Providers/bailian/bailianSettingsReader.swift`
- `Sources/CodexBar/bailianTokenStore.swift` (legacy migration helper)

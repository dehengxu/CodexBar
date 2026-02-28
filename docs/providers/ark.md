---
summary: "ark provider data sources: API token in config/env and quota API response parsing."
read_when:
  - Debugging ark token storage or quota parsing
  - Updating ark API endpoints
---

# ark provider

ark is API-token based. No browser cookies.

## Setup

1. Open **Settings → Providers**.
2. Enable **ARK**.
3. Enter your API token in **Preferences → Providers → ARK → API token** or set `ARK_API_KEY` environment variable.

## Token sources (fallback order)
1) Config token (`~/.codexbar/config.json` → `providers[].apiKey`).
2) Environment variable `ARK_API_KEY`.

### Config location
- `~/.codexbar/config.json`

## API endpoint
- `POST https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage`
- ARK host: `https://console.volcengine.com`
- Override host via Providers → ark → *API region* or `ARK_API_HOST=console.volcengine.com`.
- Override the full quota URL (e.g. coding plan endpoint) via `ARK_QUOTA_URL=https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage`.
- Headers:
  - `accept: application/json`
  - `x-ca-key: <api_key>`

## Parsing + mapping
- Response fields:
  - `Resultt.QuotaUsage[0].Level` → Level name.(session level)
  - `Resultt.QuotaUsage[0].Percent` → usage percentage (number).
  - `Resultt.QuotaUsage[0].ResetTimestamp` → Timestamp when reset session usage to 100% (number).
  - `Resultt.QuotaUsage[1].Level` → Level name.(weekly)
  - `Resultt.QuotaUsage[1].Percent` → usage percentage (number).
  - `Resultt.QuotaUsage[1].ResetTimestamp` → Timestamp when reset weekly usage to 100% (number).
  - `Resultt.QuotaUsage[2].Level` → Level name.(monthly)
  - `Resultt.QuotaUsage[2].Percent` → usage percentage (number).
  - `Resultt.QuotaUsage[2].ResetTimestamp` → Timestamp when reset monthly usage to 100% (number).
- Limit types:
  - `Session usage` → primary (usage percentage and reset timestamp).
  - `Weekly usage` → secondary (usage percentage and reset timestamp).
  - `Monthly usage` → third (usage percentage and reset timestamp).
- Window duration:
  - Unit + number → minutes/hours/days.
- Reset:
  - `nextResetTime` (epoch ms) → date.
- Usage details:
  - `Resultt.QuotaUsage[]` per level (usage list).

## Key files
- `Sources/CodexBarCore/Providers/Ark/ArkUsageStats.swift`
- `Sources/CodexBarCore/Providers/Ark/ArkSettingsReader.swift`
- `Sources/CodexBar/ArkTokenStore.swift` (legacy migration helper)

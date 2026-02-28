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

### Manual cookie import (optional)

1. Open `https://ollama.com/settings` in your browser.
2. Copy a `Cookie:` header from the Network tab.
3. Paste it into **ARK → Cookie source → Manual**.

<!--### Token sources (fallback order)
1) Config token (`~/.codexbar/config.json` → `providers[].apiKey`).
2) Environment variable `ARK_API_KEY`.-->

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
  - `Result.QuotaUsage[0].Level` → Level name.(session level)
  - `Result.QuotaUsage[0].Percent` → usage percentage (number).
  - `Result.QuotaUsage[0].ResetTimestamp` → Timestamp when reset session usage to 100% (number).
  - `Result.QuotaUsage[1].Level` → Level name.(weekly)
  - `Result.QuotaUsage[1].Percent` → usage percentage (number).
  - `Result.QuotaUsage[1].ResetTimestamp` → Timestamp when reset weekly usage to 100% (number).
  - `Result.QuotaUsage[2].Level` → Level name.(monthly)
  - `Result.QuotaUsage[2].Percent` → usage percentage (number).
  - `Result.QuotaUsage[2].ResetTimestamp` → Timestamp when reset monthly usage to 100% (number).
- Limit types:
  - `Session usage` → primary (usage percentage and reset timestamp).
  - `Weekly usage` → secondary (usage percentage and reset timestamp).
  - `Monthly usage` → third (usage percentage and reset timestamp).
- Window duration:
  - Unit + number → minutes/hours/days.
- Reset:
  - `nextResetTime` (epoch ms) → date.
- Usage details:
  - `Result.QuotaUsage[]` per level (usage list).

## Key files
- `Sources/CodexBarCore/Providers/Ark/ArkUsageStats.swift`
- `Sources/CodexBarCore/Providers/Ark/ArkSettingsReader.swift`
- `Sources/CodexBar/ArkTokenStore.swift` (legacy migration helper)

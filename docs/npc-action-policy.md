# NPC deterministic action policy

`ActionDispatcher` treats provider output as a proposal. It revalidates the exact NPC-01 response schema, binds the response to the current NPC/conversation, rejects stale request generations, resolves the live actor again at dispatch, and caches the result under a stable transaction ID. The dispatcher is runtime-only; persistent records remain data-only.

Each configured adapter is authoritative for its domain. Missing adapters and unknown IDs fail closed. Adapter callbacks must validate current state at the instant they commit and must not trust dialogue text or model-supplied quantities.

| Action | Required policy | Commit-time checks |
| --- | --- | --- |
| `offer_mission(template_id)` | `MissionDirector`; `mission_permissions` maps NPC IDs to allowed template IDs | NPC remains the active live actor; template is allowlisted; MissionDirector rechecks template, faction, target and reachability. |
| `initiate_trade(inventory_id)` | `merchant_inventory_owners` maps inventory to NPC; `validate_merchant_stock` and `open_trade` Callables | Inventory belongs to the current NPC; current stock validator passes immediately before the trade callback. The callback receives the dispatcher transaction ID. |
| `accept_into_faction(faction_id)` | `FactionState`; `faction_acceptance_rules` entry with `allowed_npc_ids`, `minimum_standing`, and `accepted_standing` | NPC is eligible at current standing; faction exists; authored target standing is bounded and reaches the configured allied threshold. The old standing is restored if the resulting relationship is not allied. |
| `begin_fight()` | `fight_allowed_npc_ids`; `resolve_player`; valid `player_faction_id` | NPC remains the same live, configured, non-dead `TacticalAgent`; player remains the same live `Node3D`; NPC permission still exists. Authored hostility and target are set only after those checks. |
| `disclose_fact(fact_id)` | `fact_available` and `commit_disclosure` Callables | Fact remains known and disclosable; commit callback receives NPC, fact and transaction ID and must enforce idempotency. |
| `give_item(item_id)` | `ItemGrants`; `resolve_item_entitlement` Callable | Resolver returns an existing valid `ItemInstance` with the requested ID; the grant uses the dispatcher transaction ID. A full inventory is accepted as pending only when ItemGrants retains that transaction. |

The policy does not authorize providers to supply merchant contents, faction rules, fact records, item definitions/instances, reward amounts, or executable code. Those values come from the current game-owned adapters. A refused or stale proposal has no gameplay side effect.

## Adapter signatures

- `resolve_actor(npc_id) -> Node`
- `validate_merchant_stock(inventory_id, npc_id) -> bool`
- `open_trade(inventory_id, npc_id, transaction_id) -> bool`
- `resolve_player() -> Node3D`
- `fact_available(npc_id, fact_id) -> bool`
- `commit_disclosure(npc_id, fact_id, transaction_id) -> bool`
- `resolve_item_entitlement(npc_id, item_id) -> ItemInstance`

All boolean callbacks must return an actual boolean `true` to authorize a transition; other values reject safely.

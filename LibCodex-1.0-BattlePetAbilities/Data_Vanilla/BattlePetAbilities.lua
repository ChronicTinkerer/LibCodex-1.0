-- LibCodex-1.0 / Data_Vanilla / BattlePetAbilities.lua
-- Stub for Classic Era / Hardcore flavor. No rows baked yet.
-- To populate, run from the repo root:
--   python .dev/tools/import-wago.py --flavor vanilla
--   python .dev/tools/bake.py        --flavor vanilla
-- bake.py treats a stub (no _FeedBundledRowsLazy call) as empty and writes
-- the full row list on first bake. Hand-curated entries marked _handcrafted
-- are preserved across bakes once the file has rows.

local LibCodex = LibStub("LibCodex-1.0")

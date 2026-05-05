-- LibCodex-1.0 / Data_TBC / ItemSets.lua
-- Stub for Burning Crusade Anniversary flavor. No rows baked yet.
-- To populate, run from the repo root:
--   python tools/import-wago.py --flavor tbc --output wago-import-tbc.lua
--   python tools/bake.py        --flavor tbc --source wago-import-tbc.lua
-- bake.py treats a stub (no _FeedBundledRowsLazy call) as empty and writes
-- the full row list on first bake. Hand-curated entries marked _handcrafted
-- are preserved across bakes once the file has rows.

local LibCodex = LibStub("LibCodex-1.0")

-- LibCodex-1.0 / Data_Mists / TransmogIllusions.lua
-- Stub for MoP Classic flavor. No rows baked yet.
-- To populate, run from the repo root:
--   python tools/import-wago.py --flavor mists --output wago-import-mists.lua
--   python tools/bake.py        --flavor mists --source wago-import-mists.lua
-- bake.py treats a stub (no _FeedBundledRowsLazy call) as empty and writes
-- the full row list on first bake. Hand-curated entries marked _handcrafted
-- are preserved across bakes once the file has rows.

local LibCodex = LibStub("LibCodex-1.0")

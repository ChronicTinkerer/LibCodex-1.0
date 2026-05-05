-- LibCodex-1.0 / Data_XPTR / TransmogSets.lua
-- Stub for Retail XPTR (experimental) flavor. No rows baked yet.
-- To populate, run from the repo root:
--   python .dev/tools/import-wago.py --flavor xptr
--   python .dev/tools/bake.py        --flavor xptr
-- bake.py treats a stub (no _FeedBundledRowsLazy call) as empty and writes
-- the full row list on first bake. Hand-curated entries marked _handcrafted
-- are preserved across bakes once the file has rows.

local LibCodex = LibStub("LibCodex-1.0")

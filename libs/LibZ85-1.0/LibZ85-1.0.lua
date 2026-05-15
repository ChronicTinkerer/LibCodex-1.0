-- LibZ85-1.0
-- Standalone Z85 encoder/decoder for World of Warcraft addons.
--
-- Z85 (https://rfc.zeromq.org/spec/32/) packs 4 binary bytes into 5 ASCII
-- characters from a fixed 85-char alphabet. Every alphabet char is safe
-- inside Lua "..." string literals with no backslash escape, which makes
-- it ideal for embedding binary data (lookup tables, packed records,
-- compressed payloads) inside Lua source you ship as part of an addon.
--
-- Public API:
--   local Z85 = LibStub("LibZ85-1.0")
--   local bytes = Z85.decode("HelloWorld")         -- returns Lua string of raw bytes
--   local encoded = Z85.encode("\xAB\xCD\xEF...")  -- returns Z85 ASCII string
--   local alphabet = Z85.ALPHABET                  -- the 85-char alphabet (read-only)
--
-- Padding policy: encode() pads input to a 4-byte boundary with trailing
-- zero bytes; decode() returns the full decoded buffer including padding.
-- Callers that emit variable-length records (e.g. packed location lists)
-- must walk the decoded buffer record-by-record and stop at minimum-record
-- size or at an all-zero header sentinel.
--
-- License: MIT. See LICENSE.
-- Author: ChronicTinkerer.

local LIB_MAJOR = "LibZ85-1.0"
local LIB_MINOR = 1

-- LibStub registration. In a non-LibStub environment (e.g. running the
-- file via dofile() in a test harness), LibStub is nil; we fall back to
-- a fresh table so the file still works when loaded outside the WoW
-- client.
local Z85
if LibStub then
    Z85 = LibStub:NewLibrary(LIB_MAJOR, LIB_MINOR)
    if not Z85 then return end  -- newer/same-version already loaded
else
    Z85 = {}
end


-- Standard Z85 alphabet (85 chars). Order matters: this is the canonical
-- spec order. Index in the string == base-85 digit value.
local ALPHABET =
    "0123456789"
    .. "abcdefghijklmnopqrstuvwxyz"
    .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    .. ".-:+=^!/*?&<>()[]{}@%$#"

-- Decode lookup: byte (0..255) -> base-85 digit (0..84) or nil for invalid.
-- Built once at file load; ~85 entries actually populated, the rest stay nil.
local DECODE = {}
for i = 1, #ALPHABET do
    DECODE[string.byte(ALPHABET, i)] = i - 1
end


-- Local aliases speed up tight loops (Lua 5.1 lookups are dictionary hits).
local floor = math.floor
local s_byte = string.byte
local s_char = string.char
local s_sub = string.sub
local t_concat = table.concat
local error = error
local format = string.format


-- decode(s) -> raw byte string
--   Length of s must be a multiple of 5. Raises on invalid char or bad length.
function Z85.decode(s)
    local n = #s
    if n == 0 then return "" end
    if n % 5 ~= 0 then
        error(format("Z85.decode: input length %d not a multiple of 5", n))
    end

    local out = {}
    local oi = 0

    for i = 1, n, 5 do
        local v = 0
        for k = 0, 4 do
            local b = s_byte(s, i + k)
            local d = DECODE[b]
            if d == nil then
                error(format(
                    "Z85.decode: invalid char %q at position %d",
                    s_char(b), i + k))
            end
            v = v * 85 + d
        end
        if v >= 0x100000000 then
            error(format("Z85.decode: chunk overflow at position %d", i))
        end
        oi = oi + 1
        out[oi] = s_char(
            floor(v / 0x1000000) % 0x100,
            floor(v / 0x10000) % 0x100,
            floor(v / 0x100) % 0x100,
            v % 0x100
        )
    end

    return t_concat(out)
end


-- encode(s) -> Z85 ASCII string
--   Pads s to 4-byte boundary with trailing zeros. Output length is always
--   a multiple of 5.
function Z85.encode(s)
    local n = #s
    if n == 0 then return "" end

    local pad = (-n) % 4
    if pad > 0 then
        s = s .. s_char(0):rep(pad)
        n = n + pad
    end

    local out = {}
    local oi = 0

    for i = 1, n, 4 do
        local v = s_byte(s, i)     * 0x1000000
                + s_byte(s, i + 1) * 0x10000
                + s_byte(s, i + 2) * 0x100
                + s_byte(s, i + 3)

        -- Five base-85 digits, MSD first
        local d5 = v % 85; v = floor(v / 85)
        local d4 = v % 85; v = floor(v / 85)
        local d3 = v % 85; v = floor(v / 85)
        local d2 = v % 85
        local d1 = floor(v / 85)

        oi = oi + 1
        out[oi] = s_sub(ALPHABET, d1 + 1, d1 + 1)
                .. s_sub(ALPHABET, d2 + 1, d2 + 1)
                .. s_sub(ALPHABET, d3 + 1, d3 + 1)
                .. s_sub(ALPHABET, d4 + 1, d4 + 1)
                .. s_sub(ALPHABET, d5 + 1, d5 + 1)
    end

    return t_concat(out)
end


-- Expose alphabet for diagnostics + cross-tool comparisons.
Z85.ALPHABET = ALPHABET

return Z85

-- Base64 with plain arithmetic, so it runs without the bit library.
local _, SF = ...

local B64 = {}
SF.Base64 = B64

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local enc, dec = {}, {}
for i = 1, 64 do
    local c = alphabet:sub(i, i)
    enc[i - 1] = c
    dec[c] = i - 1
end

function B64.encode(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = enc[c1] .. enc[c2] .. (b and enc[c3] or "=") .. (c and enc[c4] or "=")
    end
    return table.concat(out)
end

function B64.decode(s)
    s = s:gsub("[^%w%+/]", "")
    local out = {}
    for i = 1, #s, 4 do
        local chunk = s:sub(i, i + 3)
        local n, count = 0, #chunk
        for j = 1, 4 do
            local v = dec[chunk:sub(j, j)] or 0
            n = n * 64 + v
        end
        local a = math.floor(n / 65536) % 256
        local b = math.floor(n / 256) % 256
        local c = n % 256
        if count == 4 then
            out[#out + 1] = string.char(a, b, c)
        elseif count == 3 then
            out[#out + 1] = string.char(a, b)
        elseif count == 2 then
            out[#out + 1] = string.char(a)
        end
    end
    return table.concat(out)
end

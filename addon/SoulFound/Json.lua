-- Minimal JSON for export/import strings. Imported text is only ever parsed as
-- data; nothing from a plan is executed.
local _, SF = ...

local Json = {}
SF.Json = Json

local ARRAY_MT = { __jsontype = "array" }

-- Marks a table as a JSON array, so an empty one encodes as [] instead of {}.
function Json.array(t)
    return setmetatable(t or {}, ARRAY_MT)
end

local escapes = {
    ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
    ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function encodeString(s)
    local out = s:gsub('[%c"\\]', function(c)
        return escapes[c] or string.format("\\u%04x", c:byte())
    end)
    return '"' .. out .. '"'
end

local function isArray(t)
    if getmetatable(t) == ARRAY_MT then return true end
    local n = #t
    if n == 0 then return false end
    local count = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then return false end
        count = count + 1
    end
    return count == n
end

local encode

local function encodeTable(t, depth)
    if depth > 30 then error("json: nesting too deep") end
    local parts = {}
    if isArray(t) then
        for i = 1, #t do parts[i] = encode(t[i], depth + 1) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for i, k in ipairs(keys) do
        local v = t[k]
        if v == nil then v = t[tonumber(k)] end
        parts[i] = encodeString(k) .. ":" .. encode(v, depth + 1)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

encode = function(v, depth)
    local kind = type(v)
    if kind == "nil" then return "null" end
    if kind == "boolean" then return v and "true" or "false" end
    if kind == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        if v % 1 == 0 and math.abs(v) < 1e15 then return string.format("%d", v) end
        return string.format("%.10g", v)
    end
    if kind == "string" then return encodeString(v) end
    if kind == "table" then return encodeTable(v, depth or 0) end
    error("json: cannot encode " .. kind)
end

function Json.encode(v)
    return encode(v, 0)
end

local function utf8char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
    end
    if cp < 0x10000 then
        return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
    end
    return string.char(0xF0 + math.floor(cp / 0x40000), 0x80 + math.floor(cp / 0x1000) % 0x40,
        0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

local simpleEscapes = {
    ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t',
}

function Json.decode(str)
    local pos = 1

    local function fail(msg) error(string.format("json: %s at %d", msg, pos), 0) end

    local function skip()
        pos = str:find("[^ \t\r\n]", pos) or (#str + 1)
    end

    local parseValue

    local function parseString()
        pos = pos + 1
        local buf = {}
        while true do
            local c = str:sub(pos, pos)
            if c == "" then fail("unterminated string") end
            if c == '"' then
                pos = pos + 1
                return table.concat(buf)
            elseif c == "\\" then
                local e = str:sub(pos + 1, pos + 1)
                if simpleEscapes[e] then
                    buf[#buf + 1] = simpleEscapes[e]
                    pos = pos + 2
                elseif e == "u" then
                    local cp = tonumber(str:sub(pos + 2, pos + 5), 16) or fail("bad \\u escape")
                    pos = pos + 6
                    if cp >= 0xD800 and cp <= 0xDBFF and str:sub(pos, pos + 1) == "\\u" then
                        local lo = tonumber(str:sub(pos + 2, pos + 5), 16)
                        if lo and lo >= 0xDC00 and lo <= 0xDFFF then
                            cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
                            pos = pos + 6
                        end
                    end
                    buf[#buf + 1] = utf8char(cp)
                else
                    fail("bad escape")
                end
            else
                local s, e = str:find('^[^"\\]+', pos)
                buf[#buf + 1] = str:sub(s, e)
                pos = e + 1
            end
        end
    end

    local function parseNumber()
        local s, e = str:find("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if not s then fail("bad number") end
        pos = e + 1
        return tonumber(str:sub(s, e)) or fail("bad number")
    end

    local function parseArray(depth)
        pos = pos + 1
        local out = Json.array({})
        skip()
        if str:sub(pos, pos) == "]" then pos = pos + 1 return out end
        local n = 0
        while true do
            n = n + 1
            out[n] = parseValue(depth + 1)
            skip()
            local c = str:sub(pos, pos)
            pos = pos + 1
            if c == "]" then return out end
            if c ~= "," then fail("expected , or ]") end
        end
    end

    local function parseObject(depth)
        pos = pos + 1
        local out = {}
        skip()
        if str:sub(pos, pos) == "}" then pos = pos + 1 return out end
        while true do
            skip()
            if str:sub(pos, pos) ~= '"' then fail("expected key") end
            local key = parseString()
            skip()
            if str:sub(pos, pos) ~= ":" then fail("expected :") end
            pos = pos + 1
            out[key] = parseValue(depth + 1)
            skip()
            local c = str:sub(pos, pos)
            pos = pos + 1
            if c == "}" then return out end
            if c ~= "," then fail("expected , or }") end
        end
    end

    parseValue = function(depth)
        if depth > 30 then fail("nesting too deep") end
        skip()
        local c = str:sub(pos, pos)
        if c == "{" then return parseObject(depth) end
        if c == "[" then return parseArray(depth) end
        if c == '"' then return parseString() end
        if c == "-" or c:match("%d") then return parseNumber() end
        if str:sub(pos, pos + 3) == "true" then pos = pos + 4 return true end
        if str:sub(pos, pos + 4) == "false" then pos = pos + 5 return false end
        if str:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil end
        fail("unexpected character")
    end

    local value = parseValue(0)
    skip()
    if pos <= #str then fail("trailing characters") end
    return value
end

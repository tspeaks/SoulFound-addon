-- SoulFound strings: a 5-character prefix plus base64-encoded JSON.
-- The format is open (docs/plan-format.md) so anyone can write a plan.
local _, SF = ...

local Codec = {}
SF.Codec = Codec

local PREFIX = { export = "SF1E:", plan = "SF1P:", report = "SF1R:" }
local KIND = {}
for kind, prefix in pairs(PREFIX) do KIND[prefix] = kind end

function Codec.encode(kind, data)
    return PREFIX[kind] .. SF.Base64.encode(SF.Json.encode(data))
end

-- Returns kind, data on success, or nil, message.
function Codec.decode(str)
    if type(str) ~= "string" then return nil, "nothing to import" end
    str = str:gsub("%s+", "")
    local kind = KIND[str:sub(1, 5)]
    if not kind then return nil, "this isn't a SoulFound string (it should start with SF1)" end
    local ok, data = pcall(SF.Json.decode, SF.Base64.decode(str:sub(6)))
    if not ok or type(data) ~= "table" then
        return nil, "the string is damaged or incomplete. Copy it again"
    end
    return kind, data
end

local crc = {}
local crc_mt = { __metatable = {}, __index = crc }

crc.digestSize = 8
crc.blockSize = 8

function crc:new(self, data)
    if self ~= crc then
        return nil, "First argument must be singleton-self"
    end
    local o = setmetatable({}, crc_mt)
    o._crc = tonumber(0xFFFFFFFF)
    if data ~= nil then o:update(data) end
    return o
end
setmetatable(crc, { __call = crc.new })

function crc:copy(self)
    local o = crc:new()
    o._crc = self._crc:copy()
    return o
end

function crc:update(self, data)
    local byte, mask
    if data == nil then data = '' end
    data = tostring(data)
    for i = 1, #data do
        byte = string.byte(data, i)
        self._crc = bit.bxor(self._crc, byte)
        for j = 1, 8 do
            mask = bit.band(self._crc, 1) * -1
            self._crc = bit.bxor(bit.rshift(self._crc, 1), bit.band(0xEDB88320, mask))
        end
    end
end

function crc:Digest(self)
    return tostring(bit.bnot(self._crc))
end

function crc:HexDigest(self, truncationLength)
    local out, digest = {}, self:Digest()
    local length = string.len(digest)
    for i = 1, length do
        out[i] = string.format('%02X', string.byte(digest, i))
    end
    local result = table.concat(out)
    if truncationLength then
        result = string.sub(result, string.len(result) - truncationLength + 1, string.len(result))
    end
    return result
end

local hashing = {
    crc = function(self, str)
        local time = SexyLib:Util():Millis()
        local result = crc:new(str)
        SexyLib:Logger('Sexy Lib'):LogDebug('CRC took %d ms.', SexyLib:Util():Millis(time))
        return result
    end,
    Crc = function(self, str, length)
        return self:hash(str):HexDigest(length or 7)
    end
}

function SexyLib:Hashing()
    return hashing
end
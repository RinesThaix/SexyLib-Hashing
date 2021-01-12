local function toString(value)
    local libS = LibStub:GetLibrary("AceSerializer-3.0")
	local libD = LibStub:GetLibrary("LibDeflate")
    local encoded = libS:Serialize(data)
	encoded = libD:CompressDeflate(encoded)
    return libD:EncodeForWoWAddonChannel(encoded)
end

local hashing, util, logger = SexyLib:Hashing(), SexyLib:Util(), SexyLib:Logger('Sexy Lib')

hashing.Sign = function(self, value, privateKey, publicKey)
    local time = util:Millis()
    local result, err = LibDSA.Sign(publicKey, privateKey, toString(value))
    if err then return nil, err end
    logger:LogDebug('RSA signing took %d ms.', util:Millis(time))
    return result, nil
end

hashing.Validate = function(self, value, signature, publicKey)
    local time = util:Millis()
    local result = LibDSA.Validate(publicKey, signature, toString(value))
    logger:LogDebug('RSA validation took %d ms.', util:Millis(time))
    return result
end
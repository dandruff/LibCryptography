

local file_BI = assert(loadfile([[.\Utilities\BigInt.lua]]))
local file_DH = assert(loadfile([[.\DH\diffie-hellman.lua]]))


local addonName, addon = "LibCryptography", {}

file_BI(addonName, addon)
file_DH(addonName, addon)

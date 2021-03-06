-- Requires BigInt

-- Diffie-Hellman
local Name, Public = ...

-- Don't leak any globals
local _ENV = nil

-- Register this library into our shared secrets
if not Public.SharedSecrets then Public.SharedSecrets = { } end
Public.SharedSecrets.DH = { }

-- Load Utilities
local BigInt = Public.SharedSecrets.BigInt

-- Only allow Public to be accessed from the current Add-On
local Public = Public.SharedSecrets.DH

-- Pre-define some prime numbers
--  Source: http://www.iana.org/assignments/ipsec-registry/ipsec-registry.xhtml

local primes
do
	-- Pre-Defined Primes (Oakley Groups)
	-- Source: https://tools.ietf.org/html/rfc3526

	-- NOTE: All the generators are 2

	local DEBUG_PRIME =
	[[	FFFFFFFF 00000001 00000000 00000000 00000000 FFFFFFFF
		FFFFFFFF FFFFFFFF]]

	-- Group 1
	local RFC2409_MODP768 =
	[[	FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1
		29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD
		EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245
		E485B576 625E7EC6 F44C42E9 A63A3620 FFFFFFFF FFFFFFFF]]

	-- Group 2
	local RFC2409_MODP1024 =
	[[	FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1
		29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD
		EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245
		E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED
		EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE65381
		FFFFFFFF FFFFFFFF]]

	-- Group 5
	local RFC2409_MODP1536 =
	[[	FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1
		29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD
		EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245
		E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED
		EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D
		C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F
		83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D
		670C354E 4ABC9804 F1746C08 CA237327 FFFFFFFF FFFFFFFF]]

	-- Group 14 (Minimum Recommendation)
	local RFC3526_MODP2048 =
	[[	FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1
		29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD
		EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245
		E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED
		EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D
		C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F
		83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D
		670C354E 4ABC9804 F1746C08 CA18217C 32905E46 2E36CE3B
		E39E772C 180E8603 9B2783A2 EC07A28F B5C55DF0 6F4C52C9
		DE2BCBF6 95581718 3995497C EA956AE5 15D22618 98FA0510
		15728E5A 8AACAA68 FFFFFFFF FFFFFFFF]]

	-- Group 15 (Not Recommended, too CPU intensive)
	local RFC3526_MODP3072 =
	[[	FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1
		29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD
		EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245
		E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED
		EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D
		C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F
		83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D
		670C354E 4ABC9804 F1746C08 CA18217C 32905E46 2E36CE3B
		E39E772C 180E8603 9B2783A2 EC07A28F B5C55DF0 6F4C52C9
		DE2BCBF6 95581718 3995497C EA956AE5 15D22618 98FA0510
		15728E5A 8AAAC42D AD33170D 04507A33 A85521AB DF1CBA64
		ECFB8504 58DBEF0A 8AEA7157 5D060C7D B3970F85 A6E1E4C7
		ABF5AE8C DB0933D7 1E8C94E0 4A25619D CEE3D226 1AD2EE6B
		F12FFA06 D98A0864 D8760273 3EC86A64 521F2B18 177B200C
		BBE11757 7A615D6C 770988C0 BAD946E2 08E24FA0 74E5AB31
		43DB5BFC E0FD108E 4B82D120 A93AD2CA FFFFFFFF FFFFFFFF]]

	-- Group 16 (Not Recommended, too CPU intensive)
	local RFC3526_MODP4096 =
	[[	FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1
		29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD
		EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245
		E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED
		EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D
		C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F
		83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D
		670C354E 4ABC9804 F1746C08 CA18217C 32905E46 2E36CE3B
		E39E772C 180E8603 9B2783A2 EC07A28F B5C55DF0 6F4C52C9
		DE2BCBF6 95581718 3995497C EA956AE5 15D22618 98FA0510
		15728E5A 8AAAC42D AD33170D 04507A33 A85521AB DF1CBA64
		ECFB8504 58DBEF0A 8AEA7157 5D060C7D B3970F85 A6E1E4C7
		ABF5AE8C DB0933D7 1E8C94E0 4A25619D CEE3D226 1AD2EE6B
		F12FFA06 D98A0864 D8760273 3EC86A64 521F2B18 177B200C
		BBE11757 7A615D6C 770988C0 BAD946E2 08E24FA0 74E5AB31
		43DB5BFC E0FD108E 4B82D120 A9210801 1A723C12 A787E6D7
		88719A10 BDBA5B26 99C32718 6AF4E23C 1A946834 B6150BDA
		2583E9CA 2AD44CE8 DBBBC2DB 04DE8EF9 2E8EFC14 1FBECAA6
		287C5947 4E6BC05D 99B2964F A090C3A2 233BA186 515BE7ED
		1F612970 CEE2D7AF B81BDD76 2170481C D0069127 D5B05AA9
		93B4EA98 8D8FDDC1 86FFB7DC 90A6C08F 4DF435C9 34063199
		FFFFFFFF FFFFFFFF]]

	-- Group 17 (Not Recommended, too CPU intensive)
	local RFC3526_MODP6144 =
	[[	FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1
		29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD
		EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245
		E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED
		EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D
		C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F
		83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D
		670C354E 4ABC9804 F1746C08 CA18217C 32905E46 2E36CE3B
		E39E772C 180E8603 9B2783A2 EC07A28F B5C55DF0 6F4C52C9
		DE2BCBF6 95581718 3995497C EA956AE5 15D22618 98FA0510
		15728E5A 8AAAC42D AD33170D 04507A33 A85521AB DF1CBA64
		ECFB8504 58DBEF0A 8AEA7157 5D060C7D B3970F85 A6E1E4C7
		ABF5AE8C DB0933D7 1E8C94E0 4A25619D CEE3D226 1AD2EE6B
		F12FFA06 D98A0864 D8760273 3EC86A64 521F2B18 177B200C
		BBE11757 7A615D6C 770988C0 BAD946E2 08E24FA0 74E5AB31
		43DB5BFC E0FD108E 4B82D120 A9210801 1A723C12 A787E6D7
		88719A10 BDBA5B26 99C32718 6AF4E23C 1A946834 B6150BDA
		2583E9CA 2AD44CE8 DBBBC2DB 04DE8EF9 2E8EFC14 1FBECAA6
		287C5947 4E6BC05D 99B2964F A090C3A2 233BA186 515BE7ED
		1F612970 CEE2D7AF B81BDD76 2170481C D0069127 D5B05AA9
		93B4EA98 8D8FDDC1 86FFB7DC 90A6C08F 4DF435C9 34028492
		36C3FAB4 D27C7026 C1D4DCB2 602646DE C9751E76 3DBA37BD
		F8FF9406 AD9E530E E5DB382F 413001AE B06A53ED 9027D831
		179727B0 865A8918 DA3EDBEB CF9B14ED 44CE6CBA CED4BB1B
		DB7F1447 E6CC254B 33205151 2BD7AF42 6FB8F401 378CD2BF
		5983CA01 C64B92EC F032EA15 D1721D03 F482D7CE 6E74FEF6
		D55E702F 46980C82 B5A84031 900B1C9E 59E7C97F BEC7E8F3
		23A97A7E 36CC88BE 0F1D45B7 FF585AC5 4BD407B2 2B4154AA
		CC8F6D7E BF48E1D8 14CC5ED2 0F8037E0 A79715EE F29BE328
		06A1D58B B7C5DA76 F550AA3D 8A1FBFF0 EB19CCB1 A313D55C
		DA56C9EC 2EF29632 387FE8D7 6E3C0468 043E8F66 3F4860EE
		12BF2D5B 0B7474D6 E694F91E 6DCC4024 FFFFFFFF FFFFFFFF]]

	-- Group 18 (Totally recommened, with much better computers)
	local RFC3526_MODP8192 =
	[[	FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1
		29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD
		EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245
		E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED
		EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D
		C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F
		83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D
		670C354E 4ABC9804 F1746C08 CA18217C 32905E46 2E36CE3B
		E39E772C 180E8603 9B2783A2 EC07A28F B5C55DF0 6F4C52C9
		DE2BCBF6 95581718 3995497C EA956AE5 15D22618 98FA0510
		15728E5A 8AAAC42D AD33170D 04507A33 A85521AB DF1CBA64
		ECFB8504 58DBEF0A 8AEA7157 5D060C7D B3970F85 A6E1E4C7
		ABF5AE8C DB0933D7 1E8C94E0 4A25619D CEE3D226 1AD2EE6B
		F12FFA06 D98A0864 D8760273 3EC86A64 521F2B18 177B200C
		BBE11757 7A615D6C 770988C0 BAD946E2 08E24FA0 74E5AB31
		43DB5BFC E0FD108E 4B82D120 A9210801 1A723C12 A787E6D7
		88719A10 BDBA5B26 99C32718 6AF4E23C 1A946834 B6150BDA
		2583E9CA 2AD44CE8 DBBBC2DB 04DE8EF9 2E8EFC14 1FBECAA6
		287C5947 4E6BC05D 99B2964F A090C3A2 233BA186 515BE7ED
		1F612970 CEE2D7AF B81BDD76 2170481C D0069127 D5B05AA9
		93B4EA98 8D8FDDC1 86FFB7DC 90A6C08F 4DF435C9 34028492
		36C3FAB4 D27C7026 C1D4DCB2 602646DE C9751E76 3DBA37BD
		F8FF9406 AD9E530E E5DB382F 413001AE B06A53ED 9027D831
		179727B0 865A8918 DA3EDBEB CF9B14ED 44CE6CBA CED4BB1B
		DB7F1447 E6CC254B 33205151 2BD7AF42 6FB8F401 378CD2BF
		5983CA01 C64B92EC F032EA15 D1721D03 F482D7CE 6E74FEF6
		D55E702F 46980C82 B5A84031 900B1C9E 59E7C97F BEC7E8F3
		23A97A7E 36CC88BE 0F1D45B7 FF585AC5 4BD407B2 2B4154AA
		CC8F6D7E BF48E1D8 14CC5ED2 0F8037E0 A79715EE F29BE328
		06A1D58B B7C5DA76 F550AA3D 8A1FBFF0 EB19CCB1 A313D55C
		DA56C9EC 2EF29632 387FE8D7 6E3C0468 043E8F66 3F4860EE
		12BF2D5B 0B7474D6 E694F91E 6DBE1159 74A3926F 12FEE5E4
		38777CB6 A932DF8C D8BEC4D0 73B931BA 3BC832B6 8D9DD300
		741FA7BF 8AFC47ED 2576F693 6BA42466 3AAB639C 5AE4F568
		3423B474 2BF1C978 238F16CB E39D652D E3FDB8BE FC848AD9
		22222E04 A4037C07 13EB57A8 1A23F0C7 3473FC64 6CEA306B
		4BCBC886 2F8385DD FA9D4B7F A2C087E8 79683303 ED5BDD3A
		062B3CF5 B3A278A6 6D2A13F8 3F44F82D DF310EE0 74AB6A36
		4597E899 A0255DC1 64F31CC5 0846851D F9AB4819 5DED7EA1
		B1D510BD 7EE74D73 FAF36BC3 1ECFA268 359046F4 EB879F92
		4009438B 481C6CD7 889A002E D5EE382B C9190DA6 FC026E47
		9558E447 5677E9AA 9E3050E2 765694DF C81F56E8 80B96E71
		60C980DD 98EDD3DF FFFFFFFF FFFFFFFF]]

	-- Defined as a local above
	primes = {

		["DEBUG"] = DEBUG_PRIME,

		-- Why are you using this library then?
		--["768"]  = RFC2409_MODP768,
		--["1024"] = RFC2409_MODP1024,

		-- Not Recommended
		["1536"] = RFC2409_MODP1536,

		-- Recommended
		["2048"] = RFC3526_MODP2048,

		-- I mean you can try them...
		["3072"] = RFC3526_MODP3072,
		["4096"] = RFC3526_MODP4096,

		-- Why hello there CPU
		--["6144"] = RFC3526_MODP6144,
		--["8192"] = RFC3526_MODP8192
	}

	-- TODO: Add support for ECP Groups
	--[==[

		-- Source: http://tools.ietf.org/html/rfc5114

		-- 256-bit Random ECP Group

		--p = 2^(256)-2^(224)+2^(192)+2^(96)-1
		p  = [[	FFFFFFFF 00000001 00000000 00000000 00000000 FFFFFFFF
				FFFFFFFF FFFFFFFF]]

		a  = [[	FFFFFFFF 00000001 00000000 00000000 00000000 FFFFFFFF
				FFFFFFFF FFFFFFFC]]

		b  = [[	5AC635D8 AA3A93E7 B3EBBD55 769886BC 651D06B0 CC53B0F6
				3BCE3C3E 27D2604B]]

		gx = [[	6B17D1F2 E12C4247 F8BCE6E5 63A440F2 77037D81 2DEB33A0
				F4A13945 D898C296]]

		gy = [[	4FE342E2 FE1A7F9B 8EE7EB4A 7C0F9E16 2BCE3357 6B315ECE
				CBB64068 37BF51F5]]

		n  = [[	FFFFFFFF 00000000 FFFFFFFF FFFFFFFF BCE6FAAD A7179E84
				F3B9CAC2 FC632551]]

	]==]

end

local diffiehellman_mt

local function checkRange(param, P)
	assert(2 <= param and param <= P - 2)
end

math.randomseed(os.time())

local function generateKey(size)
	local s = ""
	for i=1, size / 16 do
	 s = s..string.format("%08X", math.random(2^16 - 1))
	end
	return BigInt.Create(s)
end

local function create(size)
	size = size or "2048"
	local dh = setmetatable({}, diffiehellman_mt)

	-- Set our prime
	dh.p = primes[size]

end

local function parse(self, context)
	local p, g, gy = BigInt.Create(context.P), BigInt.Create(context.G), BigInt.Create(context.GY)
	--self.good = checkRange(self.GY, self.P)


end

local BIGINT_ZERO = BigInt.Create(0)
local BIGINT_ONE = BigInt.Create(1)
local BIGINT_TWO = BigInt.Create(2)

local function odd(bi)
	return bi.comps[1] % 2 == 1
end

local function modular_pow(base, exponent, modulus)
	if modulus == BIGINT_ONE then return 0 end
	local result = BIGINT_ONE

	base = base % modulus

	while exponent > BIGINT_ZERO do

		print("--------------------------------------------------------------------------------------------------------------------")
		print(exponent == nil, base == nil, result == nil)

		if odd(exponent) then
			--print("Check:", result, base, modulus)

			print("Multiply Result and Base")
			local baseResult = result * base

			print("OddRslt: ", baseResult)

			result = baseResult % modulus

			print("NResult: ", result)
		end



		exponent = exponent / BIGINT_TWO
		print("Exp:     ", exponent)


		local squaredBase = base * base
		print("Base2:   ", squaredBase)

		base = squaredBase % modulus


		print("Result:  ", result)
		print("Base:    ", base)
		print("Exponent:", exponent)
		print("Modulus: ", modulus)
		print("")
		print("")
		print("")
	end

	return result
end


--[[function Matrix_ModExp(Matrix A, int b, int c)
   if (b == 0):
         return I  // The identity matrix
   if (b mod 2 == 1):
         return (A * Matrix_ModExp(A, b - 1, c)) mod c
   Matrix D := Matrix_ModExp(A, b / 2, c)
   return (D * D) mod c
]]

local i = 0
local function matrix_ModExp(base, exponent, modulus)
	i = i + 1
	print("New["..i.."]:", base, exponent, modulus)
	if exponent == BIGINT_ZERO then
		print("Yeah! We made it to zero!")
		return BIGINT_ONE
	elseif odd(exponent) then
		print("Odd: Minus 1")


		local minusOne = matrix_ModExp(base, exponent - 1, modulus)

		print("PostOdd:", base, minusOne, modulus)
		local t = (base * minusOne) % modulus
		print("Result:", t)
		return t
	end
	local temp =  matrix_ModExp(base, exponent / 2, modulus)
	i = i - 1
	return (temp * temp) % modulus
end




local prime = BigInt.Create(primes["DEBUG"])
print("Using Prime:", tostring(prime))


local alice = {}
local bob = {}


-- SECRET - Generate our keys
alice.a = generateKey(256)
bob.a = generateKey(256)


--alice.A = modular_pow(BIGINT_TWO, alice.a, prime)


--local testNumBase = "115792089237316195423570985008687907853269984665640564039457584007913129639936"
--                     115792089237316195423570985008687907853269984665640564039457584007913129639936
--local testNumMod =  "115792089210356248762697446949407573530086143415290314195533631308867097853951"

local testNumBase = "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
local testNumMod =  "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AACAA68FFFFFFFFFFFFFFFF"

--local testNumBase = "1000000000000"
--local testNumMod =  "FFFFFFFF741067226732FFFFFFFF"



local biNumBase = BigInt.Create(testNumBase)
local biNumMod = BigInt.Create(testNumMod)


--print(biNumBase * biNumMod)

--[[
local a = BigInt.Create("80")
local b = BigInt.Create("100")
local p = BigInt.Create("241")
local m = a * b
print("A * B = "..tostring(m), 256*128)
print(m % p)
]]


--bi - ((bi / m) * m)


--[[
local div = biNumBase / biNumMod
print("Div:", div, type(div))

local even = div * biNumMod
print("Even:", even, type(even))

local dif = biNumBase - even
print("Dif:", dif, type(dif))
]]

--print("Exponent:", alice.a)
--print("Mod:", prime)
--

--alice.A = matrix_ModExp(BIGINT_TWO, alice.a, prime)

--print(alice.A)


--local bigTest = "BCA3109AF5D6E68CD55A7C27ED3E124B651CE2ECC010940626AA3B5DDA0004ACE75A5A5296B07954932C439561F7DAC9F963EEF2692E1DA858A61A23875F5F729A963CEF1C22D664DE7DC510A6E87EEC5FE201E14FC6F109E6E2F726B6CCF471679633A085E65ED14C2A635DC20058E9E1C153792B953F524EE05BB6233095AD8A5D275A4204D62FFE8F596014A6D2EAAE88A5D70CCA47E1F5FEDE6BF355368883564F00BC521EFC1A2D2B3DA5753B2B0D2D3F735BAA3C52AD462F59D22B55CF0EA6406CEAC1B44E57EFAC5BD4AD6AE1F77A614D81A339529F9850E489CBE5E307275ABF8084D74AA7D67EC5A25F9FD59AB433E010D759EC36C547F6939149F3E5EBDCB3BB09FA712A45FAD6F8B5F8ABCCC2F7B22781946AEB20320196A1EA242445B83D2C45A06A29B6D36AD0F06D418927CA371CD221698EB7F722D09F763A55F08ACC63F837C30C81B6F761298A3F8644A0A0B994AC140F78622D2F09554764EFC7B0A470CE08BEBDA46D1F42C14358DDFCE522A0B4058867429407CDA5259430AAE0DD16AA909E6E2F0077659EE3C89C8D66D9F95DF0484FBB91419781A42233E3C100F933D5A2AE898B9D2FE95B046FBB804D70199A761F9B10685324D639A773044721AB6E1C9AC03A9969DAE5541C3A9B6B2F8F02D729DD1709394F0D51AE34AEAA6AB2E0000000000000001"
--local bitTestInt = BigInt.Create(bigTest)

--print(bitTestInt / prime)


--[[

This multiplication is hard because the first number is split into two parts, the second number is almost exactly half of the first, so all the highs are zero BUT all the lows are filled
There was a bug where this multiplication would fail, but is now fixed

local a = "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163"
local b = "BCA3F09D2562A31456604EBCB84C9392E9A89FB7E62D494F7F6204A858EAF3B26EEB7954E8652A1D0DC0157339D31FC4136C0AB8E74BED944F692103EB713195A"
local ai = BigInt.Create(a)
local bi = BigInt.Create(b)

print("")
print("")
print("")
print("Multiply:", ai)
print("      by:", bi)
print("")

local product = ai * bi

print("")
print("Result:")
print(product)
]]

--local result = modular_pow(BIGINT_TWO, BigInt.Create("BF"), BigInt.Create("241"))
--print(result)


print("Calc Public Alice")
alice.A = modular_pow(BIGINT_TWO, alice.a, prime)

print("Calc Public Bob")
bob.A = modular_pow(BIGINT_TWO, bob.a, prime)

print("Calc Private Key (Alice)")
alice.K = modular_pow(bob.A, alice.a, prime)

print("Calc Private Key (Bob)")
bob.K = modular_pow(alice.A, bob.a, prime)

print("Alice:", alice.K)
print("Bob:  ", bob.K)

--[[
]]

-- Calculate our public keys




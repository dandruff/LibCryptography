
-- Added by Dandruff
local Name, Public = ...

-- Register this library into our shared secrets
if not Public.SharedSecrets then Public.SharedSecrets = {} end
Public.SharedSecrets.BigInt = {}

-- two functions to help make Lua act more like C
local function fl(x)
	if x < 0 then
		return math.ceil(x) + 0 -- make -0 go away
	else
		return math.floor(x)
	end
end

local function cmod(a, b)
	local x = a % b
	if a < 0 and x > 0 then
		x = x - b
	end
	return x
end


local radix = 2^26 -- maybe up to 2^26 is safe?
local radix_sqrt = fl(math.sqrt(radix))

local bigintmt, bigint -- forward decl

local function alloc()
	local bi = {}
	setmetatable(bi, bigintmt)
	bi.comps = {}
	bi.sign = 1;
	return bi
end

local function clone(a)
	local bi = alloc()
	bi.sign = a.sign
	local c = bi.comps
	local ac = a.comps
	for i = 1, #ac do
		c[i] = ac[i]
	end
	return bi
end

local function normalize(bi, notrunc)
	local c = bi.comps
	local v
	-- borrow for negative components
	for i = 1, #c - 1 do
		v = c[i]
		if v < 0 then
			c[i+1] = c[i+1] + fl(v / radix) - 1
			v = cmod(v, radix)
			if v ~= 0 then
				c[i] = v + radix
			else
				c[i] = v
				c[i+1] = c[i+1] + 1
			end
		end
	end

	-- is top component negative?
	if c[#c] < 0 then
		-- switch the sign and fix components
		bi.sign = -bi.sign
		for i = 1, #c - 1 do
			v = c[i]
			c[i] = radix - v
			c[i+1] = c[i+1] + 1
		end
		c[#c] = -c[#c]
	end
	-- carry for components larger than radix
	for i = 1, #c do
		v = c[i]
		if v > radix then
			c[i+1] = (c[i+1] or 0) + fl(v / radix)
			c[i] = cmod(v, radix)
		end
	end
	-- trim off leading zeros
	if not notrunc then
		for i = #c, 2, -1 do
			if c[i] == 0 then
				c[i] = nil
			else
				break
			end
		end
	end
	-- check for -0
	if #c == 1 and c[1] == 0 and bi.sign == -1 then
		bi.sign = 1
	end
end

local function negate(a)
	local bi = clone(a)
	bi.sign = -bi.sign
	return bi
end

local function compare(a, b)
	local ac, bc = a.comps, b.comps
	local as, bs = a.sign, b.sign
	if ac == bc then
		return 0
	elseif as > bs then
		return 1
	elseif as < bs then
		return -1
	elseif #ac > #bc then
		return as
	elseif #ac < #bc then
		return -as
	end
	for i = #ac, 1, -1 do
		if ac[i] > bc[i] then
			return as
		elseif ac[i] < bc[i] then
			return -as
		end
	end
	return 0
end

local function odd(bi)
	return bi.comps[#bi.comps] % 2 == 1
end

local function lt(a, b)
	return compare(a, b) < 0
end

local function eq(a, b)
	return compare(a, b) == 0
end

local function le(a, b)
	return compare(a, b) <= 0
end

local function addint(a, n)
	local bi = clone(a)
	if bi.sign == 1 then
		bi.comps[1] = bi.comps[1] + n
	else
		bi.comps[1] = bi.comps[1] - n
	end
	normalize(bi)
	return bi
end

local function add(a, b)
	if type(a) == "number" then
		return addint(b, a)
	elseif type(b) == "number" then
		return addint(a, b)
	end
	local bi = clone(a)
	local sign = bi.sign == b.sign
	local c = bi.comps
	for i = #c + 1, #b.comps do
		c[i] = 0
	end
	local bc = b.comps
	for i = 1, #bc do
		local v = bc[i]
		if sign then
			c[i] = c[i] + v
		else
			c[i] = c[i] - v
		end
	end
	normalize(bi)
	return bi
end

local function sub(a, b)
	if type(b) == "number" then
		return addint(a, -b)
	elseif type(a) == "number" then
		a = bigint(a)
	end
	return add(a, negate(b))
end

local function mulint(a, b)
	local bi = clone(a)
	if b < 0 then
		b = -b
		bi.sign = -bi.sign
	end
	local bc = bi.comps
	for i = 1, #bc do
		bc[i] = bc[i] * b
	end
	normalize(bi)
	return bi
end

local function multiply(a, b)
	if a == bigint(0) or b == bigint(0) then return bigint(0) end
	local bi = alloc()
	local c = bi.comps
	local ac, bc = a.comps, b.comps
	for i = 1, #ac + #bc do
		c[i] = 0
	end
	for i = 1, #ac do
		for j = 1, #bc do
			c[i+j-1] = c[i+j-1] + ac[i] * bc[j]
		end
		-- keep the zeroes
		normalize(bi, true)
	end
	normalize(bi)
	if bi ~= bigint(0) then
		bi.sign = a.sign * b.sign
	end
	return bi
end

local tabs = 0
local function getTabs() return tabs > 0 and string.rep("\t", tabs) or "" end
local function tprint(...)
	local n1 = select(1, ...)
	if n1 then
		n1 = getTabs()..tostring(n1)
		print(n1, select(2, ...))
	end
end

local function kmul(a, b)
	tabs = tabs + 1

	local ac, bc = a.comps, b.comps
	local an, bn = #a.comps, #b.comps
	local bi, bj, bk, bl = alloc(), alloc(), alloc(), alloc()
	local ic, jc, kc, lc = bi.comps, bj.comps, bk.comps, bl.comps

	--local n = fl((math.max(an, bn) + 1) / 2)
	--

	local n = math.floor(math.max(an, bn) / 2 + 0.5)

	--print("No:", (math.max(an, bn) + 0.5) / 2, fl((math.max(an, bn) + 0.5) / 2))
	--print("Yes:", (math.max(an, bn) + 1) / 2, fl((math.max(an, bn) + 1) / 2))

	tprint("A ["..an.."]:", a)
	tprint("B ["..bn.."]:", b)
	tprint("Max / 2: ", n)

	for i = 1, n do
		ic[i] = (i + n <= an) and ac[i+n] or 0
		jc[i] = (i <= an) and ac[i] or 0
		kc[i] = (i + n <= bn) and bc[i+n] or 0
		lc[i] = (i <= bn) and bc[i] or 0

		tprint("Split ["..i.."]:", string.format("%-12s%-12s%-12s%-12s", ic[i], jc[i], kc[i], lc[i]))
	end

	normalize(bi)
	normalize(bj)
	normalize(bk)
	normalize(bl)


	tprint("")
	tprint("+++++++++++++")
	tprint("ik = bi * bk")
	local ik = bi * bk
	tprint("bi:", bi)
	tprint("bk:", bk)
	tprint("-------------")
	tprint("")
	tprint("+++++++++++++")
	tprint("jl = bj * bl")
	local jl = bj * bl
	tprint("bj:", bj)
	tprint("bl:", bl)
	tprint("-------------")

	tprint("")
	tprint("++=======++")
	tprint("mid = (bi + bj) * (bk + bl) - ik - jl")
	local mid = (bi + bj) * (bk + bl) - ik - jl

	tprint("bi:", bi)
	tprint("bj:", bj)
	tprint("bk:", bk)
	tprint("bl:", bl)
	tprint("ik:", ik)
	tprint("jl:", jl)
	tprint("md:", mid)
	tprint("--=======--")
	tprint("")

	local mc = mid.comps
	local ikc = ik.comps
	local jlc = jl.comps

	-- Prepare "jlc" for all the numbers its about to hold
	--for i = 1, #ikc + n*2 do -- fill it up
	for i = 1, n*2 + #mc do -- fill it up
		jlc[i] = jlc[i] or 0

	end

	tprint("ikc length is:", #ikc)
	tprint("jlc should be "..(#ikc + n*2).." big")
	tprint("n:  ", n)
	tprint("jlc:", #jlc)
	tprint("ikc:", #ikc)
	tprint("mc: ", #mc)
	tprint("max:", #mc+n)

	for i = 1, #mc do
		if i+n > #jlc then
			print(">>>] CRASH DETECTION:")
			for i, v in pairs(jlc) do
				print("   > "..i.." = "..v)
			end
		end
		jlc[i+n] = jlc[i+n] + mc[i]
	end

	-- WHAT IS THIS!
	for i = 1, #ikc do
		jlc[i+n*2] = jlc[i+n*2] + ikc[i]
	end

	jl.sign = a.sign * b.sign
	normalize(jl)

	tprint("ji is "..#jl.comps.." big")

	tabs = tabs - 1
	return jl
end

local kthresh = 12

local function mul(a, b)
	if type(a) == "number" then
		tprint("\tUsing Fastest Multiply")
		return mulint(b, a)
	elseif type(b) == "number" then
		print("\tUsing Fastest Multiply")
		return mulint(a, b)
	end
	if #a.comps < kthresh or #b.comps < kthresh then
		tprint("\tUsing Faster Multiply")
		return multiply(a, b)
	end
	tprint("\tUsing Slow Multiply")
	return kmul(a, b)
end

local function divint(numer, denom)
	local bi = clone(numer)
	if denom < 0 then
		denom = -denom
		bi.sign = -bi.sign
	end
	local r = 0
	local c = bi.comps
	for i = #c, 1, -1 do
		r = r * radix + c[i]
		c[i] = fl(r / denom)
		r = cmod(r, denom)
	end
	normalize(bi)
	return bi
end

local function multi_divide(numer, denom)
	local n = #denom.comps
	local approx = divint(numer, denom.comps[n])
	for i = n, #approx.comps do
		approx.comps[i - n + 1] = approx.comps[i]
	end
	for i = #approx.comps, #approx.comps - n + 2, -1 do
		approx.comps[i] = nil
	end
	local rem = approx * denom - numer
	if rem < denom then
		quotient = approx
	else
		quotient = approx - multi_divide(rem, denom)
	end
	return quotient
end

local function multi_divide_wrap(numer, denom)
	-- we use a successive approximation method, but it doesn't work
	-- if the high order component is too small.  adjust if needed.
	if denom.comps[#denom.comps] < radix_sqrt then
		numer = mulint(numer, radix_sqrt)
		denom = mulint(denom, radix_sqrt)
	end
	return multi_divide(numer, denom)
end

local function div(numer, denom)
	if type(denom) == "number" then
		if denom == 0 then
			error("divide by 0", 2)
		end
		return divint(numer, denom)
	elseif type(numer) == "number" then
		numer = bigint(numer)
	end
	-- check signs and trivial cases
	local sign = 1
	local cmp = compare(denom, bigint(0))
	if cmp == 0 then
		error("divide by 0", 2)
	elseif cmp == -1 then
		sign = -sign
		denom = negate(denom)
	end
	cmp = compare(numer, bigint(0))
	if cmp == 0 then
		return bigint(0)
	elseif cmp == -1 then
		sign = -sign
		numer = negate(numer)
	end
	cmp = compare(numer, denom)
	if cmp == -1 then
		return bigint(0)
	elseif cmp == 0 then
		return bigint(sign)
	end
	local bi
	-- if small enough, do it the easy way
	if #denom.comps == 1 then
		bi = divint(numer, denom.comps[1])
	else
		bi = multi_divide_wrap(numer, denom)
	end
	if sign == -1 then
		bi = negate(bi)
	end
	return bi
end

local function intrem(bi, m)
	if m < 0 then
		m = -m
	end
	local rad_r = 1
	local r = 0
	local bc = bi.comps
	for i = 1, #bc do
		local v = bc[i]
		r = cmod(r + v * rad_r, m)
		rad_r = cmod(rad_r * radix, m)
	end
	if bi.sign < 1 then
		r = -r
	end
	return r
end

local function intmod(bi, m)
	local r = intrem(bi, m)
	if r < 0 then
		r = r + m
	end
	return r
end

local function rem(bi, m)
	if type(m) == "number" then
		return bigint(intrem(bi, m))
	elseif type(bi) == "number" then
		bi = bigint(bi)
	end
	return bi - ((bi / m) * m)
end

local function mod(a, m)
	local bi = rem(a, m)
	if bi.sign == -1 then
		bi = bi + m
	end
	return bi
end

local printscale = 10000000
local printscalefmt = string.format("%%.%dd", math.log10(printscale))
local function makestr(bi, s)
	if bi >= bigint(printscale) then
		makestr(divint(bi, printscale), s)
	end
	table.insert(s, string.format(printscalefmt, intmod(bi, printscale)))
end

local function biginttostring(bi)
	local s = {}
	if bi < bigint(0) then
		bi = negate(bi)
		table.insert(s, "-")
	end
	makestr(bi, s)
	s = table.concat(s):gsub("^0*", "")
	if s == "" then s = "0" end
	return s
end

-- Defined as local on line ~~30
-- We needed to define all of our functions first
bigintmt = {
	__add = add,
	__sub = sub,
	__mul = mul,
	__div = div,
	__mod = mod,
	__unm = negate,
	__eq = eq,
	__lt = lt,
	__le = le,
	__tostring = biginttostring,

	-- Secure this meta-table
	__metatable = true
}

local cache = {}
local ncache = 0
PUBLIC_CACHE = cache

-- Defined above, this function is needed by some of the stuff
bigint = function (n)
	if cache[n] then
		return cache[n]
	end
	local bi
	if type(n) == "string" then
		local digits = { n:byte(1, -1) }
		local num

		bi = bigint(0)

		for i = 1, #digits do
			-- Just filter out spaces and non valid characters
			num = digits[i]

			-- Adjust the raw ascii value
			if ( num >= 48 and num <= 57 ) then			-- char is equal or between 0 and 9
				num = num - 48
			elseif ( num >= 65 and num <= 70 ) then		-- char is equal or between A and F
				num = num - 55							--    offset: 10 - 65 = -55
			elseif ( num >= 97 and num <= 102 ) then	-- char is equal or between a and f
				num = num - 87							--    offset: 10 - 97 = -87
			else
				-- Dont calculate whitespace or none hex characters
				num = nil
			end

			if num then
				bi = addint(mulint(bi, 16), num)
			end
		end
	else
		bi = alloc()
		bi.comps[1] = n
		normalize(bi)
	end
	if ncache > 100 then
		cache = {}
		ncache = 0
	end
	cache[n] = bi
	ncache = ncache + 1
	return bi
end

-- Public accessor to create a BigInt
Public.SharedSecrets.BigInt.Create = bigint

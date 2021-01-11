--------------------------------------------------------------------------------------------
--	LUA Big Number Library
--		Created by Jayden Koedijk (elcius@gmail.com)
--		Inspired by the works of Frederico Macedo Pessoa and Marco Serpa Molinaro.
--	Heavly optimised for the LUA implementation in World of Warcraft, minimizing
--	table creation/seeks and the use of external variables.
--	Numbers are stored as tables containing words of [radix length] decimal digits.
--	[0] being the most significant, [n-1] being the least: 1234567890 = {[0]=123,4567890}.
--	["n"] stores the length of the number, words in indexes >= n may contain zeros, all
--	words are stored as primitive type number.
--	["neg"] indicates if the value is negative, true for negative false for positive, this
--	field should not be nil. 
--------------------------------------------------------------------------------------------
BN = {
	RL = 7, -- radix length
	R = 1e7, -- radix
	
	-- create a new BN (big number)
	new = function(v)
		local neg = strfind(v,"-")==1;
		v = v:gsub("[^%d]",""):gsub("^0+","");
		local num = {n=ceil(strlen(v)/BN.RL), neg = neg};
		for i = 0,num.n-1 do
			num[i] = tonumber( v:sub( 0-((i+1)*BN.RL), -1-(i*BN.RL) ) );
		end
		return num;
	end,
	fromHex = function(h)
		local result = BN.new("0");
		local temp = BN.new("0");
		for i = 1, strlen(h) do
			BN.smul( result, 16, temp );
			BN.add( {n=1,neg=false,[0]=tonumber( h:sub(i, i), 16 )}, temp, result );
		end
		return result;
	end,
	
	-- adds a and b into c
	add = function(a,b,c)
		if a.neg ~= b.neg then --[ x+-y == x-y ]
			if a.neg then a,b = b,a; end -- move negative number to b
			b.neg = false; -- flag b as positive
			BN.sub(a,b,c); -- subtract positives
			if b ~= c then b.neg = true; end -- revert flag if b is not a pointer to c.
			return;
		end
		-- actual addition
		local radix = BN.R;
		local carry = 0;
		local n = max(a.n,b.n);
		for i = 0, n-1 do
			local s = (a[i] or 0) + (b[i] or 0) + carry;
			if s >= radix then
				s = s - radix;
				carry = 1;
			else
				carry = 0;
			end
			c[i] = s;
		end
		if carry == 1 then
			c[n] = 1;
			c.n = n+1;
		else
			c.n = n;
		end
		c.neg = a.neg;
	end,
	
	-- subtracts b from a into c
	sub = function(a,b,c)
		if a.neg ~= b.neg then --[ x--y == x+y && -x-y == -(x+y) ]
			local neg = a.neg; -- used to restore flags
			a.neg = false;
			b.neg = false;
			BN.add(a,b,c);
			a.neg = neg; -- revert flags
			b.neg = not neg;
			c.neg = neg;
		elseif a.neg then -- both negative --[ -x--y == y-x ]
			a.neg = false;
			b.neg = false;
			BN.sub(b,a,c);
			if a ~= c then a.neg = true; end -- revert flags
			if b ~= c then b.neg = true; end
		elseif BN.eqAbs(a,b) == -1 then --[ x-y == -(y-x) when y>x ]
			BN.sub(b,a,c);
			c.neg = true;
		else -- a > b, both numbers are positive
			-- actual subtraction
			local radix = BN.R;
			local carry = 0;
			local n;
			for i = 0, a.n-1 do
				local s = (a[i] or 0) - (b[i] or 0) - carry;
				if s < 0 then
					s = radix + s;
					carry = 1;
				else
					carry = 0;
				end
				if s ~= 0 then n = i+1; end
				c[i] = s;
			end
			if not n then -- zero/empty answer
				n = 1;
				c[1] = 0;
			end
			c.n = n;
			c.neg = false;
			-- clear un-used values
			while c[n+1] do
				n = n+1;
				c[n] = nil;
			end
		end
	end,
	
	-- multiplies a and b into c
	mul = function(a,b,c)
		--assert( c ~= a and c ~= b ); -- c gets cleared and can not reference an input
		if a.neg ~= b.neg then -- [-a*b == -(a*b)]
			if a.neg then a,b = b,a; end -- move negative number to b
			b.neg = false; -- flag b as positive
			BN.mul(a,b,c); -- multiply positives
			b.neg = true; -- revert flag
			c.neg = true; -- flag c as negative
			return;
		end
		-- actual multiplication
		local radix = BN.R;
		c.neg = false;
		local carry = 0;
		local an = a.n;
		local bn = b.n;
		local fmod = math.fmod;
		for i = 0, (an+bn)-1 do c[i] = 0; end -- clear and zero fill c
		for i = 0, an-1 do
			local ai = a[i];
			for j = 0, bn-1 do
				carry = ( ai * b[j] + carry ) + c[i+j];
				c[i+j] = fmod( carry, radix );
				carry = floor( carry / radix );
			end
			if carry ~= 0 then
				c[i+bn] = carry;
				carry = 0;
			end
		end
		-- update n for c, also clear zeros
		for i = (an+bn)-1, 0, -1 do
			if c[i] ~= 0 then
				c.n = i+1;
				return;
			else
				c[i] = nil;
			end
		end
		if not c[0] then
			c[0] = 0;
		end 
	end,
	
	-- equivalent to a = b*(BN.R^n)
	put = function(a,b,n)
		for i = 0, n-1 do a[i] = 0; end
		for i = n+1, a.n do a[i] = nil; end
		a[n] = b;
		a.n = n;
	end,
	
	-- divide
	div = function(a,b,c,d)
		--assert( a ~= c and a ~= d and b ~= c and b ~= d and c ~= d );
		-- actual division
		local radix = BN.R;
		local temp1 = {n=1,neg=false};
		local temp2 = {n=1,neg=false};
		if not c then c = {}; end
		if not d then d = {}; end
		for i = 0, c.n or 0 do c[i] = nil; end -- clear c
		for i = 0, a.n do d[i] = a[i]; end -- copy a into d
		c.n = 1;
		d.n = a.n;
		c.neg = false;
		d.neg = false;
		
		while BN.eqAbs( d, b ) ~= -1 do
			if d[d.n-1] >= b[b.n-1] then
				BN.put( temp1, floor( d[d.n-1] / b[b.n-1] ), d.n-b.n );
				temp1.n = d.n-b.n + 1 ;
			else
				BN.put( temp1, floor( ( d[d.n - 1] * radix + d[d.n - 2] ) / b[b.n -1] ) , d.n-b.n - 1 ) ;
				temp1.n = d.n-b.n;
			end
			temp1.neg = d.neg;
			BN.add( temp1, c, c );
			BN.mul( temp1, b, temp2 );
			temp2.neg = temp1.neg;
			BN.sub( d, temp2, d );
		end
		
		if d.neg then
			c[c.n-1] = c[c.n-1]-1; -- decr c
			BN.add( b, d, d );
		end
		
		-- adjustments
		if a.neg and d.neg then -- remainder is negative
			c[c.n-1] = c[c.n-1]+1; -- inc c
			if b.neg then
				b.neg = false;
				BN.sub( b, d, d );
				b.neg = true;
			else
				BN.sub( b, d, d );
			end
		end
		if a.neg ~= b.neg then --[ a/-b | -a/b == -(a/b) ]
			c.neg = true;
		end
		if not c[0] then c[0] = 0; end
	end,
	
	-- small divide, faster than normal div, (returns remainder as number)
	sdiv = function(a,b,c)
		local radix = BN.R;
		local carry = 0;
		for i = a.n, c.n-1 do c[i] = nil; end -- clear c
		c.n = a.n;
		for i = a.n-1, 0, -1 do
			c[i] = (a[i]/b) + (carry*radix);
			carry = c[i]%1;
			c[i] = floor(c[i]);
			if c[i] == 0 then
				c.n = c.n-1;
			end
		end
		return floor(0.5+(carry*b));
	end,
	
	-- small multiplication
	smul = function(a,b,c)
		local radix = BN.R;
		local carry = 0;
		for i = a.n, c.n-1 do c[i] = nil; end -- clear c
		for i = 0, a.n-1 do
			c[i] = (a[i]*b)+carry
			carry = floor(c[i]/radix);
			c[i] = c[i]%radix;
		end
		if carry ~= 0 then
			c[a.n] = carry;
			c.n = a.n + 1;
		else
			c.n = a.n;
		end
	end,
	
	-- a = (a*b)%c
	-- saves about 0.2s
	thing = function(a,b,c)
		-- actual multiplication
		local radix = BN.R;
		local carry = 0;
		local fmod = math.fmod;
		local d = {neg=false};
		local temp1 = {n=1,neg=false};
		local temp2 = {n=1,neg=false};
		
		-- d = a*b;
		for i = 0, a.n-1 do
			local ai = a[i];
			for j = 0, b.n-1 do
				carry = ( ai * b[j] + carry ) + (d[i+j] or 0);
				d[i+j] = fmod( carry, radix );
				carry = floor( carry / radix );
			end
			if carry ~= 0 then
				d[i+b.n] = carry;
				carry = 0;
			end
		end
		d.n = #d+1;
		-- d = (a*b)%c;
		while BN.eqAbs( d, c ) ~= -1 do
			
			temp1.n = d.n-c.n;
			for i = 0, temp1.n-2 do temp1[i] = 0; end
			temp1[temp1.n-1] = floor( ( d[d.n - 1] * radix + d[d.n - 2] ) / c[c.n -1] );
			temp1[temp1.n] = nil;
			temp1.neg = d.neg;
			
			BN.mul( temp1, c, temp2 );
			temp2.neg = temp1.neg;
			BN.sub( d, temp2, d );
		end
		if d.neg then
			BN.add(c,d,a);
		else
			BN.copy(d,a);
		end
	end,
	
	-- modular exponentiation, (b^e)%m
	-- TODO: replace divide's with dedicated modulo's
	-- TODO: e is only used as a counter, find a better way of counting
	mpow = function(b,e,m)
		local result = BN.new("1");
		e = BN.copy(e,BN.new("0"));
		local base = {n=0};
		BN.copy(b,base);
		local temp = BN.new("0");
		while e[0] ~= 0 or e.n > 1 do -- e != 0
			if BN.sdiv( e, 2, e ) == 1 then
				--BN.thing(result,base,m);
				BN.mul( result, base, temp );
				BN.div( temp, m, nil, result );
			end
			--BN.thing(base,base,m);
			BN.mul( base, base, temp );
			BN.div( temp, m, nil, base );
		end
		return result;
	end,
	
	-- modular multiplicative inverse, fips_186-3, C.1
	modInverse = function(z,a)
		local i = BN.copy(a,BN.new("0")); 
		local j = BN.copy(z,BN.new("0"));
		local y1 = BN.new("1");
		local y2 = BN.new("0");
		local r = BN.new("0");
		local q = BN.new("0");
		local y = BN.new("0");
		while j[0] > 0 or j.n > 1 do
			BN.div(i,j,q,r);
			BN.smul(y1,q[0],y);
			BN.sub(y2,y,y);
			r,i,j = i,j,r;
			BN.copy(y1,y2);
			BN.copy(y,y1);
		end
		if y2.neg or ( y2[0] == 0 and y2.n == 1 ) then
			BN.add(y2,a,y2);
		end
		return y2;
	end,
	
	-- -1 = a<b, 0 = a==b, 1 = a>b
	eq = function(a,b)
		if a.neg ~= b.neg then return b.neg and 1 or -1; end -- positive > negative
		if a.neg then return BN.eqAbs(a,b) * -1; end -- both negative so inverse
		return BN.eqAbs(a,b); -- both positive
	end,
	eqAbs = function(a,b)
		if a == b then return 0; end -- same object
		if a.n ~= b.n then return ( a.n > b.n ) and 1 or -1; end
		for i = a.n-1, 0, -1 do
			if a[i] ~= b[i] then return ( a[i] > b[i] ) and 1 or -1; end
		end
		return 0;
	end,
	
	-- copys a into b
	copy = function(a,b)
		for i = 0, max(a.n,b.n)-1 do
			b[i] = a[i];
		end
		b.n = a.n;
		b.neg = a.neg;
		return b;
	end,
	
	--[[ Unneeded/debugging functions
	-- Bitwise operations
	rshift = function( a, n, b ) BN.sdiv( a, 2^n, b or a ); end,
	lshift = function( a, n, b ) BN.smul( a, 2^n, b or a ); end,
	numBits = function(a)
		local n = 1;
		local b = BN.new("1");
		while BN.eqAbs(a,b) == -1 do
			BN.smul(b,2,b);
			n = n + 1;
		end
		return n;
	end,
	--]]
	-- Print
	toString = function(a)
		if type(a) ~= "table" then return tostring(a); end
		if a[0] == 0 and a.n == 1 then return "0"; end
		local str = "";
		for i = 0, a.n-1 do
			str = strrep("0",BN.RL-strlen(a[i] or ""))..(a[i] or "")..str;
		end
		return (a.neg and "-" or "")..(str:gsub("^0*",""));
	end,
}
local BN = BN;

--------------------------------------------------------------------------------------------
--	LUA Digital Signature Algorithm Library
--		Created by Jayden Koedijk (elcius@gmail.com)
--		http://csrc.nist.gov/publications/fips/fips186-3/fips_186-3.pdf
--	Uses the BN (Big Number) library for calculations.
--	Uses Sha256 for hashing.
--------------------------------------------------------------------------------------------
LibDSA = {
	
	-- validate a signature
	Validate = function(key,sig,msg)
		local q,p,g,y = key.q, key.p, key.g, key.y;
		local r,s = sig.r, sig.s;
		if not ( q and p and g and y and r and s and type(msg) == "string" ) then
			return false,"Invalid Input.";
		elseif not Sha256 then
			return false,"Hash function unavailable 'Sha256'.";
		end
		
		-- 0 < r < q, 0 < s < q
		local temp = BN.new("0");
		if BN.eqAbs(r,temp) ~= 1 or BN.eq(r,q) ~= -1
		or BN.eqAbs(s,temp) ~= 1 or BN.eq(s,q) ~= -1 then
			return false,"Signature out of range.";
		end
		
		-- w = s^-1 % q
		local w = BN.modInverse(s,q);
		
		-- u1 = H(m)*w % q
		local m = BN.fromHex( Sha256(msg):sub(0,40) ); -- H(m)
		local u1 = BN.new("0");
		BN.mul( m, w, temp )
		BN.div( temp, q, nil, u1 );
		
		-- u2 = r*w % q
		local u2 = BN.new("0");
		BN.mul( r, w, temp );
		BN.div( temp, q, nil, u2 );
		
		-- ((g^u1*g^u2)%p)%q == (((g^u1%q)*(y^u2%q))%p)%q
		-- these two operations are about 80% of the work
		local gu1 = BN.mpow(g,u1,p); -- (g^u1%q)
		local yu2 = BN.mpow(y,u2,p); -- (y^u2%q)
		
		local v = BN.new("0");
		BN.mul( gu1, yu2, v ); -- gu1*yu2
		BN.div( v, p, nil, temp ); -- %p
		BN.div( temp, q, nil, v ); -- %q
		
		return BN.eq(v,r) == 0;
	end,
	
	-- generate a signature
	-- this function is not needed by users and should not be packaged
	Sign = function(key,x,msg)
		local q,p,g,y = key.q, key.p, key.g, key.y;
		if not ( q and p and g and y and x and type(msg) == "string" ) then
			return false,"Invalid Input.";
		end
		
		local r = BN.new("0");
		local s = BN.new("0");
		local m = BN.fromHex( Sha256(msg):sub(0,40) ); -- H(m)
		local temp1 = BN.new("0");
		local temp2 = BN.new("0");
		
		repeat
			-- seed k
			local k = BN.new((random()..random()..random()):gsub("0%.",""));
			-- (g^k %p)%q
			temp1 = BN.mpow( g, k, p );
			BN.div( temp1, q, nil, r );
			
			-- restart if r is 0
			if r[0] ~= 0 or s.n >= 1 then
				-- ((k^-1) * (H(m) + x*r) % q
				k = BN.modInverse(k,q); -- k^-1%q
				BN.mul( x, r, temp1 ); -- x*r
				BN.div( temp1, q, nil, temp2 ); -- (x*r)%q
				BN.add( m, temp2, temp2 ); -- m+((x*r)%q)
				BN.mul( k, temp2, temp1 ); -- (k^-1%q)*(m+((x*r)%q))
				BN.div( temp1, q, nil, s ); -- s = ((k^-1%q)*(m+((x*r)%q)))%q
			end
		until s[0] ~= 0 or s.n >= 1; -- restart if s is 0
		
		return {r=r,s=s};
	end,
}

--------------------------------------------------------------------------------------------
-- Test
--------------------------------------------------------------------------------------------

local function DSA_test()
	-- values generated using OpenSSL
	local key = { -- public key
		q = BN.fromHex("e12271ec020adfe604bceafa55610a000f1f6c9f"),
		p = BN.fromHex("b53316faa1f842a44bebefa177674cb6cde6ba7894f33eff55522a73cbdb4b6390789dcb6b305c5970939e7c041859e7fd411ab747803663f8b94110ecb86b4b"),
		g = BN.fromHex("3f9b423021dc91663693a48f38c84d3986ccfd0a0c91ec578e83806275f07db1cae9170190b5d739863f7af1a7c38f381b53e7ef75be08d38eab3de5d61a8f88"),
		y = BN.fromHex("9341ba0b2aaa9a1e8d9dd1f5f58d83dd1b9fbaab39a026dbbe1e746ced9d1468c244e9e512353fe5909a3b1adb109c46c408780405a7711773047c2d85d6aa10")
	};
	local msg = "hello world";
	
	-- validate test
	local sig = {
		r = BN.fromHex("3bde3048d29076582dba3db7c72a242934aacf61"),
		s = BN.fromHex("813d6cd6e2196f029ccc19054c3f18ccd4201c40")
	};
	print("Pregenerated Signature Result: ",LibDSA.Validate(key,sig,msg));
	
	-- sign test
	local x = BN.fromHex("3fa4d6629e2688807b87eddb93c601e71eb5dbf9"); -- private key
	local sig,err = LibDSA.Sign(key,x,msg);
	print("Signature Generation: ", err or "okay.");
	print("Generated Signature Result: ",LibDSA.Validate(key,sig,msg));
	
	
	(ExecutionTimer or CreateFrame("Frame","ExecutionTimer")):SetScript("OnUpdate",function(s)
		if s.t then
			print(GetTime()-s.t,"seconds");
			s:SetScript("OnUpdate",nil);
		end
		s.t = not s.t and GetTime();
	end);
end

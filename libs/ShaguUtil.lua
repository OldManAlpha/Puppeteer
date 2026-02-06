--[[

The MIT License (MIT)

Copyright (c) 2016-2021 Eric Mauser (Shagu)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]

-- I'm too lazy to implement this myself, for now..

PTUtil.SetEnvironment(PTUtil)
local _G = getfenv(0)


local gfind = string.gmatch or string.gfind

-- [ SanitizePattern ]
-- Sanitizes and convert patterns into gfind compatible ones.
-- 'pattern'    [string]         unformatted pattern
-- returns:     [string]         simplified gfind compatible pattern
local sanitize_cache = {}
function SanitizePattern(pattern)
  if not sanitize_cache[pattern] then
    local ret = pattern
    -- escape magic characters
    ret = gsub(ret, "([%+%-%*%(%)%?%[%]%^])", "%%%1")
    -- remove capture indexes
    ret = gsub(ret, "%d%$","")
    -- catch all characters
    ret = gsub(ret, "(%%%a)","%(%1+%)")
    -- convert all %s to .+
    ret = gsub(ret, "%%s%+",".+")
    -- set priority to numbers over strings
    ret = gsub(ret, "%(.%+%)%(%%d%+%)","%(.-%)%(%%d%+%)")
    -- cache it
    sanitize_cache[pattern] = ret
  end

  return sanitize_cache[pattern]
end

-- [ GetCaptures ]
-- Returns the indexes of a given regex pattern
-- 'pat'        [string]         unformatted pattern
-- returns:     [numbers]        capture indexes
local capture_cache = {}
function GetCaptures(pat)
  local r = capture_cache
  if not r[pat] then
    for a, b, c, d, e in gfind(gsub(pat, "%((.+)%)", "%1"), gsub(pat, "%d%$", "%%(.-)$")) do
      r[pat] = { a, b, c, d, e}
    end

    r[pat] = r[pat] or {}
  end

  return r[pat][1], r[pat][2], r[pat][3], r[pat][4], r[pat][5]
end

-- [ cmatch ]
-- Same as string.match but aware of capture indexes (up to 5)
-- 'str'        [string]         input string that should be matched
-- 'pat'        [string]         unformatted pattern
-- returns:     [strings]        matched string in capture order
local a, b, c, d, e
local _, va, vb, vc, vd, ve
local ra, rb, rc, rd, re
function cmatch(str, pat)
  -- read capture indexes
  a, b, c, d, e = GetCaptures(pat)
  _, _, va, vb, vc, vd, ve = string.find(str, SanitizePattern(pat))

  -- put entries into the proper return values
  ra = e == 1 and ve or d == 1 and vd or c == 1 and vc or b == 1 and vb or va
  rb = e == 2 and ve or d == 2 and vd or c == 2 and vc or a == 2 and va or vb
  rc = e == 3 and ve or d == 3 and vd or a == 3 and va or b == 3 and vb or vc
  rd = e == 4 and ve or a == 4 and va or c == 4 and vc or b == 4 and vb or vd
  re = a == 5 and va or d == 5 and vd or c == 5 and vc or b == 5 and vb or ve

  return ra, rb, rc, rd, re
end


-- Modified serialization and compression functions from pfUI/modules/share.lua

local indentMap = {[0] = ""}
for i = 1, 8 do
    indentMap[i] = indentMap[i - 1].." "
end
-- Parameters:
-- tbl: The table to serialize
-- name: Name of the table, or nil for a nameless table
-- compare: A table to compare equality to, reducing the output if values are equal, can be nil
-- ignored: A set of ignored keys at all depths, can be nil
-- indentation: The number of spaces to indent in each nest, 0-8, default 4
-- spacing (Internal): String of current indentation
function SerializeTable(tbl, name, compare, ignored, indentation, spacing)
    indentation = indentation or 4
    spacing = spacing or ""
    local match = nil
    local str = spacing .. (name and (( spacing == "" and "" or "[\"" ) .. name .. ( spacing == "" and "" or "\"]" ) .. " = {\n")
        or "{\n")

    local isArray = GetTableSize(tbl) == table.getn(tbl)
    for k, v in (isArray and ipairs or pairs)(tbl) do
        local serializedK = type(k) == "number" and k or ("\""..k.."\"")
        local start = str .. spacing .. indentMap[indentation] .. (not isArray and "["..serializedK.."] = " or "")
        local vType = type(v)
        if not ( ignored ~= nil and (ignored[k] and spacing == "") ) and ( compare == nil or compare[k] == nil or compare[k] ~= tbl[k] ) then
            if vType == "table" then
                local result = SerializeTable(tbl[k], k, compare and compare[k], ignored, indentation, spacing .. indentMap[indentation])
                if result then
                    match = true
                    str = str .. result
                end
            elseif vType == "string" then
                match = true
                str = start.."\""..string.gsub(v, "\\", "\\\\").."\",\n"
            elseif vType == "number" or vType == "boolean" then
                match = true
                str = start..tostring(v)..",\n"
            end
        end
    end

    if not match then
        return nil
    end

    str = str .. spacing .. "}" .. ( spacing == "" and "" or "," ) .. "\n"
    return str
  end

  function DeserializeTable(str)
    return loadstring("return "..str)()
  end

  function Compress(input)
    -- based on Rochet2's lzw compression
    if type(input) ~= "string" then
      return nil
    end
    local len = strlen(input)
    if len <= 1 then
      return "u"..input
    end

    local dict = {}
    for i = 0, 255 do
      local ic, iic = strchar(i), strchar(i, 0)
      dict[ic] = iic
    end
    local a, b = 0, 1

    local result = {"c"}
    local resultlen = 1
    local n = 2
    local word = ""
    for i = 1, len do
      local c = strsub(input, i, i)
      local wc = word..c
      if not dict[wc] then
        local write = dict[word]
        if not write then
          return nil
        end
        result[n] = write
        resultlen = resultlen + strlen(write)
        n = n+1
        if  len <= resultlen then
          return "u"..input
        end
        local str = wc
        if a >= 256 then
          a, b = 0, b+1
          if b >= 256 then
            dict = {}
            b = 1
          end
        end
        dict[str] = strchar(a,b)
        a = a+1
        word = c
      else
        word = wc
      end
    end
    result[n] = dict[word]
    resultlen = resultlen+strlen(result[n])
    n = n+1
    if  len <= resultlen then
      return "u"..input
    end
    return table.concat(result)
  end

  function Decompress(input)
    -- based on Rochet2's lzw compression
    if type(input) ~= "string" or strlen(input) < 1 then
      return nil
    end

    local control = strsub(input, 1, 1)
    if control == "u" then
      return strsub(input, 2)
    elseif control ~= "c" then
      return nil
    end
    input = strsub(input, 2)
    local len = strlen(input)

    if len < 2 then
      return nil
    end

    local dict = {}
    for i = 0, 255 do
      local ic, iic = strchar(i), strchar(i, 0)
      dict[iic] = ic
    end

    local a, b = 0, 1

    local result = {}
    local n = 1
    local last = strsub(input, 1, 2)
    result[n] = dict[last]
    n = n+1
    for i = 3, len, 2 do
      local code = strsub(input, i, i+1)
      local lastStr = dict[last]
      if not lastStr then
        return nil
      end
      local toAdd = dict[code]
      if toAdd then
        result[n] = toAdd
        n = n+1
        local str = lastStr..strsub(toAdd, 1, 1)
        if a >= 256 then
          a, b = 0, b+1
          if b >= 256 then
            dict = {}
            b = 1
          end
        end
        dict[strchar(a,b)] = str
        a = a+1
      else
        local str = lastStr..strsub(lastStr, 1, 1)
        result[n] = str
        n = n+1
        if a >= 256 then
          a, b = 0, b+1
          if b >= 256 then
            dict = {}
            b = 1
          end
        end
        dict[strchar(a,b)] = str
        a = a+1
      end
      last = code
    end
    return table.concat(result)
  end

function Encode(to_encode)
    local index_table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local bit_pattern = ''
    local encoded = ''
    local trailing = ''

    for i = 1, string.len(to_encode) do
      local remaining = tonumber(string.byte(string.sub(to_encode, i, i)))
      local bin_bits = ''
      for i = 7, 0, -1 do
        local current_power = math.pow(2, i)
        if remaining >= current_power then
          bin_bits = bin_bits .. '1'
          remaining = remaining - current_power
        else
          bin_bits = bin_bits .. '0'
        end
      end
      bit_pattern = bit_pattern .. bin_bits
    end

    if mod(string.len(bit_pattern), 3) == 2 then
      trailing = '=='
      bit_pattern = bit_pattern .. '0000000000000000'
    elseif mod(string.len(bit_pattern), 3) == 1 then
      trailing = '='
      bit_pattern = bit_pattern .. '00000000'
    end

    local count = 0
    for i = 1, string.len(bit_pattern), 6 do
      local byte = string.sub(bit_pattern, i, i+5)
      local offset = tonumber(tonumber(byte, 2))
      encoded = encoded .. string.sub(index_table, offset+1, offset+1)
      count = count + 1
      if count >= 92 then
        encoded = encoded .. "\n"
        count = 0
      end
    end

    return string.sub(encoded, 1, -1 - string.len(trailing)) .. trailing
  end

  function Decode(to_decode)
    local index_table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local padded = gsub(to_decode,"%s", "")
    local unpadded = gsub(padded,"=", "")
    local bit_pattern = ''
    local decoded = ''

    to_decode = gsub(to_decode,"\n", "")
    to_decode = gsub(to_decode," ", "")

    for i = 1, string.len(unpadded) do
      local char = string.sub(to_decode, i, i)
      local offset, _ = string.find(index_table, char)
      if offset == nil then return nil end

      local remaining = tonumber(offset-1)
      local bin_bits = ''
      for i = 7, 0, -1 do
        local current_power = math.pow(2, i)
        if remaining >= current_power then
          bin_bits = bin_bits .. '1'
          remaining = remaining - current_power
        else
          bin_bits = bin_bits .. '0'
        end
      end

      bit_pattern = bit_pattern .. string.sub(bin_bits, 3)
    end

    for i = 1, string.len(bit_pattern), 8 do
      local byte = string.sub(bit_pattern, i, i+7)
      decoded = decoded .. strchar(tonumber(byte, 2))
    end

    local padding_length = string.len(padded)-string.len(unpadded)

    if (padding_length == 1 or padding_length == 2) then
      decoded = string.sub(decoded,1,-2)
    end

    return decoded
  end
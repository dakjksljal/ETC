-- 자동 생성 파일 — 수정 금지. 원본: packages/shared/src/lib/gear-core.ts
-- 재생성: node scripts/build-addon-gear-core.mjs (wythic-plus 레포)
-- Lua Library inline imports
local function __TS__ObjectEntries(obj)
    local result = {}
    local len = 0
    for key in pairs(obj) do
        len = len + 1
        result[len] = {key, obj[key]}
    end
    return result
end

local function __TS__ObjectValues(obj)
    local result = {}
    local len = 0
    for key in pairs(obj) do
        len = len + 1
        result[len] = obj[key]
    end
    return result
end

local function __TS__CountVarargs(...)
    return select("#", ...)
end

local function __TS__ArrayReduce(self, callbackFn, ...)
    local len = #self
    local k = 0
    local accumulator = nil
    if __TS__CountVarargs(...) ~= 0 then
        accumulator = ...
    elseif len > 0 then
        accumulator = self[1]
        k = 1
    else
        error("Reduce of empty array with no initial value", 0)
    end
    for i = k + 1, len do
        accumulator = callbackFn(
            nil,
            accumulator,
            self[i],
            i - 1,
            self
        )
    end
    return accumulator
end

local function __TS__ObjectKeys(obj)
    local result = {}
    local len = 0
    for key in pairs(obj) do
        len = len + 1
        result[len] = key
    end
    return result
end

local __TS__StringSplit
do
    local sub = string.sub
    local find = string.find
    function __TS__StringSplit(source, separator, limit)
        if limit == nil then
            limit = 4294967295
        end
        if limit == 0 then
            return {}
        end
        local result = {}
        local resultIndex = 1
        if separator == nil or separator == "" then
            for i = 1, #source do
                result[resultIndex] = sub(source, i, i)
                resultIndex = resultIndex + 1
            end
        else
            local currentPos = 1
            while resultIndex <= limit do
                local startPos, endPos = find(source, separator, currentPos, true)
                if not startPos then
                    break
                end
                result[resultIndex] = sub(source, currentPos, startPos - 1)
                resultIndex = resultIndex + 1
                currentPos = endPos + 1
            end
            if resultIndex <= limit then
                result[resultIndex] = sub(source, currentPos)
            end
        end
        return result
    end
end

local function __TS__Class(self)
    local c = {prototype = {}}
    c.prototype.__index = c.prototype
    c.prototype.constructor = c
    return c
end

local __TS__Symbol, Symbol
do
    local symbolMetatable = {__tostring = function(self)
        return ("Symbol(" .. (self.description or "")) .. ")"
    end}
    function __TS__Symbol(description)
        return setmetatable({description = description}, symbolMetatable)
    end
    Symbol = {
        asyncDispose = __TS__Symbol("Symbol.asyncDispose"),
        dispose = __TS__Symbol("Symbol.dispose"),
        iterator = __TS__Symbol("Symbol.iterator"),
        hasInstance = __TS__Symbol("Symbol.hasInstance"),
        species = __TS__Symbol("Symbol.species"),
        toStringTag = __TS__Symbol("Symbol.toStringTag")
    }
end

local __TS__Iterator
do
    local function iteratorGeneratorStep(self)
        local co = self.____coroutine
        local status, value = coroutine.resume(co)
        if not status then
            error(value, 0)
        end
        if coroutine.status(co) == "dead" then
            return
        end
        return true, value
    end
    local function iteratorIteratorStep(self)
        local result = self:next()
        if result.done then
            return
        end
        return true, result.value
    end
    local function iteratorStringStep(self, index)
        index = index + 1
        if index > #self then
            return
        end
        return index, string.sub(self, index, index)
    end
    function __TS__Iterator(iterable)
        if type(iterable) == "string" then
            return iteratorStringStep, iterable, 0
        elseif iterable.____coroutine ~= nil then
            return iteratorGeneratorStep, iterable
        elseif iterable[Symbol.iterator] then
            local iterator = iterable[Symbol.iterator](iterable)
            return iteratorIteratorStep, iterator
        else
            return ipairs(iterable)
        end
    end
end

local function __TS__New(target, ...)
    local instance = setmetatable({}, target.prototype)
    instance:____constructor(...)
    return instance
end

local Set
do
    Set = __TS__Class()
    Set.name = "Set"
    function Set.prototype.____constructor(self, values)
        self[Symbol.toStringTag] = "Set"
        self.size = 0
        self.nextKey = {}
        self.previousKey = {}
        if values == nil then
            return
        end
        local iterable = values
        if iterable[Symbol.iterator] then
            local iterator = iterable[Symbol.iterator](iterable)
            while true do
                local result = iterator:next()
                if result.done then
                    break
                end
                self:add(result.value)
            end
        else
            local array = values
            for ____, value in ipairs(array) do
                self:add(value)
            end
        end
    end
    function Set.prototype.add(self, value)
        local isNewValue = not self:has(value)
        if isNewValue then
            self.size = self.size + 1
        end
        if self.firstKey == nil then
            self.firstKey = value
            self.lastKey = value
        elseif isNewValue then
            self.nextKey[self.lastKey] = value
            self.previousKey[value] = self.lastKey
            self.lastKey = value
        end
        return self
    end
    function Set.prototype.clear(self)
        self.nextKey = {}
        self.previousKey = {}
        self.firstKey = nil
        self.lastKey = nil
        self.size = 0
    end
    function Set.prototype.delete(self, value)
        local contains = self:has(value)
        if contains then
            self.size = self.size - 1
            local next = self.nextKey[value]
            local previous = self.previousKey[value]
            if next ~= nil and previous ~= nil then
                self.nextKey[previous] = next
                self.previousKey[next] = previous
            elseif next ~= nil then
                self.firstKey = next
                self.previousKey[next] = nil
            elseif previous ~= nil then
                self.lastKey = previous
                self.nextKey[previous] = nil
            else
                self.firstKey = nil
                self.lastKey = nil
            end
            self.nextKey[value] = nil
            self.previousKey[value] = nil
        end
        return contains
    end
    function Set.prototype.forEach(self, callback)
        for ____, key in __TS__Iterator(self:keys()) do
            callback(nil, key, key, self)
        end
    end
    function Set.prototype.has(self, value)
        return self.nextKey[value] ~= nil or self.lastKey == value
    end
    Set.prototype[Symbol.iterator] = function(self)
        return self:values()
    end
    function Set.prototype.entries(self)
        local function getFirstKey()
            return self.firstKey
        end
        local nextKey = self.nextKey
        local key
        local started = false
        return {
            [Symbol.iterator] = function(self)
                return self
            end,
            next = function(self)
                if not started then
                    started = true
                    key = getFirstKey(nil)
                else
                    key = nextKey[key]
                end
                return {done = not key, value = {key, key}}
            end
        }
    end
    function Set.prototype.keys(self)
        local function getFirstKey()
            return self.firstKey
        end
        local nextKey = self.nextKey
        local key
        local started = false
        return {
            [Symbol.iterator] = function(self)
                return self
            end,
            next = function(self)
                if not started then
                    started = true
                    key = getFirstKey(nil)
                else
                    key = nextKey[key]
                end
                return {done = not key, value = key}
            end
        }
    end
    function Set.prototype.values(self)
        local function getFirstKey()
            return self.firstKey
        end
        local nextKey = self.nextKey
        local key
        local started = false
        return {
            [Symbol.iterator] = function(self)
                return self
            end,
            next = function(self)
                if not started then
                    started = true
                    key = getFirstKey(nil)
                else
                    key = nextKey[key]
                end
                return {done = not key, value = key}
            end
        }
    end
    function Set.prototype.union(self, other)
        local result = __TS__New(Set, self)
        for ____, item in __TS__Iterator(other) do
            result:add(item)
        end
        return result
    end
    function Set.prototype.intersection(self, other)
        local result = __TS__New(Set)
        for ____, item in __TS__Iterator(self) do
            if other:has(item) then
                result:add(item)
            end
        end
        return result
    end
    function Set.prototype.difference(self, other)
        local result = __TS__New(Set, self)
        for ____, item in __TS__Iterator(other) do
            result:delete(item)
        end
        return result
    end
    function Set.prototype.symmetricDifference(self, other)
        local result = __TS__New(Set, self)
        for ____, item in __TS__Iterator(other) do
            if self:has(item) then
                result:delete(item)
            else
                result:add(item)
            end
        end
        return result
    end
    function Set.prototype.isSubsetOf(self, other)
        for ____, item in __TS__Iterator(self) do
            if not other:has(item) then
                return false
            end
        end
        return true
    end
    function Set.prototype.isSupersetOf(self, other)
        for ____, item in __TS__Iterator(other) do
            if not self:has(item) then
                return false
            end
        end
        return true
    end
    function Set.prototype.isDisjointFrom(self, other)
        for ____, item in __TS__Iterator(self) do
            if other:has(item) then
                return false
            end
        end
        return true
    end
    Set[Symbol.species] = Set
end

local function __TS__ArrayFind(self, predicate, thisArg)
    for i = 1, #self do
        local elem = self[i]
        if predicate(thisArg, elem, i - 1, self) then
            return elem
        end
    end
    return nil
end

local function __TS__ArrayFindIndex(self, callbackFn, thisArg)
    for i = 1, #self do
        if callbackFn(thisArg, self[i], i - 1, self) then
            return i - 1
        end
    end
    return -1
end

local function __TS__StringAccess(self, index)
    if index >= 0 and index < #self then
        return string.sub(self, index + 1, index + 1)
    end
end

local function __TS__ArrayIndexOf(self, searchElement, fromIndex)
    if fromIndex == nil then
        fromIndex = 0
    end
    local len = #self
    if len == 0 then
        return -1
    end
    if fromIndex >= len then
        return -1
    end
    if fromIndex < 0 then
        fromIndex = len + fromIndex
        if fromIndex < 0 then
            fromIndex = 0
        end
    end
    for i = fromIndex + 1, len do
        if self[i] == searchElement then
            return i - 1
        end
    end
    return -1
end

local function __TS__ArraySort(self, compareFn)
    if compareFn ~= nil then
        table.sort(
            self,
            function(a, b) return compareFn(nil, a, b) < 0 end
        )
    else
        table.sort(self)
    end
    return self
end

local function __TS__StringIncludes(self, searchString, position)
    if not position then
        position = 1
    else
        position = position + 1
    end
    local index = string.find(self, searchString, position, true)
    return index ~= nil
end

local function __TS__ClassExtends(target, base)
    target.____super = base
    local staticMetatable = setmetatable({__index = base}, base)
    setmetatable(target, staticMetatable)
    local baseMetatable = getmetatable(base)
    if baseMetatable then
        if type(baseMetatable.__index) == "function" then
            staticMetatable.__index = baseMetatable.__index
        end
        if type(baseMetatable.__newindex) == "function" then
            staticMetatable.__newindex = baseMetatable.__newindex
        end
    end
    setmetatable(target.prototype, base.prototype)
    if type(base.prototype.__index) == "function" then
        target.prototype.__index = base.prototype.__index
    end
    if type(base.prototype.__newindex) == "function" then
        target.prototype.__newindex = base.prototype.__newindex
    end
    if type(base.prototype.__tostring) == "function" then
        target.prototype.__tostring = base.prototype.__tostring
    end
end

local Error, RangeError, ReferenceError, SyntaxError, TypeError, URIError
do
    local function getErrorStack(self, constructor)
        if debug == nil then
            return nil
        end
        local level = 1
        while true do
            local info = debug.getinfo(level, "f")
            level = level + 1
            if not info then
                level = 1
                break
            elseif info.func == constructor then
                break
            end
        end
        if __TS__StringIncludes(_VERSION, "Lua 5.0") then
            return debug.traceback(("[Level " .. tostring(level)) .. "]")
        elseif _VERSION == "Lua 5.1" then
            return string.sub(
                debug.traceback("", level),
                2
            )
        else
            return debug.traceback(nil, level)
        end
    end
    local function wrapErrorToString(self, getDescription)
        return function(self)
            local description = getDescription(self)
            local caller = debug.getinfo(3, "f")
            local isClassicLua = __TS__StringIncludes(_VERSION, "Lua 5.0")
            if isClassicLua or caller and caller.func ~= error then
                return description
            else
                return (description .. "\n") .. tostring(self.stack)
            end
        end
    end
    local function initErrorClass(self, Type, name)
        Type.name = name
        return setmetatable(
            Type,
            {__call = function(____, _self, message) return __TS__New(Type, message) end}
        )
    end
    local ____initErrorClass_1 = initErrorClass
    local ____class_0 = __TS__Class()
    ____class_0.name = ""
    function ____class_0.prototype.____constructor(self, message)
        if message == nil then
            message = ""
        end
        self.message = message
        self.name = "Error"
        self.stack = getErrorStack(nil, __TS__New)
        local metatable = getmetatable(self)
        if metatable and not metatable.__errorToStringPatched then
            metatable.__errorToStringPatched = true
            metatable.__tostring = wrapErrorToString(nil, metatable.__tostring)
        end
    end
    function ____class_0.prototype.__tostring(self)
        return self.message ~= "" and (self.name .. ": ") .. self.message or self.name
    end
    Error = ____initErrorClass_1(nil, ____class_0, "Error")
    local function createErrorClass(self, name)
        local ____initErrorClass_3 = initErrorClass
        local ____class_2 = __TS__Class()
        ____class_2.name = ____class_2.name
        __TS__ClassExtends(____class_2, Error)
        function ____class_2.prototype.____constructor(self, ...)
            ____class_2.____super.prototype.____constructor(self, ...)
            self.name = name
        end
        return ____initErrorClass_3(nil, ____class_2, name)
    end
    RangeError = createErrorClass(nil, "RangeError")
    ReferenceError = createErrorClass(nil, "ReferenceError")
    SyntaxError = createErrorClass(nil, "SyntaxError")
    TypeError = createErrorClass(nil, "TypeError")
    URIError = createErrorClass(nil, "URIError")
end

local function __TS__ObjectGetOwnPropertyDescriptors(object)
    local metatable = getmetatable(object)
    if not metatable then
        return {}
    end
    return rawget(metatable, "_descriptors") or ({})
end

local function __TS__Delete(target, key)
    local descriptors = __TS__ObjectGetOwnPropertyDescriptors(target)
    local descriptor = descriptors[key]
    if descriptor then
        if not descriptor.configurable then
            error(
                __TS__New(
                    TypeError,
                    ((("Cannot delete property " .. tostring(key)) .. " of ") .. tostring(target)) .. "."
                ),
                0
            )
        end
        descriptors[key] = nil
        return true
    end
    target[key] = nil
    return true
end
-- End of Lua Library inline imports
local ____exports = {}
local findInPop
function findInPop(self, pop, slot, itemId)
    local items = pop[slot]
    if items ~= nil then
        for ____, i in ipairs(items) do
            if i.item_id == itemId then
                return i
            end
        end
    end
    return nil
end
____exports.SECONDARY_STATS = {"crit", "haste", "mastery", "versatility"}
local WEIGHT_GEAR = 0.4
local WEIGHT_STAT = 0.25
local WEIGHT_ENCHANT = 0.15
local WEIGHT_TALENT = 0.2
--- 스탯 배분 편차 + 총량 부족 페널티 → 0~100 점수. diagnosis.ts calcStatScore와 동일.
function ____exports.calcStatScore(self, myStats, metaAvgStats, statAliases)
    local myMap = {}
    for ____, s in ipairs(myStats) do
        myMap[s.stat_name] = s.stat_value
    end
    local myResolved = {}
    local metaResolved = {}
    for ____, ____value in ipairs(__TS__ObjectEntries(statAliases)) do
        local koName = ____value[1]
        local aliases = ____value[2]
        for ____, alias in ipairs(aliases) do
            if myMap[alias] ~= nil then
                myResolved[koName] = myMap[alias]
                break
            end
        end
        if myResolved[koName] == nil then
            myResolved[koName] = 0
        end
        for ____, alias in ipairs(aliases) do
            if metaAvgStats[alias] ~= nil then
                metaResolved[koName] = metaAvgStats[alias]
                break
            end
        end
        if metaResolved[koName] == nil then
            metaResolved[koName] = 0
        end
    end
    local mySum = __TS__ArrayReduce(
        __TS__ObjectValues(myResolved),
        function(____, a, b) return a + b end,
        0
    )
    local metaSum = __TS__ArrayReduce(
        __TS__ObjectValues(metaResolved),
        function(____, a, b) return a + b end,
        0
    )
    local comparisons = {}
    local totalDeviation = 0
    for ____, name in ipairs(__TS__ObjectKeys(statAliases)) do
        local myPct = mySum > 0 and myResolved[name] / mySum * 100 or 0
        local metaPct = metaSum > 0 and metaResolved[name] / metaSum * 100 or 0
        local diff = myPct - metaPct
        totalDeviation = totalDeviation + math.abs(diff)
        comparisons[#comparisons + 1] = {
            name = name,
            myValue = math.floor(myResolved[name] * 100 + 0.5) / 100,
            myPct = math.floor(myPct * 10 + 0.5) / 10,
            metaValue = math.floor(metaResolved[name] * 100 + 0.5) / 100,
            metaPct = math.floor(metaPct * 10 + 0.5) / 10,
            diff = math.floor(diff * 10 + 0.5) / 10
        }
    end
    local distributionScore = 100 - totalDeviation / 2 * 1.5
    local TOTAL_GRACE = 0.2
    local totalPenalty = 0
    if metaSum > 0 then
        local deficit = math.max(0, 1 - mySum / metaSum)
        totalPenalty = 100 * (math.max(0, deficit - TOTAL_GRACE) / (1 - TOTAL_GRACE)) ^ 1.5
    end
    local score = math.max(
        0,
        math.floor(distributionScore - totalPenalty + 0.5)
    )
    return {score = score, stats = comparisons}
end
local COSMETIC = {SHIRT = true, TABARD = true}
local PAIRED = {FINGER_1 = "FINGER_2", FINGER_2 = "FINGER_1", TRINKET_1 = "TRINKET_2", TRINKET_2 = "TRINKET_1"}
--- 슬롯별 착용 아이템이 메타 top5에 있으면 매칭. diagnosis.ts calcGearScore와 동일 로직.
function ____exports.calcGearScore(self, equipment, popularItems)
    local slots = {}
    local totalPoints = 0
    local maxPoints = 0
    local equippedBySlot = {}
    for ____, eq in ipairs(equipment) do
        equippedBySlot[string.upper(eq.slot)] = eq.item_id
    end
    local recommendedBySlot = {}
    for ____, eq in ipairs(equipment) do
        local slotKey = string.upper(eq.slot)
        if not COSMETIC[slotKey] then
            local dbSlot = table.concat(
                __TS__StringSplit(
                    string.lower(eq.slot),
                    "_"
                ),
                ""
            )
            local metaList = popularItems[slotKey] or popularItems[eq.slot] or popularItems[dbSlot] or ({})
            local pairedSlot = PAIRED[slotKey]
            local excludeIds = __TS__New(Set)
            if pairedSlot ~= nil then
                if equippedBySlot[pairedSlot] ~= nil then
                    excludeIds:add(equippedBySlot[pairedSlot])
                end
                if recommendedBySlot[pairedSlot] ~= nil then
                    excludeIds:add(recommendedBySlot[pairedSlot])
                end
            end
            local ____temp_0
            if excludeIds.size > 0 then
                ____temp_0 = __TS__ArrayFind(
                    metaList,
                    function(____, m) return not excludeIds:has(m.item_id) end
                )
            else
                ____temp_0 = metaList[1]
            end
            local metaTop = ____temp_0 or nil
            if metaTop ~= nil and pairedSlot ~= nil then
                recommendedBySlot[slotKey] = metaTop.item_id
            end
            local wornVk = eq.worn_variant_key or nil
            local rank = wornVk ~= nil and __TS__ArrayFindIndex(
                metaList,
                function(____, m) return m.variant_key == wornVk end
            ) or -1
            if rank < 0 then
                rank = __TS__ArrayFindIndex(
                    metaList,
                    function(____, m) return m.item_id == eq.item_id end
                )
            end
            local metaRank = rank >= 0 and rank + 1 or nil
            local isMatch = metaRank ~= nil and metaRank <= 5
            if isMatch then
                totalPoints = totalPoints + 1
            end
            maxPoints = maxPoints + 1
            slots[#slots + 1] = {
                slot = slotKey,
                myItemId = eq.item_id,
                myItemName = eq.item_name,
                myItemLevel = eq.item_level,
                myIconUrl = eq.icon_url,
                metaRank = metaRank,
                metaTop = metaTop,
                matched = isMatch
            }
        end
    end
    local score = maxPoints > 0 and math.floor(totalPoints / maxPoints * 100 + 0.5) or 0
    return {score = score, slots = slots}
end
--- 스탯 비율 L1 거리(가중). gear-shared.ts calcWeightedDistance와 동일. total 0이면 999.
function ____exports.calcWeightedDistance(self, ratings, metaRatings, weights)
    local myTotal = 0
    local metaTotal = 0
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        myTotal = myTotal + (ratings[k] or 0)
        metaTotal = metaTotal + (metaRatings[k] or 0)
    end
    if myTotal == 0 or metaTotal == 0 then
        return 999
    end
    local dist = 0
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        local myPct = (ratings[k] or 0) / myTotal * 100
        local metaPct = (metaRatings[k] or 0) / metaTotal * 100
        dist = dist + (weights[k] or 1) * math.abs(myPct - metaPct)
    end
    return dist
end
function ____exports.toGrade(self, score)
    if score >= 90 then
        return "S"
    end
    if score >= 75 then
        return "A"
    end
    if score >= 60 then
        return "B"
    end
    if score >= 45 then
        return "C"
    end
    return "D"
end
function ____exports.calcOverall(self, gearScore, statScore, enchantScore, talentScore)
    local overallScore = math.floor(gearScore * WEIGHT_GEAR + statScore * WEIGHT_STAT + enchantScore * WEIGHT_ENCHANT + talentScore * WEIGHT_TALENT + 0.5)
    return {
        overallScore = overallScore,
        grade = ____exports.toGrade(nil, overallScore)
    }
end
--- 두 바이트 배열의 비트 일치율 (0~1). XOR popcount. diagnosis.ts talentBitSimilarity와 동일.
function ____exports.bitSimilarity(self, a, b)
    local len = math.min(#a, #b)
    if len == 0 then
        return 0
    end
    local matchingBits = 0
    local totalBits = len * 8
    do
        local i = 0
        while i < len do
            local xor = bit.bxor(a[i + 1], b[i + 1])
            local diff = xor
            local setBits = 0
            while diff ~= 0 do
                setBits = setBits + 1
                diff = bit.band(diff, diff - 1)
            end
            matchingBits = matchingBits + (8 - setBits)
            i = i + 1
        end
    end
    return matchingBits / totalBits
end
local function charSimilarity(self, a, b)
    local len = math.min(#a, #b)
    local m = 0
    do
        local i = 0
        while i < len do
            if __TS__StringAccess(a, i) == __TS__StringAccess(b, i) then
                m = m + 1
            end
            i = i + 1
        end
    end
    return len > 0 and m / len or 0
end
--- 특성 유사도. myCode/build.code는 원본 base64 문자열(정확 일치 판정용),
-- myBytes/build.bytes는 입력층에서 디코딩한 바이트(비트 유사도용, 실패 시 null → 문자 비교 폴백).
function ____exports.calcTalentScore(self, myCode, myBytes, metaBuilds)
    if myCode == nil or #myCode == 0 or #metaBuilds == 0 then
        return {score = 0, matchPct = 0}
    end
    for ____, m in ipairs(metaBuilds) do
        if m.code == myCode then
            return {score = 100, matchPct = 100}
        end
    end
    local bestSim = 0
    for ____, meta in ipairs(metaBuilds) do
        local sim = myBytes ~= nil and meta.bytes ~= nil and ____exports.bitSimilarity(nil, myBytes, meta.bytes) or charSimilarity(nil, myCode, meta.code)
        if sim > bestSim then
            bestSim = sim
        end
    end
    local matchPct = math.floor(bestSim * 100 + 0.5)
    return {score = matchPct, matchPct = matchPct}
end
function ____exports.gradeColor(self, grade)
    repeat
        local ____switch65 = grade
        local ____cond65 = ____switch65 == "S"
        if ____cond65 then
            return "#ff8000"
        end
        ____cond65 = ____cond65 or ____switch65 == "A"
        if ____cond65 then
            return "#a335ee"
        end
        ____cond65 = ____cond65 or ____switch65 == "B"
        if ____cond65 then
            return "#0070dd"
        end
        ____cond65 = ____cond65 or ____switch65 == "C"
        if ____cond65 then
            return "#1eff00"
        end
        ____cond65 = ____cond65 or ____switch65 == "D"
        if ____cond65 then
            return "#9d9d9d"
        end
    until true
end
local SIM_SLOT_ORDER = {
    "HEAD",
    "NECK",
    "SHOULDER",
    "BACK",
    "CHEST",
    "WRIST",
    "HANDS",
    "WAIST",
    "LEGS",
    "FEET",
    "FINGER_1",
    "FINGER_2",
    "TRINKET_1",
    "TRINKET_2",
    "MAIN_HAND",
    "OFF_HAND"
}
local SIM_SKIP = {SHIRT = true, TABARD = true}
local SIM_WEAPON = {MAIN_HAND = true, OFF_HAND = true}
local SIM_TRINKET = {TRINKET_1 = true, TRINKET_2 = true}
local SIM_EXHAUSTIVE_CAP = 20000
local SIM_PRIORITY_ILVL_TOLERANCE = 10
local function applySlotChangeR(self, sim, cur, next)
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        sim[k] = (sim[k] or 0) - (cur[k] or 0) + (next[k] or 0)
    end
end
local function trialDistanceR(self, sim, cur, next, meta, w)
    local trial = {}
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        trial[k] = sim[k] or 0
    end
    applySlotChangeR(nil, trial, cur, next)
    return ____exports.calcWeightedDistance(nil, trial, meta, w)
end
local function findTierSetNameC(self, pop)
    local setCounts = {}
    for ____, slot in ipairs(SIM_SLOT_ORDER) do
        local items = pop[slot]
        if items ~= nil and #items > 0 and not SIM_WEAPON[slot] and not SIM_TRINKET[slot] and not SIM_SKIP[slot] then
            local name = items[1].set_name
            if name ~= nil and name ~= "" then
                setCounts[name] = (setCounts[name] or 0) + 1
            end
        end
    end
    local best = nil
    local bestCount = 1
    for ____, name in ipairs(__TS__ObjectKeys(setCounts)) do
        if setCounts[name] > bestCount then
            best = name
            bestCount = setCounts[name]
        end
    end
    return best
end
local function sameSecondaryStats(self, a, b)
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        if (a[k] or 0) ~= (b[k] or 0) then
            return false
        end
    end
    return true
end
local function sameAsEquipped(self, eq, cand, ownedMode)
    if eq == nil or eq.item_id ~= cand.item_id then
        return false
    end
    if not ownedMode then
        return true
    end
    if (cand.item_level or 0) ~= eq.item_level then
        return false
    end
    return sameSecondaryStats(nil, eq.stats, cand.stats)
end
local function dominatedByEquipped(self, eq, cand)
    if eq == nil then
        return false
    end
    if (cand.item_level or 0) > eq.item_level then
        return false
    end
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        if (cand.stats[k] or 0) > (eq.stats[k] or 0) then
            return false
        end
    end
    return true
end
local function mergeTrinketListsC(self, pop)
    local merged = {}
    local seen = {}
    local list1 = pop.TRINKET_1 or ({})
    local list2 = pop.TRINKET_2 or ({})
    local maxLen = #list1 > #list2 and #list1 or #list2
    do
        local i = 0
        while i < maxLen do
            if i < #list1 and seen[list1[i + 1].item_id] ~= true then
                seen[list1[i + 1].item_id] = true
                merged[#merged + 1] = list1[i + 1]
            end
            if i < #list2 and seen[list2[i + 1].item_id] ~= true then
                seen[list2[i + 1].item_id] = true
                merged[#merged + 1] = list2[i + 1]
            end
            i = i + 1
        end
    end
    return merged
end
function ____exports.simulateGearSetCore(self, equipment, popularItems, metaAvgStats, preparedGems, myStats, opts)
    local pop = popularItems
    local ownedMode = opts ~= nil and opts.ownedMode == true
    local priTol = opts ~= nil and opts.priorityIlvlTolerance ~= nil and opts.priorityIlvlTolerance or SIM_PRIORITY_ILVL_TOLERANCE
    local weaponTol = opts ~= nil and opts.weaponIlvlTolerance ~= nil and opts.weaponIlvlTolerance or SIM_PRIORITY_ILVL_TOLERANCE
    local metaRatings = {}
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        metaRatings[k] = metaAvgStats[k .. "_rating"] or metaAvgStats[k] or 0
    end
    local ratingTotal = 0
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        ratingTotal = ratingTotal + (metaRatings[k] or 0)
    end
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        if ratingTotal > 0 and (metaRatings[k] or 0) / ratingTotal < 0.01 then
            metaRatings[k] = 0
        end
    end
    local ratingTotalClean = 0
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        ratingTotalClean = ratingTotalClean + (metaRatings[k] or 0)
    end
    local ratingAvg = ratingTotalClean / 4
    local weights = {}
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        weights[k] = ratingAvg > 0 and (metaRatings[k] or 0) / ratingAvg or 1
    end
    local currentStatsBySlot = {}
    local equipBySlot = {}
    for ____, eq in ipairs(equipment) do
        equipBySlot[eq.slot] = eq
        local combined = {}
        for ____, k in ipairs(____exports.SECONDARY_STATS) do
            combined[k] = (eq.stats[k] or 0) + (eq.gem_stats[k] or 0)
        end
        currentStatsBySlot[eq.slot] = combined
    end
    local actualTotalRatings = {}
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        local s = 0
        for ____, slot in ipairs(SIM_SLOT_ORDER) do
            local st = currentStatsBySlot[slot]
            if st ~= nil then
                s = s + (st[k] or 0)
            end
        end
        actualTotalRatings[k] = s
    end
    local originalDistance = ____exports.calcWeightedDistance(nil, actualTotalRatings, metaRatings, weights)
    local slotRecommendations = {}
    local slotPicks = {}
    local simRatings = {}
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        simRatings[k] = actualTotalRatings[k] or 0
    end
    local selectedIds = {}
    local function pickWeapon(____, wSlot)
        local candidates = pop[wSlot] or ({})
        local best = nil
        for ____, c in ipairs(candidates) do
            if not selectedIds[c.item_id] then
                if best == nil or (c.item_level or 0) > (best.item_level or 0) then
                    best = c
                end
            end
        end
        return best
    end
    local tierSetName = findTierSetNameC(nil, pop)
    local lockedPairSlot = {}
    local function isPairSetName(____, name)
        return name ~= nil and name ~= "" and name ~= tierSetName
    end
    for ____, wSlot in ipairs({"MAIN_HAND", "OFF_HAND"}) do
        local w = equipBySlot[wSlot]
        if w ~= nil and isPairSetName(nil, w.set_name) then
            for ____, tSlot in ipairs({"TRINKET_1", "TRINKET_2"}) do
                local t = equipBySlot[tSlot]
                if t ~= nil and t.set_name == w.set_name then
                    lockedPairSlot[wSlot] = true
                    lockedPairSlot[tSlot] = true
                    slotRecommendations[wSlot] = nil
                    slotRecommendations[tSlot] = nil
                    selectedIds[w.item_id] = true
                    selectedIds[t.item_id] = true
                end
            end
        end
    end
    local trinketMerged = mergeTrinketListsC(nil, pop)
    local function trinketRankOf(____, itemId)
        do
            local i = 0
            while i < #trinketMerged do
                if trinketMerged[i + 1].item_id == itemId then
                    return i
                end
                i = i + 1
            end
        end
        return 9999
    end
    local hasTrinketSlot = equipBySlot.TRINKET_1 ~= nil or equipBySlot.TRINKET_2 ~= nil
    for ____, wSlot in ipairs({"MAIN_HAND", "OFF_HAND"}) do
        local wEq = equipBySlot[wSlot]
        if wEq ~= nil and lockedPairSlot[wSlot] ~= true and hasTrinketSlot then
            local chosenW = nil
            local chosenT = nil
            local tSlotPick = nil
            for ____, w in ipairs(pop[wSlot] or ({})) do
                if chosenW == nil and isPairSetName(nil, w.set_name) and not selectedIds[w.item_id] and w.item_level >= wEq.item_level - weaponTol then
                    local twoHandBlocked = w.is_two_hand and wSlot == "MAIN_HAND" and equipBySlot.OFF_HAND ~= nil
                    if not twoHandBlocked then
                        local t0 = nil
                        for ____, t in ipairs(trinketMerged) do
                            if t0 == nil and t.set_name == w.set_name and not selectedIds[t.item_id] then
                                t0 = t
                            end
                        end
                        if t0 ~= nil then
                            local pick = nil
                            for ____, tSlot in ipairs({"TRINKET_1", "TRINKET_2"}) do
                                local tEq = equipBySlot[tSlot]
                                if pick == nil and tEq ~= nil and tEq.item_id == t0.item_id then
                                    pick = tSlot
                                end
                            end
                            if pick == nil then
                                local worstRank = -1
                                for ____, tSlot in ipairs({"TRINKET_1", "TRINKET_2"}) do
                                    local tEq = equipBySlot[tSlot]
                                    if tEq ~= nil and lockedPairSlot[tSlot] ~= true and t0.item_level >= tEq.item_level - priTol then
                                        local r = trinketRankOf(nil, tEq.item_id)
                                        if r >= worstRank then
                                            worstRank = r
                                            pick = tSlot
                                        end
                                    end
                                end
                            end
                            if pick ~= nil then
                                chosenW = w
                                chosenT = t0
                                tSlotPick = pick
                            end
                        end
                    end
                end
            end
            if chosenW ~= nil and chosenT ~= nil and tSlotPick ~= nil then
                if sameAsEquipped(nil, wEq, chosenW, ownedMode) then
                    slotRecommendations[wSlot] = nil
                else
                    applySlotChangeR(nil, simRatings, currentStatsBySlot[wSlot] or ({}), chosenW.stats)
                    slotRecommendations[wSlot] = chosenW.item_id
                    slotPicks[wSlot] = chosenW
                end
                selectedIds[chosenW.item_id] = true
                lockedPairSlot[wSlot] = true
                local tEq = equipBySlot[tSlotPick]
                if sameAsEquipped(nil, tEq, chosenT, ownedMode) then
                    slotRecommendations[tSlotPick] = nil
                else
                    applySlotChangeR(nil, simRatings, currentStatsBySlot[tSlotPick] or ({}), chosenT.stats)
                    slotRecommendations[tSlotPick] = chosenT.item_id
                    slotPicks[tSlotPick] = chosenT
                end
                selectedIds[chosenT.item_id] = true
                lockedPairSlot[tSlotPick] = true
            end
        end
    end
    local hasOffhand = equipBySlot.OFF_HAND ~= nil
    local metaHasOffhand = #(pop.OFF_HAND or ({})) > 0
    local bestMH = pickWeapon(nil, "MAIN_HAND")
    local recommendOffhand = not hasOffhand and metaHasOffhand and bestMH ~= nil and not bestMH.is_two_hand and lockedPairSlot.MAIN_HAND ~= true
    if recommendOffhand and bestMH ~= nil then
        local cur = equipBySlot.MAIN_HAND
        if sameAsEquipped(nil, cur, bestMH, ownedMode) then
            slotRecommendations.MAIN_HAND = nil
        else
            applySlotChangeR(nil, simRatings, currentStatsBySlot.MAIN_HAND or ({}), bestMH.stats)
            slotRecommendations.MAIN_HAND = bestMH.item_id
            slotPicks.MAIN_HAND = bestMH
        end
        selectedIds[bestMH.item_id] = true
        local bestOH = pickWeapon(nil, "OFF_HAND")
        if bestOH ~= nil then
            applySlotChangeR(nil, simRatings, {}, bestOH.stats)
            slotRecommendations.OFF_HAND = bestOH.item_id
            slotPicks.OFF_HAND = bestOH
            selectedIds[bestOH.item_id] = true
        end
    else
        for ____, wSlot in ipairs({"MAIN_HAND", "OFF_HAND"}) do
            if equipBySlot[wSlot] ~= nil and lockedPairSlot[wSlot] ~= true then
                local best = pickWeapon(nil, wSlot)
                if best ~= nil then
                    local currentEquip = equipBySlot[wSlot]
                    if sameAsEquipped(nil, currentEquip, best, ownedMode) then
                        slotRecommendations[wSlot] = nil
                    else
                        applySlotChangeR(nil, simRatings, currentStatsBySlot[wSlot] or ({}), best.stats)
                        slotRecommendations[wSlot] = best.item_id
                        slotPicks[wSlot] = best
                    end
                    selectedIds[best.item_id] = true
                end
            end
        end
    end
    local trinketSlots = {}
    for ____, tSlot in ipairs({"TRINKET_1", "TRINKET_2"}) do
        local eqT = equipBySlot[tSlot]
        if eqT ~= nil then
            if lockedPairSlot[tSlot] == true or pop[tSlot] == nil then
                selectedIds[eqT.item_id] = true
            else
                trinketSlots[#trinketSlots + 1] = tSlot
            end
        end
    end
    if #trinketSlots > 0 then
        local merged = trinketMerged
        local target = {}
        for ____, c in ipairs(merged) do
            if #target < #trinketSlots and not selectedIds[c.item_id] then
                target[#target + 1] = c
            end
        end
        local assignedTrinket = {}
        local openSlots = {}
        for ____, tSlot in ipairs(trinketSlots) do
            local cur = equipBySlot[tSlot]
            local hit = nil
            for ____, c in ipairs(target) do
                if hit == nil and assignedTrinket[c.item_id] ~= true and cur ~= nil and c.item_id == cur.item_id then
                    hit = c
                end
            end
            if hit ~= nil then
                assignedTrinket[hit.item_id] = true
                if sameAsEquipped(nil, cur, hit, ownedMode) then
                    slotRecommendations[tSlot] = nil
                else
                    applySlotChangeR(nil, simRatings, currentStatsBySlot[tSlot] or ({}), hit.stats)
                    slotRecommendations[tSlot] = hit.item_id
                    slotPicks[tSlot] = hit
                end
                selectedIds[hit.item_id] = true
            else
                openSlots[#openSlots + 1] = tSlot
            end
        end
        for ____, tSlot in ipairs(openSlots) do
            local next = nil
            for ____, c in ipairs(target) do
                if next == nil and assignedTrinket[c.item_id] ~= true then
                    next = c
                end
            end
            if next ~= nil then
                assignedTrinket[next.item_id] = true
                applySlotChangeR(nil, simRatings, currentStatsBySlot[tSlot] or ({}), next.stats)
                slotRecommendations[tSlot] = next.item_id
                slotPicks[tSlot] = next
                selectedIds[next.item_id] = true
            end
        end
    end
    local tierSlots = {}
    local tierItemBySlot = {}
    if tierSetName ~= nil then
        for ____, slot in ipairs(SIM_SLOT_ORDER) do
            local items = pop[slot]
            if items ~= nil and not SIM_SKIP[slot] and not SIM_WEAPON[slot] and not SIM_TRINKET[slot] then
                local tierItem = nil
                for ____, i in ipairs(items) do
                    if tierItem == nil and i.set_name == tierSetName then
                        tierItem = i
                    end
                end
                if tierItem ~= nil then
                    tierSlots[#tierSlots + 1] = slot
                    tierItemBySlot[slot] = tierItem
                end
            end
        end
    end
    local equippedTierCount = 0
    for ____, slot in ipairs(tierSlots) do
        local eq = equipBySlot[slot]
        if eq ~= nil and eq.item_id == tierItemBySlot[slot].item_id then
            equippedTierCount = equippedTierCount + 1
        end
    end
    local placedTierSlots = {}
    local actualTierSlots = {}
    local openTierSlot = {}
    for ____, slot in ipairs(tierSlots) do
        local tierItem = tierItemBySlot[slot]
        local currentEquip = equipBySlot[slot]
        local sameTierId = currentEquip ~= nil and currentEquip.item_id == tierItem.item_id
        if sameTierId and sameAsEquipped(nil, currentEquip, tierItem, ownedMode) then
            slotRecommendations[slot] = nil
            actualTierSlots[#actualTierSlots + 1] = slot
            selectedIds[tierItem.item_id] = true
        elseif sameTierId and currentEquip ~= nil and tierItem.item_level > currentEquip.item_level then
            applySlotChangeR(nil, simRatings, currentStatsBySlot[slot] or ({}), tierItem.stats)
            slotRecommendations[slot] = tierItem.item_id
            slotPicks[slot] = tierItem
            actualTierSlots[#actualTierSlots + 1] = slot
            selectedIds[tierItem.item_id] = true
        elseif sameTierId then
            actualTierSlots[#actualTierSlots + 1] = slot
            openTierSlot[slot] = true
        elseif equippedTierCount >= 4 then
        else
            applySlotChangeR(nil, simRatings, currentStatsBySlot[slot] or ({}), tierItem.stats)
            slotRecommendations[slot] = tierItem.item_id
            slotPicks[slot] = tierItem
            placedTierSlots[#placedTierSlots + 1] = slot
            actualTierSlots[#actualTierSlots + 1] = slot
            selectedIds[tierItem.item_id] = true
            equippedTierCount = equippedTierCount + 1
        end
    end
    local surplusTier = equippedTierCount - 4
    local wornTierSlotSet = {}
    for ____, slot in ipairs(tierSlots) do
        local eq = equipBySlot[slot]
        if eq ~= nil and eq.item_id == tierItemBySlot[slot].item_id then
            wornTierSlotSet[slot] = true
        end
    end
    local tierSlotSet = {}
    for ____, s in ipairs(actualTierSlots) do
        tierSlotSet[s] = true
    end
    local prioritySlotSet = {}
    for ____, slot in ipairs(SIM_SLOT_ORDER) do
        local eq = equipBySlot[slot]
        local openTierCopySlot = openTierSlot[slot] == true
        if eq ~= nil and not SIM_WEAPON[slot] and not SIM_SKIP[slot] and not SIM_TRINKET[slot] and (openTierCopySlot or wornTierSlotSet[slot] ~= true and tierSlotSet[slot] ~= true) and slotRecommendations[slot] == nil then
            local ____openTierCopySlot_3
            if openTierCopySlot then
                local ____opt_1 = tierItemBySlot[slot]
                ____openTierCopySlot_3 = ____opt_1 and ____opt_1.item_id
            else
                ____openTierCopySlot_3 = nil
            end
            local tierIdHere = ____openTierCopySlot_3
            local bestPri = nil
            local bestOtherIlvl = 0
            for ____, c in ipairs(pop[slot] or ({})) do
                if tierIdHere == nil or c.item_id == tierIdHere then
                    if c.is_priority == true then
                        if not selectedIds[c.item_id] and (bestPri == nil or c.item_level > bestPri.item_level) then
                            bestPri = c
                        end
                    elseif c.item_level > bestOtherIlvl then
                        bestOtherIlvl = c.item_level
                    end
                end
            end
            if eq.is_priority == true then
                if bestPri ~= nil and bestPri.item_id == eq.item_id and not sameAsEquipped(nil, eq, bestPri, ownedMode) then
                    applySlotChangeR(nil, simRatings, currentStatsBySlot[slot] or ({}), bestPri.stats)
                    slotRecommendations[slot] = bestPri.item_id
                    slotPicks[slot] = bestPri
                    selectedIds[bestPri.item_id] = true
                    prioritySlotSet[slot] = true
                elseif bestOtherIlvl <= eq.item_level + priTol then
                    slotRecommendations[slot] = nil
                    prioritySlotSet[slot] = true
                    if bestPri ~= nil and bestPri.item_id == eq.item_id then
                        selectedIds[bestPri.item_id] = true
                    end
                end
            elseif bestPri ~= nil and bestPri.item_level >= eq.item_level - priTol then
                applySlotChangeR(nil, simRatings, currentStatsBySlot[slot] or ({}), bestPri.stats)
                slotRecommendations[slot] = bestPri.item_id
                slotPicks[slot] = bestPri
                selectedIds[bestPri.item_id] = true
                prioritySlotSet[slot] = true
            end
        end
    end
    local remainingSlots = {}
    for ____, s in ipairs(SIM_SLOT_ORDER) do
        if currentStatsBySlot[s] ~= nil and not SIM_WEAPON[s] and not SIM_SKIP[s] and not SIM_TRINKET[s] and prioritySlotSet[s] ~= true and (not tierSlotSet[s] or openTierSlot[s] == true or surplusTier > 0 and wornTierSlotSet[s] == true) then
            remainingSlots[#remainingSlots + 1] = s
        end
    end
    local processed = {}
    local equippedSlotByItemId = {}
    for ____, s in ipairs(SIM_SLOT_ORDER) do
        local eq = equipBySlot[s]
        if eq ~= nil then
            equippedSlotByItemId[eq.item_id] = s
        end
    end
    local embellishCount = 0
    for ____, slot in ipairs(SIM_SLOT_ORDER) do
        local eq = equipBySlot[slot]
        if eq ~= nil and not SIM_SKIP[slot] then
            local rec = slotRecommendations[slot]
            if rec == nil then
                if eq.is_embellished then
                    embellishCount = embellishCount + 1
                end
            elseif rec == nil then
                if eq.is_embellished then
                    embellishCount = embellishCount + 1
                end
            else
                local recItem = findInPop(nil, pop, slot, rec)
                if recItem ~= nil and recItem.is_embellished then
                    embellishCount = embellishCount + 1
                end
            end
        end
    end
    local choiceBySlot = {}
    local comboCount = 1
    for ____, slot in ipairs(remainingSlots) do
        local list = {}
        local eqHere = equipBySlot[slot]
        for ____, candidate in ipairs(pop[slot] or ({})) do
            local ok = not selectedIds[candidate.item_id]
            if ok and sameAsEquipped(nil, eqHere, candidate, ownedMode) then
                ok = false
            end
            if ok and dominatedByEquipped(nil, eqHere, candidate) then
                ok = false
            end
            if ok then
                local wornInSlot = equippedSlotByItemId[candidate.item_id]
                if wornInSlot ~= nil and wornInSlot ~= slot then
                    ok = false
                end
            end
            if ok then
                local candSecTotal = 0
                local wasteRating = 0
                for ____, k in ipairs(____exports.SECONDARY_STATS) do
                    candSecTotal = candSecTotal + (candidate.stats[k] or 0)
                    if metaRatings[k] == 0 then
                        wasteRating = wasteRating + (candidate.stats[k] or 0)
                    end
                end
                if candSecTotal > 0 and wasteRating / candSecTotal > 0.15 then
                    ok = false
                end
            end
            if ok then
                list[#list + 1] = candidate
            end
        end
        choiceBySlot[slot] = list
        comboCount = comboCount * (#list + 1)
    end
    local useExhaustive = comboCount <= SIM_EXHAUSTIVE_CAP
    if useExhaustive then
        local n = #remainingSlots
        local pick = {}
        local bestPick = {}
        local used = {}
        local bestD = ____exports.calcWeightedDistance(nil, simRatings, metaRatings, weights)
        local function evalLeaf()
            local trial = {}
            for ____, k in ipairs(____exports.SECONDARY_STATS) do
                trial[k] = simRatings[k] or 0
            end
            for ____, s in ipairs(remainingSlots) do
                local c = pick[s]
                if c ~= nil then
                    applySlotChangeR(nil, trial, currentStatsBySlot[s] or ({}), c.stats)
                end
            end
            local d = ____exports.calcWeightedDistance(nil, trial, metaRatings, weights)
            if d < bestD then
                bestD = d
                for ____, s in ipairs(remainingSlots) do
                    bestPick[s] = pick[s] or nil
                end
            end
        end
        local dfs
        dfs = function(____, i, emb, surplusLeft)
            if i >= n then
                evalLeaf(nil)
                return
            end
            local slot = remainingSlots[i + 1]
            pick[slot] = nil
            dfs(nil, i + 1, emb, surplusLeft)
            local eqHere = equipBySlot[slot]
            local curEmb = eqHere ~= nil and eqHere.is_embellished and 1 or 0
            for ____, candidate in ipairs(choiceBySlot[slot]) do
                local ok = used[candidate.item_id] ~= true
                local candEmb = candidate.is_embellished and 1 or 0
                if ok and emb + candEmb - curEmb > 2 then
                    ok = false
                end
                if ok and curEmb == 1 and candEmb == 0 then
                    ok = false
                end
                local consume = 0
                if ok and wornTierSlotSet[slot] == true and candidate.set_name ~= tierSetName then
                    if surplusLeft <= 0 then
                        ok = false
                    else
                        consume = 1
                    end
                end
                if ok then
                    used[candidate.item_id] = true
                    pick[slot] = candidate
                    dfs(nil, i + 1, emb + candEmb - curEmb, surplusLeft - consume)
                    pick[slot] = nil
                    used[candidate.item_id] = false
                end
            end
        end
        dfs(nil, 0, embellishCount, surplusTier)
        for ____, slot in ipairs(remainingSlots) do
            local c = bestPick[slot]
            if c ~= nil then
                applySlotChangeR(nil, simRatings, currentStatsBySlot[slot] or ({}), c.stats)
                slotRecommendations[slot] = c.item_id
                slotPicks[slot] = c
                selectedIds[c.item_id] = true
                local eqHere = equipBySlot[slot]
                local curEmb = eqHere ~= nil and eqHere.is_embellished and 1 or 0
                embellishCount = embellishCount + ((c.is_embellished and 1 or 0) - curEmb)
                if wornTierSlotSet[slot] == true and c.set_name ~= tierSetName then
                    surplusTier = surplusTier - 1
                end
            end
        end
    end
    do
        local iter = 0
        while iter < #remainingSlots and not useExhaustive do
            local bestSlot = nil
            local bestCandidate = nil
            local bestDistance = ____exports.calcWeightedDistance(nil, simRatings, metaRatings, weights)
            for ____, slot in ipairs(remainingSlots) do
                if not processed[slot] then
                    local candidates = pop[slot] or ({})
                    local current = currentStatsBySlot[slot] or ({})
                    local currentEquipInSlot = equipBySlot[slot]
                    for ____, candidate in ipairs(candidates) do
                        local ok = not selectedIds[candidate.item_id]
                        if ok then
                            local wornInSlot = equippedSlotByItemId[candidate.item_id]
                            if wornInSlot ~= nil and wornInSlot ~= slot then
                                ok = false
                            end
                        end
                        if ok and dominatedByEquipped(nil, currentEquipInSlot, candidate) then
                            ok = false
                        end
                        if ok then
                            local candStats = candidate.stats
                            local candSecTotal = 0
                            local wasteRating = 0
                            for ____, k in ipairs(____exports.SECONDARY_STATS) do
                                candSecTotal = candSecTotal + (candStats[k] or 0)
                                if metaRatings[k] == 0 then
                                    wasteRating = wasteRating + (candStats[k] or 0)
                                end
                            end
                            if candSecTotal > 0 and wasteRating / candSecTotal > 0.15 then
                                ok = false
                            end
                            if ok then
                                local curEmb = currentEquipInSlot ~= nil and currentEquipInSlot.is_embellished and 1 or 0
                                local candEmb = candidate.is_embellished and 1 or 0
                                if embellishCount + candEmb - curEmb > 2 then
                                    ok = false
                                end
                                if ok and curEmb == 1 and candEmb == 0 then
                                    ok = false
                                end
                                if ok then
                                    local d = trialDistanceR(
                                        nil,
                                        simRatings,
                                        current,
                                        candStats,
                                        metaRatings,
                                        weights
                                    )
                                    if d < bestDistance then
                                        bestDistance = d
                                        bestSlot = slot
                                        bestCandidate = candidate
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if bestSlot == nil or bestCandidate == nil then
                break
            end
            local currentEquip = equipBySlot[bestSlot]
            if sameAsEquipped(nil, currentEquip, bestCandidate, ownedMode) then
                slotRecommendations[bestSlot] = nil
            else
                applySlotChangeR(nil, simRatings, currentStatsBySlot[bestSlot] or ({}), bestCandidate.stats)
                slotRecommendations[bestSlot] = bestCandidate.item_id
                slotPicks[bestSlot] = bestCandidate
                local curEmb = currentEquip ~= nil and currentEquip.is_embellished and 1 or 0
                local candEmb = bestCandidate.is_embellished and 1 or 0
                embellishCount = embellishCount + (candEmb - curEmb)
                if wornTierSlotSet[bestSlot] == true and bestCandidate.set_name ~= tierSetName then
                    surplusTier = surplusTier - 1
                    if surplusTier <= 0 then
                        for ____, s in ipairs(remainingSlots) do
                            if wornTierSlotSet[s] == true and s ~= bestSlot then
                                processed[s] = true
                            end
                        end
                    end
                end
            end
            selectedIds[bestCandidate.item_id] = true
            processed[bestSlot] = true
            iter = iter + 1
        end
    end
    if #placedTierSlots >= 1 and equippedTierCount >= 5 then
        local bestSwapSlot = nil
        local bestSwapItem = nil
        local bestSwapDistance = ____exports.calcWeightedDistance(nil, simRatings, metaRatings, weights)
        for ____, slot in ipairs(placedTierSlots) do
            local tierItem = tierItemBySlot[slot]
            for ____, candidate in ipairs(pop[slot] or ({})) do
                local noSet = candidate.set_name == nil or candidate.set_name == ""
                if noSet and not selectedIds[candidate.item_id] and not dominatedByEquipped(nil, equipBySlot[slot], candidate) then
                    local tierEmb = tierItem.is_embellished and 1 or 0
                    local candEmb = candidate.is_embellished and 1 or 0
                    if embellishCount + candEmb - tierEmb <= 2 then
                        local d = trialDistanceR(
                            nil,
                            simRatings,
                            tierItem.stats,
                            candidate.stats,
                            metaRatings,
                            weights
                        )
                        if d < bestSwapDistance then
                            bestSwapDistance = d
                            bestSwapSlot = slot
                            bestSwapItem = candidate
                        end
                    end
                end
            end
        end
        if bestSwapSlot ~= nil and bestSwapItem ~= nil then
            local tierStats = tierItemBySlot[bestSwapSlot].stats
            local currentEquip = equipBySlot[bestSwapSlot]
            if sameAsEquipped(nil, currentEquip, bestSwapItem, ownedMode) then
                applySlotChangeR(nil, simRatings, tierStats, currentStatsBySlot[bestSwapSlot] or ({}))
                slotRecommendations[bestSwapSlot] = nil
            else
                applySlotChangeR(nil, simRatings, tierStats, bestSwapItem.stats)
                slotRecommendations[bestSwapSlot] = bestSwapItem.item_id
                slotPicks[bestSwapSlot] = bestSwapItem
            end
            selectedIds[bestSwapItem.item_id] = true
        end
    end
    local gearOnlyRatings = {}
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        gearOnlyRatings[k] = simRatings[k] or 0
    end
    local gemRecommendations = {}
    if preparedGems ~= nil then
        for ____, slot in ipairs(SIM_SLOT_ORDER) do
            local gems = preparedGems[slot]
            if gems ~= nil and #gems > 0 then
                local isItemChanged = slotRecommendations[slot] ~= nil
                local oldGemStats = {}
                if not isItemChanged then
                    local eq = equipBySlot[slot]
                    if eq ~= nil then
                        for ____, k in ipairs(____exports.SECONDARY_STATS) do
                            oldGemStats[k] = eq.gem_stats[k] or 0
                        end
                    end
                end
                local bestGemIdx = -1
                local bestDist = ____exports.calcWeightedDistance(nil, simRatings, metaRatings, weights)
                do
                    local gi = 0
                    while gi < #gems do
                        local gs = gems[gi + 1].stats
                        local cnt = 0
                        for ____, k in ipairs(____exports.SECONDARY_STATS) do
                            if gs[k] ~= nil then
                                cnt = cnt + 1
                            end
                        end
                        if cnt > 0 then
                            local trial = {}
                            for ____, k in ipairs(____exports.SECONDARY_STATS) do
                                trial[k] = (simRatings[k] or 0) - (oldGemStats[k] or 0) + (gs[k] or 0)
                            end
                            local d = ____exports.calcWeightedDistance(nil, trial, metaRatings, weights)
                            if d < bestDist then
                                bestDist = d
                                bestGemIdx = gi
                            end
                        end
                        gi = gi + 1
                    end
                end
                if bestGemIdx >= 0 then
                    local gs = gems[bestGemIdx + 1].stats
                    for ____, k in ipairs(____exports.SECONDARY_STATS) do
                        simRatings[k] = (simRatings[k] or 0) - (oldGemStats[k] or 0) + (gs[k] or 0)
                    end
                    gemRecommendations[slot] = bestGemIdx
                end
            end
        end
    end
    local blzPctMap = {}
    local blzSlopeMap = {}
    if myStats ~= nil then
        for ____, s in ipairs(myStats) do
            blzPctMap[s.stat_name] = s.stat_value
            local rt = s.stat_rating
            local rb = s.stat_rating_bonus
            if rt ~= nil and rb ~= nil and rt > 0 and rb > 0 then
                blzSlopeMap[s.stat_name] = rb / rt
            end
        end
    end
    local statRatios = {}
    for ____, k in ipairs(____exports.SECONDARY_STATS) do
        local currentInGamePct = blzPctMap[k] or 0
        local currentPct = math.floor(currentInGamePct * 100 + 0.5) / 100
        local userEquipRating = actualTotalRatings[k] or 0
        local ratingDelta = (simRatings[k] or 0) - userEquipRating
        local metaPctVal = metaAvgStats[k] or 0
        local slopeTrue = blzSlopeMap[k]
        local simPct
        if slopeTrue ~= nil then
            simPct = currentInGamePct + ratingDelta * slopeTrue
        elseif currentInGamePct > 0 and userEquipRating > 0 then
            simPct = currentInGamePct + ratingDelta * (currentInGamePct / userEquipRating)
        else
            simPct = currentInGamePct
        end
        simPct = math.max(
            0,
            math.floor(simPct * 100 + 0.5) / 100
        )
        statRatios[#statRatios + 1] = {
            stat = k,
            currentRating = userEquipRating,
            gearOnlyRating = gearOnlyRatings[k] or 0,
            simRating = simRatings[k] or 0,
            currentPct = currentPct,
            simPct = simPct,
            metaPct = math.floor(metaPctVal * 100 + 0.5) / 100,
            pctPerRating = slopeTrue ~= nil and slopeTrue or nil
        }
    end
    local upgradePriorities = {}
    for ____, slot in ipairs(SIM_SLOT_ORDER) do
        local eq = equipBySlot[slot]
        if eq ~= nil and slotRecommendations[slot] == nil then
            if eq.upgrade_track ~= nil and eq.upgrade_track ~= "" and eq.is_capped ~= true and eq.track_max ~= nil and eq.item_level < eq.track_max then
                local secTotal = 0
                for ____, k in ipairs(____exports.SECONDARY_STATS) do
                    secTotal = secTotal + (eq.stats[k] or 0)
                end
                upgradePriorities[#upgradePriorities + 1] = {
                    slot = slot,
                    itemName = eq.item_name,
                    itemId = eq.item_id,
                    currentIlvl = eq.item_level,
                    maxIlvl = eq.track_max,
                    track = eq.upgrade_track,
                    secondaryTotal = secTotal
                }
            end
        end
    end
    __TS__ArraySort(
        upgradePriorities,
        function(____, a, b)
            local aWeapon = SIM_WEAPON[a.slot] and 1 or 0
            local bWeapon = SIM_WEAPON[b.slot] and 1 or 0
            if aWeapon ~= bWeapon then
                return bWeapon - aWeapon
            end
            if b.secondaryTotal ~= a.secondaryTotal then
                return b.secondaryTotal - a.secondaryTotal
            end
            return __TS__ArrayIndexOf(SIM_SLOT_ORDER, a.slot) - __TS__ArrayIndexOf(SIM_SLOT_ORDER, b.slot)
        end
    )
    for ____, s in ipairs(__TS__ObjectKeys(slotPicks)) do
        local rec = slotRecommendations[s]
        if rec == nil or rec ~= slotPicks[s].item_id then
            __TS__Delete(slotPicks, s)
        end
    end
    return {
        slotRecommendations = slotRecommendations,
        slotPicks = slotPicks,
        gemRecommendations = gemRecommendations,
        finalDistance = math.floor(____exports.calcWeightedDistance(nil, simRatings, metaRatings, weights) * 10 + 0.5) / 10,
        originalDistance = math.floor(originalDistance * 10 + 0.5) / 10,
        statRatios = statRatios,
        upgradePriorities = upgradePriorities
    }
end
local ENCHANTABLE = {
    HEAD = true,
    SHOULDER = true,
    CHEST = true,
    LEGS = true,
    FEET = true,
    FINGER_1 = true,
    FINGER_2 = true,
    MAIN_HAND = true
}
function ____exports.calcEnchantScoreCore(self, equipment, enchantsBySlot)
    local results = {}
    local totalPoints = 0
    local total = 0
    for ____, eq in ipairs(equipment) do
        local slotKey = string.upper(eq.slot)
        if ENCHANTABLE[slotKey] then
            local metaEnchants = enchantsBySlot[slotKey] or ({})
            local metaTop = #metaEnchants > 0 and metaEnchants[1] or nil
            local myEnchant = eq.myEnchant
            local myEnchantEn = eq.myEnchantEn
            local myEnchantId = eq.myEnchantId
            local missing = myEnchantId == nil and myEnchant == nil
            if #metaEnchants == 0 then
                results[#results + 1] = {
                    slot = slotKey,
                    myEnchant = myEnchant,
                    myEnchantEn = myEnchantEn,
                    metaTop = nil,
                    metaTopEn = nil,
                    metaTopEnchantId = nil,
                    metaTopQuality = nil,
                    matched = false,
                    missing = missing
                }
            else
                total = total + 1
                local isRing = (string.find(slotKey, "FINGER", nil, true) or 0) - 1 == 0
                local limit = isRing and math.min(3, #metaEnchants) or #metaEnchants
                local ____temp_4
                if metaTop ~= nil then
                    ____temp_4 = metaTop.quality
                else
                    ____temp_4 = nil
                end
                local topQuality = ____temp_4
                local bestScore = 0
                if not missing then
                    if myEnchantId ~= nil then
                        do
                            local i = 0
                            while i < limit do
                                local me = metaEnchants[i + 1]
                                if me.enchant_id == myEnchantId then
                                    if topQuality ~= nil and me.quality ~= nil and me.quality < topQuality then
                                        if bestScore < 0.7 then
                                            bestScore = 0.7
                                        end
                                    else
                                        bestScore = 1
                                        break
                                    end
                                end
                                i = i + 1
                            end
                        end
                    end
                    if bestScore == 0 and myEnchant ~= nil and myEnchant ~= "" then
                        local myBase = eq.myBase
                        do
                            local i = 0
                            while i < limit do
                                local me = metaEnchants[i + 1]
                                local nameMatch = myBase == me.base or myBase == me.base_en or myEnchant == me.name or myEnchant == me.name_en
                                if nameMatch then
                                    if topQuality ~= nil and me.quality ~= nil and me.quality < topQuality then
                                        if bestScore < 0.7 then
                                            bestScore = 0.7
                                        end
                                    else
                                        bestScore = 1
                                        break
                                    end
                                end
                                i = i + 1
                            end
                        end
                    end
                end
                totalPoints = totalPoints + bestScore
                local ____myEnchant_7 = myEnchant
                local ____myEnchantEn_8 = myEnchantEn
                local ____temp_9 = metaTop ~= nil and (metaTop.name or metaTop.name_en or nil) or nil
                local ____temp_10 = metaTop ~= nil and (metaTop.name_en or metaTop.name) or nil
                local ____temp_5
                if metaTop ~= nil then
                    ____temp_5 = metaTop.enchant_id or nil
                else
                    ____temp_5 = nil
                end
                local ____temp_6
                if metaTop ~= nil then
                    ____temp_6 = metaTop.quality or nil
                else
                    ____temp_6 = nil
                end
                results[#results + 1] = {
                    slot = slotKey,
                    myEnchant = ____myEnchant_7,
                    myEnchantEn = ____myEnchantEn_8,
                    metaTop = ____temp_9,
                    metaTopEn = ____temp_10,
                    metaTopEnchantId = ____temp_5,
                    metaTopQuality = ____temp_6,
                    matched = bestScore > 0,
                    missing = missing
                }
            end
        end
    end
    local score = total > 0 and math.floor(totalPoints / total * 100 + 0.5) or 100
    return {score = score, enchants = results}
end
function ____exports.reselectMetaTopsCore(self, baseSlots, popularItems, excludedRaids, equippedIds)
    local function isRaidExcluded(____, i)
        return i.source_type == "raid" and excludedRaids[i.source_name_en or ""] == true or i.converted_source_type == "raid" and excludedRaids[i.converted_source_name_en or ""] == true
    end
    local function isWornElsewhere(____, i, slotKey)
        if i.item_id == nil then
            return false
        end
        local wornIn = equippedIds[i.item_id]
        return wornIn ~= nil and wornIn ~= slotKey
    end
    local resolved = {}
    local needsReselect = {}
    for ____, slot in ipairs(baseSlots) do
        local mt = slot.metaTop
        if mt ~= nil and (isRaidExcluded(nil, mt) or isWornElsewhere(nil, mt, slot.slot)) then
            needsReselect[#needsReselect + 1] = slot.slot
        else
            resolved[slot.slot] = mt
        end
    end
    for ____, slotKey in ipairs(needsReselect) do
        local pairedSlot = PAIRED[slotKey]
        local ____temp_11
        if pairedSlot ~= nil then
            ____temp_11 = resolved[pairedSlot]
        else
            ____temp_11 = nil
        end
        local pairedResolved = ____temp_11
        local ____temp_12
        if pairedResolved ~= nil then
            ____temp_12 = pairedResolved.item_id
        else
            ____temp_12 = nil
        end
        local pairedId = ____temp_12
        local items = popularItems[slotKey] or ({})
        local found = nil
        for ____, i in ipairs(items) do
            if found == nil and not isRaidExcluded(nil, i) and not isWornElsewhere(nil, i, slotKey) and (pairedId == nil or i.item_id ~= pairedId) then
                found = i
            end
        end
        resolved[slotKey] = found
    end
    return resolved
end
WythicPlusGearCore = ____exports

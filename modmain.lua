-- 资源声明
Assets = {
        -- 抽奖机相关
        Asset("IMAGE", "images/dubloon.tex"),
        Asset("ATLAS", "images/dubloon.xml"),
        Asset("IMAGE", "images/ohcoinrandom.tex"),
        Asset("ATLAS", "images/ohcoinrandom.xml"),
        Asset("IMAGE", "images/ohcoin10.tex"),
        Asset("ATLAS", "images/ohcoin10.xml"),
        Asset("IMAGE", "images/ohcoincursed.tex"),
        Asset("ATLAS", "images/ohcoincursed.xml"),
        Asset("IMAGE", "images/ohcoinlucky.tex"),
        Asset("ATLAS", "images/ohcoinlucky.xml"),
        -- 附魔相关
        Asset("IMAGE", "images/hh_treasure_tally.tex"),  -- 寻宝卷轴
        Asset("ATLAS", "images/hh_treasure_tally.xml"),
        Asset("IMAGE", "images/hh_essence.tex"),  -- 水晶小人
        Asset("ATLAS", "images/hh_essence.xml"),
        Asset("IMAGE", "images/hh_effect_tally.tex"),  -- 附魔卷轴
        Asset("ATLAS", "images/hh_effect_tally.xml"),
        Asset("IMAGE", "images/hh_remove_stone.tex"),  -- 洗蕴石
        Asset("ATLAS", "images/hh_remove_stone.xml"),
        -- 附魔石相关
        Asset("IMAGE", "images/hh_effect_stone.tex"),
        Asset("ATLAS", "images/hh_effect_stone.xml"),
        -- 海钓相关
        Asset("IMAGE", "images/twigs.tex"),
        Asset("ATLAS", "images/twigs.xml"),
        Asset("IMAGE", "images/oceanfishingbobber_ball.tex"),
        Asset("ATLAS", "images/oceanfishingbobber_ball.xml"),
        Asset("IMAGE", "images/oceanfishingbobber_oval.tex"),
        Asset("ATLAS", "images/oceanfishingbobber_oval.xml"),
        Asset("IMAGE", "images/oceanfishingbobber_robin.tex"),
        Asset("ATLAS", "images/oceanfishingbobber_robin.xml"),
        Asset("IMAGE", "images/oceanfishingbobber_canary.tex"),
        Asset("ATLAS", "images/oceanfishingbobber_canary.xml"),
        Asset("IMAGE", "images/oceanfishingbobber_crow.tex"),
        Asset("ATLAS", "images/oceanfishingbobber_crow.xml"),
        Asset("IMAGE", "images/oceanfishingbobber_robin_winter.tex"),
        Asset("ATLAS", "images/oceanfishingbobber_robin_winter.xml"),
        Asset("IMAGE", "images/oceanfishingbobber_goose.tex"),
        Asset("ATLAS", "images/oceanfishingbobber_goose.xml"),
        Asset("IMAGE", "images/oceanfishingbobber_malbatross.tex"),
        Asset("ATLAS", "images/oceanfishingbobber_malbatross.xml"),
        Asset("IMAGE", "images/trinket_8.tex"),
        Asset("ATLAS", "images/trinket_8.xml"),
}

-- 安全获取玩家实例
local function UserToPlayer(userid)
    for i, v in ipairs(GLOBAL.AllPlayers) do
        if v.userid == userid then
            return v
        end
    end
    return nil
end

-- 安全获取范围内的玩家
local function FindPlayersInRange(x, y, z, radius, mustbevalid)
    local players = {}
    for i, v in ipairs(GLOBAL.AllPlayers) do
        if not mustbevalid or v:IsValid() then
            if v:GetDistanceSqToPoint(x, y, z) < radius * radius then
                table.insert(players, v)
            end
        end
    end
    return players
end

-- 获取战斗参与者（用于金币奖励分配）
local function GetCombatParticipants(victim)
    if not victim or not victim:IsValid() then return {} end
    local players = {}
    local victim_pos = victim:GetPosition()
    
    local smu = GLOBAL.TUNING and GLOBAL.TUNING.slotmachineutils or nil
    local is_boss = victim:HasTag("epic") or (smu and smu.isBoss and smu.isBoss(victim))
    
    -- Boss 奖励范围 40，普通怪 20
    local radius = is_boss and 40 or 20
    local potential_players = FindPlayersInRange(victim_pos.x, victim_pos.y, victim_pos.z, radius, true)
    
    for _, player in ipairs(potential_players) do
        local eligible = false
        if is_boss then
            -- Boss 战：只要在范围内就算参与（考虑到辅助、跑位等情况）
            eligible = true
        else
            -- 普通怪物：检查是否正在攻击该生物，或者是否是该生物的攻击者之一
            if player.components.combat and player.components.combat.target == victim then
                eligible = true
            elseif victim.components.combat and victim.components.combat.attackers then
                -- attackers 表中的 key 是实体
                if victim.components.combat.attackers[player] then
                    eligible = true
                end
            end
        end
        
        if eligible then
            table.insert(players, player)
        end
    end
    
    -- 兜底：如果没找到符合条件的参与者（例如陷阱杀、反伤杀），则奖励给 15 码内最近的一个玩家
    if #players == 0 then
        local closest_player = nil
        local min_dist_sq = 15 * 15
        for _, p in ipairs(potential_players) do
            local d_sq = p:GetDistanceSqToPoint(victim_pos)
            if d_sq < min_dist_sq then
                min_dist_sq = d_sq
                closest_player = p
            end
        end
        if closest_player then
            table.insert(players, closest_player)
        end
    end
    
    return players
end

local exchange_enabled = GetModConfigData("dh_enable_exchange") ~= false
local exchange_slotmachine_enabled = exchange_enabled and GetModConfigData("dh_enable_exchange_slotmachine") ~= false
local exchange_enchant_enabled = exchange_enabled and GetModConfigData("dh_enable_exchange_enchant") ~= false
local exchange_bobber_enabled = exchange_enabled and GetModConfigData("dh_enable_exchange_bobber") ~= false
local exchange_ui_enabled = exchange_slotmachine_enabled or exchange_enchant_enabled or exchange_bobber_enabled
local ohmnq_shop_sell_all = GetModConfigData("dh_ohmnq_shop_sell_all") == true
local ohmnq_start_dubloon_enable = GetModConfigData("dh_ohmnq_start_dubloon_enable") == true
local ohmnq_start_dubloon_amount = GetModConfigData("dh_ohmnq_start_dubloon_amount")

if type(ohmnq_start_dubloon_amount) ~= "number" then
        ohmnq_start_dubloon_amount = 0
end
ohmnq_start_dubloon_amount = math.floor(ohmnq_start_dubloon_amount)
if ohmnq_start_dubloon_amount < 0 then
        ohmnq_start_dubloon_amount = 0
end

-- 开局金币
if ohmnq_start_dubloon_enable and ohmnq_start_dubloon_amount > 0 then
        AddPlayerPostInit(function(inst)
                -- 必须在服务器端运行
                if not GLOBAL.TheWorld.ismastersim then
                        return inst
                end
                -- 监听玩家出生
                local oldOnNewSpawn = inst.OnNewSpawn
                inst.OnNewSpawn = function(inst, ...)
                        if oldOnNewSpawn then oldOnNewSpawn(inst, ...) end
                        -- 检查是否是首次出生
                        if GLOBAL.TheWorld.components.playerspawner ~= nil and GLOBAL.TheWorld.components.playerspawner:IsPlayersInitialSpawn(inst) then
                                local prefab = "dubloon"
                                local count = ohmnq_start_dubloon_amount
                                
                                -- 模仿 c_give 的高效发放逻辑
                                local item = GLOBAL.SpawnPrefab(prefab)
                                if item ~= nil then
                                        if item.components.stackable ~= nil then
                                                -- 如果是可堆叠物品，直接设置堆叠数量
                                                item.components.stackable:SetStackSize(count)
                                                -- 放入背包，背包会自动处理超限分堆
                                                inst.components.inventory:GiveItem(item)
                                        else
                                                -- 如果不可堆叠，则只能循环发放
                                                inst.components.inventory:GiveItem(item)
                                                if count > 1 then
                                                        for i = 2, count do
                                                                local extra = GLOBAL.SpawnPrefab(prefab)
                                                                if extra ~= nil then
                                                                        inst.components.inventory:GiveItem(extra)
                                                                end
                                                        end
                                                end
                                        end
                                end
                        end
                end
        end)
end

local dh_shop_price_rate = GetModConfigData("dh_shop_price_rate") or 1.0
local dh_coins_explosion_rate_mult = GetModConfigData("dh_coins_explosion_rate_mult") or 1.0

-- 注入金币爆率倍率逻辑
AddPrefabPostInit("world", function(inst)
    inst:DoTaskInTime(0, function()
        if dh_coins_explosion_rate_mult ~= 1.0 then
            if GLOBAL.TUNING.SLOTMACHINE_MODCONFIGDATA and GLOBAL.TUNING.SLOTMACHINE_MODCONFIGDATA["CoinsExplosionRate"] then
                GLOBAL.TUNING.SLOTMACHINE_MODCONFIGDATA["CoinsExplosionRate"] = GLOBAL.TUNING.SLOTMACHINE_MODCONFIGDATA["CoinsExplosionRate"] * dh_coins_explosion_rate_mult
            end
        end
    end)
end)

-- 注入商店价格倍率逻辑
AddPrefabPostInit("world", function(inst)
    inst:DoTaskInTime(0, function()
        local smu = GLOBAL.TUNING and GLOBAL.TUNING.slotmachineutils or nil
        if not smu then return end

        -- 拦截价格倍率获取函数
        local original_GetShopBuyPriceRate = smu.GetShopBuyPriceRate
        smu.GetShopBuyPriceRate = function(...)
            local base_rate = 1
            if original_GetShopBuyPriceRate then
                base_rate = original_GetShopBuyPriceRate(...)
            end
            -- 将原始倍率与补丁配置的倍率相乘
            return base_rate * dh_shop_price_rate
        end
        
        -- 同时拦截最终价格计算逻辑（双重保险，确保即使原模组有其他折扣，补丁倍率也生效）
        local original_getShopItemFinalPrice = smu.getShopItemFinalPrice
        if original_getShopItemFinalPrice then
            smu.getShopItemFinalPrice = function(itemName, ...)
                local price = original_getShopItemFinalPrice(itemName, ...)
                if price and not smu.IsIgnoreRate(itemName) then
                    -- 注意：这里不再乘 dh_shop_price_rate，因为上面 GetShopBuyPriceRate 已经乘过了
                    -- 如果发现倍率没生效，可以在这里强制干预
                end
                return price
            end
        end
    end)
end)

-- 商店全物品
if ohmnq_shop_sell_all then
        AddPrefabPostInit("world", function(inst)
                inst:DoTaskInTime(0, function()
                        local smu = GLOBAL.TUNING and GLOBAL.TUNING.slotmachineutils or nil
                        if not smu or smu._luckysimulator_patch_sell_all_shop then
                                return
                        end

                        local original_build = smu.buildShopItemConfig
                        smu._luckysimulator_patch_sell_all_shop = true
                        smu.buildShopItemConfig = function(num_items, seed)
                                local lsvu = GLOBAL.TUNING and GLOBAL.TUNING.luckySimulatorVarUtils or nil
                                local procShopConfig = lsvu and lsvu.getProcShopConfig and lsvu.getProcShopConfig() or nil
                                local shopFilters = lsvu and lsvu.getShopFiltersConfig and lsvu.getShopFiltersConfig() or nil
                                if type(procShopConfig) ~= "table" or type(shopFilters) ~= "table" then
                                        if type(original_build) == "function" then
                                                return original_build(num_items, seed)
                                        end
                                        return {}
                                end

                                local shopItemConfig = {}
                                local function addToShopMap(filter, item)
                                        local entry = shopItemConfig[filter]
                                        if entry == nil then
                                                entry = {}
                                                shopItemConfig[filter] = entry
                                        end
                                        entry[#entry + 1] = item
                                end

                                for _, v in pairs(procShopConfig) do
                                        if v then
                                                local filters = v.shopFilter
                                                if type(filters) == "table" and #filters > 0 then
                                                        for _, filter in ipairs(filters) do
                                                                addToShopMap(filter, v)
                                                        end
                                                else
                                                        addToShopMap(shopFilters.OTHER, v)
                                                end
                                                addToShopMap(shopFilters.EVERYTHING, v)
                                        end
                                end

                                for _, entry in pairs(shopItemConfig) do
                                        if type(entry) == "table" and #entry > 0 then
                                                table.sort(entry, function(a, b)
                                                        if a.sortKey and b.sortKey then
                                                                return a.sortKey < b.sortKey
                                                        else
                                                                return a.price < b.price
                                                        end
                                                end)
                                        end
                                end

                                return shopItemConfig
                        end
                end)
        end)
end

coinslist = {}
local exchange_price_by_prefab = {}
local exchange_allowed_prefabs = {}

if exchange_slotmachine_enabled then
        local price_ohcoinrandom = GetModConfigData("dh_ohcoinrandom")
        local price_ohcoin10 = GetModConfigData("dh_ohcoin10")
        local price_ohcoincursed = GetModConfigData("dh_ohcoincursed")
        local price_ohcoinlucky = GetModConfigData("dh_ohcoinlucky")

        coinslist[#coinslist + 1] = { name = "dh_ohcoinrandom", oh_name = "ohcoinrandom", label = "随机币", price = price_ohcoinrandom, row = 1 }
        coinslist[#coinslist + 1] = { name = "dh_ohcoin10", oh_name = "ohcoin10", label = "10倍币", price = price_ohcoin10, row = 1 }
        coinslist[#coinslist + 1] = { name = "dh_ohcoincursed", oh_name = "ohcoincursed", label = "厄运币", price = price_ohcoincursed, row = 1 }
        coinslist[#coinslist + 1] = { name = "dh_ohcoinlucky", oh_name = "ohcoinlucky", label = "幸运币", price = price_ohcoinlucky, row = 1 }

        exchange_price_by_prefab.ohcoinrandom = price_ohcoinrandom
        exchange_price_by_prefab.ohcoin10 = price_ohcoin10
        exchange_price_by_prefab.ohcoincursed = price_ohcoincursed
        exchange_price_by_prefab.ohcoinlucky = price_ohcoinlucky

        exchange_allowed_prefabs.ohcoinrandom = true
        exchange_allowed_prefabs.ohcoin10 = true
        exchange_allowed_prefabs.ohcoincursed = true
        exchange_allowed_prefabs.ohcoinlucky = true
end

if exchange_enchant_enabled then
        local price_hh_treasure_tally = GetModConfigData("dh_hh_treasure_tally")
        local price_hh_essence = GetModConfigData("dh_hh_essence")
        local price_hh_effect_tally = GetModConfigData("dh_hh_effect_tally")
        local price_hh_remove_stone = GetModConfigData("dh_hh_remove_stone")

        coinslist[#coinslist + 1] = { name = "dh_hh_treasure_tally", oh_name = "hh_treasure_tally", label = "藏宝图", price = price_hh_treasure_tally, row = 2 }
        coinslist[#coinslist + 1] = { name = "dh_hh_essence", oh_name = "hh_essence", label = "水晶小人", price = price_hh_essence, row = 2 }
        coinslist[#coinslist + 1] = { name = "dh_hh_effect_tally", oh_name = "hh_effect_tally", label = "附魔卷轴", price = price_hh_effect_tally, row = 2 }
        coinslist[#coinslist + 1] = { name = "dh_hh_remove_stone", oh_name = "hh_remove_stone", label = "洗蕴石", price = price_hh_remove_stone, row = 2 }

        exchange_price_by_prefab.hh_treasure_tally = price_hh_treasure_tally
        exchange_price_by_prefab.hh_essence = price_hh_essence
        exchange_price_by_prefab.hh_effect_tally = price_hh_effect_tally
        exchange_price_by_prefab.hh_remove_stone = price_hh_remove_stone

        exchange_allowed_prefabs.hh_treasure_tally = true
        exchange_allowed_prefabs.hh_essence = true
        exchange_allowed_prefabs.hh_effect_tally = true
        exchange_allowed_prefabs.hh_remove_stone = true
end

if exchange_bobber_enabled then
        local bobber_list = {
                { oh_name = "twigs", label = "树枝", desc = "排除 物品表", cfg = "twigs" },
                { oh_name = "oceanfishingbobber_ball", label = "木球浮标", desc = "排除 事件表", cfg = "ball" },
                { oh_name = "oceanfishingbobber_oval", label = "硬物浮标", desc = "排除 穿戴表", cfg = "oval" },
                { oh_name = "trinket_8", label = "橡胶塞", desc = "双倍钓取", cfg = "trinket_8" },
                { oh_name = "oceanfishingbobber_robin", label = "红羽浮标", desc = "排除 食材表", cfg = "robin" },
                { oh_name = "oceanfishingbobber_canary", label = "黄羽浮标", desc = "排除 种植表", cfg = "canary" },
                { oh_name = "oceanfishingbobber_crow", label = "黑羽浮标", desc = "排除 生物表", cfg = "crow" },
                { oh_name = "oceanfishingbobber_robin_winter", label = "蔚蓝浮标", desc = "排除 建筑表", cfg = "robin_winter" },
                { oh_name = "oceanfishingbobber_goose", label = "鹅羽浮标", desc = "排除 材料表", cfg = "goose" },
                { oh_name = "oceanfishingbobber_malbatross", label = "邪天翁浮标", desc = "排除 巨兽表", cfg = "malbatross" },
        }

        for _, info in ipairs(bobber_list) do
                local price = GetModConfigData("dh_bobber_price_" .. info.cfg) or 10
                coinslist[#coinslist + 1] = { 
                        name = "dh_" .. info.oh_name, 
                        oh_name = info.oh_name, 
                        label = info.label, 
                        price = price, 
                        row = 3,
                        desc = info.desc
                }
                exchange_price_by_prefab[info.oh_name] = price
                exchange_allowed_prefabs[info.oh_name] = true
        end
end

SpawnPrefab = GLOBAL.SpawnPrefab
ThePlayer = GLOBAL.ThePlayer

-- 服务端处理RPC
AddModRPCHandler("buyCoin", "buy", function(player, oh_name, price, count)
        if not exchange_enabled then
                return
        end
        if not exchange_allowed_prefabs[oh_name] then
                return
        end
        if type(count) ~= "number" then
                count = 1
        end
        count = math.floor(count)
        if count < 1 then
                return
        end
        local base_price = exchange_price_by_prefab[oh_name]
        if type(base_price) ~= "number" or base_price < 0 then
                return
        end
        local total_price = base_price * count
        if checkItemExists(player, "dubloon", total_price) then
        	local item = SpawnPrefab(oh_name)
                if item then
                        if item.components and item.components.stackable then
                                item.components.stackable:SetStackSize(count)
                                player.components.inventory:GiveItem(item)
                        else
                                player.components.inventory:GiveItem(item)
                                for i = 2, count do
                                        local extra = SpawnPrefab(oh_name)
                                        if extra then
                                                player.components.inventory:GiveItem(extra)
                                        end
                                end
                        end
        	        player.components.inventory:ConsumeByName("dubloon", total_price)
                end
        end
end)

-- 击杀掉落金币直接存款
local kill_to_deposit_enabled = GetModConfigData("dh_kill_to_deposit") ~= false

if kill_to_deposit_enabled then
    AddComponentPostInit("lootdropper", function(self)
        -- 用于缓存同一帧内拦截到的金币总数
        self._intercepted_count = 0
        self._deposit_batch_task = nil
        
        -- 先定义变量名，确保闭包可以引用到
        local old_FlingItem = nil

        local function queue_intercept(amount)
            self._intercepted_count = self._intercepted_count + amount
            if not self._deposit_batch_task then
                -- 必须在当前帧获取参与者，因为下一帧生物实体可能就被移除了
                local participants = GetCombatParticipants(self.inst)
                local victim_pos = self.inst:GetPosition()

                -- 使用 TheWorld 发起任务，确保即使生物实体消失也能完成结算
                self._deposit_batch_task = GLOBAL.TheWorld:DoTaskInTime(0, function()
                    if self._intercepted_count > 0 then
                        local has_rewarded = false
                        if #participants > 0 then
                            for _, player in ipairs(participants) do
                                if player:IsValid() and player.components.moneymanager then
                                    player.components.moneymanager:AddFunds("击杀掉落", self._intercepted_count)
                                    has_rewarded = true
                                end
                            end
                        end

                        -- 如果没人领（参与者都不在线或无效），则回退到原地掉落实体金币
                        if not has_rewarded then
                            for i = 1, self._intercepted_count do
                                local loot = GLOBAL.SpawnPrefab("dubloon")
                                if loot then
                                    -- 这里引用闭包内的 old_FlingItem
                                    if old_FlingItem then
                                        old_FlingItem(self, loot, victim_pos)
                                    else
                                        self.inst:DoTaskInTime(0, function() loot:Remove() end) -- 彻底兜底
                                    end
                                end
                            end
                        end
                    end
                    self._intercepted_count = 0
                    self._deposit_batch_task = nil
                end)
            end
        end

        -- 拦截 FlingItem (处理某些 BOSS 直接使用 SpawnPrefab + FlingItem 抛出金币的情况)
        old_FlingItem = self.FlingItem
        self.FlingItem = function(self, loot, pt, dropper)
            if loot and loot.prefab == "dubloon" then
                local stacksize = (loot.components.stackable and loot.components.stackable:StackSize()) or 1
                queue_intercept(stacksize)
                loot:Remove() -- 直接移除实体，杜绝渲染和物理计算产生的卡顿
                return
            end
            return old_FlingItem(self, loot, pt, dropper)
        end

        -- 拦截 SpawnLootPrefab (处理大多数基于 LootTable 的常规掉落)
        local old_SpawnLootPrefab = self.SpawnLootPrefab
        self.SpawnLootPrefab = function(self, loot, pt)
            if loot == "dubloon" then
                queue_intercept(1)
                return nil -- 返回 nil 表示不生成 Prefab，从源头上删去产出过程
            end
            return old_SpawnLootPrefab(self, loot, pt)
        end
    end)
end

--UI尺寸
local function ScaleUI(self, screensize)
        -- local hudscale = self.top_root:GetScale()
        -- self.coinUi:SetScale(.75*hudscale.x,.75*hudscale.y,1)
        self.coinUi:SetScale(1, 1, 1)
end

--UI
local coinUi = require("widgets/coinUi")
local function AddcoinUi(self)
        self.coinUi = self.top_root:AddChild(coinUi(self.owner, coinslist))
        local screensize = {GLOBAL.TheSim:GetScreenSize()}
        ScaleUI(self, screensize)
        self.coinUi:SetHAnchor(0)
        self.coinUi:SetVAnchor(0)
        --H: 0=中间 1=左端 2=右端
        --V: 0=中间 1=顶端 2=底端
        self.coinUi:MoveToFront()
end

-- 检查背包是否存在指定物品及数量
function checkItemExists(player, prefab, count)
        if count == 0 then
                return true
        end

        local inventory = player.components.inventory
        local found_count = 0

        -- 遍历物品槽位
        for slot_index = 1, inventory.maxslots do
                local item = inventory.itemslots[slot_index]
                if item and item.prefab == prefab then
                        -- 处理堆叠物品
                        if item.components.stackable then
                                found_count = found_count + item.components.stackable:StackSize()
                        else
                                found_count = found_count + 1
                        end
                        if found_count >= count then
                                return true  -- 数量达标立即返回
                        end
                end
        end
        return false
end

if exchange_ui_enabled then
        AddClassPostConstruct("widgets/controls", AddcoinUi)
end

-- 智能回收系统
local smart_recycle_enabled = GetModConfigData("dh_enable_smart_recycle") ~= false

local function splitStringIntoWords(message)
    if not message or message == "" then
        return {}
    end
    local words = {}
    for word in string.gmatch(message, "[%S]+") do
        table.insert(words, word)
    end
    return words
end

local function CalculateItemRecycleValue(item)
    if not item or not item:IsValid() then
        return 0
    end
    local slotmachineutils = require "modules.slotmachineutils"
    local baseValue = slotmachineutils.getRecycleItemFinalPrice(item) or 0
    if baseValue <= 0 then
        return 0
    end
    baseValue = baseValue < 0.1 and 0.1 or baseValue
    local percent = 1
    local cmp = item.components
    if cmp.finiteuses then
        percent = cmp.finiteuses:GetPercent()
    elseif cmp.armor then
        percent = cmp.armor:GetPercent()
    elseif cmp.perishable then
        percent = cmp.perishable:GetPercent()
        percent = percent > 0.75 and 1 or percent > 0.5 and 0.75 or 0.5
    end
    local stackSize = (cmp.stackable and cmp.stackable.stacksize or 1)
    local itemValue = baseValue * percent * stackSize
    if itemValue <= 0.1 then
        itemValue = 0.1
    end
    return itemValue
end

local OldNetworking_Say = GLOBAL.Networking_Say
GLOBAL.Networking_Say = function(guid, userid, name, prefab, message, colour, whisper, isemote)
    OldNetworking_Say(guid, userid, name, prefab, message, colour, whisper, isemote)
    local talker = UserToPlayer(userid)
    if smart_recycle_enabled and talker and message then
        local words = splitStringIntoWords(message)
        if words[1] and string.lower(words[1]) == "#ql" then
            local cleanupRadius = 7 -- 默认范围
            if words[2] and tonumber(words[2]) then
                cleanupRadius = math.min(tonumber(words[2]), 100) -- 允许任何人指定范围，但最大限制为 100 防止过载
            end
            local totalValue = 0
            local pos = talker:GetPosition()
            local items = GLOBAL.TheSim:FindEntities(pos.x, pos.y, pos.z, cleanupRadius, {"_inventoryitem"}, {"INLIMBO", "NOBLOCK", "player", "FX", "DECOR", "character", "ghost"})
            if items and #items > 0 then
                talker.components.talker:Say("正在为您清理和回收物品...")
                for _, item in ipairs(items) do
                    if item and item:IsValid() and not item:HasTag("_health") then
                        totalValue = totalValue + CalculateItemRecycleValue(item)
                    end
                end
                for _, item in ipairs(items) do
                    if item and item:IsValid() and not item:HasTag("_health") then
                        item:Remove()
                    end
                end
                if totalValue > 0 and talker.components.moneymanager then
                    talker.components.moneymanager:AddFunds("清理回收", totalValue)
                end
            else
                talker.components.talker:Say("附近没有可清理的物品。")
            end
        end
    end
end
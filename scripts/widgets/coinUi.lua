local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local AnimButton = require "widgets/animbutton"
local HoverText = require "widgets/hoverer"
local ItemSlot = require "widgets/itemslot"

local mainState = false

local coinUi = Class(Widget, function(self, owner, coinslist)
	Widget._ctor(self, "coinUi")
	self.owner = owner

	-- 拖动状态：右键按住兑换按钮时进入拖动，松开结束
	self._dragging = false

	-- 拖动偏移：记录“鼠标位置 - 根节点位置”，用于拖动过程中保持相对位置不跳动
	self._drag_offset_x = 0
	self._drag_offset_y = 0

	-- 持久化 Key：按玩家 userid 区分（同机多账号互不影响）
	self._persist_key = "luckysimulator_patch_coinui_pos_" .. tostring(self.owner and self.owner.userid or "default")

	-- 可拖动根节点：只移动这个节点，节点下的按钮/文字会一起移动；兑换列表(main)不挂在这里，所以不跟随移动
	self.drag_root = self:AddChild(Widget("drag_root"))
	self.drag_root:SetPosition(-800, 300, 0)

	-- 添加兑换页面
	self.main = self:AddChild(Widget("main"))
	self.main:SetScale(.75, .75, 1)
	self.main:SetPosition(0, 0, 0)
	self.main:Hide()

	-- 基准位置
	local x = 0
	local y = 0
	local spacing = 150
	local max_columns = 10

	local rows = { {}, {}, {} }
	for _, coin in ipairs(coinslist) do
		local row = coin.row
		if type(row) ~= "number" then
			row = 1
		end
		row = math.floor(row)
		if row < 1 then
			row = 1
		elseif row > 3 then
			row = 3
		end
		rows[row][#rows[row] + 1] = coin
	end

	local index = 0
	for row_index = 1, 3 do
		local row_items = rows[row_index]
		if #row_items > 0 then
			local row_placed = {}
			for row_pos, coin in ipairs(row_items) do
				local oh_name = coin.oh_name
				local label = coin.label
				local price = coin.price
				local desc = coin.desc

				index = index + 1
				self.main[index] = self.main:AddChild(ImageButton("images/" .. oh_name .. ".xml", oh_name .. ".tex"))
				
				-- 计算当前物品在行内的网格位置
				local col = (row_pos - 1) % max_columns
				local extra_row_offset = math.floor((row_pos - 1) / max_columns)
				
				-- px, py 是相对于 self.main 的原始网格位置
				local px = x + (spacing * col)
				local py = y - ((row_index - 1 + extra_row_offset) * spacing)
				
				self.main[index]:SetPosition(px, py, 0)
				row_placed[#row_placed + 1] = { w = self.main[index], x = px, y = py }
				
				self.main[index]:SetScale(2, 2, 1)
				self.main[index]:SetNormalScale(1,1,1)
				self.main[index]:SetFocusScale(1,1,1)
				self.main[index]:Show()

				if type(price) == "number" and price > -1 then
					local hover_text = label .. ": " .. price .. "金币"
					if desc then
						hover_text = hover_text .. "\n" .. desc
					end
					self.main[index]:SetHoverText(hover_text)
					self.main[index]:SetOnClick(function()
						SendModRPCToServer(MOD_RPC["buyCoin"]["buy"], oh_name, price, 1)
					end)
				else
					local hover_text = label .. ": 已售罄!"
					if desc then
						hover_text = hover_text .. "\n" .. desc
					end
					self.main[index]:SetHoverText(hover_text)
				end

				local oldItemOnMouseButton = self.main[index].OnMouseButton
				self.main[index].OnMouseButton = function(btn, button, down, x, y)
					if type(price) == "number" and price > -1 and button == _G.MOUSEBUTTON_RIGHT then
						if down then
							return true
						end
						SendModRPCToServer(MOD_RPC["buyCoin"]["buy"], oh_name, price, 10)
						return true
					end
					if oldItemOnMouseButton then
						return oldItemOnMouseButton(btn, button, down, x, y)
					end
				end
			end

			-- 对当前行（或当前行的子行）进行居中处理
			-- 这里的逻辑支持如果一行超过 max_columns 自动换行后的居中
			local sub_rows = {}
			for _, it in ipairs(row_placed) do
				local ry = it.y
				sub_rows[ry] = sub_rows[ry] or {}
				table.insert(sub_rows[ry], it)
			end

			for ry, items in pairs(sub_rows) do
				local minx, maxx = items[1].x, items[1].x
				for i = 2, #items do
					if items[i].x < minx then minx = items[i].x end
					if items[i].x > maxx then maxx = items[i].x end
				end
				local row_cx = (minx + maxx) / 2
				for _, it in ipairs(items) do
					local current_pos = it.w:GetPosition()
					it.w:SetPosition(current_pos.x - row_cx, current_pos.y, 0)
				end
			end
		end
	end

	-- 整体垂直居中调整（可选，保持原有的 y 轴居中感）
	-- 如果需要整体也在 y 轴居中，可以记录所有物品的 miny, maxy
	local all_items = {}
	for i = 1, index do
		table.insert(all_items, self.main[i])
	end
	if #all_items > 0 then
		local miny, maxy = all_items[1]:GetPosition().y, all_items[1]:GetPosition().y
		for i = 2, #all_items do
			local py = all_items[i]:GetPosition().y
			if py < miny then miny = py end
			if py > maxy then maxy = py end
		end
		local cy = (miny + maxy) / 2
		for i = 1, #all_items do
			local p = all_items[i]:GetPosition()
			all_items[i]:SetPosition(p.x, p.y - cy, 0)
		end
	end

	-- 添加图标 可显示/隐藏兑换页面
	self.button = self.drag_root:AddChild(ImageButton("images/ohcoinrandom.xml", "ohcoinrandom.tex"))
	self.button:SetPosition(0, 0, 0)
	self.button:SetNormalScale(1,1,1)
	self.button:SetFocusScale(1,1,1)
	self.button:SetHoverText("兑换! (右键拖动)", { offset_y = 40, attach_to_parent = self.button })
	self.button:SetOnClick(function()
		if mainState then
			self.main:Hide()
			mainState = false
		else
			self.main:Show()
			mainState = true
		end
	end)

	local function GetMouseLocalPos()
		-- TheInput:GetScreenPosition() 返回屏幕坐标(左下为原点)
		-- Widget:SetPosition() 使用以屏幕中心为原点的坐标系，所以这里做一次转换
		local sp = _G.TheInput:GetScreenPosition()
		local w, h = _G.TheSim:GetScreenSize()
		return sp.x - (w / 2), sp.y - (h / 2)
	end

	local function ParseNumber(str)
		if type(str) ~= "string" then
			return nil
		end
		local sign = 1
		local start = 1
		local first = str:sub(1, 1)
		if first == "-" then
			sign = -1
			start = 2
		elseif first == "+" then
			start = 2
		end
		local int = 0
		local frac = 0
		local frac_div = 1
		local has_digit = false
		local in_frac = false
		for i = start, #str do
			local b = str:byte(i)
			if b == 46 and not in_frac then
				in_frac = true
			elseif b and b >= 48 and b <= 57 then
				has_digit = true
				if not in_frac then
					int = int * 10 + (b - 48)
				else
					frac = frac * 10 + (b - 48)
					frac_div = frac_div * 10
				end
			else
				return nil
			end
		end
		if not has_digit then
			return nil
		end
		return sign * (int + (frac / frac_div))
	end

	local function LoadPosition()
		-- 读取上次保存的位置（异步回调）
		_G.TheSim:GetPersistentString(self._persist_key, function(load_success, str)
			if not load_success or type(str) ~= "string" then
				return
			end
			local x, y = str:match("^%s*(-?%d+%.?%d*)%s*,%s*(-?%d+%.?%d*)%s*$")
			x = ParseNumber(x)
			y = ParseNumber(y)
			if x and y then
				self.drag_root:SetPosition(x, y, 0)
			end
		end)
	end

	local function SavePosition()
		-- 松开拖动时保存当前位置，格式为 "x,y"
		local pos = self.drag_root:GetPosition()
		_G.TheSim:SetPersistentString(self._persist_key, string.format("%.2f,%.2f", pos.x, pos.y), false)
	end

	LoadPosition()

	local oldOnMouseButton = self.button.OnMouseButton
	self.button.OnMouseButton = function(btn, button, down, x, y)
		if button == _G.MOUSEBUTTON_RIGHT then
			if down then
				-- 开始拖动：记录偏移并开启更新
				local mx, my = GetMouseLocalPos()
				local pos = self.drag_root:GetPosition()
				self._dragging = true
				self._drag_offset_x = mx - pos.x
				self._drag_offset_y = my - pos.y
				self:StartUpdating()
				return true
			elseif self._dragging then
				-- 结束拖动：停止更新并持久化保存
				self._dragging = false
				self:StopUpdating()
				SavePosition()
				return true
			end
		end
		if oldOnMouseButton then
			return oldOnMouseButton(btn, button, down, x, y)
		end
	end

	function self:OnUpdate(dt)
		-- 拖动过程中每帧更新根节点位置
		if self._dragging then
			local mx, my = GetMouseLocalPos()
			self.drag_root:SetPosition(mx - self._drag_offset_x, my - self._drag_offset_y, 0)
		end
	end

end)

function lookupPlayerInstByUserID(userid)
	for _, v in ipairs(AllPlayers) do
		if v.userid == userid then
			return v
		end
	end
	return nil
end

return coinUi

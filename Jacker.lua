-- Jacker UI Library v1.0
-- Roblox Lua (executor-friendly): rounded UI, tabs, 2-column layout, theme support.

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local Jacker = {}
Jacker.__index = Jacker
Jacker.Version = "1.0.0"

local DefaultTheme = {
	Background = Color3.fromRGB(11, 14, 19),
	Topbar = Color3.fromRGB(18, 22, 29),
	Sidebar = Color3.fromRGB(15, 19, 25),
	Card = Color3.fromRGB(22, 27, 35),
	CardAlt = Color3.fromRGB(28, 34, 44),
	Text = Color3.fromRGB(233, 238, 246),
	SubText = Color3.fromRGB(154, 163, 179),
	Accent = Color3.fromRGB(43, 108, 224),
	Border = Color3.fromRGB(45, 53, 66),
}

local function copyTable(tbl)
	local out = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			out[k] = copyTable(v)
		else
			out[k] = v
		end
	end
	return out
end

local function deepMerge(base, overrides)
	local out = copyTable(base)
	if type(overrides) ~= "table" then
		return out
	end
	for k, v in pairs(overrides) do
		if type(v) == "table" and type(out[k]) == "table" then
			out[k] = deepMerge(out[k], v)
		else
			out[k] = v
		end
	end
	return out
end

local function create(className, props)
	local obj = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			obj[k] = v
		end
	end
	return obj
end

local function addCorner(inst, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
		Parent = inst,
	})
end

local function addStroke(inst, color, thickness)
	return create("UIStroke", {
		Color = color or Color3.fromRGB(45, 53, 66),
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function tween(obj, ti, props)
	local ok, tw = pcall(function()
		return TweenService:Create(obj, ti, props)
	end)
	if ok and tw then
		tw:Play()
	end
	return tw
end

local function makeDraggable(handle, target, bucket)
	local dragging = false
	local dragStart
	local startPos
	local dragInput

	table.insert(bucket, handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
		end
	end))

	table.insert(bucket, handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end))

	table.insert(bucket, UserInputService.InputChanged:Connect(function(input)
		if dragging and dragInput == input and dragStart and startPos then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))

	table.insert(bucket, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

local function getGuiParent()
	local env = getfenv and getfenv() or _G
	if env and type(env.gethui) == "function" then
		local ok, res = pcall(env.gethui)
		if ok and res then
			return res
		end
	end
	return CoreGui
end

local function protectGui(gui)
	local env = getfenv and getfenv() or _G
	if env and type(env.syn) == "table" and type(env.syn.protect_gui) == "function" then
		pcall(function()
			env.syn.protect_gui(gui)
		end)
	end
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local MiniWindow = {}
MiniWindow.__index = MiniWindow

function Jacker:CreateWindow(options)
	options = options or {}

	local window = setmetatable({}, Window)
	window.Theme = deepMerge(DefaultTheme, options.Theme)
	window.Tabs = {}
	window._selectedTab = nil
	window._hooks = {}
	window._connections = {}
	window._toggleKey = options.ToggleKey or Enum.KeyCode.RightShift
	window._visible = true
	window._minimized = false
	window._twoColumnMinWidth = options.TwoColumnMinWidth or 620

	local gui = create("ScreenGui", {
		Name = options.Name or ("JackerUI_" .. tostring(math.random(1000, 99999))),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		IgnoreGuiInset = true,
	})
	protectGui(gui)
	gui.Parent = options.Parent or getGuiParent()
	window.Gui = gui

	local requestedSize = options.Size or UDim2.fromOffset(860, 540)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)

	local maxW = math.max(math.floor(viewport.X * 0.9), 640)
	local maxH = math.max(math.floor(viewport.Y * 0.9), 420)
	local minW = math.min(700, maxW)
	local minH = math.min(420, maxH)

	local reqW = requestedSize.X.Offset > 0 and requestedSize.X.Offset or math.floor(viewport.X * requestedSize.X.Scale)
	local reqH = requestedSize.Y.Offset > 0 and requestedSize.Y.Offset or math.floor(viewport.Y * requestedSize.Y.Scale)
	local size = UDim2.fromOffset(math.clamp(reqW, minW, maxW), math.clamp(reqH, minH, maxH))
	window._defaultSize = size
	window._expandedSize = size
	window._sizeBounds = {
		MinW = minW,
		MinH = minH,
		MaxW = maxW,
		MaxH = maxH,
	}

	local shadow = create("Frame", {
		Name = "Shadow",
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(size.X.Scale, size.X.Offset + 12, size.Y.Scale, size.Y.Offset + 12),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = 0,
	})
	addCorner(shadow, 14)
	window.Shadow = shadow

	local root = create("Frame", {
		Name = "Root",
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = window.Theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	addCorner(root, 12)
	local rootStroke = addStroke(root, window.Theme.Border)
	window.Root = root

	table.insert(window._connections, root:GetPropertyChangedSignal("Size"):Connect(function()
		shadow.Size = UDim2.new(root.Size.X.Scale, root.Size.X.Offset + 12, root.Size.Y.Scale, root.Size.Y.Offset + 12)
	end))
	table.insert(window._connections, root:GetPropertyChangedSignal("Position"):Connect(function()
		shadow.Position = root.Position
	end))

	local topbar = create("Frame", {
		Name = "Topbar",
		Parent = root,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = window.Theme.Topbar,
		BorderSizePixel = 0,
	})
	addStroke(topbar, window.Theme.Border)
	window.Topbar = topbar

	local title = create("TextLabel", {
		Name = "Title",
		Parent = topbar,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -130, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		Text = options.Title or "Jacker UI",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = window.Theme.Text,
		TextSize = 15,
	})
	window.TitleLabel = title

	local topRight = create("Frame", {
		Parent = topbar,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -102, 0.5, -14),
		Size = UDim2.fromOffset(92, 28),
	})
	create("UIListLayout", {
		Parent = topRight,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})

	local minimizeBtn = create("TextButton", {
		Parent = topRight,
		Size = UDim2.fromOffset(42, 28),
		Text = "_",
		BackgroundColor3 = window.Theme.CardAlt,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextColor3 = window.Theme.Text,
		TextSize = 14,
		AutoButtonColor = false,
	})
	addCorner(minimizeBtn, 8)
	addStroke(minimizeBtn, window.Theme.Border)

	local closeBtn = create("TextButton", {
		Parent = topRight,
		Size = UDim2.fromOffset(42, 28),
		Text = "X",
		BackgroundColor3 = window.Theme.CardAlt,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextColor3 = window.Theme.Text,
		TextSize = 13,
		AutoButtonColor = false,
	})
	addCorner(closeBtn, 8)
	addStroke(closeBtn, window.Theme.Border)

	local body = create("Frame", {
		Name = "Body",
		Parent = root,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
	})
	window.Body = body

	local sidebarWidth = options.SidebarWidth or 185
	local sidebar = create("Frame", {
		Name = "Sidebar",
		Parent = body,
		Size = UDim2.fromOffset(sidebarWidth, 0),
		BackgroundColor3 = window.Theme.Sidebar,
		BorderSizePixel = 0,
	})
	addStroke(sidebar, window.Theme.Border)
	window.Sidebar = sidebar

	create("UIPadding", {
		Parent = sidebar,
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})

	local searchWrap = create("Frame", {
		Name = "SearchWrap",
		Parent = sidebar,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = window.Theme.CardAlt,
		BorderSizePixel = 0,
	})
	addCorner(searchWrap, 8)
	addStroke(searchWrap, window.Theme.Border)

	local searchBox = create("TextBox", {
		Name = "Search",
		Parent = searchWrap,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -12, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		TextColor3 = window.Theme.Text,
		PlaceholderText = "Search tabs",
		PlaceholderColor3 = window.Theme.SubText,
		ClearTextOnFocus = false,
	})
	window.SearchBox = searchBox

	local tabList = create("ScrollingFrame", {
		Name = "TabList",
		Parent = sidebar,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = true,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = window.Theme.Accent,
	})
	window.TabList = tabList
	create("UIListLayout", {
		Parent = tabList,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})

	local content = create("Frame", {
		Name = "Content",
		Parent = body,
		Position = UDim2.fromOffset(sidebarWidth, 0),
		Size = UDim2.new(1, -sidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	})
	window.Content = content

	local pages = create("Frame", {
		Name = "Pages",
		Parent = content,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundTransparency = 1,
	})
	window.Pages = pages

	makeDraggable(topbar, root, window._connections)

	table.insert(window._connections, searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local query = string.lower(searchBox.Text or "")
		for _, tab in ipairs(window.Tabs) do
			if tab.Button then
				tab.Button.Visible = query == "" or string.find(string.lower(tab.Name), query, 1, true) ~= nil
			end
		end
	end))

	table.insert(window._connections, closeBtn.MouseButton1Click:Connect(function()
		window:Destroy()
	end))

	table.insert(window._connections, minimizeBtn.MouseButton1Click:Connect(function()
		window:SetMinimized(not window._minimized)
	end))

	table.insert(window._connections, UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == window._toggleKey then
			window:SetVisible(not window._visible)
		end
	end))

	function window:_applyTheme()
		root.BackgroundColor3 = window.Theme.Background
		rootStroke.Color = window.Theme.Border
		topbar.BackgroundColor3 = window.Theme.Topbar
		title.TextColor3 = window.Theme.Text

		minimizeBtn.BackgroundColor3 = window.Theme.CardAlt
		minimizeBtn.TextColor3 = window.Theme.Text
		closeBtn.BackgroundColor3 = window.Theme.CardAlt
		closeBtn.TextColor3 = window.Theme.Text

		sidebar.BackgroundColor3 = window.Theme.Sidebar
		searchWrap.BackgroundColor3 = window.Theme.CardAlt
		searchBox.TextColor3 = window.Theme.Text
		searchBox.PlaceholderColor3 = window.Theme.SubText
		tabList.ScrollBarImageColor3 = window.Theme.Accent

		for _, cb in ipairs(window._hooks) do
			cb(window.Theme)
		end
	end

	window:_applyTheme()
	return window
end

function Window:_onThemeChanged(callback)
	table.insert(self._hooks, callback)
	callback(self.Theme)
end

function Window:SetTheme(theme)
	self.Theme = deepMerge(self.Theme, theme or {})
	self:_applyTheme()
end

function Window:SetVisible(state)
	self._visible = state and true or false
	self.Gui.Enabled = self._visible
end

function Window:Toggle()
	self:SetVisible(not self._visible)
end

function Window:SetMinimized(state)
	self._minimized = state and true or false
	if self._minimized then
		self._expandedSize = self.Root.Size
		self.Body.Visible = false
		tween(self.Root, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(self.Root.Size.X.Scale, self.Root.Size.X.Offset, 0, 40),
		})
	else
		self.Body.Visible = true
		tween(self.Root, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = self._expandedSize or self._defaultSize or UDim2.fromOffset(860, 540),
		})
	end
end

function Window:SelectTab(tabObj)
	if self._selectedTab == tabObj then
		return
	end
	self._selectedTab = tabObj
	for _, tab in ipairs(self.Tabs) do
		local selected = tab == tabObj
		tab.Page.Visible = selected
		tab.Button.BackgroundColor3 = selected and self.Theme.Accent or self.Theme.CardAlt
		tab.Button.TextColor3 = selected and self.Theme.Text or self.Theme.SubText
	end
end

function Window:CreateTab(options)
	options = options or {}
	if type(options) == "string" then
		options = { Name = options }
	end

	local tab = setmetatable({}, Tab)
	tab.Window = self
	tab.Name = options.Name or ("Tab " .. tostring(#self.Tabs + 1))
	tab.Sections = {}
	tab._leftOrder = 0
	tab._rightOrder = 0

	local button = create("TextButton", {
		Parent = self.TabList,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = self.Theme.CardAlt,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextColor3 = self.Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "  " .. tab.Name,
	})
	addCorner(button, 8)
	addStroke(button, self.Theme.Border)
	tab.Button = button

	local page = create("Frame", {
		Parent = self.Pages,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
	})
	tab.Page = page

	local leftCol = create("ScrollingFrame", {
		Parent = page,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0.5, -6, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = true,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = self.Theme.Accent,
	})
	tab.LeftColumn = leftCol

	local rightCol = create("ScrollingFrame", {
		Parent = page,
		Position = UDim2.new(0.5, 6, 0, 0),
		Size = UDim2.new(0.5, -6, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = true,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = self.Theme.Accent,
	})
	tab.RightColumn = rightCol

	create("UIPadding", {
		Parent = leftCol,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
	})
	create("UIPadding", {
		Parent = rightCol,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
	})
	create("UIListLayout", {
		Parent = leftCol,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	})
	create("UIListLayout", {
		Parent = rightCol,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	})

	function tab:_updateColumns()
		local w = page.AbsoluteSize.X
		if w >= (self.Window._twoColumnMinWidth or 620) then
			leftCol.Position = UDim2.fromOffset(0, 0)
			leftCol.Size = UDim2.new(0.5, -6, 1, 0)
			rightCol.Position = UDim2.new(0.5, 6, 0, 0)
			rightCol.Size = UDim2.new(0.5, -6, 1, 0)
		else
			leftCol.Position = UDim2.fromOffset(0, 0)
			leftCol.Size = UDim2.new(1, 0, 0.5, -6)
			rightCol.Position = UDim2.new(0, 0, 0.5, 6)
			rightCol.Size = UDim2.new(1, 0, 0.5, -6)
		end
	end
	tab:_updateColumns()

	table.insert(self._connections, page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		tab:_updateColumns()
	end))

	table.insert(self._connections, button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end))

	self:_onThemeChanged(function(theme)
		local selected = self._selectedTab == tab
		button.BackgroundColor3 = selected and theme.Accent or theme.CardAlt
		button.TextColor3 = selected and theme.Text or theme.SubText
		leftCol.ScrollBarImageColor3 = theme.Accent
		rightCol.ScrollBarImageColor3 = theme.Accent
	end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

local function setupSectionLayout(parent)
	create("UIPadding", {
		Parent = parent,
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	create("UIListLayout", {
		Parent = parent,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
end

function Tab:CreateSection(options)
	options = options or {}
	if type(options) == "string" then
		options = { Name = options }
	end

	local side = string.lower(tostring(options.Side or "left"))
	local isRight = side == "right"
	local host = isRight and self.RightColumn or self.LeftColumn
	if isRight then
		self._rightOrder = self._rightOrder + 1
	else
		self._leftOrder = self._leftOrder + 1
	end

	local section = setmetatable({}, Section)
	section.Tab = self
	section.Window = self.Window
	section.Name = options.Name or "Section"
	section._collapsed = options.Collapsed and true or false

	local frame = create("Frame", {
		Parent = host,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.Window.Theme.Card,
		BorderSizePixel = 0,
		LayoutOrder = isRight and self._rightOrder or self._leftOrder,
		ClipsDescendants = true,
	})
	addCorner(frame, 10)
	local frameStroke = addStroke(frame, self.Window.Theme.Border)
	section.Frame = frame

	local header = create("TextButton", {
		Parent = frame,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = self.Window.Theme.CardAlt,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	})
	section.Header = header

	local title = create("TextLabel", {
		Parent = header,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		Text = section.Name,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		TextColor3 = self.Window.Theme.Text,
	})

	local arrow = create("TextLabel", {
		Parent = header,
		Position = UDim2.new(1, -22, 0.5, -10),
		Size = UDim2.fromOffset(16, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = section._collapsed and ">" or "v",
		TextColor3 = self.Window.Theme.SubText,
	})

	local container = create("Frame", {
		Parent = frame,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = not section._collapsed,
	})
	setupSectionLayout(container)
	section.Container = container

	function section:SetCollapsed(state)
		self._collapsed = state and true or false
		container.Visible = not self._collapsed
		arrow.Text = self._collapsed and ">" or "v"
	end

	table.insert(self.Window._connections, header.MouseButton1Click:Connect(function()
		section:SetCollapsed(not section._collapsed)
	end))

	self.Window:_onThemeChanged(function(theme)
		frame.BackgroundColor3 = theme.Card
		frameStroke.Color = theme.Border
		header.BackgroundColor3 = theme.CardAlt
		title.TextColor3 = theme.Text
		arrow.TextColor3 = theme.SubText
	end)

	table.insert(self.Sections, section)
	return section
end

local function makeCard(window, parent, h)
	local row = create("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, h or 34),
		BackgroundColor3 = window.Theme.CardAlt,
		BorderSizePixel = 0,
	})
	addCorner(row, 8)
	local stroke = addStroke(row, window.Theme.Border)
	return row, stroke
end

function Section:AddLabel(options)
	options = options or {}
	if type(options) == "string" then
		options = { Text = options }
	end

	local row, stroke = makeCard(self.Window, self.Container, 30)
	local label = create("TextLabel", {
		Parent = row,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -12, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = options.Text or "Label",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = options.TextSize or 13,
		TextColor3 = options.Color or self.Window.Theme.SubText,
	})

	self.Window:_onThemeChanged(function(theme)
		row.BackgroundColor3 = theme.CardAlt
		stroke.Color = theme.Border
		label.TextColor3 = options.Color or theme.SubText
	end)

	return {
		SetText = function(_, value)
			label.Text = tostring(value)
		end,
	}
end

function Section:AddSeparator(options)
	options = options or {}
	local row = create("Frame", {
		Parent = self.Container,
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
	})
	local line = create("Frame", {
		Parent = row,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = self.Window.Theme.Border,
		BorderSizePixel = 0,
	})
	local title
	if options.Text then
		title = create("TextLabel", {
			Parent = row,
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.fromOffset(140, 16),
			BackgroundColor3 = self.Window.Theme.Card,
			Font = Enum.Font.GothamSemibold,
			Text = tostring(options.Text),
			TextSize = 11,
			TextColor3 = self.Window.Theme.SubText,
		})
	end

	self.Window:_onThemeChanged(function(theme)
		line.BackgroundColor3 = theme.Border
		if title then
			title.BackgroundColor3 = theme.Card
			title.TextColor3 = theme.SubText
		end
	end)
end

function Section:AddButton(options)
	options = options or {}
	local callback = options.Callback
	local btn = create("TextButton", {
		Parent = self.Container,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = self.Window.Theme.CardAlt,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamSemibold,
		Text = options.Text or options.Name or "Button",
		TextSize = 13,
		TextColor3 = self.Window.Theme.Text,
	})
	addCorner(btn, 8)
	local stroke = addStroke(btn, self.Window.Theme.Border)

	table.insert(self.Window._connections, btn.MouseButton1Click:Connect(function()
		local original = btn.BackgroundColor3
		tween(btn, TweenInfo.new(0.08), { BackgroundColor3 = self.Window.Theme.Accent })
		task.delay(0.1, function()
			if btn and btn.Parent then
				tween(btn, TweenInfo.new(0.12), { BackgroundColor3 = original })
			end
		end)
		if callback then
			task.spawn(callback)
		end
	end))

	self.Window:_onThemeChanged(function(theme)
		btn.BackgroundColor3 = theme.CardAlt
		btn.TextColor3 = theme.Text
		stroke.Color = theme.Border
	end)

	return {
		SetText = function(_, value)
			btn.Text = tostring(value)
		end,
	}
end

function Section:AddToggle(options)
	options = options or {}
	local callback = options.Callback
	local state = options.Default and true or false

	local row, stroke = makeCard(self.Window, self.Container, 36)
	local label = create("TextLabel", {
		Parent = row,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -72, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = options.Text or options.Name or "Toggle",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		TextColor3 = self.Window.Theme.Text,
	})

	local switch = create("Frame", {
		Parent = row,
		Position = UDim2.new(1, -54, 0.5, -11),
		Size = UDim2.fromOffset(44, 22),
		BackgroundColor3 = self.Window.Theme.Border,
		BorderSizePixel = 0,
	})
	addCorner(switch, 100)
	local switchStroke = addStroke(switch, self.Window.Theme.Border)

	local knob = create("Frame", {
		Parent = switch,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.fromRGB(245, 248, 252),
		BorderSizePixel = 0,
	})
	addCorner(knob, 100)

	local control = {}
	local function redraw()
		switch.BackgroundColor3 = state and self.Window.Theme.Accent or self.Window.Theme.Border
		tween(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = state and UDim2.new(1, -20, 0, 2) or UDim2.fromOffset(2, 2),
		})
	end

	function control:Set(value, doCallback)
		value = value and true or false
		if state == value then
			return
		end
		state = value
		redraw()
		if doCallback ~= false and callback then
			task.spawn(callback, state)
		end
	end

	function control:Get()
		return state
	end

	local clickArea = create("TextButton", {
		Parent = row,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	})
	table.insert(self.Window._connections, clickArea.MouseButton1Click:Connect(function()
		control:Set(not state, true)
	end))

	self.Window:_onThemeChanged(function(theme)
		row.BackgroundColor3 = theme.CardAlt
		stroke.Color = theme.Border
		label.TextColor3 = theme.Text
		switchStroke.Color = theme.Border
		switch.BackgroundColor3 = state and theme.Accent or theme.Border
	end)

	redraw()
	return control
end

function Section:AddSlider(options)
	options = options or {}
	local min = tonumber(options.Min) or 0
	local max = tonumber(options.Max) or 100
	local step = tonumber(options.Step) or 1
	local value = tonumber(options.Default) or min
	local callback = options.Callback
	local suffix = options.Suffix or ""

	if max <= min then
		max = min + 1
	end
	if step <= 0 then
		step = 1
	end

	local row, stroke = makeCard(self.Window, self.Container, 58)
	local title = create("TextLabel", {
		Parent = row,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -86, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = options.Text or options.Name or "Slider",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		TextColor3 = self.Window.Theme.Text,
	})
	local valueLabel = create("TextLabel", {
		Parent = row,
		Position = UDim2.new(1, -72, 0, 4),
		Size = UDim2.fromOffset(64, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 12,
		TextColor3 = self.Window.Theme.SubText,
	})

	local bar = create("Frame", {
		Parent = row,
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -20, 0, 10),
		BackgroundColor3 = self.Window.Theme.Border,
		BorderSizePixel = 0,
	})
	addCorner(bar, 100)

	local fill = create("Frame", {
		Parent = bar,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = self.Window.Theme.Accent,
		BorderSizePixel = 0,
	})
	addCorner(fill, 100)

	local knob = create("Frame", {
		Parent = bar,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(242, 247, 252),
		BorderSizePixel = 0,
	})
	addCorner(knob, 100)

	local function snap(v)
		v = math.clamp(v, min, max)
		local snapped = min + math.floor((v - min) / step + 0.5) * step
		return math.clamp(snapped, min, max)
	end

	local function percent(v)
		return (v - min) / (max - min)
	end

	local function redraw()
		local p = percent(value)
		fill.Size = UDim2.new(p, 0, 1, 0)
		knob.Position = UDim2.new(p, 0, 0.5, 0)
		valueLabel.Text = tostring(value) .. suffix
	end

	local function setFromX(x, doCallback)
		local p = (x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
		p = math.clamp(p, 0, 1)
		local newValue = snap(min + (max - min) * p)
		if newValue ~= value then
			value = newValue
			redraw()
			if doCallback ~= false and callback then
				task.spawn(callback, value)
			end
		end
	end

	local control = {}
	function control:Set(v, doCallback)
		local newValue = snap(tonumber(v) or min)
		if newValue ~= value then
			value = newValue
			redraw()
			if doCallback ~= false and callback then
				task.spawn(callback, value)
			end
		end
	end
	function control:Get()
		return value
	end

	local dragging = false
	table.insert(self.Window._connections, bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X, true)
		end
	end))
	table.insert(self.Window._connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X, true)
		end
	end))
	table.insert(self.Window._connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	self.Window:_onThemeChanged(function(theme)
		row.BackgroundColor3 = theme.CardAlt
		stroke.Color = theme.Border
		title.TextColor3 = theme.Text
		valueLabel.TextColor3 = theme.SubText
		bar.BackgroundColor3 = theme.Border
		fill.BackgroundColor3 = theme.Accent
	end)

	value = snap(value)
	redraw()
	return control
end

function Section:AddDropdown(options)
	options = options or {}
	local values = options.Values or options.Options or {}
	local callback = options.Callback
	local current
	local opened = false
	local optionButtons = {}

	local row = create("Frame", {
		Parent = self.Container,
		Size = UDim2.new(1, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.Window.Theme.CardAlt,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	addCorner(row, 8)
	local stroke = addStroke(row, self.Window.Theme.Border)

	local main = create("TextButton", {
		Parent = row,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})

	local title = create("TextLabel", {
		Parent = row,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -60, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = options.Text or options.Name or "Dropdown",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		TextColor3 = self.Window.Theme.Text,
	})
	local valueLabel = create("TextLabel", {
		Parent = row,
		Position = UDim2.new(1, -58, 0, 0),
		Size = UDim2.fromOffset(42, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		Text = "...",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 12,
		TextColor3 = self.Window.Theme.SubText,
	})
	local arrow = create("TextLabel", {
		Parent = row,
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.fromOffset(12, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "v",
		TextSize = 12,
		TextColor3 = self.Window.Theme.SubText,
	})

	local list = create("Frame", {
		Parent = row,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
	})
	create("UIPadding", {
		Parent = list,
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	create("UIListLayout", {
		Parent = list,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})

	local function setOpen(state)
		opened = state and true or false
		list.Visible = opened
		arrow.Text = opened and "^" or "v"
	end

	local function selectValue(v, doCallback)
		current = v
		valueLabel.Text = tostring(v)
		setOpen(false)
		if doCallback ~= false and callback then
			task.spawn(callback, current)
		end
	end

	local function clearOptions()
		for _, b in ipairs(optionButtons) do
			b:Destroy()
		end
		optionButtons = {}
	end

	local function rebuild()
		clearOptions()
		for _, opt in ipairs(values) do
			local b = create("TextButton", {
				Parent = list,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = self.Window.Theme.Card,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = Enum.Font.Gotham,
				Text = tostring(opt),
				TextSize = 12,
				TextColor3 = self.Window.Theme.Text,
			})
			addCorner(b, 6)
			addStroke(b, self.Window.Theme.Border)
			table.insert(optionButtons, b)
			table.insert(self.Window._connections, b.MouseButton1Click:Connect(function()
				selectValue(opt, true)
			end))
		end
	end

	local control = {}
	function control:Set(v, doCallback)
		selectValue(v, doCallback)
	end
	function control:Get()
		return current
	end
	function control:SetOptions(newValues)
		values = newValues or {}
		rebuild()
		if #values > 0 and current == nil then
			selectValue(values[1], false)
		elseif #values == 0 then
			current = nil
			valueLabel.Text = "..."
		end
	end

	rebuild()
	table.insert(self.Window._connections, main.MouseButton1Click:Connect(function()
		setOpen(not opened)
	end))
	if options.Default ~= nil then
		selectValue(options.Default, false)
	elseif #values > 0 then
		selectValue(values[1], false)
	end

	self.Window:_onThemeChanged(function(theme)
		row.BackgroundColor3 = theme.CardAlt
		stroke.Color = theme.Border
		title.TextColor3 = theme.Text
		valueLabel.TextColor3 = theme.SubText
		arrow.TextColor3 = theme.SubText
		for _, b in ipairs(optionButtons) do
			b.BackgroundColor3 = theme.Card
			b.TextColor3 = theme.Text
			for _, c in ipairs(b:GetChildren()) do
				if c:IsA("UIStroke") then
					c.Color = theme.Border
				end
			end
		end
	end)

	return control
end

function Section:AddInput(options)
	options = options or {}
	local callback = options.Callback

	local row, stroke = makeCard(self.Window, self.Container, 58)
	local title = create("TextLabel", {
		Parent = row,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -16, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = options.Text or options.Name or "Input",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 12,
		TextColor3 = self.Window.Theme.SubText,
	})

	local box = create("TextBox", {
		Parent = row,
		Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -20, 0, 26),
		BackgroundColor3 = self.Window.Theme.Card,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		Text = tostring(options.Default or ""),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 12,
		TextColor3 = self.Window.Theme.Text,
		PlaceholderText = options.Placeholder or "Type here...",
		PlaceholderColor3 = self.Window.Theme.SubText,
		ClearTextOnFocus = false,
	})
	addCorner(box, 6)
	local boxStroke = addStroke(box, self.Window.Theme.Border)

	table.insert(self.Window._connections, box.FocusLost:Connect(function(enterPressed)
		if callback then
			task.spawn(callback, box.Text, enterPressed)
		end
	end))

	self.Window:_onThemeChanged(function(theme)
		row.BackgroundColor3 = theme.CardAlt
		stroke.Color = theme.Border
		title.TextColor3 = theme.SubText
		box.BackgroundColor3 = theme.Card
		box.TextColor3 = theme.Text
		box.PlaceholderColor3 = theme.SubText
		boxStroke.Color = theme.Border
	end)

	return {
		Get = function()
			return box.Text
		end,
		Set = function(_, value)
			box.Text = tostring(value)
		end,
	}
end

function Window:CreateMiniWindow(options)
	options = options or {}
	local mini = setmetatable({}, MiniWindow)
	mini.Window = self

	local panel = create("Frame", {
		Parent = self.Gui,
		Size = options.Size or UDim2.fromOffset(320, 180),
		Position = options.Position or UDim2.new(1, -360, 0.5, -90),
		BackgroundColor3 = self.Theme.Card,
		BorderSizePixel = 0,
		Visible = options.Visible and true or false,
		ZIndex = 50,
	})
	addCorner(panel, 10)
	local panelStroke = addStroke(panel, self.Theme.Border)
	mini.Frame = panel

	local top = create("Frame", {
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = self.Theme.CardAlt,
		BorderSizePixel = 0,
		ZIndex = 51,
	})
	addCorner(top, 10)

	local title = create("TextLabel", {
		Parent = top,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		Text = options.Title or "Mini Window",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 12,
		TextColor3 = self.Theme.Text,
		ZIndex = 52,
	})
	mini.TitleLabel = title

	local close = create("TextButton", {
		Parent = top,
		Position = UDim2.new(1, -28, 0.5, -12),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = self.Theme.Card,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "X",
		TextColor3 = self.Theme.Text,
		TextSize = 11,
		AutoButtonColor = false,
		ZIndex = 52,
	})
	addCorner(close, 6)
	local closeStroke = addStroke(close, self.Theme.Border)

	local body = create("Frame", {
		Parent = panel,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		ZIndex = 51,
	})
	mini.Body = body

	local text = create("TextLabel", {
		Parent = body,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = options.Text or "Mini panel body",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 12,
		TextColor3 = self.Theme.SubText,
		ZIndex = 52,
	})
	mini.TextLabel = text

	makeDraggable(top, panel, self._connections)
	table.insert(self._connections, close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end))

	self:_onThemeChanged(function(theme)
		panel.BackgroundColor3 = theme.Card
		panelStroke.Color = theme.Border
		top.BackgroundColor3 = theme.CardAlt
		title.TextColor3 = theme.Text
		close.BackgroundColor3 = theme.Card
		close.TextColor3 = theme.Text
		closeStroke.Color = theme.Border
		text.TextColor3 = theme.SubText
	end)

	function mini:Show()
		self.Frame.Visible = true
	end
	function mini:Hide()
		self.Frame.Visible = false
	end
	function mini:Toggle()
		self.Frame.Visible = not self.Frame.Visible
	end
	function mini:SetTitle(v)
		self.TitleLabel.Text = tostring(v)
	end
	function mini:SetText(v)
		self.TextLabel.Text = tostring(v)
	end
	function mini:Destroy()
		if self.Frame then
			self.Frame:Destroy()
		end
	end

	return mini
end

function Window:Destroy()
	for _, conn in ipairs(self._connections) do
		if conn and conn.Disconnect then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	self._connections = {}

	if self.Shadow then
		self.Shadow:Destroy()
	end
	if self.Gui then
		self.Gui:Destroy()
	end
end

return Jacker

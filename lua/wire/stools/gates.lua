-- Made by Divran 06/01/2012
WireToolSetup.setCategory( "Chips, Gates" )
WireToolSetup.open( "gates", "Gates", "gmod_wire_gate", nil, "Gates" )

WireToolSetup.BaseLang()
WireToolSetup.SetupMax(30)

-- The limit convars are in lua/wire/wiregates.lua

if SERVER then
	ModelPlug_Register("gate")
end

if CLIENT then
	----------------------------------------------------------------------------------------------------
	-- Tool Info
	----------------------------------------------------------------------------------------------------

	language.Add( "Tool.wire_gates.name", "Gates Tool (Wire)" )
	language.Add( "Tool.wire_gates.desc", "Spawns gates for use with the wire system." )
	language.Add( "Tool.wire_gates.0", "Primary: Create/Update Gate, Secondary: Copy Gate, Reload: Increase angle offset by 45 degrees, Shift+Reload: Unparent gate (If parented)." )

	TOOL.ClientConVar["model"] = "models/jaanus/wiretool/wiretool_gate.mdl"
	TOOL.ClientConVar["parent"] = 0
	TOOL.ClientConVar["noclip"] = 1
	TOOL.ClientConVar["angleoffset"] = 0
	TOOL.ClientConVar["action"] = "+"
	TOOL.ClientConVar["searchresultnum"] = 28

	language.Add( "WireGatesTool_action", "Gate action" )
	language.Add( "WireGatesTool_noclip", "NoCollide" )
	language.Add( "WireGatesTool_parent", "Parent" )
	language.Add( "WireGatesTool_angleoffset", "Spawn angle offset" )
	language.Add( "sboxlimit_wire_gates", "You've hit your gates limit!" )

	function TOOL.BuildCPanel( panel )
		WireDermaExts.ModelSelect(panel, "wire_gates_model", list.Get("Wire_gate_Models"), 3, true)

		local nocollidebox = panel:CheckBox("#WireGatesTool_noclip", "wire_gates_noclip")
		local parentbox = panel:CheckBox("#WireGatesTool_parent","wire_gates_parent")

		panel:Help("When parenting, you should check the nocollide box, or adv duplicator might not dupe the gate.")

		local angleoffset = panel:NumSlider( "#WireGatesTool_angleoffset","wire_gates_angleoffset", 0, 360, 0 )

		function nocollidebox.Button:DoClick()
			self:Toggle()
		end

		function parentbox.Button:DoClick() -- when you check the parent box, check the nocollide box
			self:Toggle()
			if (self:GetChecked() == true) then
				nocollidebox:SetValue(1)
			end
		end

		----------------- GATE SELECTION & SEARCHING

		-- Create panels
		local searchbox = vgui.Create( "DTextEntry" )
		
		searchbox:SetValue( "Search..." )
		
		local old = searchbox.OnGetFocus
		function searchbox:OnGetFocus()
			if self:GetValue() == "Search..." then -- If "Search...", erase it
				self:SetValue( "" )
			end
			old( self )
		end
		
		-- On lose focus
		local old = searchbox.OnLoseFocus
		function searchbox:OnLoseFocus()
			if self:GetValue() == "" then -- if empty, reset "Search..." text
				timer.Simple( 0, function() self:SetValue( "Search..." ) end )
			end
			old( self )
		end
		
		local holder = vgui.Create( "DPanel" )
		holder:SetTall( 500 )

		local tree = vgui.Create( "DTree", holder )
		local searchlist = vgui.Create( "DListView", holder )
		searchlist:AddColumn( "Gate Name" )
		searchlist:AddColumn( "Category" )

		-- Thank you http://lua-users.org/lists/lua-l/2009-07/msg00461.html
		local function Levenshtein( s, t )
			local d, sn, tn = {}, #s, #t
			local byte, min = string.byte, math.min
			for i = 0, sn do d[i * tn] = i end
			for j = 0, tn do d[j] = j end
			for i = 1, sn do
				local si = byte(s, i)
				for j = 1, tn do
					d[i*tn+j] = min(d[(i-1)*tn+j]+1, d[i*tn+j-1]+1, d[(i-1)*tn+j-1]+(si == byte(t,j) and 0 or 1))
				end
			end
			return d[#d]
		end

		local string_find = string.find
		local table_SortByMember = table.SortByMember
		local string_lower = string.lower

		-- Searching algorithm
		local function Search( text )
			text = string_lower(text)

			local results = {}
			for action,gate in pairs( GateActions ) do
				local name = gate.name
				local lowname = string_lower(name)
				if string_find( lowname, text, 1, true ) then -- If it has ANY match at all
					results[#results+1] = { name = gate.name, group = gate.group, action = action, dist = Levenshtein( text, lowname ) }
				end
			end

			table_SortByMember( results, "dist", true )

			return results
		end

		-- Main searching
		local searching
		local anim = 0
		local animstart = 0
		function searchbox:OnTextChanged()
			local text = searchbox:GetValue()
			if text ~= "" then
				if not searching then
					searching = true
					local x,y = tree:GetPos()
					local w,h = tree:GetSize()
					searchlist:SetPos( x + w, y )
					searchlist:MoveTo( x, y, 0.1, 0, 1 )
					searchlist:SetSize( w, h )
					searchlist:SetVisible( true )
				end
				local results = Search( text )
				searchlist:Clear()
				for i=1,#results do
					local result = results[i]

					local line = searchlist:AddLine( result.name, result.group )
					local action = GetConVarString("wire_gates_action")
					if action == result.action then
						line:SetSelected( true )
					end
					line.action = result.action
				end
			else
				if searching then
					searching = false
					local x,y = tree:GetPos()
					local w,h = tree:GetSize()
					searchlist:SetPos( x, y )
					searchlist:MoveTo( x + w, y, 0.1, 0, 1 )
					searchlist:SetSize( w, h )
					timer.Create( "wire_customspawnmenu_hidesearchlist", 0.1, 1, function()
						if IsValid( searchlist ) then
							searchlist:SetVisible( false )
						end
					end )
				end
				searchlist:Clear()
			end
		end

		function searchlist:OnClickLine( line )
			-- Deselect old
			local t = searchlist:GetSelected()
			if t and next(t) then
				t[1]:SetSelected(false)
			end

			line:SetSelected(true) -- Select new
			RunConsoleCommand( "wire_gates_action", line.action )
		end
		
		function searchbox:OnEnter()
			if #searchlist:GetLines() > 0 then
				searchlist:OnClickLine( searchlist:GetLine( 1 ) )
			end
		end

		panel:AddItem( searchbox )
		
		tree:Dock( FILL )

		-- Set sizes & other settings
		searchlist:SetVisible( false )
		searchlist:SetMultiSelect( false )


		local function FillSubTree( tree, node, temp )
			node.Icon:SetImage( "icon16/arrow_refresh.png" )

			local subtree = {}
			for k,v in pairs( temp ) do
				subtree[#subtree+1] = { action = k, gate = v, name = v.name }
			end

			table_SortByMember(subtree, "name", true )

			local index = 0
			local max = #subtree

			timer.Create( "wire_gates_fillsubtree_delay"..tostring(subtree), 0, 0, function()
				index = index + 1

				local action, gate = subtree[index].action, subtree[index].gate
				local node2 = node:AddNode( gate.name or "No name found :(" )
				node2.name = gate.name
				node2.action = action
				function node2:DoClick()
					RunConsoleCommand( "wire_gates_Action", self.action )
				end
				node2.Icon:SetImage( "icon16/newspaper.png" )
				tree:InvalidateLayout()

				if index == max then
					timer.Remove("wire_gates_fillsubtree_delay" .. tostring(subtree))
					node.Icon:SetImage( "icon16/folder.png" )
				end
			end )
		end
		
		local CategoriesSorted = {}
		
		for gatetype, gatefuncs in pairs( WireGatesSorted ) do
			CategoriesSorted[#CategoriesSorted+1] = { gatetype = gatetype, gatefuncs = gatefuncs }
		end
		
		table.sort( CategoriesSorted, function( a, b ) return a.gatetype < b.gatetype end )

		for i=1,#CategoriesSorted do
			local gatetype = CategoriesSorted[i].gatetype
			local gatefuncs = CategoriesSorted[i].gatefuncs
			
			local node = tree:AddNode( gatetype )
			node.Icon:SetImage( "icon16/folder.png" )
			FillSubTree( tree, node, gatefuncs )
			function node:DoClick()
				self:SetExpanded( not self.m_bExpanded )
			end
		end

		-- add it all to the main panel
		panel:AddItem( holder )
	end
end

if SERVER then
	function TOOL:GetConVars() 
		return self:GetClientInfo( "action" ), self:GetClientNumber( "noclip" ) == 1
	end
	
	function TOOL:MakeEnt( ply, model, Ang, trace )
		return MakeWireGate( ply, trace.HitPos, Ang, model, self:GetConVars() )
	end
end

function TOOL:CheckMaxLimit()
	local action	= self:GetClientInfo( "action" )
	return self:GetSWEP():CheckLimit(self.MaxLimitName) and self:GetSWEP():CheckLimit("wire_gate_" .. string.lower( GateActions[action].group ) .. "s")
end


--------------------
-- RightClick
-- Copy gate
--------------------
function TOOL:RightClick( trace )
	if CLIENT then return true end
	if self:CheckHitOwnClass(trace) then
		local action = GateActions[trace.Entity.action]
		assert(action, "Attempted to copy gate " .. tostring(trace.Entity) .. " with no action!")

		self:GetOwner():ConCommand( "wire_gates_action " .. trace.Entity.action )
		self:GetOwner():ChatPrint( "Gate copied ('" .. action.name .. "')." )
		return true
	else
		return false
	end
end

--------------------
-- Reload
-- Increase angle offset by 45 degrees
--------------------
function TOOL:Reload( trace )
	if self:GetOwner():KeyDown( IN_SPEED ) then -- Unparent
		if (!trace or !trace.Hit) then return false end
		if (CLIENT and trace.Entity) then return true end
		if (trace.Entity:GetParent():IsValid()) then

			-- Get its position
			local pos = trace.Entity:GetPos()

			-- Unparent
			trace.Entity:SetParent()

			-- Teleport it back to where it was before unparenting it (because unparenting causes issues which makes the gate teleport to random wierd places)
			trace.Entity:SetPos( pos )

			-- Wake
			local phys = trace.Entity:GetPhysicsObject()
			if (phys) then
				phys:Wake()
			end

			-- Notify
			self:GetOwner():ChatPrint("Entity unparented.")
			return true
		end
		return false
	else
		if game.SinglePlayer() and SERVER then
			self:GetOwner():ConCommand( "wire_gates_angleoffset " .. (self:GetClientNumber( "angleoffset" ) + 45) % 360 )
		elseif CLIENT then
			RunConsoleCommand( "wire_gates_angleoffset", (self:GetClientNumber( "angleoffset" ) + 45) % 360 )
		end
	end

	return false
end

function TOOL:GetAngle( trace )
	local ang = WireToolObj.GetAngle(self, trace)
	ang:RotateAroundAxis( trace.HitNormal, self:GetClientNumber( "angleoffset" ) )
	return ang
end

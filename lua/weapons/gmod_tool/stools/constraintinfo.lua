TOOL.Category = "Constraints"
TOOL.Name = "#tool.constraintinfo.listname"
TOOL.Command = nil
TOOL.ConfigName = nil

if CLIENT then
	language.Add( "tool.constraintinfo.name", "Constraint Information Tool" )
	language.Add( "tool.constraintinfo.listname", "Constraint Info" )
	language.Add( "tool.constraintinfo.desc", "Displays constraints for selected entities." )
	language.Add( "tool.constraintinfo.0", "Click on an entity to draw constraint info. Right click an entity for even more info." )
	
	local drawdata = {} -- Will hold constraints for the draw function
	local drawtarget = nil -- Selected entity
	local constraintdata = {} -- Full table of constraint data
	
	--Specific colors for different constraints
	local colors = {
		Default = 		Color( 100, 100, 100, 255 ),
		Weld = 			Color( 255, 100, 100, 255 ),
		Nail = 			Color( 255, 100, 100, 255 ),
		NoCollide = 	Color( 100, 255, 100, 255 ),
		Rope = 			Color( 255, 255, 100, 255 ),
		Elastic = 		Color( 255, 255, 50,  255 ),
		Ballsocket = 	Color( 100, 100, 255, 255 ),
		AdvBallsocket =	Color( 100, 100, 255, 255 )
	}
	
	local function inview( pos2D )
		if	pos2D.x > -ScrW() and
			pos2D.y > -ScrH() and
			pos2D.x < ScrW() * 2 and
			pos2D.y < ScrH() * 2 then
				return true
		end
		return false
	end
    
    function TOOL:LeftClick( trace )
        return true
    end

    function TOOL:RightClick( trace )
        return true
    end
    
	function TOOL:DrawHUD()
		if not IsValid( drawtarget ) then return end
		
		local lpos, rpos, tpos
		
		for k, v in pairs( drawdata ) do
			if v.ent and ( v.ent:IsValid() or v.ent:IsWorld() ) then
				lpos = drawtarget:LocalToWorld( v.loc )
				
				if v.ent:IsWorld() then
					rpos = lpos + Vector( 0, 0, -25 )
				else
					rpos = v.ent:LocalToWorld( v.rem )
				end
				
				tpos = ( lpos + rpos ) / 2
				tpos = tpos:ToScreen()
				tpos.y = tpos.y - v.y
				
				lpos = lpos:ToScreen()
				rpos = rpos:ToScreen()
				
				surface.SetDrawColor( colors[v.typ] or colors["Default"] ) -- Set the constraint's drawing color
				
				if inview( lpos ) and inview( rpos ) then
					surface.DrawLine( lpos.x, lpos.y, rpos.x, rpos.y )
					draw.SimpleTextOutlined( v.txt, "DermaDefault", tpos.x, tpos.y, color_white, 1, 1, 1, color_black )
				end
			else
				drawdata[k] = nil -- If it's not valid, remove it from the constraints table.
			end
		end
	end
	
	local PANEL = {}
	
	function PANEL:Init() end

	function PANEL:Setup( vars )
		self:Clear()

		local text = self:Add( "DTextEntry" )
		text:SetDrawBackground( false )
		text:SetEditable( false )
		text:Dock( FILL )

		-- Return true if we're editing
		self.IsEditing = function( self ) return false end

		-- Set the value
		self.SetValue = function( self, val )
			text:SetText( util.TypeToString( val ) ) 
		end
	end
	
	derma.DefineControl( "DProperty_GenericNoEdit", "", PANEL, "DProperty_Generic" )
	
	local function ShowInfo()
		local frame = vgui.Create( "DFrame" )
		frame:SetSize( 512, ScrH() / 1.5 )
		frame:Center()
		frame:SetTitle( "Constraint Info for " .. tostring( drawtarget ) )
		frame:MakePopup()
		
		local tree = frame:Add( "DProperties" )
		tree:Dock( FILL )
		
		table.sort( constraintdata, function( a, b ) return string.lower( a.Type ) < string.lower( b.Type ) end )
		
		for k, c in ipairs( constraintdata ) do
			local typ = ( c.Type or "" )
			if typ == "" then typ = c.Constraint:GetClass() end
			
			local catname = k .. ". " .. typ
			
			local tbl = {}
			
			for prop, value in pairs( c ) do
				if type( value ) == "table" then continue end
				table.insert( tbl, { prop, value } )
			end
			
			table.sort( tbl, function( a, b ) return string.lower( a[1] ) < string.lower( b[1] ) end )
			
			for _, r in ipairs( tbl ) do
				local row = tree:CreateRow( catname, r[1] )
				row:Setup( "GenericNoEdit" )
				row:SetValue( tostring( r[2] ) )
			end
			
			tree:GetCategory( catname ).Container:SetVisible( false )
		end
	end

	local function Update( len )
		-- empty the constraints table
		drawdata = {}
		
		-- read data
		drawtarget = net.ReadEntity()
		constraintdata = net.ReadTable()

		local yoff = {}
		
		-- build table for drawhud function
		for _, c in pairs( constraintdata ) do
			local data = {}
			for _, e in pairs( c.Entity ) do
				if e.Entity and ( IsValid( e.Entity ) or e.Entity:IsWorld() ) then
					if e.Entity == drawtarget then
						data.loc = e.LPos or Vector( 0, 0, 0 )
					else
						data.ent = e.Entity
						
						local world = ""
						if data.ent:IsWorld() then world = "(WORLD) " end
						
						data.typ = ( c.Type or "" )
						if data.typ == "" then data.typ = c.Constraint:GetClass() end
						data.txt = world .. data.typ
						
						data.y = yoff[data.ent] or 0
						yoff[data.ent] = ( yoff[data.ent] or 0 ) + 7
						
						data.rem = e.LPos or Vector( 0, 0, 0 )
					end
				end
			end
			if data.ent then table.insert( drawdata, data ) end
		end
		
		if IsValid( drawtarget ) then
			local count = table.Count( drawdata )
			
			local ct = "no"
			if count > 0 then ct = tostring( count ) end
			
			local suf = "s"
			if count == 1 then suf = "" end
			
			LocalPlayer():PrintMessage( HUD_PRINTTALK, "Selected entity has " .. ct .. " constraint" .. suf .. "." )
		end
		
		if tobool( net.ReadBit() ) then
			ShowInfo()
		end
	end
	net.Receive( "constraintinfo_update", Update )
end

if SERVER then
	util.AddNetworkString( "constraintinfo_update" )
	
	local function getEntityConstraints( ent )
		local originalTbl = constraint.GetTable( ent ) 
        
		for k, const in ipairs( originalTbl ) do
			for field, val in pairs( const ) do
				if field == "OnDieFunctions" then
					originalTbl[k][field] = nil
				end
			end
		end
		
		return originalTbl
	end
	
	local function sendConstraintInfo( ply, ent, isDetailed )
		if ent and ent:IsWorld() then ent = nil end
		
		local tbl = getEntityConstraints( ent )
		
        xpcall(function()
            net.Start( "constraintinfo_update" )
                net.WriteEntity( ent )
                net.WriteTable( tbl )
                net.WriteBit( isDetailed ) -- do not show detailed info
            net.Send( ply )
        end, function( err )
            PrintTable( tbl ) MsgC(Color(255,0,0), err, "\n")
        end)
	end
    
    function TOOL:LeftClick( trace )
        sendConstraintInfo( self:GetOwner(), trace.Entity, false )
    end

    function TOOL:RightClick( trace )
        sendConstraintInfo( self:GetOwner(), trace.Entity, true )
    end
end
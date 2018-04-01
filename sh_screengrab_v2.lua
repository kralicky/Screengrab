if SERVER then
	local sg = {}
	local NWStrings = {
		"ScreengrabRequest",
		"StartScreengrab",
		"ScreengrabInitCallback",
		"ScreengrabConfirmation",
		"ScreengrabSendPart",
		"SendPartBack",
		"ScreengrabFinished",
		"rtxappend",
		"rtxappend2",
		"Progress",
		"ScreengrabInterrupted"
	}
	for k, v in next, NWStrings do
		util.AddNetworkString( v )
	end
	umsg.PoolString( "progress" )
	
	sg.white = "color_white"
	sg.black = "color_black"
	sg.red = "Color( 255, 0, 0 )"
	sg.green = "Color( 0, 255, 0 )"
	sg.orange = "Color( 255, 100, 0 )"
	sg.yellow = "Color( 255, 255, 0 )"
	sg.blue = "Color( 0, 200, 255 )"
	
	local meta = FindMetaTable( "Player" )
	
	function meta:CanScreengrab()
		return self:IsAdmin()
	end
	
	function meta:rtxappend( col, str )
		self:SendLua( [[rtxappend(]] .. col .. [[,"]] .. str .. [[")]] )
	end	

	net.Receive( "ScreengrabRequest", function( _, ply )
		local ent = net.ReadEntity()
		local qual = net.ReadUInt( 32 )
		for k, v in next, player.GetAll() do
			if v.isgrabbing and v ~= ply then
				ply:rtxappend( sg, red, "Error: " .. v:Name() .. "is screengrabbing " .. v.sg .. ". To reduce server stress, only one screengrab can be performed at once." )
				return
			end
		end
		if ply.isgrabbing then
			ply:rtxappend( sg.red, "Error: You are already screengrabbing someone" )
			return
		end
		if not IsValid( ent ) then
			ply:rtxappend( sg.red, "Error: Invalid target" )
			return
		end
		if ply:CanScreengrab() then
			ply:rtxappend( sg.green, "Initializing" )
			net.Start( "StartScreengrab" )
				net.WriteUInt( qual, 32 )
				net.WriteEntity( ply )
			net.Send( ent )		
			ent.sg = ply
			ply.sg = ent
		else
			ply:rtxappend( sg.red, "Error: Insufficient permissions" )
		end
	end )
	net.Receive( "ScreengrabInitCallback", function( _, ply )
		local tosend = net.ReadEntity()
		local parts = net.ReadUInt( 32 )
		local len = net.ReadUInt( 32 )
		local time = net.ReadFloat()
		ply.parts = parts
		ply.IsSending = true
		net.Start( "ScreengrabConfirmation" )
			net.WriteUInt( parts, 32 )
			net.WriteUInt( len, 32 )
			net.WriteFloat( time )
			net.WriteEntity( ply )
		net.Send( tosend )
	end )
	net.Receive( "ScreengrabSendPart", function( _, ply )
		local sendto = ply.sg
		local len = net.ReadUInt( 32 )
		local data = net.ReadData( len )
		if not ply.data then
			ply.data = {}
			ply.data[ 1 ] = data
			sendto:rtxappend( sg.blue, "Received 1st part" )
		else
			local num = table.getn( ply.data ) + 1
			ply.data[ num ] = data
			sendto:rtxappend( sg.blue, "Received " .. num .. STNDRD( num ) .. " part" )
		end
		if table.getn( ply.data ) == ply.parts then
			ply.IsSending = nil
			sendto:rtxappend( sg.green, "Preparing to send data [" .. ply.parts .. " parts]" )
			local i = 1
			timer.Create( "SendDataBack", 0.1, ply.parts, function()
				net.Start( "SendPartBack" )
					local x = ply.data[ i ]:len()
					net.WriteUInt( x, 32 )
					net.WriteData( ply.data[ i ], x )
				net.Send( sendto )
				sendto:rtxappend( sg.yellow, "Sent " .. i .. STNDRD( i ) .. " part" )
				i = i + 1
			end )
		end
	end )
	net.Receive( "ScreengrabFinished", function( _, ply )
		local _ply = ply.sg
		_ply.parts = nil
		_ply.data = nil
		ply.parts = nil
		ply.data = nil
		_ply.sg = nil
		ply.sg = nil
		ply.isgrabbing = nil
		_ply.isgrabbing = nil
		ply:rtxappend( sg.green, "Finished" )
	end )
	net.Receive( "rtxappend2", function( _, ply )
		local col = net.ReadColor()
		local str = net.ReadString()
		local tosend = net.ReadEntity()
		net.Start( "rtxappend" )
			net.WriteColor( col )
			net.WriteString( str )
		net.Send( tosend )
	end )
	net.Receive( "Progress", function( _, ply )
		local pl = net.ReadEntity()
		local num = net.ReadFloat()		
		umsg.Start( "progress", pl )
			umsg.Float( num )
		umsg.End()
	end )
	hook.Add( "PlayerDisconnected", "ScreengrabInterrupt", function( ply )
		if ply.IsSending then
			local _ply = ply.sg
			_ply.parts = nil
			_ply.data = nil
			ply.parts = nil
			ply.data = nil
			_ply.sg = nil
			ply.sg = nil
			ply.isgrabbing = nil
			_ply.isgrabbing = nil
			_ply:rtxappend( sg.red, "Target disconnected before their data finished sending" )
			net.Start( "ScreengrabInterrupted" )
			net.Send( _ply )
		end
	end )
end

if CLIENT then
	
	CreateClientConVar( "sg_auto_open", "0" )
	
	surface.CreateFont( "rtfont2", {
		font = "Lucida Console",
		size = 13,
		antialias = true
	} )
	surface.CreateFont( "asdf2", {
		font = "Lucida Console",
		size = 15,
		antialias = true
	} )
	surface.CreateFont( "topmenu2", {
		font = "Lucida Console",
		size = 15,
		antialias = true
	} )
		
	local sg = {}
	sg.white = color_white
	sg.black = color_black
	sg.red = Color( 255, 0, 0 )
	sg.green = Color( 0, 255, 0 )
	sg.orange = Color( 255, 100, 0 )
	sg.yellow = Color( 255, 255, 0 )
	sg.blue = Color( 0, 200, 255 )
	
	local progress = {}
	progress.num = 0
	progress.screenshot = nil
	local function cl_rtxappend2( color, text, ply )
		net.Start( "rtxappend2" )
			net.WriteColor( color )
			net.WriteString( text )
			net.WriteEntity( ply )
		net.SendToServer()
	end
	local shouldScreengrab = false
	local quality
	local _ply
	net.Receive( "StartScreengrab", function()
		shouldScreengrab = true
		quality = net.ReadUInt(32)
		_ply = net.ReadEntity()
	end)
	local render_Capture=render_Capture or render.Capture -- breaking render.Capture is a common way to prevent screengrabbing
	local util_Base64Encode=util_Base64Encode or util.Base64Encode -- breaking util.Base64Encode is a common way to prevent screengrabbing
	local util_Compress=util_Compress or util.Compress -- breaking util.Compress is another possible way to prevent screengrabbing
	hook.Add("PostRender", "Screengrab", function()
		if (!shouldScreengrab) then return end
		shouldScreengrab = false
		cl_rtxappend2( sg.green, "Initializing", _ply )		
		local function capture( q )
			local tab = {
				format = "jpeg",
				h = ScrH(),
				w = ScrW(),
				quality = q,
				x = 0,
				y = 0
			}
			local split = 20000
			local data = util_Compress(util_Base64Encode(render_Capture(tab)))
			local len = string.len( data )
			cl_rtxappend2( color_white, "Captured " .. len .. " bytes", _ply )
			local parts = math.ceil( len / split )
			cl_rtxappend2( color_white, parts .. " parts", _ply )
			local partstab = {}
			for i = 1, parts do
				local min
				local max
				if i == 1 then
					min = i
					max = split
				elseif i > 1 and i ~= parts then
					min = ( i - 1 ) * split + 1
					max = min + split - 1
				elseif i > 1 and i == parts then
					min = ( i - 1 ) * split + 1
					max = len
				end
				local str = string.sub( data, min, max )
				partstab[ i ] = str
			end
			local amt = table.getn( partstab )
			net.Start( "ScreengrabInitCallback" )
				net.WriteEntity( _ply )
				net.WriteUInt( amt, 32 )
				net.WriteUInt( len, 32 )
				net.WriteFloat( CurTime(), 32 )
			net.SendToServer()
			cl_rtxappend2( Color( 0, 255, 0 ), "Preparing to send data", _ply )
			local i = 1
			timer.Create( "ScreengrabSendParts", 0.1, amt, function()
				net.Start( "ScreengrabSendPart" )
					local l = partstab[ i ]:len()
					net.WriteUInt( l, 32 )
					net.WriteData( partstab[ i ], l )
				net.SendToServer()
				cl_rtxappend2( Color( 255, 255, 0 ), "Sent " .. i .. STNDRD( i ) .. " part", _ply )
				net.Start( "Progress" )
					net.WriteEntity( _ply )
					net.WriteFloat( ( i / amt ) / 2 )
				net.SendToServer()
				i = i + 1
			end )
		end
		capture( quality )
	end )
	local function DisplayData( str, name )
		local elapsedtime
		if not name then
			elapsedtime = math.Round( LocalPlayer().EndTime - LocalPlayer().StartTime, 3 )
		end
		local main = vgui.Create( "DFrame", vgui.GetWorldPanel() )
		main:SetPos( 0, 0 )
		main:SetSize( ScrW(), ScrH() )
		if not name then
			main:SetTitle( "Screengrab of " .. LocalPlayer().gfname .. " (" .. string.len( str ) .. " bytes, took " .. elapsedtime .. " seconds)" )
		else
			local str = name:sub( 1, -5 )
			main:SetTitle( str )
		end
		main:MakePopup()
		local html = vgui.Create( "HTML", main )
		html:DockMargin( 0, 0, 0, 0 )
		html:Dock( FILL )
		html:SetHTML( [[ <img width="]] .. ScrW() .. [[" height="]] .. ScrH() .. [[" src="data:image/jpeg;base64, ]] .. str .. [["/> ]] )
	end

	net.Receive( "ScreengrabInterrupted", function()
		cl_rtxappend( sg.red, "Connection with target interrupted" )
		LocalPlayer().InProgress = nil
		progress.screenshot = nil
		progress.num = 0
	end )
	
	net.Receive( "ScreengrabConfirmation", function()
		local parts = net.ReadUInt( 32 )
		local len = net.ReadUInt( 32 )
		local time = net.ReadFloat()
		local ent = net.ReadEntity()
		LocalPlayer().parts = parts
		LocalPlayer().len = len
		LocalPlayer().StartTime = time
		LocalPlayer().gfname = ent:Name()
	end )
	net.Receive( "SendPartBack", function()
		local len = net.ReadUInt( 32 )
		local data = net.ReadData( len )
		if not LocalPlayer().sgtable then
			LocalPlayer().sgtable = {}
			LocalPlayer().sgtable[ 1 ] = data
			cl_rtxappend( sg.blue, "Received 1st part" )
			progress.num = ( ( 1 / LocalPlayer().parts ) / 2 ) + 0.5
		else
			local x = table.getn( LocalPlayer().sgtable ) + 1
			LocalPlayer().sgtable[ x ] = data
			cl_rtxappend( sg.blue, "Received " .. x .. STNDRD( x ) .. " part" )
			progress.num = ( ( x / LocalPlayer().parts ) / 2 ) + 0.5
		end
		if table.getn( LocalPlayer().sgtable ) == LocalPlayer().parts then
			cl_rtxappend( sg.orange, "Constructing data" )
			local con = table.concat( LocalPlayer().sgtable )
			local d = util.Decompress( con )
			LocalPlayer().EndTime = CurTime()
			if GetConVar( "sg_auto_open" ):GetInt() == 0 then
				progress.screenshot = d
			else
				progress.screenshot = d
				DisplayData( d )
			end
			cl_rtxappend( sg.green, "Finished" )
			net.Start( "ScreengrabFinished" )
			net.SendToServer()
			LocalPlayer().InProgress = nil
		end
	end )
	
	local main
	function OpenSGMenu()
	
		if main then
			return
		end
		
		main = vgui.Create( "DFrame" )
		main:SetSize( 635, 300 )
		main:SetTitle( "" )
		main:SetVisible( true )
		main:ShowCloseButton( true )
		main:MakePopup()
		main:Center()	
		main.btnMaxim:Hide()
		main.btnMinim:Hide() 
		main.btnClose:Hide()
		main.Paint = function()
			surface.SetDrawColor( 50, 50, 50, 135 )
			surface.DrawOutlinedRect( 0, 0, main:GetWide(), main:GetTall() )
			surface.SetDrawColor( 0, 0, 0, 240 )
			surface.DrawRect( 1, 1, main:GetWide() - 2, main:GetTall() - 2 )
			surface.SetFont( "topmenu2" )
			surface.SetTextPos( main:GetWide() / 2 - surface.GetTextSize( "Screengrab Menu" ) / 2, 5 ) 
			surface.SetTextColor( 255, 255, 255, 255 )
			surface.DrawText( "Screengrab Menu" )
		end
		
		local close = vgui.Create( "DButton", main )
		close:SetPos( main:GetWide() - 50, 0 )
		close:SetSize( 44, 22 )
		close:SetText( "" )
		
		local colorv = Color( 150, 150, 150, 250 )
		function PaintClose()
			if not main then 
				return 
			end
			surface.SetDrawColor( colorv )
			surface.DrawRect( 1, 1, close:GetWide() - 2, close:GetTall() - 2 )	
			surface.SetFont( "asdf2" )
			surface.SetTextColor( 255, 255, 255, 255 )
			surface.SetTextPos( 19, 3 ) 
			surface.DrawText( "x" )
			return true
		end
		
		close.Paint = PaintClose		
		close.OnCursorEntered = function()
			colorv = Color( 195, 75, 0, 250 )
			PaintClose()
		end	
		
		close.OnCursorExited = function()
			colorv = Color( 150, 150, 150, 250 )
			PaintClose()
		end	
		
		close.OnMousePressed = function()
			colorv = Color( 170, 0, 0, 250 )
			PaintClose()
		end	
		
		close.OnMouseReleased = function()
			if not LocalPlayer().InProgress then
				main:Close()
			end
		end	
		
		main.OnClose = function()
			main:Remove()
			if main then
				main = nil
			end
		end	
		
		local inside = vgui.Create( "DPanel", main )
		inside:SetPos( 7, 27 )
		inside:SetSize( main:GetWide() - 14, main:GetTall() - 34 )
		inside.Paint = function()
			surface.SetDrawColor( 255, 255, 255, 255 )
			surface.DrawOutlinedRect( 0, 0, inside:GetWide(), inside:GetTall() )
			surface.SetDrawColor( 255, 255, 255, 250 )
			surface.DrawRect( 1, 1, inside:GetWide() - 2, inside:GetTall() - 2 )
		end
		
		local plys = vgui.Create( "DComboBox", inside )
		plys:SetPos( 5, 5 )
		plys:SetSize( 150, 25 )
		plys:AddChoice( "Select a Player", nil, true )
		plys.curChoice = "Select a Player"
		
		for k, v in next, player.GetHumans() do
			plys:AddChoice( v:Nick(), v )
		end
		
		plys.OnSelect = function( pnl, index, value )
			local ent = plys.Data[ index ]
			plys.curChoice = ent
		end
		local q = vgui.Create( "Slider", inside )
		q:SetPos( 5, 55 )
		q:SetWide( 180 )
		q:SetMin( 1 )
		q:SetMax( 90 )
		q:SetDecimals( 0 )
		q:SetValue( 50 )
		
		local execute = vgui.Create( "DButton", inside )
		execute:SetPos( 5, 35 )
		execute:SetSize( 150, 25 )
		execute:SetText( "Screengrab" )
		execute.Think = function()
			local cur = plys.curChoice
			if cur and not isstring( cur ) then
				execute:SetDisabled( false )
			else
				execute:SetDisabled( true )
			end
		end
		
		execute.DoClick = function()
			LocalPlayer().parts = nil
			LocalPlayer().len = nil
			LocalPlayer().StartTime = nil
			LocalPlayer().gfname = nil
			LocalPlayer().sgtable = nil
			progress.screenshot = nil
			progress.num = 0
			timer.Simple( 0.1, function()
				net.Start( "ScreengrabRequest" )
					net.WriteEntity( plys.curChoice )
					net.WriteUInt( q:GetValue(), 32 )
				net.SendToServer()
				LocalPlayer().InProgress = true
			end )
		end
		
		local auto = vgui.Create( "DCheckBoxLabel", inside )
		auto:SetPos( 5, 83 )
		auto:SetText( "Automatically Open" )
		auto:SetDark( true )
		auto:SizeToContents()
		auto:SetConVar( "sg_auto_open" )
		
		local files = vgui.Create( "DListView", inside )
		files:SetPos( 5, 100 )
		files:SetSize( 150, 110 )
		files:AddColumn( "Screenshots" )
		files.filetable = {}
		files:SetHeaderHeight( 15 )
		local f = file.Find( "screengrabs/*.txt", "DATA" )
		files.filetable = f
		for k, v in next, f do
			files:AddLine( v )
		end

		files.Think = function()
			local f = file.Find( "screengrabs/*.txt", "DATA" )
			if table.ToString( files.filetable ) ~= table.ToString( f ) then
				files.filetable = f
				files:Clear()
				for k, v in next, f do
					files:AddLine( v )
				end
			end
		end
		
		files.OnRowRightClick = function( main, line )
			local menu = DermaMenu()
				menu:AddOption( "Delete file", function()
					local f = files:GetLine( line ):GetValue( 1 )
					file.Delete( "screengrabs/" .. f )
				end ):SetIcon( "icon16/delete.png" )
				menu:AddOption( "View Screenshot", function()
					local f = file.Read( "screengrabs/" .. files:GetLine( line ):GetValue( 1 ), "DATA" )
					hook.Add( "Think", "wait", function()
						if f and isstring( f ) and string.len( f ) > 1 then
							DisplayData( f, files:GetLine( line ):GetValue( 1 ) )
							hook.Remove( "Think", "wait" )
						end
					end )
				end ):SetIcon( "icon16/zoom.png" )
			menu:Open()
		end
		
		local svlogs = vgui.Create( "DFrame", inside )
		svlogs:SetSize( 220, 230 )
		svlogs:SetPos( 165, 5 )
		svlogs:SetTitle( "Server Logs" )
		svlogs:SetSizable( false )
		svlogs.Paint = function() 
			surface.SetDrawColor( Color( 0, 0, 0, 250 ) )
			surface.DrawRect( 0, 0, svlogs:GetSize() )
		end
		svlogs:ShowCloseButton( false )

		rtx = vgui.Create( "RichText", svlogs )
		rtx:Dock( FILL )
		rtx.Paint = function()
			rtx.m_FontName = "rtfont2"
			rtx:SetFontInternal( "rtfont2" )	
			rtx:SetBGColor( Color( 0, 0, 0, 0 ) )		
			rtx.Paint = nil
		end
		rtx:InsertColorChange( 255, 255, 255, 255 )
		
		function rtxappend( color, text )
			if rtx:IsValid() and rtx:IsVisible() then
				if type( color ) == "string" then
					rtx:AppendText( color .. "\n" )
					return
				end
				if IsValid( rtx ) then
					rtx:InsertColorChange( color.r, color.g, color.b, color.a or 255 )
					rtx:AppendText( text .. "\n" )
					rtx:InsertColorChange( 255, 255, 255, 255 )
				end
			end
		end	
		
		local cllogs = vgui.Create( "DFrame", inside )
		cllogs:SetSize( 220, 230 )
		cllogs:SetPos( 395, 5 )
		cllogs:SetTitle( "Client Logs" )
		cllogs:SetSizable( false )
		cllogs.Paint = function() 
			surface.SetDrawColor( Color( 0, 0, 0, 250 ) )
			surface.DrawRect( 0, 0, cllogs:GetSize() )
		end
		cllogs:ShowCloseButton( false )
		
		cl_rtx = vgui.Create( "RichText", cllogs )
		cl_rtx:Dock( FILL )
		cl_rtx.Paint = function()
			cl_rtx.m_FontName = "rtfont2"
			cl_rtx:SetFontInternal( "rtfont2" )	
			cl_rtx:SetBGColor( Color( 0, 0, 0, 0 ) )		
			cl_rtx.Paint = nil
		end
		cl_rtx:InsertColorChange( 255, 255, 255, 255 )
		
		function cl_rtxappend( color, text )
			if cl_rtx:IsValid() and cl_rtx:IsVisible() then
				cl_rtx:InsertColorChange( color.r, color.g, color.b, color.a or 255 )
				cl_rtx:AppendText( text .. "\n" )
				cl_rtx:InsertColorChange( 255, 255, 255, 255 )
			end
		end
		net.Receive( "rtxappend", function()
			local col = net.ReadColor()
			local str = net.ReadString()
			cl_rtxappend( col, str )
		end )
		local pro = vgui.Create( "DProgress", inside )
		pro:SetPos( 165, 241 )
		pro:SetSize( 450, 20 )
		pro:SetFraction( 0 )
		pro.Think = function()
			pro:SetFraction( progress.num )
		end
		
		
		progress.open = vgui.Create( "DButton", inside )
		progress.open:SetPos( 4, 241 )
		progress.open:SetSize( 150, 20 )
		progress.open:SetText( "Open" )
		progress.open:SetDisabled( true )
		progress.open.screenshot = nil
		progress.open.DoClick = function()
			DisplayData( progress.screenshot )
		end
		
		cl_rtx.Think = function()
			if type( progress.screenshot ) == "string" then
				progress.open:SetDisabled( false )
			elseif type( progress.screenshot ) == "nil" then
				progress.open:SetDisabled( true )
			end
		end
		
		local save = vgui.Create( "DButton", inside )
		save:SetPos( 4, 220 )
		save:SetSize( 150, 20 )
		save:SetText( "Save Data" )
		save:SetDisabled( true )
		rtx.Think = function()
			if type( progress.screenshot ) == "string" then
				save:SetDisabled( false )
			elseif type( progress.screenshot ) == "nil" then
				save:SetDisabled( true )
			end
		end
		
		save.DoClick = function()
			if not file.Exists( "screengrabs", "DATA" ) then
				file.CreateDir( "screengrabs" )
			end
			local name = LocalPlayer().gfname .. " - " .. os.date( "%m_%d %H_%M_%S" ) .. ".txt"
			local text = progress.screenshot
			cl_rtxappend( Color( 255, 100, 0 ), "Saving to file: " .. name .. " (" .. string.len( text ) .. " bytes)" )
			file.Write( "screengrabs/" .. name, text )
			timer.Simple( 1, function()
				if file.Exists( "screengrabs/" .. name, "DATA" ) then
					cl_rtxappend( Color( 255, 100, 0 ), "Screenshot saved!" )
				else
					cl_rtxappend( Color( 255, 0, 0 ), "Error: Screenshot not saved!" )
				end
			end )
		end
		
	end
	concommand.Add( "screengrab", OpenSGMenu )
	usermessage.Hook( "progress", function( um )
		progress.num = um:ReadFloat()
	end )
end

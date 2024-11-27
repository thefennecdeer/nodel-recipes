' 23/09/2024
' Nodel Control Script v2.0
' Troy Takac (troy@fennecdeer.com)

function Nodel_Initialize(msgPort as object, userVariables as object, bsp as object)
	Nodel = newNodel(msgPort, userVariables, bsp)
	return Nodel
end function

function newNodel(msgPort as object, userVariables as object, bsp as object)
	' Create the object to return and set it up
	s = {}
	s.msgPort = msgPort
	s.userVariables = userVariables
	s.bsp = bsp
	s.ProcessEvent = Nodel_ProcessEvent
	s.sTime = CreateObject("roSystemTime")
	s.HandleTimerEvent = HandleTimerEvent
	s.StartTimer = StartTimer
	s.readTimer = CreateObject("roTimer")
	s.readTimer.SetPort(s.msgPort)
	s.FirstCheck = true
	s.PluginSendMessage = PluginSendMessage
	s.Generate_SnapShot_to_Folder = Generate_SnapShot_to_Folder
	s.AddHttpHandlers = AddHttpHandlers

	s.GetStatusinfo = GetStatusinfo
	s.PlaybackZone = PlaybackZone
	s.SetMuteConnectorHandler = SetMuteConnectorHandler
	s.SetMuteConnector = SetMuteConnector
	s.SetVolConnectorHandler = SetVolConnectorHandler
	s.SetVolConnector = SetVolConnector
	s.RebootPlayer = RebootPlayer
	s.DefaultsPlayer = DefaultsPlayer
	
	s.Subscribe = Subscribe
	s.Unsubscribe = Unsubscribe
	s.CurrentSubscribers = []
	s.PlaybackSingleZone = PlaybackSingleZone
	s.SleepSingleZone = SleepSingleZone
	s.LoadRegistry = LoadRegistry

	s.SendUDPMessage = SendUDPMessage
	s.AudioConnectors = ["analog", "hdmi", "hdmi1", "hdmi2", "hdmi3", "hdmi4", "spdif"]

	s.Registry = CreateObject("roRegistrySection", "Nodel")
	
	videoMode = CreateObject("roVideoMode")
		if type(videoMode) = "roVideoMode" then
			s.SleepSingleZone("true", videoMode)
		end if
		
	s.HandleMessageEventPlugin = HandleMessageEventPlugin
	
	s.AddStatusUrls = AddStatusUrls
	s.HandleHTTPEventPlugin = HandleHTTPEventPlugin
	s.nc = CreateObject("roNetworkConfiguration", 0)
	s.PlayerIP = ""
	s.currentConfig = ""
	s.currentConfig = s.nc.GetCurrentConfig()
	if s.currentConfig <> invalid then
		s.PlayerIP = s.currentConfig.ip4_address
	end if

	s.Storage = "SD:"
	s.Path = "/"
	s.vmPlugin = CreateObject("roVideoMode")
	s.AddHttpHandlers()

	reg = CreateObject("roRegistrySection", "networking")
	reg.write("ssh","22")
	n=CreateObject("roNetworkConfiguration", 0)
	
	print "network: ";n.GetClientIdentifier()
	n.SetLoginPassword("nodel")
	n.Apply()
	reg.flush()
	return s
end function

function Generate_SnapShot_to_Folder() as boolean
	DoesSnapshotFolderExist = MatchFiles("/", "mySnap")
	if DoesSnapshotFolderExist.count() <= 0 then
		IsFoldercreationOK = CreateDirectory("mySnap")
		if IsFoldercreationOK then
			status = "true"
		else
			status = "false"
		end if
		m.bsp.diagnostics.PrintDebug(" @@@ IsFoldercreationOK ? @@@ " + status)
	else if DoesSnapshotFolderExist.count() > 0 then
		screenShotParam = CreateObject("roAssociativeArray")
		screenShotParam["filename"] = m.Storage + m.Path + "mySnap/LastSnapshot.jpg"
		screenShotParam["width"] = m.vmPlugin.GetResX()
		screenShotParam["height"] = m.vmPlugin.GetResY()
		screenShotParam["filetype"] = "JPEG"
		screenShotParam["quality"] = 25
		screenShotParam["async"] = 0
		screenShotTaken = m.vmPlugin.Screenshot(screenShotParam)
		if screenShotTaken then
			status = "true"
		else
			status = "false"
		end if
		m.bsp.diagnostics.PrintDebug(" @@@ Screenshot Taken @@@ " + status)
	end if
end function

function Nodel_ProcessEvent(event as object) as boolean
	retval = false
	print "Nodel_ProcessEvent - entry"
	print "type of m is ";type(m)
	print "type of event is ";type(event)
	if type(event) = "roHttpEvent" then
		retval = HandleHTTPEventPlugin(event, m)
	end if
	if type(event) = "roStorageAttached" then
		if m.FirstCheck = true then
			m.LoadRegistry()
			m.FirstCheck = false
		end if
	end if
	if type(event) = "roControlDown" then
		msg = {}
		msg.event = "button down"
		msg.gpio = event.GetInt()
		m.SendUDPMessage(FormatJson(msg), m)
	end if
	if type(event) = "roControlUp" then
		msg = {}
		msg.event = "button up"
		msg.gpio = event.GetInt()
		m.SendUDPMessage(FormatJson(msg), m)
	end if
	if type(event) = "roVideoEvent" then
		print "event: ";event
		if event = 3 then
			
			msg = {}
			msg.event = "media start"
			print "Video Started: ";m.bsp.getvideozone(0).playbackfilename$
			msg.file = m.bsp.getvideozone(0).playbackfilename$
			msg.previousfile = m.bsp.getvideozone(0).previousstatename$
			m.SendUDPMessage(FormatJson(msg), m)
		else if event = 8 then
			msg = {}
			msg.event = "media ended"
			msg.file = m.bsp.getvideozone(0).playbackfilename$
			m.SendUDPMessage(FormatJson(msg), m)
		end if
	else if type(event) = "roTimerEvent" then
		print "timer event: "event;
		retval = HandleTimerEvent(event, m)
	else if type(event) = "roAssociativeArray" then
		if type(event["EventType"]) = "roString"
			if event["EventType"] = "EVENT_PLUGIN_MESSAGE" then
				if event["PluginName"] = "Nodel" then
					pluginMessage$ = event["PluginMessage"]
				end if
			else if event["EventType"] = "SEND_PLUGIN_MESSAGE" then
				if event["PluginName"] = "Nodel" then
					pluginMessage$ = event["PluginMessage"]
					retval = HandleMessageEventPlugin(pluginMessage$, m)
				end if
			end if
		end if
	end if
	return retval
end function

sub SendUDPMessage(msg as object, s as object)
	if type(s.bsp.pluginUDPsender) <> "roDatagramSender" then
		s.bsp.pluginUDPsender = createobject("roDatagramSender")
	end if
	if s.CurrentSubscribers <> invalid then
		
		n = s.CurrentSubscribers.Count()
		i = 0
		while (i < n)
			r = CreateObject("roRegex", ":", "i")
			fields=r.split(s.CurrentSubscribers[i])
			s.bsp.pluginUDPsender.SetDestination(fields[0],fields[1].ToInt())
			mybytes=createobject("roByteArray")
			mybytes.FromAsciiString(msg)
			s.bsp.pluginUDPsender.Send(mybytes)
			i = i + 1
		end while
		
	end if
end sub

function HandleMessageEventPlugin(origMsg as object, s as object) as boolean
	msg = lcase(origMsg)
	r = CreateObject("roRegex", "!", "i")
	fields=r.split(msg)
	if fields <> invalid then
		numFields = fields.count()
		if fields[0] = "customaction" then
			newmsg = {}
			if numFields > 1 then
				' Do we have arguments? 
				r2 = CreateObject("roRegex", "&", "i")
				fields2=r2.split(fields[1])
				numFields2 = fields2.count()
				if numFields > 1 then
					newmsg.name = fields2[0]
					newmsg.arg = fields2[1]
					newmsg.event = fields[0]
					s.SendUDPMessage(FormatJson(newmsg), s)
				else
				' we dont have arguments
					newmsg.name = fields[1]
					newmsg.event = fields[0]
					s.SendUDPMessage(FormatJson(newmsg), s)
				end if
			end if
		end if
	end if
end function



function HandleHTTPEventPlugin(origMsg as object, Custom as object) as boolean
	userData = origMsg.GetUserData()
	if type(userdata) = "roAssociativeArray" and type(userdata.HandleEvent) = "roFunction" then
		userData.HandleEvent(userData, origMsg)
	end if
end function

sub AddHttpHandlers()
	m.pluginLocalWebServer = CreateObject("roHttpServer", { port: 8081 })
	m.pluginLocalWebServer.SetPort(m.msgPort)
	m.AddStatusUrls()
end sub

sub LoadRegistry()
	print "Loading Registry"
	if m.Registry.Exists("powersave") then
		if m.Registry.Read("powersave") = "false" then
			videoMode = CreateObject("roVideoMode")
			if type(videoMode) = "roVideoMode" then
				m.SleepSingleZone("false", videoMode)
			end if
		end if
	else
		m.Registry.Write("powersave", "false")
		videoMode = CreateObject("roVideoMode")
		if type(videoMode) = "roVideoMode" then
			m.SleepSingleZone("false", videoMode)
		end if
	end if

	if m.Registry.Exists("playing") then
		if m.Registry.Read("playing") = "false" then
			for each zone in m.bsp.sign.zonesHSM
				if zone.videoplayer <> invalid then 
					m.PlaybackSingleZone("pause", zone)
				end if
			end for
		end if
	else
		m.Registry.Write("playing", "true")
	end if

	if m.Registry.Exists("volume") then
		print "Volume found"
	else
		m.Registry.Write("volume", "100")
	end if


	if m.Registry.Exists("muted") then
		if m.Registry.Read("muted") = "true" then
			m.SetMuteConnector(m, "0")
			m.SetVolConnector(m, m.Registry.Read("volume"))
		else
			m.SetVolConnector(m, m.Registry.Read("volume"))
		end if
	else
		print "No Registry Data"
		m.Registry.Write("muted", "false")
		m.Registry.Write("volume", "100")
		m.Registry.Write("powersave", "false")
		m.Registry.Write("playing", "true")

	end if
	m.Registry.Flush()
end sub

sub AddStatusUrls()
	m.GetStatusinfoAA = { HandleEvent: m.GetStatusinfo, mVar: m }
	m.SetPlaybackZoneAA = { HandleEvent: m.PlaybackZone, mVar: m }
	m.SetMuteConnectorAA = { HandleEvent: m.SetMuteConnectorHandler, mVar: m }
	m.SetVolConnectorAA = { HandleEvent: m.SetVolConnectorHandler, mVar: m }
	m.RebootPlayerAA = { HandleEvent: m.RebootPlayer, mVar: m }
	m.DefaultsPlayerAA = { HandleEvent: m.DefaultsPlayer, mVar: m }
	m.SubscribeAA = { HandleEvent: m.Subscribe, mVar: m }
	m.UnsubscribeAA = { HandleEvent: m.Unsubscribe, mVar: m }
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/status", user_data: m.GetStatusinfoAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/playback", user_data: m.SetPlaybackZoneAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/mute", user_data: m.SetMuteConnectorAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/volume", user_data: m.SetVolConnectorAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/reboot", user_data: m.RebootPlayerAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/default", user_data: m.DefaultsPlayerAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/subscribe", user_data: m.SubscribeAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/unsubscribe", user_data: m.UnsubscribeAA })
end sub

function RebootPlayer(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()

	for each keys in args
		if lcase(keys) = "reboot" then
			e.SetResponseBodyString("Blank")
			e.SendResponse(200)
			RebootSystem()
   			stop
			
		end if
	end for 
end function

function DefaultsPlayer(userData as object, e as object) as boolean
	mVar = userData.mVar
	mVar.Registry.Write("muted", "false")
	mVar.Registry.Write("volume", "100")
	mVar.Registry.Write("powersave", "false")
	mVar.Registry.Write("playing", "true")
	mVar.Registry.Write("subscribers", "{'active':[]}")
	e.SetResponseBodyString("Blank")
	e.SendResponse(200)
end function

function PlaybackZone(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()
	print args
	for each keys in args
		if lcase(keys) = "playback" then
			if args.zone <> invalid then
				if lcase(args[keys]) = "pause" then
					for each zone in mVar.bsp.sign.zonesHSM
						if lcase(zone.name$) = lcase(args.zone) then
							print "Found Zone to Pause: "; args.zone
							if zone.videoplayer <> invalid then zone.videoplayer.Pause()
						end if
					end for
				else if lcase(args[keys]) = "play" then
					for each zone in mVar.bsp.sign.zonesHSM
						if lcase(zone.name$) = lcase(args.zone) then
							print "Found Zone to Play: "; args.zone
							if zone.videoplayer <> invalid then zone.videoplayer.Play()
						end if
					end for
				end if
			else
				if lcase(args[keys]) = "pause" then
					for each zone in mVar.bsp.sign.zonesHSM
						if zone.videoplayer <> invalid then 
							mVar.PlaybackSingleZone("pause", zone)
							mVar.Registry.Write("playing", "false")
						end if
					end for
				end if
				if lcase(args[keys]) = "play" then
					for each zone in mVar.bsp.sign.zonesHSM
						if zone.videoplayer <> invalid then 
							videoMode = CreateObject("roVideoMode")
							if mVar.Registry.Read("powersave") = "false" then
								mVar.SleepSingleZone("false", videoMode)
								mVar.Registry.Write("powersave", "false")
							end if
							mVar.PlaybackSingleZone("play", zone)
							mVar.Registry.Write("playing", "true")
						end if
					end for
				end if
			end if
		else if lcase(keys) = "sleep" then
			if lcase(args[keys]) = "true" then
				videoMode = CreateObject("roVideoMode")
				if type(videoMode) = "roVideoMode" then
					mVar.SleepSingleZone("true", videoMode)
					mVar.Registry.Write("powersave", "true")
					for each zone in mVar.bsp.sign.zonesHSM
						if type(zone) = "roAssociativeArray" then
							mVar.SetVolConnector(mVar, "0")
							if zone.videoplayer <> invalid then 
								mVar.PlaybackSingleZone("pause", zone)
								mVar.Registry.Write("playing", "false")
							end if
						end if
					end for
				end if
				videoMode = invalid
			else if lcase(args[keys]) = "false" then
				videoMode = CreateObject("roVideoMode")
				if type(videoMode) = "roVideoMode" then
					mVar.SleepSingleZone("false", videoMode)
					mVar.Registry.Write("powersave", "false")
					for each zone in mVar.bsp.sign.zonesHSM
						if type(zone) = "roAssociativeArray" then
							if zone.videoplayer <> invalid then 
								mVar.PlaybackSingleZone("play", zone)
								mVar.Registry.Write("playing", "true")
							end if
						end if
					end for
				end if
				videoMode = invalid
			end if
		end if
	end for
	e.SetResponseBodyString("Blank")
	e.SendResponse(200)
end function

function PlaybackSingleZone(state as object, zone as object) as boolean
	if state = "play" then
		zone.videoplayer.Play()
	else if state = "pause" then	
		zone.videoplayer.Pause()
	end if
end function

function SleepSingleZone(state as object, videoMode as object) as boolean
	if state = "true" then
		videoMode.SetPowerSaveMode(true)
	else if state = "false" then	
		videoMode.SetPowerSaveMode(false)
	end if
end function


function SetVolConnector(userData as object, volume as string) as boolean
	mVar = userData.mVar
	volParams = {}
	print "Volume: ";(volume.ToInt())
	if type(m.bsp.AudioConnectors) = "roArray" then
		for each connector in m.bsp.AudioConnectors
			connector$ = connector
			volume% = int(val(volume))
			if lcase(connector$) = "analog" or lcase(connector$) = "analog1" then
				m.bsp.analogVolume% = ExecuteChangeConnectorVolume("Analog:1", volume%, m.bsp.sign.audio1MinVolume%, m.bsp.sign.audio1MaxVolume%)
			else if lcase(connector$) = "hdmi" then
				m.bsp.hdmiVolume% = ExecuteChangeConnectorVolume("HDMI", volume%, m.bsp.sign.hdmiMinVolume%, m.bsp.sign.hdmiMaxVolume%)
			else if lcase(connector$) = "hdmi1" then
				m.bsp.hdmi1Volume% = ExecuteChangeConnectorVolume("HDMI:1", volume%, m.bsp.sign.hdmi1MinVolume%, m.bsp.sign.hdmi1MaxVolume%)
			else if lcase(connector$) = "hdmi2" then
				m.bsp.hdmi2Volume% = ExecuteChangeConnectorVolume("HDMI:2", volume%, m.bsp.sign.hdmi2MinVolume%, m.bsp.sign.hdmi2MaxVolume%)
			else if lcase(connector$) = "hdmi3" then
				m.bsp.hdmi3Volume% = ExecuteChangeConnectorVolume("HDMI:3", volume%, m.bsp.sign.hdmi3MinVolume%, m.bsp.sign.hdmi3MaxVolume%)
			else if lcase(connector$) = "hdmi4" then
				m.bsp.hdmi4Volume% = ExecuteChangeConnectorVolume("HDMI:4", volume%, m.bsp.sign.hdmi4MinVolume%, m.bsp.sign.hdmi4MaxVolume%)
			else if lcase(connector$) = "spdif" then
				m.bsp.spdifVolume% = ExecuteChangeConnectorVolume("SPDIF", volume%, m.bsp.sign.spdifMinVolume%, m.bsp.sign.spdifMaxVolume%)
			end if
		end for
	end if
	m.Registry.Write("volume", volume)
	m.Registry.Flush()
end function

function SetVolConnectorHandler(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()
	for each keys in args
		mVar.SetVolConnector(userData, keys)
	end for
	e.SetResponseBodyString("Set Volume!")
	e.SendResponse(200)
end function

function SetMuteConnector(userData as object, mute as string) as boolean
	mVar = userData.mVar
	muteBool = false
	muteStr = "false"
	volParams = {}

	if mute = "mute" then
		muteBool = true
		muteStr = "true"
	else
		muteBool = false
		muteStr = "false"
	end if
	

	for each connectors in m.bsp.AudioConnectors
		volParams.connector = connectors
		m.bsp.MuteAudioOutputs(muteBool, volParams)
	end for
	m.Registry.Write("muted", muteStr)
	m.Registry.Flush()
end function

function SetMuteConnectorHandler(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()

	for each keys in args
		mVar.SetMuteConnector(userData, keys)
	end for
	e.SetResponseBodyString("Set Mute!")
	e.SendResponse(200)
end function

function GetStatusinfo(userData as object, e as object) as boolean
	mVar = userData.mVar
	out = {}
	modelObject = CreateObject("roDeviceInfo")
	out.AddReplace("model", modelObject.GetModel())
	out.AddReplace("serialNumber", modelObject.GetDeviceUniqueId())
	out.AddReplace("playing", mVar.Registry.Read("playing"))
	out.AddReplace("sleep", mVar.Registry.Read("powersave"))
	out.AddReplace("videomode", mVar.bsp.sign.videomode$)
	out.AddReplace("volume", mVar.Registry.Read("volume"))
	out.AddReplace("muted", mVar.Registry.Read("muted"))
	playlistTemp = []
	if mVar.bsp.getvideozone(0) <> invalid then
		for each keys in mVar.bsp.getvideozone(0).stateTable
			playlistTemp.push(keys)
		end for
		out.AddReplace("playlist", playlistTemp)
	end if
	if mVar.CurrentSubscribers <> invalid then
		out.AddReplace("currentSubscribers", mVar.CurrentSubscribers) 
	end if
	if mVar.bsp.activePresentation <> invalid then
		out.AddReplace("activePresentation", mVar.bsp.activePresentation$) 
	end if
	
	isTheHeaderAddedOK = e.AddResponseHeader("Content-type", "application/json")
	e.SetResponseBodyString(FormatJson(out))
	e.SendResponse(200)
end function


function Subscribe(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()
	tempaddress = ""
	tempport = ""
	for each keys in args
		if lcase(keys) = "address" then
			tempaddress = args[keys]
		else if lcase(keys) = "port"
			tempport = args[keys]
		end if
	end for

	print "address: ";tempaddress
	print "port: ";tempport


	if tempaddress <> "" and tempport <> "" then
		tempfull = tempaddress + ":" + tempport
		print "full: ";tempfull

		if mVar.CurrentSubscribers <> invalid then
			n = mVar.CurrentSubscribers.Count()
			i = 0
			while (i < n)
				print "active: "; mVar.CurrentSubscribers[i]
				if mVar.CurrentSubscribers[i] = tempfull then
					e.SetResponseBodyString("Already Subscribed!")
					e.SendResponse(200)
					return false
				end if
				i = i + 1
			end while
		end if
		
		mVar.CurrentSubscribers.push(tempfull)
		print "final json: ";FormatJson(mVar.CurrentSubscribers)

		e.SetResponseBodyString("Added!")
		e.SendResponse(200)
	else
		e.SetResponseBodyString("incorrect formatting!")
		e.SendResponse(400)
	end if	

end function

function Unsubscribe(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()
	tempaddress = ""
	tempport = ""
	for each keys in args
		if lcase(keys) = "address" then
			tempaddress = args[keys]
		else if lcase(keys) = "port"
			tempport = args[keys]
		end if
	end for

	print "address: ";tempaddress
	print "port: ";tempport


	if tempaddress <> "" and tempport <> "" then
		tempfull = tempaddress + ":" + tempport
		print "full: ";tempfull

		if mVar.CurrentSubscribers <> invalid then
			n = mVar.CurrentSubscribers.Count()
			i = 0
			while (i < n)
				print "active: "; mVar.CurrentSubscribers[i]
				if mVar.CurrentSubscribers[i] = tempfull then
					mVar.CurrentSubscribers.Delete(i)
					e.SetResponseBodyString("Unsubscribed!")
					e.SendResponse(200)
					return true
				end if
				i = i + 1
			end while
		end if

		e.SetResponseBodyString("Not Currently Subscribed!")
		e.SendResponse(200)
	else
		e.SetResponseBodyString("incorrect formatting!")
		e.SendResponse(400)
	end if	

end function

function StartTimer()
	newTimeout = m.sTime.GetLocalDateTime()
	newTimeout.AddSeconds(5)
	m.readTimer.SetDateTime(newTimeout)
	m.readTimer.Start()
end function

function HandleTimerEvent(origMsg as object, Custom as object) as boolean
	retval = false
	timerIdentity = origMsg.GetSourceIdentity()
	if Custom.readTimer.GetIdentity() = timerIdentity then
		timerIdentity = origMsg.GetSourceIdentity()
	end if
end function

function PluginSendMessage(Pmessage$ as string)
	pluginMessageCmd = CreateObject("roAssociativeArray")
	pluginMessageCmd["EventType"] = "EVENT_PLUGIN_MESSAGE"
	pluginMessageCmd["PluginName"] = "Nodel"
	pluginMessageCmd["PluginMessage"] = Pmessage$
	m.msgPort.PostMessage(pluginMessageCmd)
end function

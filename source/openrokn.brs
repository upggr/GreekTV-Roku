' Name: OpenRokn
' Homepage: http://openrokn.sourceforge.net
' Description: Open source Roku channel building kit
' Author: kavulix
' 
' Copyright (C) 2011 kavulix
' 
' Licensed under the Apache License, Version 2.0 (the "License");
' you may not use this file except in compliance with the License.
' You may obtain a copy of the License at
'
' http://www.apache.org/licenses/LICENSE-2.0
'
' Unless required by applicable law or agreed to in writing, software
' distributed under the License is distributed on an "AS IS" BASIS,
' WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
' See the License for the specific language governing permissions and
' limitations under the License.



Sub Main()
	initConstants()
	initGlobalDialogOps()

	success = testPkgIntegrity()
	if not(success) then
		print "unrecoverable errors encountered - channel now exiting"
		return
	endif

	' set overhang background, logo and color scheme
	success = initTheme()
	if not(success) then
		print "unrecoverable errors encountered - channel now exiting"
		return
	endif

	' save preferences to global object
	success = loadPreferences()
	if not(success) then
		print "unrecoverable errors encountered - channel now exiting"
		return
	endif

	' test for adrise requirements and enable/disable ads
	manageAdrise()

	splash = createSplashScreen()
	splash.Show()

	feedurl = getCustomFeed()
	xe = validateFeed(feedurl, true)
	if not(type(xe) = "roXMLElement") then
		feedurl = getDefaultFeed()
		xe = validateFeed(feedurl, true)
		if not(type(xe) = "roXMLElement") then
			feedurl = getFailsafeFeed()
			xe = validateFeed(feedurl, true)
			if not(type(xe) = "roXMLElement") then
				print "unrecoverable errors encountered - channel now exiting"
				return
			endif
		endif
	endif

	' save url of currently loaded feed
	gaa = GetGlobalAA()
	gaa.feeds.Push(feedurl)

	itype = xe.channel[0].item[0]@type
	if itype = "poster" then
		displayPoster("", xe.channel[0].item[0])
	else 'itype = "grid"
		' the type attribute was already tested in the validateFeed
		' function so we know that if it is not a poster then it
		' must be a grid
		displayGrid("", xe.channel[0].item[0])
	endif
End Sub

Sub initConstants()
	gaa = GetGlobalAA()
	gaa.feeds = []
	gaa.constants = {}
	' paths
	gaa.constants.path = {}
	gaa.constants.path.failsafe = "pkg:/control/failsafe.xml"
	gaa.constants.path.manifest = "pkg:/control/manifest.xml"
	gaa.constants.path.style = "pkg:/control/style.xml"
	gaa.constants.path.preferences = "pkg:/control/preferences.xml"
	' max lengths
	gaa.constants.maxlength = {}
	gaa.constants.maxlength.breadcrumb = 18
	gaa.constants.maxlength.posterTitle = 58
	gaa.constants.maxlength.posterShortDesc = 58
	gaa.constants.maxlength.posterFullDesc = 202
	gaa.constants.maxlength.gridTitle = 58
	gaa.constants.maxlength.gridShortDesc = 58
	gaa.constants.maxlength.gridFullDesc = 202
	gaa.constants.maxlength.documentTitle = 40
	gaa.constants.maxlength.springboardFullDesc = 260
End Sub

Function testPkgIntegrity() As Boolean
	gaa = GetGlobalAA()

	' parse manifest.xml and retrieve title, version, required files and checksums
	xe = CreateObject("roXMLElement")
	if not(xe.Parse(ReadAsciiFile(gaa.constants.path.manifest))) then
		print "cannot parse manifest.xml"
		return false
	endif

	if not(xe.title.Count() > 0) or not(xe.version.Count() > 0) then
		print "manifest.xml improperly structured"
		return false
	endif

	title = getStringAttribute(xe.title[0], "value", false)
	major = getStringAttribute(xe.version[0], "major", false)
	minor = getStringAttribute(xe.version[0], "minor", false)
	build = getStringAttribute(xe.version[0], "build", false)
	if len(title) < 1 or len(major) < 1 or len(minor) < 1 or len(build) < 1 then
		print "manifest.xml improperly structured"
		return false
	endif

	print title
	print "v";major;".";minor;" build";build
	print chr(10);"Searching for required files..."

	for i = 0 to xe.required.Count() - 1
		flist = MatchFiles("pkg:/source/", xe.required[i]@file)
		if flist.Count() > 0 then
			print xe.required[i]@file;": found"
		else
			flist = MatchFiles("pkg:/control/", xe.required[i]@file)
			if flist.Count() > 0 then
				print xe.required[i]@file;": found"
			else
				print xe.required[i]@file;": NOT FOUND!"
				return false
			endif
		endif
	end for

	print chr(10);"Generating and comparing hashes..."

	for i = 0 to xe.checksum.Count() - 1
		fileContents = CreateObject("roByteArray")
		' we only hash files located in the source folder since theyre
		' assumed to be read-only
		success = fileContents.ReadFile("pkg:/source/" + xe.checksum[i]@file)
		if not(success) then
			print "The contents of ";xe.checksum[i]@file;" could not be read"
			return false
		endif
		digest = CreateObject("roEVPDigest")
		digest.Setup("sha1")
		digest.Update(fileContents)
		fileHash = digest.Final()
		if fileHash = xe.checksum[i]@hash then
			print fileHash;" ";xe.checksum[i]@file;" : success"
		else
			' we dont exit on a failed match since the user may have only
			' modified a single character in the source code. we just
			' report the error and continue.
			print fileHash;" ";xe.checksum[i]@file;" : FAIL!"
		endif
	end for
	return true
End Function

Function initTheme() As Boolean
	gaa = GetGlobalAA()

	' parse the style.xml file and retrieve the theme settings
	xe = CreateObject("roXMLElement")
	if not(xe.Parse(ReadAsciiFile(gaa.constants.path.style))) then
		print "cannot parse style.xml"
		return false
	endif

	if not(xe.theme.Count() > 0) then
		print "style.xml improperly structured"
		return false
	endif

	print chr(10);"Initializing theme..."

	theme = {}

	for i = 0 to xe.theme.Count() - 1
		tname = getStringAttribute(xe.theme[i], "name", false)
		if len(tname) > 0 then
			tvalue = getStringAttribute(xe.theme[i], "value", true)
			if len(tvalue) > 0 then
				ecode = Eval("theme." + tname + " = " + chr(34) + tvalue + chr(34))
				if not(type(ecode) = "Integer") or (not(ecode = 252) and not(ecode = 226)) then
					print "cannot set theme option: ";tname
				endif
			else
				print "cannot set theme option: ";tname
			endif
		else
			print "cannot set theme option: ";tname
		endif
	end for

	app = CreateObject("roAppManager")
	app.SetTheme(theme)
	return true
End Function

Function loadPreferences() As Boolean
	gaa = GetGlobalAA()

	' parse the preferences.xml file and save values to global object
	xe = CreateObject("roXMLElement")
	if not(xe.Parse(ReadAsciiFile(gaa.constants.path.preferences))) then
		print "cannot parse preferences.xml"
		return false
	endif

	if not(xe.pref.Count() > 0) then
		print "preferences.xml improperly structured"
		return false
	endif

	print chr(10);"Loading preferences..."

	gaa.prefs = {}
	' we cant count on all of the pref elements being
	' available in the xml file so we define them here
	gaa.prefs.pfurl = ""
	gaa.prefs.rbsurl = ""
	gaa.prefs.eiurl = ""
	gaa.prefs.searchurl = ""
	gaa.prefs.sdsplashurl = "pkg:/images/splash_sd.png"
	gaa.prefs.hdsplashurl = "pkg:/images/splash_hd.png"
	gaa.prefs.postercounterbground = "#FFFFFF"
	gaa.prefs.postercountertext = "#000000"
	gaa.prefs.exitgridtoprow = false
	gaa.prefs.scrollsb = false
	gaa.prefs.enableadrise = false
	gaa.prefs.overhangheightsd = 92
	gaa.prefs.overhangheighthd = 138

	for i = 0 to xe.pref.Count() - 1
		pname = getStringAttribute(xe.pref[i], "name", false)
		if len(pname) > 0 then
			pvalue = getStringAttribute(xe.pref[i], "value", true)
			if len(pvalue) > 0 and gaa.prefs.DoesExist(pname) then
				ptype = type(gaa.prefs[pname])
				if ptype = "roString" then
					gaa.prefs[pname] = pvalue
				elseif ptype = "roInteger" then
					gaa.prefs[pname] = getIntegerAttribute(xe.pref[i], "value", gaa.prefs[pname])
				elseif ptype = "roBoolean" then
					gaa.prefs[pname] = getBoolAttribute(xe.pref[i], "value", gaa.prefs[pname])
				else
					print "cannot set preference: ";pname
				endif
			else
				print "cannot set preference: ";pname
			endif
		else
			print "cannot set preference: ";pname
		endif
	end for
	return true
End Function

Sub manageAdrise()
	gaa = GetGlobalAA()
	if not(gaa.prefs.enableadrise) then
		print "adrise DISABLED"
		return
	endif

	requiredFiles = ["adrise_ad.brs","generalUtils.brs","urlUtils.brs"]
	for i = 0 to requiredFiles.Count() - 1
		flist = MatchFiles("pkg:/source/", requiredFiles[i])
		if flist.Count() < 1 then
			' set global pref to disabled
			gaa.prefs.enableadrise = false
			print "adrise DISABLED"
			return
		endif
	end for

	print "adrise ENABLED"
End Sub

' we maintain a reference to any open loading dialogs in
' a global object so that they can be closed from any
' method or script
Sub initGlobalDialogOps()
	gaa = GetGlobalAA()
	gaa.dialog = {}
	gaa.dialog.isShown = false
	gaa.dialog.canceled = false
	gaa.dialog.romd = {}
	gaa.dialog.timer = CreateObject("roTimespan")
	gaa.dialog.minimumDelay = 300
	gaa.dialog.minimumShow = 400
	' these functions are only meant to be used for message dialogs that contain
	' a single cancel button and a loading animation. for alerts and other
	' dialog types use the non-global createMessageDialog function.
	gaa.dialog.createMessageDialog = Function(port As Object, title As String, message As String, isLoading As Boolean, buttons As Object)
		if type(m.romd) = "roMessageDialog" then
			m.close()
		endif
		dialog = CreateObject("roMessageDialog")
		if not(type(port) = "roMessagePort") then
			port = CreateObject("roMessagePort")
		endif
		dialog.SetMessagePort(port)
		dialog.SetTitle(title)
		if len(message) > 0 then dialog.SetText(message)
		dialog.EnableOverlay(true)
		if isLoading then dialog.ShowBusyAnimation()
		for i = 0 to buttons.Count() - 1
			dialog.AddButton(buttons[i].index, buttons[i].label)
		end for
		m.romd = dialog
		m.timer.Mark() ' restart the timer
	End Function
	gaa.dialog.getPort = Function() As Object
		if type(m.romd) = "roMessageDialog" then
			return m.romd.GetMessagePort()
		else
			return CreateObject("roMessagePort")
		endif
	End Function
	gaa.dialog.close = Function()
		if type(m.romd) = "roMessageDialog" then
			m.romd.Close()
			m.romd = {}
			m.isShown = false
			m.canceled = false
		endif
	End Function
	gaa.dialog.delayClose = Function() As Boolean 'return value = isCanceled
		if type(m.romd) = "roMessageDialog" then
			totalMS = m.timer.TotalMilliseconds()
			if m.isShown and totalMS < m.minimumShow then
				msg = wait(m.minimumShow - totalMS, m.romd.GetMessagePort())
				if type(msg) = "roMessageDialogEvent" and msg.isButtonPressed() and msg.GetIndex() = 1 then
					m.close()
					return true
				endif
			endif
			m.close()
		endif
		return false
	End Function
	gaa.dialog.show = Function()
		if type(m.romd) = "roMessageDialog" and not(m.isShown) then
			m.isShown = true
			m.romd.Show()
			m.timer.Mark() ' restart the timer
		endif
	End Function
	gaa.dialog.delayShow = Function(ms As Integer) ' -1 forces m.minimumDelay to be used
		if type(m.romd) = "roMessageDialog" and not(m.isShown) then
			if (ms > 0 and m.timer.TotalMilliseconds() > ms) or ms = 0 or m.timer.TotalMilliseconds() > m.minimumDelay then
				m.show()
			endif
		endif
	End Function
	gaa.dialog.isCanceled = Function() As Boolean
		if type(m.romd) = "roMessageDialog" then
			msg = wait(1, m.romd.GetMessagePort())
			if type(msg) = "roMessageDialogEvent" and msg.isButtonPressed() and msg.GetIndex() = 1 then
				print "cancel event detected"
				m.canceled = true
			endif
		endif
		return m.canceled
	End Function
End Sub

Function createSplashScreen() As Object
	' if a splash screen is not displayed prior to displaying the loading
	' dialog then the initial screen that is displayed when the main feed
	' is retrieved will display odd colors. the title text color will be
	' the same as the background color making it impossible to read and
	' the button color may be a violet hue. setting the background color
	' with the theme object has no effect on this bug.

	gaa = GetGlobalAA()

	dinfo = CreateObject("roDeviceInfo")
	dsize = dinfo.GetDisplaySize()
	dtype = dinfo.GetDisplayType()
	width = dsize.w
	height = dsize.h

	if dtype = "HDTV" then
		iurl = gaa.prefs.hdsplashurl
		if not(width = 1280) or not(height = 720) then
			print "WARNING: unusual screen dimensions detected. the splash screen may not display properly."
		endif
	else
		iurl = gaa.prefs.sdsplashurl
		if not(width = 720) or not(height = 480) then
			print "WARNING: unusual screen dimensions detected. the splash screen may not display properly."
		endif
	endif

	image = {
		Color:"#000000",
		CompositionMode:"Source",
		Url:iurl,
		TargetRect:{x:0,y:0}
	}

	canvas = CreateObject("roImageCanvas")
	canvas.AllowUpdates(true)
	canvas.SetLayer(0, image)
	return canvas
End Function

Function getCustomFeed() As String
	return getStrValFromReg("primaryfeed", "profile")
End Function

Function getDefaultFeed() As String
	gaa = GetGlobalAA()
	return gaa.prefs.pfurl
End Function

Function getFailsafeFeed() As String
	gaa = GetGlobalAA()
	return gaa.constants.path.failsafe
End Function

' we keep track of all loaded feeds so we can access them from
' extensions and send the feed url as part of the emailInformation
' and reportBrokenStream requests
Function getCurrentFeed() As String
	gaa = GetGlobalAA()
	if gaa.feeds.Count() > 0 then
		return gaa.feeds[gaa.feeds.Count() - 1]
	endif
	return ""
End Function

Function validateFeed(feedurl As String, isPrimary = false As Boolean, sendDevID = false As Boolean, hideAlert = false As Boolean, template = "" As String, posterurl = "" As String) As Object
	gaa = GetGlobalAA()

	' get the original file name
	fname = getFileNameFromUrl(feedurl)

	' retrieve and save xml feed to temp folder. the local
	' path will be returned on success. all errors are
	' handled by the saveXMLFeed function so we dont need
	' to add code for errors here or delete the temp file.
	' url will be validated in the saveXMLFeed function so
	' we dont need to test it here.
	path = saveXMLFeed(feedurl, sendDevID, hideAlert)
	if len(path) < 1 then return {}

	if gaa.dialog.isCanceled() then
		DeleteFile(path)
		return {}
	endif

	' we have to make sure that the feed uses UTF-8 encoding. if the
	' feed uses an encoding like windows-1252 then we wont be able to
	' parse the xml. the only way to work around this is to rewrite
	' the xml header and set the encoding to UTF-8.
	success = testXMLEncoding(path)
	if not(success) then
		print "incompatible xml encoding"
		DeleteFile(path)
		return {}
	endif

	if gaa.dialog.isCanceled() then
		DeleteFile(path)
		return {}
	endif

	' try to parse original feed
	xe = CreateObject("roXMLElement")
	if not(xe.Parse(ReadAsciiFile(path))) then
		print "cannot parse ";fname
		DeleteFile(path)
		return {}
	endif

	if gaa.dialog.isCanceled() then
		DeleteFile(path)
		return {}
	endif

	' convert unsupported xml format (e.g., rss) to orml if a
	' template is specified and root element is not orml
	if not(xe.IsName("orml")) then
		print "unsupported xml format detected"
		if len(template) > 0 then
			print template;" template detected"
			print "attempting to convert to orml"
			success = convertXMLFeedToORML(path, isPrimary, template, posterurl)
			if not(success) then
				print "xml conversion failed"
				DeleteFile(path)
				return {}
			endif

			if gaa.dialog.isCanceled() then
				DeleteFile(path)
				return {}
			endif

			' try to parse converted feed
			xe = CreateObject("roXMLElement")
			if not(xe.Parse(ReadAsciiFile(path))) or not(xe.IsName("orml")) then
				print "xml conversion failed"
				DeleteFile(path)
				return {}
			endif

			print "xml conversion successful"
		else
			print "no template specified"
			DeleteFile(path)
			return {}
		endif
	endif

	if isPrimary then
		' if we add line breaks after each "or" it will break the script
		if not(xe.channel.Count() > 0) or not(xe.channel[0].item.Count() > 0) or not(xe.channel[0].item[0].HasAttribute("type")) then
			print fname;" improperly structured"
			return {}
		endif

		itype = xe.channel[0].item[0]@type
		if itype = "poster" then
			if not(xe.channel[0].item[0].item.Count() > 0) and (not(xe.channel[0].item[0].HasAttribute("feedurl")) or len(xe.channel[0].item[0]@feedurl) < 1) then
				' we cant display a poster screen that doesnt contain any items or a feedurl
				print fname;" improperly structured"
				return {}
			endif
		elseif itype = "grid"
			if not(xe.channel[0].item[0].row.Count() > 0) then
				' we cant display a grid screen that doesnt contain any rows
				print fname;" improperly structured"
				return {}
			endif
		else
			' primary feeds must begin with a poster or grid item
			print fname;" improperly structured"
			return {}
		endif
	else
		if not(xe.feed.Count() > 0) or not(xe.feed[0].item.Count() > 0) or not(xe.feed[0].item[0].HasAttribute("type")) then
			print fname;" improperly structured"
			return {}
		endif
	endif

	if gaa.dialog.isCanceled() then
		return {}
	endif

	return xe
End Function

Function saveXMLFeed(url As String, sendDevID As Boolean, hideAlert = false As Boolean) As String
	' validate the url
	if len(url) < 1 then return ""

	if not(isValidUrl(url)) then
		print "feed url is invalid"
		return ""
	endif

	print chr(10);"Downloading feed..."
	gaa = GetGlobalAA()
	port = gaa.dialog.getPort()

	fname = convertUrlToFileName(url, ".xml")
	path = "tmp:/" + fname

	' does local xml file already exist for this url?
	flist = MatchFiles("tmp:/", fname)
	if flist.Count() > 0 then
		print "feed already cached"
		return path
	elseif left(url, 4) = "pkg:" then
		print "local file url detected"
		success = CopyFile(url, path)
		if success then
			print "feed successfully cached"
			return path
		else
			print "could not cache feed"
			' always delete the file before returning from this function
			' so that we avoid leaving incomplete cached feeds
			DeleteFile(path)
			return ""
		endif
	else
		http = CreateObject("roUrlTransfer")
		http.SetPort(port)
		'http.InitClientCertificates()
		if sendDevID then http.AddHeader("X-Roku-Reserved-Dev-Id", "")
		http.SetUrl(url)
		success = http.AsyncGetToFile(path)
		if not(success) then
			print "url transfer failed"
			' always delete the file before returning from this function
			' so that we avoid leaving incomplete cached feeds
			DeleteFile(path)
			return ""
		endif

		while true
			msg = wait(0, port)
			if type(msg) = "roMessageDialogEvent" then
				if msg.isButtonPressed() and msg.GetIndex() = 1 then
					print "download canceled"
					http.AsyncCancel()
					' always delete the file before returning from this function
					' so that we avoid leaving incomplete cached feeds
					DeleteFile(path)
					return ""
				endif
			elseif type(msg) = "roUrlEvent"
				print "http status code: ";msg.GetResponseCode()
				if msg.GetInt() = 1 and msg.GetResponseCode() = 200 then
					print "feed successfully cached"
					return path
				else
					print msg.GetFailureReason()
					if not(hideAlert) then alert("Alert", "Could not connect to server. Please try again later.")
					' always delete the file before returning from this function
					' so that we avoid leaving incomplete cached feeds
					DeleteFile(path)
					return ""
				endif
			endif
		end while
	endif
End Function

Function saveDocument(url As String, hideAlert = false As Boolean) As String
	' validate the url
	if len(url) < 1 then return ""

	if not(isValidUrl(url)) then
		print "document url is invalid"
		return ""
	endif

	print chr(10);"Downloading document..."
	gaa = GetGlobalAA()
	port = gaa.dialog.getPort()

	fname = convertUrlToFileName(url, ".txt")
	path = "tmp:/" + fname

	' does local xml file already exist for this url?
	flist = MatchFiles("tmp:/", fname)
	if flist.Count() > 0 then
		print "document already cached"
		return path
	elseif left(url, 4) = "pkg:" then
		print "local file url detected"
		success = CopyFile(url, path)
		if success then
			print "document successfully cached"
			return path
		else
			print "could not cache document"
			' always delete the file before returning from this function
			' so that we avoid leaving incomplete cached documents
			DeleteFile(path)
			return ""
		endif
	else
		http = CreateObject("roUrlTransfer")
		http.SetPort(port)
		'http.InitClientCertificates()
		'http.AddHeader("X-Roku-Reserved-Dev-Id", "")
		http.SetUrl(url)
		success = http.AsyncGetToFile(path)
		if not(success) then
			print "url transfer failed"
			' always delete the file before returning from this function
			' so that we avoid leaving incomplete cached documents
			DeleteFile(path)
			return ""
		endif

		while true
			msg = wait(0, port)
			if type(msg) = "roMessageDialogEvent" then
				if msg.isButtonPressed() and msg.GetIndex() = 1 then
					print "download canceled"
					http.AsyncCancel()
					' always delete the file before returning from this function
					' so that we avoid leaving incomplete cached documents
					DeleteFile(path)
					return ""
				endif
			elseif type(msg) = "roUrlEvent"
				print "http status code: ";msg.GetResponseCode()
				if msg.GetInt() = 1 and msg.GetResponseCode() = 200 then
					print "document successfully cached"
					return path
				else
					print msg.GetFailureReason()
					if not(hideAlert) then alert("Alert", "Could not connect to server. Please try again later.")
					' always delete the file before returning from this function
					' so that we avoid leaving incomplete cached documents
					DeleteFile(path)
					return ""
				endif
			endif
		end while
	endif
End Function

Function testXMLEncoding(path As String) As Boolean
	success = true
	feed = ReadAsciiFile(path)
	fre = CreateObject("roRegex", "\<\?xml\s.*?encoding\=\x22([^\x22]+)\x22.*?\?\>", "s")
	fmatches = fre.Match(feed)
	if fmatches.Count() > 1 then
		print UCase(fmatches[1]);" encoding detected"
		enc = LCase(fmatches[1])
		if not(enc = "utf-8") then
			print "attempting to convert to UTF-8"
			ere = CreateObject("roRegex", reEscape(fmatches[1]), "")
			xmlheader = ere.Replace(fmatches[0], "UTF-8")
			success = WriteAsciiFile(path, fre.Replace(feed, xmlheader))
			if success then
				print "encoding conversion successful"
			else
				print "encoding conversion failed"
			endif
		endif
	endif
	return success
End Function

Function getCounterLayers(iindex As Integer, total As Integer) As Object
	gaa = GetGlobalAA()
	dinfo = CreateObject("roDeviceInfo")
	dsize = dinfo.GetDisplaySize()
	dtype = dinfo.GetDisplayType()

	bgroundX = 60 - 83 + dsize.w - (60 * 2)
	bgroundW = 70
	if dtype = "HDTV" then
		bgroundY = gaa.prefs.overhangheighthd + 10
	else
		bgroundY = gaa.prefs.overhangheightsd + 10
	endif
	bgroundH = 20

	' layer 0 provides the background for the page number. without this
	' layer the index number text (layer 1) cannot be cleared successfully
	' which results in each page number overlaying the previous one.
	bground = {
		Color:gaa.prefs.postercounterbground, CompositionMode:"Source",
		TargetRect:{x:bgroundX,y:bgroundY,w:bgroundW,h:bgroundH}
	}

	' layer 1 displays the index number of the selected item
	itemIndex = {
		Color:gaa.prefs.postercounterbground, CompositionMode:"Source",
		Text:str(iindex + 1) + "/" + str(total),
		TextAttrs: {
			Color:gaa.prefs.postercountertext, Font:"Small",
			HAlign:"Center", VAlign:"Center",
			TextDirection:"LeftToRight"
		},
		TargetRect:{x:bgroundX,y:bgroundY,w:bgroundW,h:bgroundH}
	}

	return [bground,itemIndex]
End Function

Sub popFeed(url)
	gaa = GetGlobalAA()
	if len(url) > 0 and gaa.feeds.Count() > 1 and gaa.feeds[gaa.feeds.Count() - 1] = url then
		gaa.feeds.Pop()
	endif
End Sub

Function getPosterBookmark(xe As Object) As Object
	bkmk = {}
	bkmk.length = 0
	bkmk.resume = 0

	url = ""
	itype = getStringAttribute(xe, "type", false)
	' new attribute in orml v1.2
	format = getStringAttribute(xe, "streamformat", false)
	if len(format) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		format = getStringAttribute(xe, "format", false)
	endif
	live = getBoolAttribute(xe, "live")

	if live or format = "hls" then
		return bkmk
	endif

	if itype = "video" or itype = "audio" then
		length = getIntegerAttribute(xe, "length")
		if length > 0 then
			bkmk.length = length
			streams = getAudioVideoStreams(xe)
			if streams.Count() > 0 then
				url = streams[0].url
			endif
		endif
	else 'itype = "slideshow"
		length = xe.image.Count()
		if length > 0 then
			bkmk.length = length
			url = getStringAttribute(xe.image[0], "url", true)
		endif
	endif

	if len(url) > 0 then
		urlhash = hashString(url, "md5")
		resume = getIntValFromReg(urlhash, itype)
		if resume > 0 and bkmk.length > resume then
			bkmk.resume = resume
		endif
	endif

	return bkmk
End Function

Sub displayPoster(parentTitle As String, xe As Object)
	gaa = GetGlobalAA()
	gaa.dialog.createMessageDialog(CreateObject("roMessagePort"), "Loading...", "", true, [{index:1,label:"Cancel"}])
	gaa.dialog.show()

	pindex = 0
	posterurl = ""

	title = getStringAttribute(xe, "title", true)
	style = getStringAttribute(xe, "style", false, "flat-category")
	feedurl = getStringAttribute(xe, "feedurl", true)
	enablecounter = getBoolAttribute(xe, "enablecounter")

	ere = CreateObject("roRegex", "episodic", "")
	ematches = ere.Match(style)
	isEpisodic = (ematches.Count() > 0)

	if len(feedurl) > 0 then
		usetemplate = getStringAttribute(xe, "usetemplate", false)

		' this is only used if the feedurl attribute is specified and only
		' if the defaultSDPoster property in the template is empty
		posterurl = getStringAttribute(xe, "hdposterurl", true)
		if len(posterurl) < 1 then
			posterurl = getStringAttribute(xe, "sdposterurl", true)
		endif

		rootElem = validateFeed(feedurl, false, false, false, usetemplate, posterurl)
		if not(type(rootElem) = "roXMLElement") then
			print "cannot display poster screen"
			gaa.dialog.close()
			return
		endif

		' remove the usetemplate attribute from the poster item. we
		' can assume that since we have made it this far that the
		' feed has either been converted successfully or it is
		' already in orml format.
		xe.AddAttribute("usetemplate","")

		' preserve existing title and style of poster screen.
		' the feed element will be used as a poster item.
		rootElem.feed[0].AddAttribute("title", title)
		rootElem.feed[0].AddAttribute("style", style)

		' set xe to the feed element which will simulate a poster item
		xe = rootElem.feed[0]

		' keep track of all loaded feeds
		gaa.feeds.Push(feedurl)
	else
		' theres no point in showing a poster screen that doesnt contain
		' any items. the feedurl has already been tested so we only test
		' the original feed for items.
		if xe.item.Count() < 1 then
			print "there are no items to display"
			gaa.dialog.close()
			return
		endif
	endif

	port = CreateObject("roMessagePort")
	poster = createPosterScreen(parentTitle, xe)
	poster.SetMessagePort(port)

	' we cant close the dialog until after we call isCanceled since closing
	' the dialog resets the gaa.dialog.romd object.
	canceled = gaa.dialog.isCanceled()
	gaa.dialog.close()
	if canceled then
		popFeed(feedurl)
		return
	endif

	poster.Show()

	' allow poster screen enough time to be generated and displayed
	' before overlaying it with the canvas. add more time to the
	' first sleep() since it may take a while to download and display
	' multiple remote image urls.
	msDelay = 75
	sleep(msDelay * 8)

	if enablecounter then
		layers = getCounterLayers(pindex, xe.item.Count())
		textLayer = layers[1]
		canvas = CreateObject("roImageCanvas")
		canvas.AllowUpdates(true)
		canvas.SetMessagePort(port)
		canvas.SetLayer(0, layers[0])
		canvas.SetLayer(1, textLayer)
		canvas.Show()
	endif

	while true
		msg = wait(0, port)
		if type(msg) = "roPosterScreenEvent" then
			if msg.isScreenClosed() then
				popFeed(feedurl)
				return
			elseif msg.isListItemSelected()
				index = msg.GetIndex()
				itype = getStringAttribute(xe.item[index], "type", false)

				if itype = "poster" then
					displayPoster(title, xe.item[index])
				elseif itype = "grid"
					displayGrid(title, xe.item[index])
				elseif itype = "document"
					displayDocument(title, xe.item[index])
				elseif itype = "settings"
					' we have to completely exit the settings screen in order
					' to refresh the content
					reloadPage = true
					while reloadPage
						reloadPage = displaySettings(title, xe.item[index])
					end while
				elseif itype = "video" or itype = "audio" or itype = "slideshow"
					' we return the selected item index from the displaySpringboard
					' function since it is possible to scroll through the items
					' from the springboard screen.
					oldindex = index
					index = displaySpringboard(title, xe.item, oldindex)
					' if the index is different from the original index or if this
					' is an episodic poster screen then set the focus on the correct
					' item, update the bookmark position and call the show() method
					' to refresh the screen.
					if isEpisodic or not(index = oldindex) then
						if isEpisodic then
							bkmk = getPosterBookmark(xe.item[index])
							clist = poster.GetContentList()
							clist[index].Length = bkmk.length
							clist[index].BookmarkPosition = bkmk.resume
							poster.SetContentList(clist)
						endif
						if not(index = oldindex) then
							poster.SetFocusedListItem(index)
						endif
						poster.Show()
					endif
				elseif itype = "search"
					displaySearch(title, xe.item[index])
				endif
			endif
		elseif type(msg) = "roImageCanvasEvent"
			if msg.isScreenClosed() then
				'popFeed(feedurl)
				'return
			elseif msg.isRemoteKeyPressed()
				bindex = msg.GetIndex()
				' next page
				if (bindex = 5 or bindex = 9) and xe.item.Count() > 1 then
					canvas.ClearLayer(1)
					if pindex < xe.item.Count() - 1 then
						pindex = pindex + 1
					else
						pindex = 0
					endif
					textLayer.Text = str(pindex + 1) + "/" + str(xe.item.Count())
					canvas.SetLayer(1, textLayer)
					'canvas.Close()
					poster.SetFocusedListItem(pindex)
					poster.Show()
					sleep(msDelay)
					canvas.Show()
				' previous page
				elseif (bindex = 4 or bindex = 8) and xe.item.Count() > 1
					canvas.ClearLayer(1)
					if pindex > 0 then
						pindex = pindex - 1
					else
						pindex = xe.item.Count() - 1
					endif
					textLayer.Text = str(pindex + 1) + "/" + str(xe.item.Count())
					canvas.SetLayer(1, textLayer)
					'canvas.Close()
					poster.SetFocusedListItem(pindex)
					poster.Show()
					sleep(msDelay)
					canvas.Show()
				' select item
				elseif (bindex = 6 or bindex = 13)
					itype = getStringAttribute(xe.item[pindex], "type", false)

					if itype = "poster" then
						displayPoster(title, xe.item[pindex])
					elseif itype = "grid"
						displayGrid(title, xe.item[pindex])
					elseif itype = "document"
						displayDocument(title, xe.item[pindex])
					elseif itype = "settings"
						reloadPage = true
						while reloadPage
							reloadPage = displaySettings(title, xe.item[pindex])
						end while
					elseif itype = "video" or itype = "audio" or itype = "slideshow"
						oldindex = pindex
						pindex = displaySpringboard(title, xe.item, oldindex)
						if isEpisodic or not(pindex = oldindex) then
							canvas.ClearLayer(1)
							textLayer.Text = str(pindex + 1) + "/" + str(xe.item.Count())
							canvas.SetLayer(1, textLayer)
							'canvas.Close()
							if isEpisodic then
								bkmk = getPosterBookmark(xe.item[pindex])
								clist = poster.GetContentList()
								clist[pindex].Length = bkmk.length
								clist[pindex].BookmarkPosition = bkmk.resume
								poster.SetContentList(clist)
							endif
							if not(pindex = oldindex) then
								poster.SetFocusedListItem(pindex)
							endif
						endif
					elseif itype = "search"
						displaySearch(title, xe.item[pindex])
					endif

					' refresh the poster screen otherwise the counter may appear
					' on top of the selected item screen instead of overlaying
					' the original poster screen
					poster.Show()
					sleep(msDelay)
					canvas.Show()
				' back/up button pressed
				elseif bindex = 0 or bindex = 2
					popFeed(feedurl)
					return
				endif
			endif
		endif
	end while
End Sub

Function createPosterScreen(parentTitle As String, xe As Object) As Object
	gaa = GetGlobalAA()

	list = []
	title = getStringAttribute(xe, "title", true)
	style = getStringAttribute(xe, "style", false, "flat-category")

	ere = CreateObject("roRegex", "episodic", "")
	ematches = ere.Match(style)
	isEpisodic = (ematches.Count() > 0)

	bcp = cropString(parentTitle, gaa.constants.maxlength.breadcrumb, true)
	bct = cropString(title, gaa.constants.maxlength.breadcrumb, true)

	poster = CreateObject("roPosterScreen")
	poster.SetBreadcrumbText(bcp, bct)
	poster.SetBreadcrumbEnabled(true)
	poster.SetListStyle(style)
	poster.SetListDisplayMode("scale-to-fit")

	for i = 0 to xe.item.Count() - 1
		' has the cancel button has been pressed?
		if gaa.dialog.isCanceled() then
			return poster
		endif

		po = {}
		fulldesc = ""

		itype = getStringAttribute(xe.item[i], "type", false)
		title = getStringAttribute(xe.item[i], "title", true)
		author = getStringAttribute(xe.item[i], "author", true)
		date = getStringAttribute(xe.item[i], "date", false)
		artist = getStringAttribute(xe.item[i], "artist", true)
		album = getStringAttribute(xe.item[i], "album", true)
		shortdesc = getStringAttribute(xe.item[i], "shortdesc", true)

		' if the title is too long then it may cause a delay
		' on poster screens when pressing the left/right buttons
		title = cropString(title, gaa.constants.maxlength.posterTitle, true)

		' we use episode as a generic type for all items
		po.ContentType = "episode"
		po.SDPosterUrl = getStringAttribute(xe.item[i], "sdposterurl", true)
		po.HDPosterUrl = getStringAttribute(xe.item[i], "hdposterurl", true)
		po.Title = title
		po.ShortDescriptionLine1 = title

		if isEpisodic and (itype = "video" or itype = "audio" or itype = "slideshow") then
			bkmk = getPosterBookmark(xe.item[i])
			po.Length = bkmk.length
			po.BookmarkPosition = bkmk.resume
		endif

		if itype = "document" then
			if len(author) > 0 and len(date) > 0 then
				shortdesc = "Author: " + author + " | " + "Date: " + date
			elseif len(author) > 0
				shortdesc = "Author: " + author
			elseif len(date) > 0
				shortdesc = "Date: " + date
			endif
		elseif itype = "audio"
			if len(artist) > 0 and len(album) > 0 then
				shortdesc = "Artist: " + artist + " | " + "Album: " + album
			elseif len(artist) > 0
				shortdesc = "Artist: " + artist
			elseif len(album) > 0
				shortdesc = "Album: " + album
			endif
		endif

		' if the short description is too long then it may cause a delay
		' on poster screens when pressing the left/right buttons
		shortdesc = cropString(shortdesc, gaa.constants.maxlength.posterShortDesc, true)
		po.ShortDescriptionLine2 = shortdesc

		if xe.item[i].description.Count() > 0 then
			fulldesc = getElementText(xe.item[i], "description", true, true)
		elseif itype = "document" and xe.item[i].body.Count() > 0
			fulldesc = getElementText(xe.item[i], "body", true, true)
		endif

		' if the description is too long then it may cause a delay
		' on poster screens when pressing the left/right buttons
		fulldesc = cropString(fulldesc, gaa.constants.maxlength.posterFullDesc, true)

		po.Description = fulldesc
		list.Push(po)
	end for

	poster.SetContentList(list)
	return poster
End Function

Sub displayGrid(parentTitle As String, xe As Object)
	' theres no point in displaying the grid screen if it
	' doesnt contain any rows
	if xe.row.Count() < 1 then
		print "there are no rows to display"
		return
	endif

	gaa = GetGlobalAA()
	gaa.dialog.createMessageDialog(CreateObject("roMessagePort"), "Loading...", "", true, [])
	gaa.dialog.show()

	port = CreateObject("roMessagePort")
	grid = createGridScreen(parentTitle, xe)
	grid.SetMessagePort(port)

	' hide the loading dialog prior to showing the grid screen. if it is
	' not closed first then the back button may not work.
	gaa.dialog.close()

	grid.Show()

	dgStartLoop:
	while true
		msg = wait(0, port)
		if type(msg) = "roGridScreenEvent" then
			if msg.isScreenClosed() then
				return
			elseif msg.isListItemSelected()
				rowIndex = msg.GetIndex()
				colIndex = msg.GetData()

				title = getStringAttribute(xe.row[rowIndex], "title", true)
				feedurl = getStringAttribute(xe.row[rowIndex], "feedurl", true)

				if len(feedurl) > 0 then
					' we dont need to validate the feed here since it was validated
					' prior to creating the grid row. the previously cached feed will
					' be returned by saveXMLFeed.
					path = saveXMLFeed(feedurl, false, true)
					if len(path) < 1 then
						print "cannot display item"
						goto dgStartLoop
					endif

					rootElem = CreateObject("roXMLElement")
					if not(rootElem.Parse(ReadAsciiFile(path))) or rootElem.feed[0].item.Count() < colIndex then
						print "cannot display item"
						goto dgStartLoop
					endif

					items = rootElem.feed[0].item

					' keep track of currently loaded feed
					gaa.feeds.Push(feedurl)
				else
					if xe.row[rowIndex].item.Count() < colIndex then
						print "cannot display item"
						goto dgStartLoop
					endif

					items = xe.row[rowIndex].item
				endif

				' we cant retrieve the item type until after we have the
				' correct items array since this may be an external feed
				itype = getStringAttribute(items[colIndex], "type", false)

				if itype = "poster" then
					displayPoster(title, items[colIndex])
				elseif itype = "grid"
					displayGrid(title, items[colIndex])
				elseif itype = "document"
					displayDocument(title, items[colIndex])
				elseif itype = "settings"
					reloadPage = true
					while reloadPage
						reloadPage = displaySettings(title, items[colIndex])
					end while
				elseif itype = "video" or itype = "audio" or itype = "slideshow"
					' we return the selected item index from the displaySpringboard
					' function since it is possible to scroll through the items
					' from the springboard screen. if the index is different from
					' the original index then set the focus on the correct item
					' and call the show() method to refresh the screen.
					oldindex = colIndex
					colIndex = displaySpringboard(title, items, oldindex)
					if not(colIndex = oldindex) then
						grid.SetFocusedListItem(rowIndex, colIndex)
						grid.Show()
					endif
				elseif itype = "search"
					displaySearch(title, items[colIndex])
				endif

				' this will remove the currently loaded feed from the array
				' assuming that the feedurl attribute is set on this row
				popFeed(feedurl)
			endif
		endif
	end while
End Sub

Function createGridScreen(parentTitle As String, xe As Object) As Object
	gaa = GetGlobalAA()

	title = getStringAttribute(xe, "title", true)
	style = getStringAttribute(xe, "style", false, "flat-square")

	bcp = cropString(parentTitle, gaa.constants.maxlength.breadcrumb, true)
	bct = cropString(title, gaa.constants.maxlength.breadcrumb, true)

	rowTitles = []
	for i = 0 to xe.row.Count() - 1
		rtitle = getStringAttribute(xe.row[i], "title", true)
		rowTitles.Push(rtitle)
	end for

	grid = CreateObject("roGridScreen")
	grid.SetBreadcrumbText(bcp, bct)
	grid.SetBreadcrumbEnabled(true)
	grid.SetGridStyle(style)
	grid.SetDisplayMode("scale-to-fit")
	grid.SetDescriptionVisible(true)
	if gaa.prefs.exitgridtoprow then
		grid.SetUpBehaviorAtTopRow("exit")
	else
		grid.SetUpBehaviorAtTopRow("stop")
	endif
	' the second that you call SetupLists() the grid will begin
	' intercepting all events preventing any open dialogs from
	' detecting when a button has been pressed. This is definitely
	' a bug. It occurs before the Show() function has been called
	' and occurs even if a port has not been set on the grid. You
	' can verify that all events are being intercepted by the grid
	' by showing a roMessageDialog in the Main() function with a
	' single button. Set the while loop to exit the channel when
	' the button is pressed. Then create a grid screen with
	' SetUpBehaviorAtTopRow("exit") set but do not call Show() and
	' do not set a port. Pressing enter will have no effect on the
	' dialog button. In fact you may not even be able to see a
	' button in the dialog which might be a separate bug. When you
	' press the up button on the remote the channel will exit to
	' the main Roku menu indicating that events are still being
	' detected but they are all intercepted by the grid object even
	' though it has not been shown and the port was never set.
	grid.SetupLists(rowTitles.Count())
	grid.SetListNames(rowTitles)

	index = 0
	cgsStartLoop:
	for i = index to xe.row.Count() - 1
		list = []
		feedurl = getStringAttribute(xe.row[i], "feedurl", true)

		if len(feedurl) > 0 then
			usetemplate = getStringAttribute(xe.row[i], "usetemplate", false)

			' this is only used if the feedurl attribute is specified and only
			' if the defaultSDPoster property in the template is empty
			posterurl = getStringAttribute(xe.row[i], "hdposterurl", true)
			if len(posterurl) < 1 then
				posterurl = getStringAttribute(xe.row[i], "sdposterurl", true)
			endif

			rootElem = validateFeed(feedurl, false, false, true, usetemplate, posterurl)
			if not(type(rootElem) = "roXMLElement") then
				print "errors encountered - disabling row"
				grid.SetListVisible(i, false)
				index = index + 1
				goto cgsStartLoop
			endif

			' remove the usetemplate attribute from the grid row. we
			' can assume that since we have made it this far that the
			' feed has either been converted successfully or it is
			' already in orml format.
			xe.row[i].AddAttribute("usetemplate","")

			items = rootElem.feed[0].item
		else
			if xe.row[i].item.Count() < 1 then
				print "there are no items to display - disabling row"
				grid.SetListVisible(i, false)
				index = index + 1
				goto cgsStartLoop
			endif

			items = xe.row[i].item
		endif

		for j = 0 to items.Count() - 1
			o = {}
			fulldesc = ""

			itype = getStringAttribute(items[j], "type", false)
			ititle = getStringAttribute(items[j], "title", true)
			author = getStringAttribute(items[j], "author", true)
			date = getStringAttribute(items[j], "date", false)
			artist = getStringAttribute(items[j], "artist", true)
			album = getStringAttribute(items[j], "album", true)
			shortdesc = getStringAttribute(items[j], "shortdesc", true)

			' if the title is too long then it may cause a delay
			' on poster screens when pressing the left/right buttons
			ititle = cropString(ititle, gaa.constants.maxlength.gridTitle, true)

			' we use episode as a generic type for all items
			o.ContentType = "episode"
			o.SDPosterUrl = getStringAttribute(items[j], "sdposterurl", true)
			o.HDPosterUrl = getStringAttribute(items[j], "hdposterurl", true)
			o.Title = ititle
			o.ShortDescriptionLine1 = ititle

			if itype = "document" then
				if len(author) > 0 and len(date) > 0 then
					shortdesc = "Author: " + author + " | " + "Date: " + date
				elseif len(author) > 0
					shortdesc = "Author: " + author
				elseif len(date) > 0
					shortdesc = "Date: " + date
				endif
			elseif itype = "audio"
				if len(artist) > 0 and len(album) > 0 then
					shortdesc = "Artist: " + artist + " | " + "Album: " + album
				elseif len(artist) > 0
					shortdesc = "Artist: " + artist
				elseif len(album) > 0
					shortdesc = "Album: " + album
				endif
			endif

			if items[j].description.Count() > 0 then
				fulldesc = getElementText(items[j], "description", true, true)
			elseif itype = "document" and items[j].body.Count() > 0
				fulldesc = getElementText(items[j], "body", true, true)
			endif

			' use shortdesc for description if no description was provided
			if len(fulldesc) < 1 then
				fulldesc = shortdesc
			endif

			' if the fulldesc or shortdesc is too long then it may cause a delay
			' on poster screens when pressing the left/right buttons
			fulldesc = cropString(fulldesc, gaa.constants.maxlength.gridFullDesc, true)
			o.Description = fulldesc

			' if the fulldesc or shortdesc is too long then it may cause a delay
			' on poster screens when pressing the left/right buttons. this is
			' probably a pointless step since the shortdesc is not displayed in
			' the description box but keeping it as is for now.
			shortdesc = cropString(shortdesc, gaa.constants.maxlength.gridShortDesc, true)
			o.ShortDescriptionLine2 = shortdesc

			list.Push(o)
		end for

		grid.SetContentList(i, list)

		index = index + 1
	end for

	' the default grid style can display 3 rows of visible items
	' at a time so we select the 2nd row here which will ensure
	' that the maximum number of rows will be visible. we select
	' the first item in the 2nd row since theres no guarantee
	' that there is more than 1 item in the row.
	grid.SetFocusedListItem(1, 0)
	return grid
End Function

Sub displayDocument(parentTitle As String, xe As Object)
	gaa = GetGlobalAA()
	gaa.dialog.createMessageDialog(CreateObject("roMessagePort"), "Loading...", "", true, [{index:1,label:"Cancel"}])
	gaa.dialog.show()

	bodytxt = ""
	pubinfo = ""

	' the new line character is represented by the ascii code 10
	newLine = chr(10)

	itype = getStringAttribute(xe, "type", false)
	title = getStringAttribute(xe, "title", true)
	author = getStringAttribute(xe, "author", true)
	date = getStringAttribute(xe, "date", false)
	shortdesc = getStringAttribute(xe, "shortdesc", true)
	url = getStringAttribute(xe, "url", true)
	stripHTML = getBoolAttribute(xe, "striphtml")
	stripEWS = getBoolAttribute(xe, "stripews")
	regexfilter = getStringAttribute(xe, "regexfilter", true)

	if itype = "settings" then
		title = "Privacy Policy"
		if xe.policy.Count() > 0 then
			bodytxt = getElementText(xe, "policy", true, true)
		endif
	elseif itype = "video" or itype = "audio" or itype = "slideshow" then
		title = "Description"
		if xe.description.Count() > 0 then
			bodytxt = getElementText(xe, "description", true, true)
		endif
	elseif itype = "document" and len(url) > 0 then
		' retrieve and save document to temp folder
		path = saveDocument(url)
		if len(path) < 1 then
			print "cannot display document"
			gaa.dialog.close()
			return
		endif

		if gaa.dialog.isCanceled() then
			gaa.dialog.close()
			DeleteFile(path)
			return
		endif

		doctxt = ReadAsciiFile(path)

		if len(regexfilter) > 0 then
			ecode = Eval("re = CreateObject(" + chr(34) + "roRegex" + chr(34) + ", " + chr(34) + regexfilter + chr(34) + ", " + chr(34) + "s" + chr(34) + ")")
			if type(ecode) = "Integer" and (ecode = 252 or ecode = 226) and type(re) = "roRegex" then
				doctxt = re.ReplaceAll(doctxt, "")
			else
				print "invalid regexp detected"
			endif
		endif

		if gaa.dialog.isCanceled() then
			gaa.dialog.close()
			DeleteFile(path)
			return
		endif

		if stripHTML then
			' remove all html tags and entities
			doctxt = stripHTMLTags(doctxt)
			doctxt = stripHTMLEntities(doctxt)
		endif

		if gaa.dialog.isCanceled() then
			gaa.dialog.close()
			DeleteFile(path)
			return
		endif

		if stripEWS then
			doctxt = stripExtraWhiteSpace(doctxt)
		endif

		if stripHTML or stripEWS or len(regexfilter) > 0 then
			' overwrite existing file to avoid having to reformat document again
			success = WriteAsciiFile(path, doctxt)
			if not(success) then
				print "cannot display document"
				gaa.dialog.close()
				DeleteFile(path)
				return
			endif
		endif

		bodytxt = ReadAsciiFile(path)
	else ' itype = document
		if xe.body.Count() > 0 then
			bodytxt = getElementText(xe, "body", true, true)
		endif
	endif

	if gaa.dialog.isCanceled() then
		gaa.dialog.close()
		return
	endif

	if len(bodytxt) < 1 then
		print "cannot display document"
		gaa.dialog.close()
		return
	endif

	if len(author) > 0 and len(date) > 0 then
		pubinfo = "Author: " + author + newLine + "Date: " + date + newLine + newLine
	elseif len(author) > 0
		pubinfo = "Author: " + author + newLine + newLine
	elseif len(date) > 0 then
		pubinfo = "Date: " + date + newLine + newLine
	endif

	bodytxt = pubinfo + bodytxt + newLine + newLine + "***"

	port = CreateObject("roMessagePort")
	paragraph = createParagraphScreen(parentTitle, title, false)
	paragraph.SetMessagePort(port)
	layers = createDocumentLayers(title, bodytxt)
	canvas = createDocumentCanvas(layers)
	canvas.SetMessagePort(port)

	' get height for lines, document and screen
	dspec = getDocSpecs(bodytxt)

	' we cant close the dialog until after we call isCanceled since closing
	' the dialog resets the gaa.dialog.romd object.
	canceled = gaa.dialog.isCanceled()
	gaa.dialog.close()
	if canceled then return

	paragraph.Show()

	' set a short timeout to allow the paragraph screen to fully load
	' prior to displaying the image canvas. without the timeout the
	' breadcrumb text will not be updated.
	sleep(100)

	canvas.Show()

	' alert the user that they can scroll with left/right remote buttons
	hideTip = getBoolValFromReg("hideDocumentTip", "preferences")
	if not(hideTip) then
		btninfo = showDialog("Tip", "Use the up/down remote buttons to scroll one line at a time. Use the ffwd/rwnd buttons to scroll one page at a time. Press the ok or back button to exit.", true, false, false, [{index:1,label:"OK"}, {index:2,label:"Do not show again"}])
		if btninfo.index = 2 then
			saveBoolValToReg("hideDocumentTip", true, "preferences")
		endif
	endif

	while true
		msg = wait(0, port)
		if type(msg) = "roParagraphScreenEvent" then
			if msg.isScreenClosed() then
				return
			endif
		elseif type(msg) = "roImageCanvasEvent" then
			if msg.isScreenClosed() then
				' we cant return here because the canvas.close() method has to
				' be called occasionally after scrolling up
				'return
			elseif msg.isRemoteKeyPressed()
				bindex = msg.GetIndex()
				if (bindex = 3 or bindex = 9) and layers[0].TargetRect.y > dspec.minY then
					if bindex = 3 then ' down one line
						if layers[0].TargetRect.y - dspec.lineHeight > dspec.minY then
							incrementY = dspec.lineHeight
						else
							incrementY = layers[0].TargetRect.y - dspec.minY
						endif
					elseif bindex = 9 then ' down one page
						if layers[0].TargetRect.y - dspec.screenAvailableHeight > dspec.minY then
							incrementY = dspec.screenAvailableHeight
						else
							incrementY = layers[0].TargetRect.y - dspec.minY
						endif
					endif
					for i = 0 to layers.Count() - 1
						layers[i].TargetRect.y = layers[i].TargetRect.y - incrementY
						canvas.ClearLayer(i)
						canvas.SetLayer(i, layers[i])
					end for
				elseif (bindex = 2 or bindex = 8) and layers[0].TargetRect.y < dspec.maxY
					if bindex = 2 then ' up one line
						if layers[0].TargetRect.y + dspec.lineHeight < dspec.maxY then
							incrementY = dspec.lineHeight
						else
							incrementY = dspec.maxY - layers[0].TargetRect.y
						endif
					endif
					if bindex = 8 then ' up one page
						if layers[0].TargetRect.y + dspec.screenAvailableHeight < dspec.maxY then
							incrementY = dspec.screenAvailableHeight
						else
							incrementY = dspec.maxY - layers[0].TargetRect.y
						endif
					endif
					for i = 0 to layers.Count() - 1
						layers[i].TargetRect.y = layers[i].TargetRect.y + incrementY
						canvas.ClearLayer(i)
						canvas.SetLayer(i, layers[i])
					end for
					' we have to recreate the canvas screen when scrolling down otherwise
					' the canvas will appear overlapped and the paragraph screen will be
					' completely hidden
					if layers[0].TargetRect.y > 0 then
						canvas.Close()
						canvas = createDocumentCanvas(layers)
						canvas.SetMessagePort(port)
						sleep(25)
						canvas.Show()
					endif
				elseif bindex = 6 or bindex = 0
					' 6 = ok button, 0 = back button
					return
				endif
			elseif msg.isButtonPressed()
				' done button pressed - not currently used
				if msg.GetIndex() = 1 then
					return
				endif
			endif
		endif
	end while
End Sub

Function getDocSpecs(body As String) As Object
	gaa = GetGlobalAA()
	spec = {}
	spec.lineTotal = countLines(body)

	dinfo = CreateObject("roDeviceInfo")
	dsize = dinfo.GetDisplaySize()
	dtype = dinfo.GetDisplayType()
	spec.screenHeight = dsize.h
	spec.screenWidth = dsize.w

	if dtype = "HDTV" then
		spec.maxY = gaa.prefs.overhangheighthd
		spec.screenAvailableHeight = dsize.h - spec.maxY
	else
		spec.maxY = gaa.prefs.overhangheightsd
		spec.screenAvailableHeight = dsize.h - spec.maxY
	endif

	' max lines per screen is 20 on a sdtv. 14 lines with the
	' channel banner and no header. 12 lines with the channel
	' banner and header.
	spec.maxLinesPerScreen = 20

	' this needs to be an integer instead of a float for the canvas
	spec.lineHeight = fix(spec.screenHeight / spec.maxLinesPerScreen)
	spec.docHeight = spec.lineHeight * spec.lineTotal
	spec.minY = 0 - spec.docHeight + dsize.h
	return spec
End Function

Function createDocumentLayers(header As String, body As String) As Object
	gaa = GetGlobalAA()
	layers = []

	header = cropString(header, gaa.constants.maxlength.documentTitle, true)

	dinfo = CreateObject("roDeviceInfo")
	dsize = dinfo.GetDisplaySize()
	dtype = dinfo.GetDisplayType()

	bgroundX = 0
	bgroundW = dsize.w
	if dtype = "HDTV" then
		bgroundY = gaa.prefs.overhangheighthd
	else
		bgroundY = gaa.prefs.overhangheightsd
	endif
	'bgroundH = dspec.docHeight

	titleX = 60
	titleW = dsize.w - (titleX * 2)
	titleY = bgroundY + 10 'add a 10 pixel top margin
	titleH = 35

	bodyX = titleX
	bodyW = titleW
	bodyY = titleY + titleH
	'bodyH = dspec.docHeight

	' layer 0 provides the background for the text
	layer0 = {
		Color:"#FFFFFF", CompositionMode:"Source",
		TargetRect:{x:bgroundX,y:bgroundY,w:bgroundW}
	}

	' layer 1 is the title
	layer1 = {
		Color:"#FFFFFF", CompositionMode:"Source",
		Text:header,
		TextAttrs:{
			Color:"#000000", Font:"Large",
			HAlign:"Left", VAlign:"Top",
			TextDirection:"LeftToRight"
		},
		TargetRect:{x:titleX,y:titleY,w:titleW,h:titleH}
	}

	' layer 2 is the document contents
	layer2 = {
		Color:"#FFFFFF", CompositionMode:"Source",
		Text:body,
		TextAttrs:{
			Color:"#000000", Font:"Medium",
			HAlign:"Justify", VAlign:"Top",
			TextDirection:"LeftToRight"
		},
		' position below layer 1 since we know this is pagenum 0
		TargetRect:{x:bodyX,y:bodyY,w:bodyW}
	}

	layers.Push(layer0)
	layers.Push(layer1)
	layers.Push(layer2)
	return layers
End Function

Function createDocumentCanvas(layers As Object) As Object
	canvas = CreateObject("roImageCanvas")
	canvas.AllowUpdates(true)
	for i = 0 to layers.Count() - 1
		canvas.SetLayer(i, layers[i])
	end for
	'canvas.AddButton(1, "Done")
	return canvas
End Function

Sub displaySearch(parentTitle As String, xe As Object)
	gaa = GetGlobalAA()
	url = getStringAttribute(xe, "url", true)
	title = getStringAttribute(xe, "title", true)

	if len(url) < 1 then
		if len(gaa.prefs.searchurl) > 0 then
			url = gaa.prefs.searchurl
		else
			print "cannot find a valid search url"
			return
		endif
	endif

	bcp = cropString(parentTitle, gaa.constants.maxlength.breadcrumb, true)
	bct = cropString(title, gaa.constants.maxlength.breadcrumb, true)

	port = CreateObject("roMessagePort")

	shistory = CreateObject("roSearchHistory")
	history = shistory.GetAsArray()

	search = CreateObject("roSearchScreen")
	search.SetBreadcrumbText(bcp, bct)
	search.SetMessagePort(port)
	search.SetSearchTermHeaderText("Recent Searches:")
	search.SetSearchButtonText("Search")
	search.SetClearButtonText("Clear History")
	search.SetClearButtonEnabled(true)
	search.SetSearchTerms(history)
	search.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roSearchScreenEvent" then
			if msg.isScreenClosed() then
				return
			elseif msg.isCleared()
				proceed = confirm("Warning", "The search history is used system-wide and other channels might display this history within their own search screens. If you clear the search history it will no longer be accessible to any channel. Are you sure you want to continue?")
				if proceed then
					print "search history cleared"
					shistory.Clear()
				else
					' restore history
					search.SetSearchTerms(history)
				endif
			elseif msg.isPartialResult()
				'print "search text changed"
			elseif msg.isFullResult()
				'print "search button pressed"
				kwords = msg.GetMessage()
				if len(kwords) > 0 then
					shistory.Push(kwords)
					history = shistory.GetAsArray()
					search.SetSearchTerms(history)
					hasResults = performSearch(xe, kwords)
					if not(hasResults) then
						alert("Alert", "No results found.")
					endif
				else
					print "no search keywords detected"
					alert("Alert", "You must enter at least one keyword in order to continue.")
				endif
			endif
		endif
	end while
End Sub

Function performSearch(xe As Object, keywords As String) As Boolean
	gaa = GetGlobalAA()

	url = getStringAttribute(xe, "url", true)
	title = getStringAttribute(xe, "title", true)
	paramname = getStringAttribute(xe, "paramname", false, "keywords")
	usetemplate = getStringAttribute(xe, "usetemplate", false)
	senddevid = getBoolAttribute(xe, "senddevid", true)

	' this is only used if the template attribute is specified and only
	' if the defaultSDPoster property in the template is empty
	posterurl = getStringAttribute(xe, "hdposterurl", true)
	if len(posterurl) < 1 then
		posterurl = getStringAttribute(xe, "sdposterurl", true)
	endif

	if len(url) < 1 then
		if len(gaa.prefs.searchurl) > 0 then
			url = gaa.prefs.searchurl
		else
			print "cannot find a valid search url"
			return false
		endif
	endif

	' combine url and parameters
	url = generateUrlWithParams(url, [[paramname,keywords]])

	gaa.dialog.createMessageDialog(CreateObject("roMessagePort"), "Searching...", "", true, [{index:1,label:"Cancel"}])
	gaa.dialog.show()

	xe = validateFeed(url, true, senddevid, false, usetemplate, posterurl)
	if not(type(xe) = "roXMLElement") then
		print "cannot display search results"
		gaa.dialog.close()
		return false
	endif

	canceled = gaa.dialog.isCanceled()
	gaa.dialog.close()
	if canceled then return false

	' save a reference to search feed url
	gaa.feeds.Push(url)

	itype = xe.channel[0].item[0]@type
	if itype = "poster" then
		displayPoster(title, xe.channel[0].item[0])
	else 'itype = "grid"
		' the type attribute was already tested in the validateFeed
		' function so we know that if it is not a poster then it
		' must be a grid
		displayGrid(title, xe.channel[0].item[0])
	endif

	' remove the search url from the feeds array before returning
	popFeed(url)

	return true
End Function

Function displaySettings(parentTitle As String, xe As Object) As Boolean
	extensions = []
	title = getStringAttribute(xe, "title", true)
	itype = getStringAttribute(xe, "type", false)
	enableemailbtn = getBoolAttribute(xe, "enableemailbtn")
	enablepolicybtn = getBoolAttribute(xe, "enablepolicybtn")
	enablenewsletterbtn = getBoolAttribute(xe, "enablenewsletterbtn")
	enableprimaryfeedbtn = getBoolAttribute(xe, "enableprimaryfeedbtn")
	enableclearregistrybtn = getBoolAttribute(xe, "enableclearregistrybtn")

	' retrieve array of extension objects
	enableext = getBoolAttribute(xe, "enableextensions")
	if enableext then
		extensions = validateExtensions(itype, xe.extension)
	endif

	paragraph = createParagraphScreen(parentTitle, title, true)
	port = CreateObject("roMessagePort")
	paragraph.SetMessagePort(port)

	if enableemailbtn then
		email = getStrValFromReg("email", "profile")
		if len(email) < 1 then
			email = "not set"
		endif
		paragraph.AddParagraph("Email address: " + email)
		paragraph.AddButton(1, "Change email")

		if enablenewsletterbtn then
			isSubscribed = getBoolValFromReg("newsletter", "profile")
			if isSubscribed then
				newsletter = "subscribed"
			else
				newsletter = "not subscribed"
			endif
			paragraph.AddParagraph("Newsletter: " + newsletter)
			paragraph.AddButton(2, "Manage subscription")
		endif
	endif

	if enableprimaryfeedbtn then
		primaryfeed = getStrValFromReg("primaryfeed", "profile")
		if len(primaryfeed) < 1 then
			primaryfeed = getDefaultFeed()
			if len(primaryfeed) < 1 then
				primaryfeed = getFailsafeFeed()
			endif
		endif
		paragraph.AddParagraph("Primary feed: " + primaryfeed)
		paragraph.AddButton(3, "Change primary feed")
	endif

	' display customized buttons via extensions
	installSettingsExtensions(paragraph, extensions)

	if enableclearregistrybtn then
		paragraph.AddButton(4, "Clear registry")
	endif
	if enablepolicybtn then
		paragraph.AddButton(5, "Privacy Policy")
	endif
	paragraph.AddButton(6, "Done")
	paragraph.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roParagraphScreenEvent" then
			if msg.isScreenClosed() then
				return false
			elseif msg.isButtonPressed()
				if msg.GetIndex() = 1 then
					reloadPage = saveEmailToRegistry()
					if reloadPage then return true
				elseif msg.GetIndex() = 2
					'subscribeNewsletter(true)
				elseif msg.GetIndex() = 3
					reloadPage = saveCustomFeedToRegistry()
					if reloadPage then return true
				elseif msg.GetIndex() = 4
					reloadPage = clearRegistry()
					if reloadPage then return true
				elseif msg.GetIndex() = 5
					displayDocument(title, xe)
				elseif msg.GetIndex() = 6
					return false
				else
					runExtension(msg.GetIndex(), extensions, xe)
					' always refresh page since we have no way of knowing the
					' purpose or type of code being executed by the extension
					return true
				endif
			endif
		endif
	end while
End Function

Sub reportBrokenStream(rbsurl As String, params As Object)
	' if no url was included as an attribute of the media item
	' in the xml feed then try to retrieve the url from the
	' global object. if both variables are empty strings then
	' report an error and return.
	gaa = GetGlobalAA()
	if len(rbsurl) < 1 then
		if len(gaa.prefs.rbsurl) > 0 then
			rbsurl = gaa.prefs.rbsurl
		else
			print "cannot find a valid url for ";chr(34);"report broken stream";chr(34);" script"
			return
		endif
	endif

	port = CreateObject("roMessagePort")
	dialog = createMessageDialog(port, "Sending...", "", true, false, true, [{index:1,label:"Cancel"}])
	dialog.Show()

	http = CreateObject("roUrlTransfer")
	http.SetPort(port)
	'http.InitClientCertificates()
	http.AddHeader("X-Roku-Reserved-Dev-Id", "")

	' generate device info params
	dinfo = CreateObject("roDeviceInfo")
	dsize = dinfo.GetDisplaySize()
	params.Push(["model", dinfo.GetModel()])
	params.Push(["version", dinfo.GetVersion()])
	params.Push(["serial_pre", left(dinfo.GetDeviceUniqueId(), 1)])
	params.Push(["serial_rev", mid(dinfo.GetDeviceUniqueId(), 2, 2)])
	params.Push(["display_type", dinfo.GetDisplayType()])
	params.Push(["display_mode", dinfo.GetDisplayMode()])
	params.Push(["aspect", dinfo.GetDisplayAspectRatio()])
	params.Push(["width", str(dsize.w)])
	params.Push(["height", str(dsize.h)])
	params.Push(["timezone", dinfo.GetTimeZone()])
	params.Push(["has_51", convertBoolToString(dinfo.HasFeature("5.1_surround_sound"))])
	params.Push(["has_sd_only", convertBoolToString(dinfo.HasFeature("sd_only_hardware"))])
	params.Push(["has_usb", convertBoolToString(dinfo.HasFeature("usb_hardware"))])
	params.Push(["has_1080p", convertBoolToString(dinfo.HasFeature("1080p_hardware"))])

	' combine url and parameters
	url = generateUrlWithParams(rbsurl, params)

	http.SetUrl(url)
	success = http.AsyncGetToString()

	if not(success) then
		print "url transfer failed"
		alert("Alert", "The report could not be submitted. Please try again later.")
		dialog.Close()
		return
	endif

	while true
		msg = wait(0, port)
		if type(msg) = "roMessageDialogEvent" then
			if msg.isButtonPressed() and msg.GetIndex() = 1 then
				print "url transfer canceled"
				dialog.Close()
				http.AsyncCancel()
				return
			endif
		elseif type(msg) = "roUrlEvent"
			if msg.GetInt() = 1 and msg.GetResponseCode() = 200 then
				alert("Alert", msg.GetString())
			else
				print msg.GetFailureReason()
				alert("Alert", "The report could not be submitted. Please try again later.")
			endif
			dialog.Close()
			return
		endif
	end while
End Sub

' etype "me" = email me
' etype "friend" = email friend
Sub sendEmail(etype As String, eiurl As String, params As Object)
	' if no url was included as an attribute of the media item
	' in the xml feed then try to retrieve the url from the
	' global object. if both variables are empty strings then
	' report an error and return.
	gaa = GetGlobalAA()
	if len(eiurl) < 1 then
		if len(gaa.prefs.eiurl) > 0 then
			eiurl = gaa.prefs.eiurl
		else
			print "cannot find a valid url for ";chr(34);"email information";chr(34);" script"
			return
		endif
	endif

	if etype = "me" then
		email = getStrValFromReg("email", "profile")
		etip = "enter your email address"
	else
		email = ""
		etip = "enter the email address"
	endif

	if len(email) < 1 then
		keyboard = createKeyboard("Email", etip, email, -1)
		port = CreateObject("roMessagePort")
		keyboard.SetMessagePort(port)
		keyboard.Show()

		while true
			msg = wait(0, port)
			if type(msg) = "roKeyboardScreenEvent" then
				if msg.isScreenClosed() then
					return
				elseif msg.isButtonPressed()
					if msg.GetIndex() = 1 then
						email = keyboard.GetText()
						if len(email) < 1 then
							print "keyboard text is empty"
							alert("Alert", "You must enter a valid email address in order to continue.")
						elseif not(validateEmail(email)) then
							print "email is invalid"
							alert("Alert", "You must enter a valid email address in order to continue.")
						else
							if etype = "me" then
								success = saveStrValToReg("email", email, "profile")
								if success then
									txt = "The email address was saved successfully to your Roku registry."
								else
									txt = "The email address could not be saved!"
								endif
								alert("Alert", txt)
							endif
							' we know that the email address is valid so we continue even if we
							' cannot save it to the registry. make sure to close the keyboard
							' before continuing.
							keyboard.Close()
							exit while
						endif
					else
						keyboard.Close()
						return
					endif
				endif
			endif
		end while
	endif

	port = CreateObject("roMessagePort")
	dialog = createMessageDialog(port, "Sending...", "", true, false, true, [{index:1,label:"Cancel"}])
	dialog.Show()

	http = CreateObject("roUrlTransfer")
	http.SetPort(port)
	'http.InitClientCertificates()
	http.AddHeader("X-Roku-Reserved-Dev-Id", "")

	params.Push(["email",email])

	' combine url and parameters
	url = generateUrlWithParams(eiurl, params)

	http.SetUrl(url)
	success = http.AsyncGetToString()

	if not(success) then
		print "url transfer failed"
		alert("Alert", "The email could not be sent. Please try again later.")
		dialog.Close()
		return
	endif

	while true
		msg = wait(0, port)
		if type(msg) = "roMessageDialogEvent" then
			if msg.isButtonPressed() and msg.GetIndex() = 1 then
				print "url transfer canceled"
				dialog.Close()
				http.AsyncCancel()
				return
			endif
		elseif type(msg) = "roUrlEvent"
			if msg.GetInt() = 1 and msg.GetResponseCode() = 200 then
				alert("Alert", msg.GetString())
			else
				print msg.GetFailureReason()
				alert("Alert", "The email could not be sent. Please try again later.")
			endif
			dialog.Close()
			return
		endif
	end while
End Sub

Function saveCustomFeedToRegistry() As Boolean
	primaryfeed = getStrValFromReg("primaryfeed", "profile")
	keyboard = createKeyboard("Primary feed", "enter the feed url", primaryfeed, -1)
	port = CreateObject("roMessagePort")
	keyboard.SetMessagePort(port)
	keyboard.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roKeyboardScreenEvent" then
			if msg.isScreenClosed() then
				return false
			elseif msg.isButtonPressed()
				if msg.GetIndex() = 1 then
					primaryfeed = keyboard.GetText()
					if len(primaryfeed) < 1 then
						print "keyboard text is empty"
						alert("Alert", "You must enter a valid url in order to continue.")
					elseif not(isValidUrl(primaryfeed)) then
						print "url is invalid"
						alert("Alert", "You must enter a valid url in order to continue.")
					else
						success = saveStrValToReg("primaryfeed", primaryfeed, "profile")
						if success then
							txt = "The feed url was saved successfully to your Roku registry."
						else
							txt = "The feed url could not be saved!"
						endif
						alert("Alert", txt)
						keyboard.Close()
						return success
					endif
				else
					keyboard.Close()
					return false
				endif
			endif
		endif
	end while
End Function

Function saveEmailToRegistry() As Boolean
	email = getStrValFromReg("email", "profile")
	keyboard = createKeyboard("Email", "enter your email address", email, -1)
	port = CreateObject("roMessagePort")
	keyboard.SetMessagePort(port)
	keyboard.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roKeyboardScreenEvent" then
			if msg.isScreenClosed() then
				return false
			elseif msg.isButtonPressed()
				if msg.GetIndex() = 1 then
					email = keyboard.GetText()
					if len(email) < 1 then
						print "keyboard text is empty"
						alert("Alert", "You must enter a valid email address in order to continue.")
					elseif not(validateEmail(email)) then
						print "email is invalid"
						alert("Alert", "You must enter a valid email address in order to continue.")
					else
						success = saveStrValToReg("email", email, "profile")
						if success then
							txt = "The email address was saved successfully to your Roku registry."
						else
							txt = "The email address could not be saved!"
						endif
						alert("Alert", txt)
						keyboard.Close()
						return success
					endif
				else
					keyboard.Close()
					return false
				endif
			endif
		endif
	end while
End Function

Sub playSlideshow(xe As Object, resumeIndex As Integer) As Integer
	urlhash = ""
	currentIndex = resumeIndex

	if xe.image.Count() > 0 then
		url = getStringAttribute(xe.image[0], "url", true)
		if len(url) > 0 then
			urlhash = hashString(url, "md5")
		endif
	else
		print "there are no image to display"
		return 0
	endif

	useRegistry = (len(urlhash) > 0)

	slide = createSlideshow(xe)
	port = CreateObject("roMessagePort")
	slide.SetMessagePort(port)
	slide.SetNext(currentIndex, true)
	slide.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roSlideShowEvent" then
			if msg.isScreenClosed() then
				if useRegistry then saveIntValToReg(urlhash, currentIndex, true, "slideshow")
				return currentIndex
			elseif msg.isPlaybackPosition()
				print "slide index: ";msg.GetIndex()
				currentIndex = msg.GetIndex()
			elseif msg.isRequestSucceeded()
				'print "request succeeded"
			elseif msg.isRequestFailed()
				print "request failed"
				print "error code: ";msg.GetIndex()
				print "error slide index: ";msg.GetData()
				if len(msg.GetMessage()) > 0 then
					print "error message: ";msg.GetMessage()
				endif
				' we dont have to return on error as long as there are other images
				' in the slideshow. the roSlideShow will just skip the unavailable
				' images.
				'alert("Alert", "Could not connect to server. Please try again later.")
				'if useRegistry then saveIntValToReg(urlhash, currentIndex, true, "slideshow")
				'return currentIndex
			elseif msg.isRequestInterrupted()
				print "playback interrupted"
				if useRegistry then saveIntValToReg(urlhash, currentIndex, true, "slideshow")
				return currentIndex
			elseif msg.isPaused()
				print "playback paused"
				if useRegistry then saveIntValToReg(urlhash, currentIndex, true, "slideshow")
			elseif msg.isResumed()
				print "playback resumed"
			endif
		endif
	end while
End Sub

Function createSlideshow(xe As Object) As Object
	imagetime = getIntegerAttribute(xe, "imagetime", 3)
	overlaytime = getIntegerAttribute(xe, "overlaytime")
	enableoverlay = getBoolAttribute(xe, "enableoverlay")

	slide = CreateObject("roSlideShow")
	slide.SetPeriod(imagetime)
	if enableoverlay and overlaytime > 0 then
		slide.SetTextOverlayHoldTime(overlaytime)
	endif
	' even if we set overlayIsVisible to false the overlay will
	' still be displayed during the time specified by the holdTime
	slide.SetTextOverlayIsVisible(false)
	slide.SetDisplayMode("scale-to-fit")

	list = []

	for i = 0 to xe.image.Count() - 1
		o = {}
		o.Url = getStringAttribute(xe.image[i], "url", true)
		o.TextOverlayBody = getStringAttribute(xe.image[i], "overlay", true)
		list.Push(o)
	end for

	slide.SetContentList(list)
	return slide
End Function

Function constructURL(fileurl, baseurl) As String
	pre = CreateObject("roRegex", "^(.+?)\://", "s")
	dre = CreateObject("roRegex", "^(.+?\://.+?)/", "s")
	dpre = CreateObject("roRegex", "^(.+?\://.+/)", "s")

	pmatches = pre.Match(fileurl)
	if pmatches.Count() > 1 then
		if len(pmatches[1]) < 1 or not(pmatches[1] = "http") then
			print "Cannot find valid url"
			return ""
		endif
		return fileurl
	endif

	if left(fileurl, 1) = "/" then
		dmatches = dre.Match(baseurl)
		if dmatches.Count() < 2 or len(dmatches[1]) < 1 then
			print "Cannot find valid url"
			return ""
		endif
		return dmatches[1] + fileurl
	else
		dmatches = dpre.Match(baseurl)
		if dmatches.Count() < 2 or len(dmatches[1]) < 1 then
			print "Cannot find valid url"
			return ""
		endif
		return dmatches[1] + fileurl
	endif

	return ""
End Function

Sub scrapeHTML(xe As Object, scraper As Object)
	totalMatches = 0

	url = getStringAttribute(scraper, "url", true)
	regex = getStringAttribute(scraper, "regex", true)
	etype = getStringAttribute(scraper, "type", false, "parent")
	ename = getStringAttribute(scraper, "ename", false, "item")
	aname = getStringAttribute(scraper, "aname", false)
	limit = getIntegerAttribute(scraper, "limit")

	if len(url) < 1 or len(regex) < 1 or len(etype) < 1 or len(ename) < 1 or (etype = "parent" and len(aname) < 1) then
		print "invalid scraper detected"
		return
	endif

	' theres no point in performing more than one match for the
	' parent item element since we can only modify a single
	' attribute on that element
	if etype = "parent" then
		limit = 1
	endif

	' retrieve and save document to temp folder
	path = saveDocument(url)
	if len(path) < 1 then
		print "cannot retrieve html document"
		return
	endif

	htmlsource = ReadAsciiFile(path)

	ecode = Eval("re = CreateObject(" + chr(34) + "roRegex" + chr(34) + ", " + chr(34) + regex + chr(34) + ", " + chr(34) + "s" + chr(34) + ")")
	if not(type(ecode) = "Integer") or (not(ecode = 252) and not(ecode = 226)) or not(type(re) = "roRegex") then
		print "invalid regex detected"
		return
	endif

	print chr(10);"Scraping strings from document..."

	startscraping:
	matches = re.Match(htmlsource)
	while matches.Count() > 1 and (limit < 1 or totalMatches < limit)
		' keep track of number of matches so we can cancel if
		' the limit attribute is set. we cant use the Count()
		' function since the htmlsource is modified after each
		' match is no longer needed
		totalMatches = totalMatches + 1

		if len(matches[1]) < 1 then
			print "empty string detected"
			htmlsource = re.Replace(htmlsource, "")
			goto startscraping
		endif

		scrapedString = matches[1]
		if len(aname) > 0 and right(aname, 3) = "url" then
			scrapedString = constructURL(scrapedString, url)
			if len(scrapedString) < 1 then
				print "invalid url detected"
				htmlsource = re.Replace(htmlsource, "")
				goto startscraping
			endif
		endif

		print "the string below was scraped from the document:"
		print scrapedString

		if etype = "parent" then
			if xe.IsName(ename) then
				xe.AddAttribute(aname, scrapedString)
			endif
			' we can only modify a single attribute on the parent
			' element so we exit the loop here even if there is
			' more than one match
			exit while
		else 'etype = sibling
			nodes = xe.GetNamedElements(ename)
			if nodes.Count() >= totalMatches then
				if len(aname) > 0 then
					nodes[totalMatches - 1].AddAttribute(aname, scrapedString)
				else
					nodes[totalMatches - 1].SetBody(scrapedString)
				endif
			else
				tmpnode = xe.AddElement(ename)
				if len(aname) > 0 then
					tmpnode.AddAttribute(aname, scrapedString)
				else
					tmpnode.SetBody(scrapedString)
				endif
			endif
		endif

		' remove the scraped string from the source so the regex
		' will be able capture the next matching string
		htmlsource = re.Replace(htmlsource, "")
		goto startscraping
	end while
End Sub

Function validateExtensions(itype As String, extensions As Object) As Object
	EXTENSIONS_DIR = "pkg:/source/extensions/"

	' this represents the index of the button that will be applied
	' on the springboard screen. we start from 11 to avoid conflicts
	' with built-in buttons and to allow space for future built-in
	' buttons.
	eindex = 11
	validExtensions = []

	for i = 0 to extensions.Count() - 1
		ename = getStringAttribute(extensions[i], "name", false)
		if len(ename) > 0 then
			elist = MatchFiles(EXTENSIONS_DIR, ename + ".brs")
			if elist.Count() > 0 then
				ecode = Eval("e = " + ename + "()")
				if type(ecode) = "Integer" and (ecode = 252 or ecode = 226) and type(e) = "roAssociativeArray" then
					if e.isEnabled then
						supportedTypes = e.enableForItems
						for j = 0 to supportedTypes.Count() - 1
							if supportedTypes[j] = itype then
								e.buttonIndex = eindex
								eindex = eindex + 1
								validExtensions.Push(e)
								exit for
							endif
						end for
					endif
				endif
			endif
		endif
	end for

	return validExtensions
End Function

Sub installSettingsExtensions(paraScreen As Object, ext As Object)
	for i = 0 to ext.Count() - 1
		if ext[i].enableParagraph then
			ecode = Eval("ptext = " + ext[i].paragraphCodeToExecute)
			if type(ecode) = "Integer" and (ecode = 252 or ecode = 226) and type(ptext) = "String" then
				paraScreen.AddParagraph(ptext)
			endif
		endif
		paraScreen.AddButton(ext[i].buttonIndex, ext[i].buttonLabel)
	end for
End Sub

Sub runExtension(index As Integer, ext As Object, xe As Object)
	for i = 0 to ext.Count() - 1
		if ext[i].buttonIndex = index then
			ecode = Eval("success = " + ext[i].codeToExecute)
			if type(ecode) = "Integer" and (ecode = 252 or ecode = 226) and type(success) = "Boolean" then
				print chr(34);ext[i].title;chr(34);" executed successfully"
			else
				alert("Alert", "The requested operation could not be completed.")
			endif
			exit for
		endif
	end for
End Sub

Function getSpringboardButtons(xe As Object, extensions As Object) As Object
	gaa = GetGlobalAA()
	url = ""
	buttons = []

	itype = getStringAttribute(xe, "type", false)
	' new attribute in orml v1.2
	format = getStringAttribute(xe, "streamformat", false)
	if len(format) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		format = getStringAttribute(xe, "format", false)
	endif
	islive = getBoolAttribute(xe, "live")
	disableresumebtn = getBoolAttribute(xe, "disableresumebtn")
	disableplaybtn = getBoolAttribute(xe, "disableplaybtn")
	disabledescriptionbtn = getBoolAttribute(xe, "disabledescriptionbtn")
	enablereportstreambtn = getBoolAttribute(xe, "enablereportstreambtn")
	enableemailmebtn = getBoolAttribute(xe, "enableemailmebtn")
	enableemailfriendbtn = getBoolAttribute(xe, "enableemailfriendbtn")

	if itype = "slideshow" then
		if xe.image.Count() > 0 then
			url = getStringAttribute(xe.image[0], "url", true)
		endif
	else
		streams = getAudioVideoStreams(xe)
		if streams.Count() > 0 then
			url = streams[0].url
		endif
	endif

	if not(disableresumebtn) and not(islive) and not(format = "hls") and len(url) > 0 and not(gaa.prefs.enableadrise) then
		buttons.Push({index:1, label:"Resume"})
	endif

	if not(disableplaybtn) and len(url) > 0 then
		pbtn = {index:2, label:"Play " + itype, label2:"Play " + itype}
		if not(disableresumebtn) and not(islive) and not(format = "hls") and not(gaa.prefs.enableadrise) then
			pbtn.label2 = "Restart " + itype
		endif
		buttons.Push(pbtn)
	endif

	if not(disabledescriptionbtn) then
		buttons.Push({index:3, label:"View full description"})
	endif

	' the report broken stream feature is not enabled for slideshows
	if enablereportstreambtn and not(itype = "slideshow") and len(url) > 0 then
		buttons.Push({index:4, label:"Report broken stream"})
	endif

	if enableemailmebtn and len(url) > 0 then
		buttons.Push({index:5, label:"Email me more info"})
	endif

	if enableemailfriendbtn and len(url) > 0 then
		buttons.Push({index:6, label:"Email a friend"})
	endif

	for i = 0 to extensions.Count() - 1
		buttons.Push({index:extensions[i].buttonIndex, label:extensions[i].buttonLabel})
	end for

	return buttons
End Function

Function installSpringboardButtons(springboard As Object, buttons As Object, resumepos As Integer) As Object
	' we create a copy of the buttons array here so that if there
	' are any remaining buttons after the max limit is reached
	' we can return them for the more options feature
	moreoptions = []
	moreoptions.Append(buttons)
	moreoptions.Push({index:0, label:"Cancel"})

	springboard.ClearButtons()
	for i = 0 to buttons.Count() - 1
		if buttons[i].index = 1 then
			if resumepos > 0 then
				' show Resume button
				springboard.AddButton(buttons[i].index, buttons[i].label)
			endif
		elseif buttons[i].index = 2
			if resumepos > 0 then
				' show Restart label
				label = buttons[i].label2
			else
				' show Play label
				label = buttons[i].label
			endif
			springboard.AddButton(buttons[i].index, label)
		else
			total = springboard.CountButtons()
			if total = 4 and i < buttons.Count() - 1 then
				springboard.AddButton(10, "More Options")
				exit for
			else
				springboard.AddButton(buttons[i].index, buttons[i].label)
			endif
		endif
		moreoptions.Shift()
	end for

	return moreoptions
End Function

Sub updateSpringboardProgress(springboard As Object, length As Integer, resumepos As Integer, islive As Boolean, format As String)
	gaa = GetGlobalAA()
	if length > 0 and resumepos > 0 and length > resumepos and not(islive) and not(format = "hls") and not(gaa.prefs.enableadrise) then
		springboard.SetProgressIndicatorEnabled(true)
		springboard.SetProgressIndicator(resumepos, length)
	else
		springboard.SetProgressIndicatorEnabled(false)
	endif
End Sub

Function displaySpringboard(parentTitle As String, items As Object, iindex As Integer) As Integer
	' only create springboard screen the first time that displaySpringboard
	' is called. if a user is scrolling through media items on the springboard
	' screen then we just update the iindex and populate the existing springboard
	' object with the new content.
	springboard = CreateObject("roSpringboardScreen")

	sbStart:
	url = ""
	urlhash = ""
	length = 0
	resumepos = 0
	extensions = []
	gaa = GetGlobalAA()
	xe = items[iindex]

	' scrape the html here and update the attributes in the feed
	' before retrieving any attribute values
	enablescrapers = getBoolAttribute(xe, "enablescrapers")
	if enablescrapers then
		for i = 0 to xe.scraper.Count() - 1
			scrapeHTML(xe, xe.scraper[i])
		end for
		' set enablescrapers attribute to false since we no longer need it
		xe.AddAttribute("enablescrapers", "false")
	endif

	enableext = getBoolAttribute(xe, "enableextensions")
	islive = getBoolAttribute(xe, "live")
	itype = getStringAttribute(xe, "type", false)
	' new attribute in orml v1.2
	format = getStringAttribute(xe, "streamformat", false)
	if len(format) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		format = getStringAttribute(xe, "format", false)
	endif
	' new attribute in orml v1.2
	cid = getStringAttribute(xe, "contentid", false)
	if len(cid) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		cid = getStringAttribute(xe, "cid", false)
	endif
	title = getStringAttribute(xe, "title", true)
	rbsurl = getStringAttribute(xe, "rbsurl", true)
	eiurl = getStringAttribute(xe, "eiurl", true)

	' if the description is empty then we set the disabledescriptionbtn
	' attribute here to prevent the button from being added to the
	' springboard screen
	fulldesc = getElementText(xe, "description", true, true)
	if len(fulldesc) < 1 then
		xe.AddAttribute("disabledescriptionbtn", "true")
	endif

	if itype = "slideshow" then
		images = xe.GetNamedElements("image")
		length = images.Count()
		if length > 0 then
			url = getStringAttribute(xe.image[0], "url", true)
		endif
	else
		length = getIntegerAttribute(xe, "length")
		streams = getAudioVideoStreams(xe)
		if streams.Count() > 0 then
			url = streams[0].url
		endif
	endif

	if len(url) > 0 then
		urlhash = hashString(url, "md5")
		resumepos = getIntValFromReg(urlhash, itype)
	endif

	if len(cid) < 1 and len(urlhash) > 0
		cid = urlhash
	endif

	' retrieve array of extension objects
	if enableext and xe.extension.Count() > 0 then
		extensions = validateExtensions(itype, xe.extension)
	endif

	' retrieve array of button objects
	buttons = getSpringboardButtons(xe, extensions)

	initSpringboardScreen(parentTitle, xe, springboard)
	sbc = getSpringboardContent(xe)
	springboard.SetContent(sbc)

	' only the first 4 or 5 buttons are displayed, extra buttons are
	' returned and saved to the moreoptions array
	moreoptions = installSpringboardButtons(springboard, buttons, resumepos)

	' update progress indicator
	updateSpringboardProgress(springboard, length, resumepos, islive, format)

	' add support for like and rating buttons in a future version
	'springboard.AddThumbsUpDownButtonWithTips(7, 1, ["disliked it", "liked it"])
	'springboard.AddRatingButton(8, 60, 10)

	port = CreateObject("roMessagePort")
	springboard.SetMessagePort(port)
	springboard.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roSpringboardScreenEvent" then
			if msg.isScreenClosed() then
				return iindex
			elseif msg.isButtonPressed()
				bindex = msg.GetIndex()

				sbBtnOps:
				if bindex = 1 then ' resume
					if itype = "video" or itype = "audio" then
						resumepos = playAudioVideo(xe, resumepos)
					else ' itype = "slideshow"
						resumepos = playSlideshow(xe, resumepos)
					endif
					' we need to remove the resume button if playback has completed
					moreoptions = installSpringboardButtons(springboard, buttons, resumepos)
					' update progress indicator
					updateSpringboardProgress(springboard, length, resumepos, islive, format)
				elseif bindex = 2 ' play/restart
					if itype = "video" or itype = "audio" then
						resumepos = playAudioVideo(xe, 0)
					else ' itype = "slideshow"
						resumepos = playSlideshow(xe, 0)
					endif
					' we need to add the resume button if it doesnt exist
					moreoptions = installSpringboardButtons(springboard, buttons, resumepos)
					' update progress indicator
					updateSpringboardProgress(springboard, length, resumepos, islive, format)
				elseif bindex = 3
					' display full description as document screen
					if len(fulldesc) > 0 displayDocument(title, xe)
				elseif bindex = 4
					reportBrokenStream(rbsurl, [["id",cid],["url",url],["feedurl",getCurrentFeed()]])
				elseif bindex = 5
					sendEmail("me", eiurl, [["id",cid],["url",url],["feedurl",getCurrentFeed()]])
				elseif bindex = 6
					sendEmail("friend", eiurl, [["id",cid],["url",url],["feedurl",getCurrentFeed()]])
				elseif bindex > 6 and bindex < 10
					' reserved for future buttons
				elseif bindex = 10
					' show popup containing remaining buttons
					btninfo = showDialog("More Options", "", true, true, false, moreoptions)
					bindex = btninfo.index
					if bindex > 0 then goto sbBtnOps
				else
					' extensions must contain an index higher than 10
					runExtension(msg.GetIndex(), extensions, xe)
				endif
			elseif msg.isRemoteKeyPressed()
				if gaa.prefs.scrollsb then
					bindex = msg.GetIndex()
					if bindex = 4 or bindex = 5 then
						if bindex = 5 then 'right button
							if items.Count() - 1 > iindex then
								tmpiindex = iindex + 1
							else
								tmpiindex = 0
							endif
						else 'bindex = 4 'left button
							if iindex > 0 then
								tmpiindex = iindex - 1
							else
								tmpiindex = items.Count() - 1
							endif
						endif
						' we can only scroll through items that support springboard
						' screens. might be a good idea to scroll to next supported
						' item in row instead of just preventing the user from scrolling
						' any further when an unsupported item is detected.
						tmpitype = getStringAttribute(items[tmpiindex], "type", false)
						if tmpitype = "audio" or tmpitype = "video" or tmpitype = "slideshow" then
							iindex = tmpiindex
							goto sbStart
						endif
					endif
				endif
			endif
		endif
	end while
End Function

Function getAudioVideoStreams(xe As Object) As Object
	streams = []
	itype = getStringAttribute(xe, "type", false)
	' new attribute in orml v1.2
	cidDefault = getStringAttribute(xe, "contentid", false)
	if len(cidDefault) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		cidDefault = getStringAttribute(xe, "cid", false)
	endif
	stickyredirectsDefault = getBoolAttribute(xe, "stickyredirects")

	for i = 0 to xe.stream.Count() - 1
		url = getStringAttribute(xe.stream[i], "url", true)
		if len(url) > 0 then
			ishd = false
			if itype = "video" then
				ishd = getBoolAttribute(xe.stream[i], "ishd")
			endif
			' new attribute in orml v1.2
			cid = getStringAttribute(xe.stream[i], "contentid", false)
			if len(cid) < 1 then
				' added to maintain backwards compatibility with orml v1.1
				' send a default cid value in case it was only included on
				' the item element and not on the stream elements.
				cid = getStringAttribute(xe.stream[i], "cid", false, cidDefault)
			endif

			stream = {
				url: url,
				bitrate: getIntegerAttribute(xe.stream[i], "bitrate"),
				quality: ishd,
				contentid: cid,
				' send a default stickyredirects value in case it was only included on
				' the item element and not on the stream elements
				stickyredirects: getBoolAttribute(xe.stream[i], "stickyredirects", stickyredirectsDefault)
			}
			streams.Push(stream)
		else
			print "no url detected - skipping ";itype
		endif
	end for

	' if streams array is empty then try to grab the
	' stream info from the item element
	if streams.Count() < 1 then
		url = getStringAttribute(xe, "url", true)
		if len(url) > 0 then
			ishd = false
			if itype = "video" then
				ishd = getBoolAttribute(xe, "ishd")
			endif

			stream = {
				url: url,
				bitrate: getIntegerAttribute(xe, "bitrate"),
				quality: ishd,
				contentid: cidDefault,
				stickyredirects: stickyredirectsDefault
			}
			streams.Push(stream)
		endif
	endif

	return streams
End Function

Function playAudioVideo(xe As Object, resumepos As Integer) As Integer
	gaa = GetGlobalAA()
	urlhash = ""
	isResumed = false
	currentpos = resumepos ' in seconds

	streams = getAudioVideoStreams(xe)
	if streams.Count() < 1 then return 0

	' grab the first url in the streams array for generating the hash
	url = streams[0].url

	itype = getStringAttribute(xe, "type", false)
	title = getStringAttribute(xe, "title", true)
	' new attribute in orml v1.2
	suburl = getStringAttribute(xe, "subtitleurl", true)
	if len(suburl) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		suburl = getStringAttribute(xe, "suburl", true)
	endif
	sdbifurl = getStringAttribute(xe, "sdbifurl", true)
	hdbifurl = getStringAttribute(xe, "hdbifurl", true)
	' new attribute in orml v1.2
	format = getStringAttribute(xe, "streamformat", false)
	if len(format) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		format = getStringAttribute(xe, "format", false)
	endif
	' new attribute in orml v1.2
	cid = getStringAttribute(xe, "contentid", false)
	if len(cid) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		cid = getStringAttribute(xe, "cid", false)
	endif
	disableAdrise = getBoolAttribute(xe, "disableadrise")
	ishd = getBoolAttribute(xe, "ishd")
	islive = getBoolAttribute(xe, "live")
	length = getIntegerAttribute(xe, "length")

	if len(url) > 0 then
		urlhash = hashString(url, "md5")
	endif

	if len(cid) < 1 and len(urlhash) > 0
		cid = urlhash
	endif

	' we dont test for a length value since there may be instances
	' where a rss feed does not contain the length of the media.
	' by requiring a length it would prevent users from resuming
	' playback of some podcasts at a specific position.
	useRegistry = (not(islive) and not(format = "hls") and len(urlhash) > 0 and (not(gaa.prefs.enableadrise) or disableAdrise))

	o = {}
	o.Streams = streams
	o.Title = title
	o.IsHD = ishd
	o.StreamFormat = format
	o.SubtitleUrl = suburl
	o.Live = islive

	if itype = "video" then
		o.SDBifUrl = sdbifurl
		o.HDBifUrl = hdbifurl
		o.HDBranded = ishd
		' only used for adrise sdk
		o.Id = cid
	endif

	if not(islive) and not(format = "hls") then
		if length > 0 then
			o.Length = length
		endif
		if resumepos > 0 and itype = "video" then
			print "resuming playback at ";resumepos;" seconds"
			o.PlayStart = resumepos + 1 'the offset is from 0 so we add one
			'o.StreamStartTimeOffset = resumepos
		endif
	endif

	if gaa.prefs.enableadrise and not(disableAdrise) then
		adrise_PlayVideo(o)
		' theres no way to retrieve the current playback position without
		' modifying the adrise sdk so we just return 0
		return 0
	endif

	port = CreateObject("roMessagePort")
	player = CreateObject("roVideoScreen")
	player.SetMessagePort(port)
	player.SetPositionNotificationPeriod(5)
	player.SetContent(o)
	player.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roVideoScreenEvent" then
			if msg.isScreenClosed() then
				if useRegistry then saveIntValToReg(urlhash, currentpos, true, itype)
				return currentpos
			elseif msg.isPlaybackPosition()
				currentpos = msg.GetIndex()
				'print "playback position: ";currentpos

				' this is literally the ONLY way to resume playback of a mp3 file
				' (and possibly wma files - none tested yet) at a position other
				' than 0. the PlayStart property has no effect on the playback
				' position for audio files. calling Seek() prior to or after calling
				' Show() has no effect. calling Seek() from the isStreamStarted
				' notification has no effect. the StreamStartTimeOffset property
				' also has no effect.
				if itype = "audio" and not(isResumed) and resumepos > 0 then
					print "resuming playback at ";resumepos;" seconds"
					isResumed = true
					player.Seek((resumepos + 1) * 1000)
				endif
			elseif msg.isRequestFailed()
				print "request failed"
				print "error code: ";msg.GetIndex()
				print "error message: ";msg.GetMessage()
				alert("Alert", "Could not connect to server. Please try again later.")
				return currentpos
			elseif msg.isStatusMessage()
				print "status message: ";msg.GetMessage()
			elseif msg.isFullResult()
				print "playback completed"
				currentpos = 0
				if useRegistry then saveIntValToReg(urlhash, currentpos, true, itype)
				return currentpos
			elseif msg.isPartialResult()
				print "playback interrupted"
				if useRegistry then saveIntValToReg(urlhash, currentpos, true, itype)
				return currentpos
			elseif msg.isStreamStarted()
				print "stream started: ";msg.GetIndex()
			elseif msg.isPaused()
				print "stream paused"
				if useRegistry then saveIntValToReg(urlhash, currentpos, true, itype)
			elseif msg.isResumed()
				print "stream resumed"
			endif
		endif
	end while
End Function

Function getSpringboardContent(xe As Object) As Object
	gaa = GetGlobalAA()
	sbo = {}
	fulldesc = ""

	itype = getStringAttribute(xe, "type", false)
	album = getStringAttribute(xe, "album", true)
	artist = getStringAttribute(xe, "artist", true)
	' new attribute in orml v1.2
	format = getStringAttribute(xe, "streamformat", false)
	if len(format) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		format = getStringAttribute(xe, "format", false)
	endif
	' new attribute in orml v1.2
	released = getStringAttribute(xe, "releasedate", false)
	if len(released) < 1 then
		' added to maintain backwards compatibility with orml v1.1
		released = getStringAttribute(xe, "released", false)
	endif
	length = getIntegerAttribute(xe, "length")
	live = getBoolAttribute(xe, "live")

	' we have to set the content type to audio in order to
	' enable the progress indicator for all media types.
	sbo.ContentType = "audio"

	sbo.Title = getStringAttribute(xe, "title", true)
	sbo.ShortDescriptionLine1 = sbo.Title
	sbo.ShortDescriptionLine2 = getStringAttribute(xe, "shortdesc", true)
	sbo.SDPosterUrl = getStringAttribute(xe, "sdposterurl", true)
	sbo.HDPosterUrl = getStringAttribute(xe, "hdposterurl", true)
	sbo.ReleaseDate = released
	sbo.UserStarRating = getIntegerAttribute(xe, "starrating")

	if itype = "video" then
		sbo.Rating = getStringAttribute(xe, "rating", false)
		sbo.Categories = []
		sbo.Categories.Push(getStringAttribute(xe, "genre1", false))
		sbo.Categories.Push(getStringAttribute(xe, "genre2", false))
		sbo.Actors = []
		sbo.Actors.Push(getStringAttribute(xe, "actor1", false))
		sbo.Actors.Push(getStringAttribute(xe, "actor2", false))
		sbo.Actors.Push(getStringAttribute(xe, "actor3", false))
		sbo.Director = getStringAttribute(xe, "director", false)
		sbo.IsHD = getBoolAttribute(xe, "ishd")
		sbo.HDBranded = sbo.IsHD
	endif

	if itype = "video" or itype = "audio" then
		sbo.Live = live
	endif

	if itype = "audio" and (len(album) > 0 or len(artist) > 0) then
		' in order to make the artist and album values stand out from
		' the rest of the text on the screen we can either color them
		' blue and underline them with <a href=#></a> or make them
		' bold with <font color=black></font>
		if len(artist) > 0 then
			fulldesc = "artist &nbsp; <font color=black>" + artist + "</font><br>"
		endif
		if len(album) > 0 then
			 fulldesc = fulldesc + "album &nbsp; <font color=black>" + album + "</font>"
		endif

		' the two lines below are not necessary since the audio
		' description style isnt supported due to the bug described
		' in the createSpringboardScreen function
		'sbo.Album = album
		'sbo.Artist = artist
	else
		fulldesc = getElementText(xe, "description", true, true)

		' if we dont crop the text here then it may cause a long
		' delay when the springboard is loaded. the longer the
		' description the more likely a delay is to occur.
		fulldesc = cropString(fulldesc, gaa.constants.maxlength.springboardFullDesc, true)
	endif

	sbo.Description = fulldesc

	if not(itype = "slideshow") and not(live) and not(format = "hls") and length > 0 then
		sbo.Length = length
	endif

	return sbo
End Function

Sub initSpringboardScreen(parentTitle As String, xe As Object, springboard As Object)
	gaa = GetGlobalAA()
	itype = getStringAttribute(xe, "type", false)
	album = getStringAttribute(xe, "album", true)
	artist = getStringAttribute(xe, "artist", true)
	starrating = getIntegerAttribute(xe, "starrating")
	title = getStringAttribute(xe, "title", true)
	sdposterurl = getStringAttribute(xe, "sdposterurl", true)
	hdposterurl = getStringAttribute(xe, "hdposterurl", true)

	' we cannot set a custom poster style if we have enabled the
	' progress indicator. it is currently enabled by default.
	'style = getStringAttribute(xe, "style", false, "rounded-square-generic")
	'springboard.SetPosterStyle(style)

	'if itype = "audio" then
		'if len(album) > 0 or len(artist) > 0 then
			' the only reason to set the description style to audio is
			' to display an album and artist label on the springboard
			' screen. unfortunately if the description style is set to
			' audio then the second that the back button is pressed
			' while the audio is playing it will crash the channel and
			' return to the main Roku menu. if the style is removed then
			' everything works as expected.
			'springboard.SetDescriptionStyle("audio")
		'endif
	'endif

	' enable or disable the star rating
	springboard.SetStaticRatingEnabled((starrating > 0))

	springboard.AllowNavLeft(gaa.prefs.scrollsb)
	springboard.AllowNavRight(gaa.prefs.scrollsb)

	bcp = cropString(parentTitle, gaa.constants.maxlength.breadcrumb, true)
	bct = cropString(title, gaa.constants.maxlength.breadcrumb, true)

	springboard.SetBreadcrumbText(bcp, bct)
	springboard.SetBreadcrumbEnabled(true)
	springboard.SetDisplayMode("scale-to-fit")
	springboard.PrefetchPoster(sdposterurl, hdposterurl)
End Sub

Function createKeyboard(title As String, tip As String, defaultValue As String, maxLength As Integer) As Object
	keyboard = CreateObject("roKeyboardScreen")
	keyboard.SetTitle(title)
	keyboard.SetDisplayText(tip)
	keyboard.SetText(defaultValue)
	if maxLength > 0 then keyboard.SetMaxLength(maxLength)
	keyboard.AddButton(1, "finished")
	keyboard.AddButton(2, "back")
	return keyboard
End Function

Function createParagraphScreen(parentTitle As String, title As String, addHeader As Boolean) As Object
	gaa = GetGlobalAA()

	bcp = cropString(parentTitle, gaa.constants.maxlength.breadcrumb, true)
	bct = cropString(title, gaa.constants.maxlength.breadcrumb, true)

	paragraph = CreateObject("roParagraphScreen")
	paragraph.SetBreadcrumbText(bcp, bct)
	if addHeader then
		ht = cropString(title, gaa.constants.maxlength.documentTitle, true)
		paragraph.AddHeaderText(ht)
	endif
	return paragraph
End Function


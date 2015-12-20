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



Function isValidUrl(url As String) As Boolean
	re = CreateObject("roRegex", "^(http|pkg|tmp)\:\/\/?\w+", "s")
	matches = re.Match(url)
	return (matches.Count() > 1)
End Function

Function getFileNameFromUrl(url As String) As String
	re = CreateObject("roRegex", "\/([^\/\?]+)\?|\/([^\/\?]+)$", "s")
	matches = re.Match(url)
	if matches.Count() > 1 and len(matches[1]) > 0 then
		return matches[1]
	elseif matches.Count() > 2 and len(matches[2]) > 0
		return matches[2]
	else
		return ""
	endif
End Function

Function cropString(str As String, maxLength As Integer, addElipsis As Boolean) As String
	if len(str) > maxLength then
		if addElipsis and maxLength > 3 then
			str = left(str, maxLength - 3) + "..."
		else
			str = left(str, maxLength)
		endif
	endif
	return str
End Function

Function generateUrlWithParams(url As String, params As Object) As String
	' determine if url already has parameters attached to it
	pre = CreateObject("roRegex", "\?", "")
	matches = pre.Match(url)
	hasParam = (matches.Count() > 0)

	pstr = ""
	http = CreateObject("roUrlTransfer")
	for i = 0 to params.Count() - 1
		if i = 0 and not(hasParam) then
			pstr = pstr + "?"
		else
			pstr = pstr + "&"
		endif
		pstr = pstr + params[i][0] + "=" + http.Escape(params[i][1])
	end for
	return url + pstr
End Function

Function validateEmail(email As String) As Boolean
	re = CreateObject("roRegex", "^(\w+?)@(\w+?)\.?\w*$", "s")
	matches = re.Match(email)
	return (matches.Count() > 2)
End Function

Function convertBoolToString(boolValue As Boolean) As String
	if boolValue then
		return "true"
	else
		return "false"
	endif
End Function

Function reEscape(str As String) As String
	re = CreateObject("roRegex", "(\W)", "")
	str = re.ReplaceAll(str, "\\\1")
	return str
End Function

Function getBoolAttribute(xe As Object, attrName As String, defaultValue = false As Boolean) As Boolean
	if xe.HasAttribute(attrName) then
		attrs = xe.GetAttributes()
		if attrs[attrName] = "true" or attrs[attrName] = "1" then
			return true
		elseif attrs[attrName] = "false" or attrs[attrName] = "0"
			return false
		endif
	endif
	return defaultValue
End Function

Function getStringAttribute(xe As Object, attrName As String, stripHTML As Boolean, defaultValue = "" As String) As String
	if xe.HasAttribute(attrName) then
		attrs = xe.GetAttributes()
		if len(attrs[attrName]) > 0 then
			if stripHTML then
				return stripHTMLEntities(attrs[attrName])
			else
				return attrs[attrName]
			endif
		endif
	endif
	return defaultValue
End Function

Function getIntegerAttribute(xe As Object, attrName As String, defaultValue = 0 As Integer) As Integer
	if xe.HasAttribute(attrName) then
		attrs = xe.GetAttributes()
		attrInt = strtoi(attrs[attrName])
		if type(attrInt) = "Integer" then
			return attrInt
		endif
	endif
	return defaultValue
End Function

Function getElementText(xe As Object, elemName As String, stripHTML As Boolean, stripEWS As Boolean) As String
	txt = ""
	elems = xe.GetNamedElements(elemName)
	if elems.Count() > 0 and len(elems[0].GetText()) > 0 then
		txt = elems[0].GetText()
		if stripHTML then
			txt = stripHTMLEntities(txt)
		endif
		if stripEWS then
			txt = stripExtraWhiteSpace(txt)
		endif
	endif
	return txt
End Function

Function createMessageDialog(port As Object, title As String, message As String, enableOverlay As Boolean, enableTopLeft As Boolean, enableBusyAnimation As Boolean, buttons As Object) As Object
	dialog = CreateObject("roMessageDialog")
	if not(type(port) = "roMessagePort") then
		port = CreateObject("roMessagePort")
	endif
	dialog.SetMessagePort(port)
	dialog.SetTitle(title)
	if len(message) > 0 then dialog.SetText(message)
	dialog.EnableOverlay(enableOverlay)
	dialog.SetMenuTopLeft(enableTopLeft)
	if enableBusyAnimation then dialog.ShowBusyAnimation()
	for i = 0 to buttons.Count() - 1
		dialog.AddButton(buttons[i].index, buttons[i].label)
	end for
	return dialog
End Function

Function showDialog(title As String, message As String, enableOverlay As Boolean, enableTopLeft As Boolean, enableBusyAnimation As Boolean, buttons As Object) As Object
	port = CreateObject("roMessagePort")
	dialog = createMessageDialog(port, title, message, enableOverlay, enableTopLeft, enableBusyAnimation, buttons)
	dialog.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roMessageDialogEvent" then
			if msg.isScreenClosed() then
				return {index:0,data:0}
			elseif msg.isButtonPressed()
				return {index:msg.GetIndex(),data:msg.GetData()}
			endif
		endif
	end while
End Function

Sub alert(title As String, message As String)
	port = CreateObject("roMessagePort")
	dialog = createMessageDialog(port, title, message, true, false, false, [{index:1,label:"OK"}])
	dialog.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roMessageDialogEvent" then
			if msg.isScreenClosed() or (msg.isButtonPressed() and msg.GetIndex() = 1) then
				return
			endif
		endif
	end while
End Sub

Function confirm(title As String, message As String) As Boolean
	port = CreateObject("roMessagePort")
	dialog = createMessageDialog(port, title, message, true, false, false, [{index:1,label:"OK"}, {index:2,label:"Cancel"}])
	dialog.Show()

	while true
		msg = wait(0, port)
		if type(msg) = "roMessageDialogEvent" then
			if msg.isScreenClosed() then
				return false
			elseif msg.isButtonPressed()
				if msg.GetIndex() = 1 then
					return true
				else
					return false
				endif
			endif
		endif
	end while
End Function

' the return value indicates whether or not any registry entries were cleared.
' a return value of true is not necessarily an indication of success.
Function clearRegistry() As Boolean
	ok = confirm("Warning", "This will clear everything in the registry including saved playback positions for all media in this channel. Are you sure you want to continue?")
	if not(ok) then return false

	isError = false
	reg = CreateObject("roRegistry")
	reglist = reg.GetSectionList()
	for i = 0 to reglist.Count() - 1
		if not reg.Delete(reglist[i]) then
			print "could not delete ";reglist[i];" from registry"
			isError = true
		else
			print "deleting ";reglist[i]
		endif
	end for

	if not(reg.Flush()) or isError then
		msg = "Some entries could not be cleared."
	else
		msg = "All registry entries successfully cleared."
	endif

	alert("Alert", msg)

	return true
End Function

Function stripExtraWhiteSpace(str As String) As String
	' remove all whitespace except spaces and new lines. this
	' should strip all unicode whitespace.
	re = CreateObject("roRegex", "[^\S \n]", "s")
	str = re.ReplaceAll(str, "")

	' remove any whitespace at the beginning or end of the string,
	' remove spaces before or after new lines and reduce sequences
	' of consecutive spaces to a single space.
	re = CreateObject("roRegex", "^\s+|(?<=\n) | (?=\s)|\s+$", "s")
	str = re.ReplaceAll(str, "")

	' reduce sequences of consecutive new lines to a maximum of 2.
	re = CreateObject("roRegex", "\n\n\K\n+", "s")
	str = re.ReplaceAll(str, "")
	return str
End Function

Function hashString(str As String, alg As String) As String
	ba = CreateObject("roByteArray")
	ba.FromAsciiString(str)
	digest = CreateObject("roEVPDigest")
	digest.Setup(alg)
	digest.Update(ba)
	result = digest.Final()
	return result
End Function

Function convertUrlToFileName(url As String, fileExt As String) As String
	filename = hashString(url, "sha1")
	return filename + fileExt
End Function

Function convertUrlToPath(url As String, fileExt As String) As String
	path = "tmp:/" + convertUrlToFileName(url, fileExt)
	return path
End Function

Function countLines(content As String) As Integer
	re = CreateObject("roRegex", "\n", "s")
	lines = re.Split(content) 'returns roList
	totalLines = lines.Count()
	for i = 0 to lines.Count() - 1
		' we estimate a max of 68 characters per line
		for j = 68 to len(lines[i]) step 67
			totalLines = totalLines + 1
		end for
	end for
	return totalLines
End Function

Function getStrValFromReg(keyname As String, section As String) As String
	reg = CreateObject("roRegistrySection", section)
	if reg.Exists(keyname) then
		return reg.Read(keyname)
	endif
	return ""
End Function

Function saveStrValToReg(keyname As String, val As String, section As String) As Boolean
	reg = CreateObject("roRegistrySection", section)
	reg.Write(keyname, val)
	return reg.Flush()
End Function

Function getBoolValFromReg(keyname As String, section As String) As Boolean
	reg = CreateObject("roRegistrySection", section)
	if reg.Exists(keyname) then
		val = reg.Read(keyname)
		if val = "true" or val = "1" then return true
	endif
	return false
End Function

Function saveBoolValToReg(keyname As String, val As Boolean, section As String) As Boolean
	reg = CreateObject("roRegistrySection", section)
	' we use a 1 for true and 0 for false to save space in the registry
	if val then
		keyval = "1"
	else
		keyval = "0"
	endif
	reg.Write(keyname, keyval)
	return reg.Flush()
End Function

Function getIntValFromReg(keyname As String, section As String) As Integer
	reg = CreateObject("roRegistrySection", section)
	if reg.Exists(keyname) then
		temp = strtoi(reg.Read(keyname))
		if not(type(temp) = "Invalid") then return temp
	endif
	return 0
End Function

' when saving resume positions for video/audio/slideshow we use md5 to
' conserve as much space as possible in the registry.
' md5 = 32 bytes
' sha1 = 40 bytes
Function saveIntValToReg(keyname As String, val As Integer, deleteIfEmpty As Boolean, section As String) As Boolean
	' count number of registry entries to avoid running out of space
	total = countRegistryKeys()
	print total;" total registry keys"
	if total >= 443 then
		' only 16kb is allocated for storage and each playback position
		' saved to the registry requires between 33 - 36 bytes. we set
		' a max limit of 443 registry entries. 440 playback positions
		' plus 1 profile entry and 2 preferences entries.
		clearPlaybackPositions()
	endif

	reg = CreateObject("roRegistrySection", section)
	' to conserve space we delete registry entries if val = 0 and
	' deleteIfEmpty = true. theres no point in saving most 0 values
	' since a 0 is returned automatically if an entry is not found.
	if reg.Exists(keyname) and val = 0 and deleteIfEmpty then
		reg.Delete(keyname)
	else
		reg.Write(keyname, str(val))
	endif
	return reg.Flush()
End Function

Sub clearPlaybackPositions()
	reg = CreateObject("roRegistry")
	reg.Delete("audio")
	reg.Delete("video")
	reg.Delete("slideshow")
	reg.Flush()
End Sub

Function countRegistryKeys() As Integer
	total = 0
	reg = CreateObject("roRegistry")
	sections = reg.GetSectionList()
	for i = 0 to sections.Count() - 1
		rsec = CreateObject("roRegistrySection", sections[i])
		keys = rsec.GetKeyList()
		total = total + keys.Count()
	end for
	return total
End Function

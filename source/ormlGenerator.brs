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


Function convertExtToFormat(url As String) As String
	format = ""
	' we want this regex to be a greedy match so
	' that it replaces everything up to the file
	' extension. otherwise it might stop after the
	' domain name.
	re = CreateObject("roRegex", "^.+\.", "s")
	ext = re.Replace(url, "")
	extArray = [
                    ["mp3", ["mp3"]],
                    ["wma", ["wma"]],
                    ["mp4", ["mp4","m4v","m4a","mov"]],
                    ["wmv", ["wmv","asf"]],
                    ["hls", ["m3u", "m3u8", "ts"]]
                   ]

	for i = 0 to extArray.Count() - 1
		for j = 0 to extArray[i][1].Count() - 1
			if ext = extArray[i][1][j] then
				format = extArray[i][0]
				return format
			endif
		end for
	end for

	return format
End Function

Function convertMimeToFormat(mime As String) As String
	format = mime
        mimeArray = [
                     ["mp3", [
                              "audio/mpeg","audio/x-mpeg","audio/mp3","audio/x-mp3","audio/mpeg3",
                              "audio/x-mpeg3","audio/mpg","audio/x-mpg","audio/x-mpegaudio"
                             ]
                     ],
                     ["wma", ["audio/wma","audio/x-wma","audio/x-ms-wma","audio/x-ms-asf"]],
                     ["mp4", [
                              "audio/mp4","audio/x-mp4","audio/m4a","audio/x-m4a","video/m4v",
                              "video/x-m4v","video/m4v-es","video/mp4","video/x-mp4",
                              "video/quicktime","video/x-quicktime","video/mov","video/x-mov",
                              "video/mpeg","video/vnd.objectvideo","audio/mp4a-latm"
                             ]
                     ],
                     ["wmv", ["video/wmv","video/x-wmv","video/x-ms-wmv"]],
                     ["hls", ["application/vnd.apple.mpegurl"]]
                    ]

	for i = 0 to mimeArray.Count() - 1
		for j = 0 to mimeArray[i][1].Count() - 1
			if mime = mimeArray[i][1][j] then
				format = mimeArray[i][0]
				return format
			endif
		end for
	end for

	return format
End Function

Function convertHMSToSeconds(time As String) As Integer
	seconds = 0
	timeArr = []
	' split hh:mm:ss into array and then reverse order
	re = CreateObject("roRegex", ":", "")
	tempArr = re.Split(time) 'returns roList
	for i = tempArr.Count() - 1 to 0 step - 1
		timeArr.Push(tempArr[i])
	end for

	for i = 0 to timeArr.Count() - 1
		if i > 2 then exit for
		tempInt = strtoi(timeArr[i])
		if type(tempInt) = "Invalid" then exit for
		seconds = seconds + (60 ^ i) * tempInt
	end for
	return seconds
End Function

Function convertTemplateMarkupArray(item As Object, tmark As Object) As String
	wstest = ""
	output = ""
	re = CreateObject("roRegex", "\s+", "s")
	for i = 0 to tmark.Count() - 1
		if type(tmark[i]) = "roString" then
			output = convertTemplateMarkup(item, tmark[i])
			if len(output) > 0 then
				wstest = re.ReplaceAll(output, "")
				if len(wstest) > 0 then return output
			endif
		endif
	end for
	return output
End Function

Function convertTemplateMarkup(item As Object, tmark As String) As String
	dtre = CreateObject("roRegex", "<%([^%]*)%>", "s") 'dt = dynamic tags
	bre = CreateObject("roRegex", "{([^{}]*)}", "s") 'b = brackets
	cre = CreateObject("roRegex", ":(.?)$", "s") 'c = case
	ihre = CreateObject("roRegex", "#$", "s") 'ih = innerHTML
	' use greedy capture so that all forward slashes are captured
	rere = CreateObject("roRegex", "/(.*)/", "s")

	dtwhile:
	dtmatches = dtre.Match(tmark)
	while dtmatches.Count() > 1
		if len(dtmatches[1]) < 1 then
			tmark = dtre.Replace(tmark, "")
			goto dtwhile
		endif

		dtprop = dtmatches[1]

		' remove regex from the dynamic tag
		re = ""
		rmatches = rere.Match(dtprop)
		if rmatches.Count() > 1 then
			re = rmatches[1]
		endif
		dtprop = rere.Replace(dtprop, "")

		' remove case type from the dynamic tag
		caseType = 0
		cmatches = cre.Match(dtprop)
		if cmatches.Count() > 1 then
			if cmatches[1] = "L" then
				caseType = 1
			elseif cmatches[1] = "U"
				caseType = 2
			endif
		endif
		dtprop = cre.Replace(dtprop, "")

		bwhile:
		bmatches = bre.Match(dtprop)
		while bmatches.Count() > 1
			if len(bmatches[1]) < 1 then
				dtprop = bre.Replace(dtprop, "")
				goto bwhile
			endif

			bprop = bmatches[1]

			brsmark = "GetNamedElements(" + chr(34) + bprop + chr(34) + ")"
			dtprop = bre.Replace(dtprop, brsmark)
			bmatches = bre.Match(dtprop)
		end while

		dtprop = ihre.Replace(dtprop, ".GetText()")

		ormlAttributeValue = ""
		ecode = Eval("ormlAttributeValue = item." + dtprop)
		if type(ormlAttributeValue) = "Invalid" or not(type(ecode) = "Integer") or (not(ecode = 252) and not(ecode = 226)) then
			print "item.";dtprop;" could not be found in the xml feed"
			tmark = dtre.Replace(tmark, "")
		else
			' search attribute value or text node for regex specified in dynamic tag
			if len(re) > 0 then
				attrre = CreateObject("roRegex", re, "s")
				attrmatches = attrre.Match(ormlAttributeValue)
				if attrmatches.Count() > 1 then
					ormlAttributeValue = attrmatches[1]
				endif
			endif

			' convert case if specified in template
			if caseType = 1 then
				ormlAttributeValue = LCase(ormlAttributeValue)
			elseif caseType = 2 then
				ormlAttributeValue = UCase(ormlAttributeValue)
			endif

			' theres no point in preserving html markup since it cant be displayed
			' on the Roku screens so we decode any html entities and then strip the
			' html tags.
			ormlAttributeValueStripped = stripHTMLTags(stripHTMLEntities(ormlAttributeValue))

			tmark = dtre.Replace(tmark, ormlAttributeValueStripped)
		endif
		dtmatches = dtre.Match(tmark)
	end while

	return tmark
End Function

Function convertXMLFeedToORML(xmlFilePath As String, isPrimary As Boolean, template As String, defaultPosterUrl As String) As Boolean
	TEMPLATE_DIR = "pkg:/source/templates/"
	TEMPLATE_FILE_NAME = template + ".brs"
	TEMPLATE_FILE_PATH = TEMPLATE_DIR + TEMPLATE_FILE_NAME

	xml = CreateObject("roXMLElement")
	xml.SetName("orml")
	xml.AddAttribute("version", "1.2")
	xml.AddAttribute("xmlns", "http://sourceforge.net/p/openrokn/home/ORML")
	if isPrimary then
		' if we are converting to a primary feed then it is safe to assume
		' this is for a search item. we use Results as a generic title and
		' use the 16x9 episodic style since it supports long descriptions.
		channel = xml.AddElement("channel")
		feed = channel.AddElement("item")
		feed.AddAttribute("type", "poster")
		feed.AddAttribute("style", "flat-episodic-16x9")
		feed.AddAttribute("title", "Results")
	else
		feed = xml.AddElement("feed")
	endif

	' parse xml feed
	xe = CreateObject("roXMLElement")
	if not xe.Parse(ReadAsciiFile(xmlFilePath)) then
		print "The xml feed could not be parsed."
		return false
	endif

	tlist = MatchFiles(TEMPLATE_DIR, TEMPLATE_FILE_NAME)
	if tlist.Count() < 1 then
		print "The template cannot be found."
		return false
	endif

	ecode = Eval("t = " + template + "()")
	if not(type(ecode) = "Integer") or (not(ecode = 252) and not(ecode = 226)) then
		print "The template cannot be found."
		return false
	endif

	if not(t.isEnabled) or not(t.isXML) or not(type(t) = "roAssociativeArray") then
		print "The template is currently disabled."
		return false
	endif

	if len(t.items) < 1 then
		print "You have not specified the items array."
		return false
	endif

	ecode = Eval("items = xe." + t.items)
	if not(type(ecode) = "Integer") or (not(ecode = 252) and not(ecode = 226)) then
		print "The items array could not be found."
		return false
	endif

	if not(type(items) = "roXMLList") or items.Count() < 1 then
		print "The items array could not be found."
		return false
	endif

	sdposterurl = ""
	hdposterurl = ""

	' get default poster urls in case they are not defined per item
	if type(t.defaultSDPoster) = "roArray" then
		sdposterurl = convertTemplateMarkupArray(xe, t.defaultSDPoster)
	elseif type(t.defaultSDPoster) = "roString"
		sdposterurl = convertTemplateMarkup(xe, t.defaultSDPoster)
	endif
	if len(sdposterurl) < 1 then sdposterurl = defaultPosterUrl
	sdposterurl = encodeHTMLEntities(sdposterurl)

	if type(t.defaultHDPoster) = "roArray" then
		hdposterurl = convertTemplateMarkupArray(xe, t.defaultHDPoster)
	elseif type(t.defaultHDPoster) = "roString"
		hdposterurl = convertTemplateMarkup(xe, t.defaultHDPoster)
	endif
	if len(hdposterurl) < 1 then hdposterurl = defaultPosterUrl
	hdposterurl = encodeHTMLEntities(hdposterurl)

	for i = 0 to items.Count() - 1
		if t.limit > -1 and i >= t.limit then exit for

		' generate xml
		item = feed.AddElement("item")
		item.AddAttribute("type", t.itemType)

		for each j in t.itemAttributes
			ormlAttributeValue = ""

			if type(t.itemAttributes[j]) = "roArray" then
				ormlAttributeValue = convertTemplateMarkupArray(items[i], t.itemAttributes[j])
			elseif type(t.itemAttributes[j]) = "roString"
				ormlAttributeValue = convertTemplateMarkup(items[i], t.itemAttributes[j])
			endif

			if len(ormlAttributeValue) > 0 then
				' we have to re-encode any leftover html entities to prevent
				' errors in the xml.
				ormlAttributeValue = encodeHTMLEntities(ormlAttributeValue)

				' convert mime types into supported formats - only necessary for audio/video
				if t.itemType = "video" or t.itemType = "audio" then
					if j = "format" or j = "streamformat" then
						ormlAttributeValue = convertMimeToFormat(ormlAttributeValue)
						format = getStringAttribute(item, "streamformat", false)
						if len(format) < 1 then format = getStringAttribute(item, "format", false)
						if not(format = ormlAttributeValue) then
							if t.itemType = "video" and not(ormlAttributeValue = "mp4") and not(ormlAttributeValue = "wmv") and not(ormlAttributeValue = "hls") then
								ormlAttributeValue = ""
							elseif t.itemType = "audio" and not(ormlAttributeValue = "mp3") and not(ormlAttributeValue = "mp4") and not(ormlAttributeValue = "wma")
								ormlAttributeValue = ""
							endif
						endif
					elseif j = "url"
						' rss feeds may occasionally contain incorrect mime types so
						' we also use the file extension to try to determine the correct
						' media format
						extFormat = convertExtToFormat(ormlAttributeValue)
						format = getStringAttribute(item, "streamformat", false)
						if len(format) < 1 then format = getStringAttribute(item, "format", false)
						if not(format = extFormat) then
							if t.itemType = "video" then
								if extFormat = "mp4" or extFormat = "m4v" or extFormat = "wmv" or extFormat = "hls" then
									item.AddAttribute("format", extFormat)
								endif
							elseif t.itemType = "audio"
								if extFormat = "mp3" or extFormat = "m4a" or extFormat = "mp4" or extFormat = "wma" then
									item.AddAttribute("format", extFormat)
								endif
							endif
						endif
					elseif j = "length"
						ormlAttributeValue = convertHMSToSeconds(ormlAttributeValue)
					endif
				endif

				' some attribute values like length are returned as an integer
				if type(ormlAttributeValue) = "Integer" then
					ormlAttributeValue = str(ormlAttributeValue)
				endif

				if type(ormlAttributeValue) = "String" and len(ormlAttributeValue) > 0 then
					item.AddAttribute(j, ormlAttributeValue)
				endif
			endif
		end for

		url = getStringAttribute(item, "url", false)
		format = getStringAttribute(item, "streamformat", false)
		if len(format) < 1 then format = getStringAttribute(item, "format", false)
		if not(validateFormat(t.itemType, format, url)) then
			' disable item element if the format does not match the item type
			' or if the format or url is empty. the element can be disabled
			' by changing its name.
			item.SetName("ditem")

			' add 1 to the limit to compensate for the skipped item.
			if t.limit > -1 then
				t.limit = t.limit + 1
			endif
		else
			' only continue if the format matches the item type or if
			' this is not a video or audio item
			if (not(item.HasAttribute("sdposterurl")) or len(item@sdposterurl) < 1) and len(sdposterurl) > 0 then
				item.AddAttribute("sdposterurl", sdposterurl)
			endif
			if (not(item.HasAttribute("hdposterurl")) or len(item@hdposterurl) < 1) and len(hdposterurl) > 0 then
				item.AddAttribute("hdposterurl", hdposterurl)
			endif

			' generate child nodes for item elements
			if type(t.itemChildNodes) = "roArray" then
				processChildNodesArray(items[i], item, t.itemChildNodes)
			elseif type(t.itemChildNodes) = "roAssociativeArray"
				processChildNodesObject(items[i], item, t.itemChildNodes)
			endif
		endif
	end for

	' print xml source to temp folder so we dont have to download and convert
	' the feed every time it is loaded
	success = WriteAsciiFile(xmlFilePath, xml.GenXml(true))

	return success
End Function

Function validateFormat(itemType As String, format As String, url As String) As Boolean
	if (itemType = "video") then
		'if len(format) < 1 or len(url) < 1 then return false
		if not(format = "mp4") and not(format = "wmv") and not(format = "hls") then
			return false
		endif
	elseif (itemType = "audio") then
		'if len(format) < 1 or len(url) < 1 then return false
		if not(format = "mp3") and not(format = "mp4") and not(format = "wma") then
			return false
		endif
	endif
	return true
End Function

Sub processChildNodesObject(rssItem As Object, ormlItem As Object, nodes As Object)
	for each k in nodes
		if type(nodes[k]) = "roAssociativeArray" then
			cn = ""
			for each l in nodes[k]
				if type(nodes[k][l]) = "roString" then
					ormlChildNode = convertTemplateMarkup(rssItem, nodes[k][l])
					if len(ormlChildNode) > 0 then
						if not(type(cn) = "roXMLElement") then
							cn = ormlItem.AddElement(k)
						endif
						' some values might be returned as an integer
						if type(ormlChildNode) = "Integer" then
							ormlChildNode = str(ormlChildNode)
						endif
						if type(ormlChildNode) = "String" then
							' re-encode any leftover html entities to prevent errors in the xml
							ormlChildNode = encodeHTMLEntities(ormlChildNode)
							if l = "_body" then
								cn.SetBody(ormlChildNode)
							else
								cn.AddAttribute(l, ormlChildNode)
							endif
						endif
					endif
				endif
			end for
		else
			ormlChildNode = ""

			if type(nodes[k]) = "roArray" then
				ormlChildNode = convertTemplateMarkupArray(rssItem, nodes[k])
			elseif type(nodes[k]) = "roString" then
				ormlChildNode = convertTemplateMarkup(rssItem, nodes[k])
			endif

			if len(ormlChildNode) > 0 then
				' some values might be returned as an integer
				if type(ormlChildNode) = "Integer" then
					ormlChildNode = str(ormlChildNode)
				endif

				if type(ormlChildNode) = "String" then
					' re-encode any leftover html entities to prevent errors in the xml
					ormlChildNode = encodeHTMLEntities(ormlChildNode)
					cn = ormlItem.AddElement(k)
					cn.SetBody(ormlChildNode)
				endif
			endif
		endif
	end for
End Sub

Sub processChildNodesArray(rssItem As Object, ormlItem As Object, nodes As Object)
	for k = 0 to nodes.Count() - 1
		for each l in nodes[k]
			if type(nodes[k][l]) = "roAssociativeArray" then
				cn = ""
				for each n in nodes[k][l]
					if type(nodes[k][l][n]) = "roString" then
						ormlChildNode = convertTemplateMarkup(rssItem, nodes[k][l][n])
						if len(ormlChildNode) > 0 then
							if not(type(cn) = "roXMLElement") then
								cn = ormlItem.AddElement(l)
							endif
							' some values might be returned as an integer
							if type(ormlChildNode) = "Integer" then
								ormlChildNode = str(ormlChildNode)
							endif
							if type(ormlChildNode) = "String" then
								' re-encode any leftover html entities to prevent errors in the xml
								ormlChildNode = encodeHTMLEntities(ormlChildNode)
								if n = "_body" then
									cn.SetBody(ormlChildNode)
								else
									cn.AddAttribute(n, ormlChildNode)
								endif
							endif
						endif
					endif
				end for
			else
				ormlChildNode = ""

				if type(nodes[k][l]) = "roArray" then
					ormlChildNode = convertTemplateMarkupArray(rssItem, nodes[k][l])
				elseif type(nodes[k][l]) = "roString" then
					ormlChildNode = convertTemplateMarkup(rssItem, nodes[k][l])
				endif

				if len(ormlChildNode) > 0 then
					' some values might be returned as an integer
					if type(ormlChildNode) = "Integer" then
						ormlChildNode = str(ormlChildNode)
					endif

					if type(ormlChildNode) = "String" then
						' re-encode any leftover html entities to prevent errors in the xml
						ormlChildNode = encodeHTMLEntities(ormlChildNode)
						cn = ormlItem.AddElement(l)
						cn.SetBody(ormlChildNode)
					endif
				endif
			endif
		end for
	end for
End Sub

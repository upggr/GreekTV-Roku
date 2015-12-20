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


Library "v30/bslCore.brs"

Function encodeHTMLEntities(text As String) As String
	re = CreateObject("roRegex", "&", "")
	text = re.ReplaceAll(text, "&amp;")
	re = CreateObject("roRegex", "<", "")
	text = re.ReplaceAll(text, "&lt;")
	re = CreateObject("roRegex", ">", "")
	text = re.ReplaceAll(text, "&gt;")
	re = CreateObject("roRegex", chr(34), "")
	text = re.ReplaceAll(text, "&quot;")
	return text
End Function

Function stripHTMLTags(text as String) As String
	' convert all line breaks and paragraph tags to the
	' new line character prior to stripping the tags.
	newLine = chr(10)
	re = CreateObject("roRegex", "<br/?>", "s")
	text = re.ReplaceAll(text, newLine)
	re = CreateObject("roRegex", "</?p>", "s")
	text = re.ReplaceAll(text, newLine + newLine)

	re = CreateObject("roRegex", "<\!\[CDATA\[|\]\]>", "")
	text = re.ReplaceAll(text, "")
	re = CreateObject("roRegex", "<[^<>]+>", "s")
	text = re.ReplaceAll(text, "")
	return text
End Function

Function stripHTMLEntities(text As String) As String
	re = CreateObject("roRegex", "(&[\w#]*;)", "s")
	matches = re.Match(text)
	while matches.Count() > 1
		decodedChar = convertHTMLEntity(matches[1])
		re2 = CreateObject("roRegex", matches[1], "")
		text = re2.ReplaceAll(text, decodedChar)
		matches = re.Match(text)
	end while
	return text
End Function

Function convertHTMLEntity(entity As String) As String
	decodedChar = ""
	re = CreateObject("roRegex", "^&[\W0]*|;$", "s")
	entity = re.ReplaceAll(entity, "")
	numCode = strtoi(entity)

	if type(numCode) = "Invalid" or numCode = 0 then ' not a number
		' test for hex entity (e.g. &#x3c;)
		if left(entity, 1) = "x" then
			'numCode = HexToInteger(mid(entity, 2))
			'decodedChar = chr(numCode)
			decodedChar = HexToAscii(mid(entity, 2))
		' test for xhtml entity (e.g. &lt;)
		else
			numCode = getCharCodeForHTML(entity)
			if numCode > -1 then
				decodedChar = chr(numCode)
			' probably not a valid entity
			else
				print "An error has occurred while trying to decode this entity: "; entity
			endif
		endif
	else
		' must be a decimal entity (e.g. &#60; or &#0060;)
		decodedChar = chr(numCode)
	endif

	return decodedChar
End Function

Function getCharCodeForHTML(entity As String) As Integer
	charcodes = {
		AElig: 198,
		Aacute: 193,
		Acirc: 194,
		Agrave: 192,
		Aring: 197,
		Atilde: 195,
		Auml: 196,
		Ccedil: 199,
		ETH: 208,
		Eacute: 201,
		Ecirc: 202,
		Egrave: 200,
		Euml: 203,
		Iacute: 205,
		Icirc: 206,
		Igrave: 204,
		Iuml: 207,
		Ntilde: 209,
		Oacute: 211,
		Ocirc: 212,
		Ograve: 210,
		Oslash: 216,
		Otilde: 213,
		Ouml: 214,
		THORN: 222,
		Uacute: 218,
		Ucirc: 219,
		Ugrave: 217,
		Uuml: 220,
		Yacute: 221,
		aacute: 225,
		acirc: 226,
		acute: 180,
		aelig: 230,
		agrave: 224,
		amp: 38,
		apos: 39,
		aring: 229,
		atilde: 227,
		auml: 228,
		brvbar: 166,
		bull: 8226,
		ccedil: 231,
		cedil: 184,
		cent: 162,
		copy: 169,
		curren: 164,
		deg: 176,
		divide: 247,
		eacute: 233,
		ecirc: 234,
		egrave: 232,
		eth: 240,
		euml: 235,
		frac12: 189,
		frac14: 188,
		frac34: 190,
		gt: 62,
		hellip: 8230,
		iacute: 237,
		icirc: 238,
		iexcl: 161,
		igrave: 236,
		iquest: 191,
		iuml: 239,
		laquo: 171,
		ldquo: 8220,
		lsquo: 8216,
		lt: 60,
		macr: 175,
		mdash: 8212,
		micro: 181,
		middot: 183,
		nbsp: 32,
		ndash: 8211,
		not: 172,
		ntilde: 241,
		oacute: 243,
		ocirc: 244,
		ograve: 242,
		ordf: 170,
		ordm: 186,
		oslash: 248,
		otilde: 245,
		ouml: 246,
		para: 182,
		plusmn: 177,
		pound: 163,
		quot: 34,
		raquo: 187,
		rdquo: 8221,
		reg: 174,
		rsaquo: 8250,
		rsquo: 8217,
		sect: 167,
		shy: 173,
		sup1: 185,
		sup2: 178,
		sup3: 179,
		szlig: 223,
		thorn: 254,
		times: 215,
		uacute: 250,
		ucirc: 251,
		ugrave: 249,
		uml: 168,
		uuml: 252,
		yacute: 253,
		yen: 165,
		yuml: 255
	}

	for each i in charcodes
		if i = entity then
			return charcodes[i]
		endif
	end for

	return -1
End Function

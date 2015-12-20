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


Function sourceforge_document() As Object
	template = {
		title: "RSS Document template",
		description: "Template for sourceforge blog",
		isEnabled: true,
		isXML: true,
		itemType: "document",
		limit: 20,

		items: "channel[0].item",

		defaultSDPoster: "http://openrokn.sourceforge.net/images/main_menu_logo_focus_sd.png",
		defaultHDPoster: "http://openrokn.sourceforge.net/images/main_menu_logo_focus_hd.png",

		itemAttributes: {
        		title: "<%title[0]#%>",
        		author: "<%{dc:creator}[0]#%>",
        		date: "<%pubDate[0]#/^(.+?\d{4})/%>",
			'url: "<%link[0]#%>",
			striphtml: "true",
			stripews: "true"
			'regexfilter: "^.*?\<div class\=\x22markdown_content\x22\>|\<\/div\>.*$"
		},

        	itemChildNodes: {
        		body: "<%description[0]#%>"
		}
	}
	return template
End Function

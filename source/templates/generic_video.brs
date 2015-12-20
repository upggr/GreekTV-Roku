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


' the function should use the exact name as the file minus the .brs extension
Function generic_video() As Object
	template = {
		title: "Generic video template",
		description: "RSS to ORML video",
		isEnabled: true, ' set to false to prevent this template from being used
		isXML: true, ' MUST be set to true. json is not currently supported. if you need json support use the php converter script.
		itemType: "video", ' the type of orml item that you want to generate
		limit: 20, ' limits the number of items retrieved from the original feed. -1 = no limit

		' where can the item array be found?
		' you do not need to use dynamic tags here and you do not need to specify the
		' root element (e.g., "channel[0].item" instead of "rss[0].channel[0].item").
		' these templates were designed for the purpose of supporting rss feeds but
		' they can be used to convert any type of xml file into orml. if the xml file
		' you wish to convert does not contain any item elements then just use the
		' element name that references the array of elements that you wish to convert.
		' For example, if the original feed contains something like the following:
		' <videos><video><title>Video 1</title></video><video><title>Video 2</title></video></videos>
		' Then you would use (items: "video") for the items property below. Since you
		' dont need to specify the root element and since there isnt a channel element
		' you would only have to include a single element name in the items property.
		items: "channel[0].item",

		' all properties below this point MUST contain dynamic tags if
		' you wish to extract a value from the original xml feed. otherwise
		' the properties below will be interpreted as string constants.

		defaultSDPoster: ["<%channel[0].image[0].url[0]#%>",
                                  '"<%channel[0].image[0].link[0]#%>",
                                  "<%channel[0].{itunes:image}[0]@href%>",
                                  "<%channel[0].{itunes:image}[0]#%>",
                                  "<%channel[0].{media:thumbnail}[0]@url%>"],
		defaultHDPoster: ["<%channel[0].image[0].url[0]#%>",
                                  '"<%channel[0].image[0].link[0]#%>",
                                  "<%channel[0].{itunes:image}[0]@href%>",
                                  "<%channel[0].{itunes:image}[0]#%>",
                                  "<%channel[0].{media:thumbnail}[0]@url%>"],

		' you do not need to specify the item element for any of the
		' attributes or child nodes below. it is assumed that the
		' elements they reference are child nodes of an item element
		' in the original xml feed.

		' map the property values to an orml item attribute. all property
		' values must be entered as strings. if you want to use a boolean
		' or integer value make sure it is in quotes.
		itemAttributes: {
        		title: "<%title[0]#%>",
        		shortdesc: "<%pubDate[0]#%>",
        		url: "<%enclosure[0]@url%>",
			format: "<%enclosure[0]@type%>",
			length: "<%{itunes:duration}[0]#%>",
			sdposterurl: ["<%{itunes:image}[0]@href%>", "<%{itunes:image}[0]#%>", "<%{media:thumbnail}[0]@url%>"],
			hdposterurl: ["<%{itunes:image}[0]@href%>", "<%{itunes:image}[0]#%>", "<%{media:thumbnail}[0]@url%>"]
		},

		' map the property values to a child node of the orml item element
        	itemChildNodes: {
        		description: ["<%description[0]#%>", "<%{itunes:summary}[0]#%>", "<%{itunes:subtitle}[0]#%>"]
		}
	}
	return template
End Function

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


Function helloworld() As Object
	extension = {
		title: "Hello World",
		description: "Display a popup containing the message Hello World.",
		isEnabled: true,
		enableForItems: ["video"], 'video,audio,slideshow,settings items supported
		buttonLabel: "Hello World",
		' if you need access to the xml element that was used to generate the
		' video screen then pass xe as an argument - "execHelloWorld(xe)"
		' make sure to define it as an object - Function execHelloWorld(xe As Object)
		codeToExecute: "execHelloWorld()",
		enableParagraph: false, 'only valid for settings screens
		paragraphCodeToExecute: "" 'only valid for settings screens
	}
	return extension
End Function

'return true on success, false on error or cancel
Function execHelloWorld() As Boolean
	alert("Alert", "Hello World!")
	return true
End Function

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

Function helloregistry() As Object
	extension = {
		title: "Registry extension example",
		description: "Save a value to the registry and display it on a settings screen",
		isEnabled: true,
		enableForItems: ["settings"], 'video,audio,slideshow,settings items supported
		buttonLabel: "Hello Registry",
		codeToExecute: "execHelloRegistry()",
		enableParagraph: true, 'only valid for settings screens
		paragraphCodeToExecute: "displayHelloRegistryText()" 'only valid for settings screens
	}
	return extension
End Function

' return true on success, false on error or cancel
Function execHelloRegistry() As Boolean
	regvalue = getStrValFromReg("helloregistry", "profile")
	keyboard = createKeyboard("Hello Registry", "enter a value to save to the registry", regvalue, 25)
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
					regvalue = keyboard.GetText()
					if len(regvalue) > 0 then
						success = saveStrValToReg("helloregistry", regvalue, "profile")
						if success then
							alert("Alert", "The value was saved successfully to the Roku registry.")
						else
							alert("Alert", "The value was not saved!")
						endif
						return success
					else
						alert("Alert", "You must enter a value in order to continue.")
					endif
				else
					return false
				endif
			endif
		endif
	end while
End Function

Function displayHelloRegistryText() As String
	regvalue = getStrValFromReg("helloregistry", "profile")
	if len(regvalue) < 1 then
		regvalue = "not set"
	endif
	return "Hello Registry: " + regvalue
End Function

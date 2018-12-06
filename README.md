[![Build status](https://saftrare.visualstudio.com/GitRnD/_apis/build/status/HueTests)](https://saftrare.visualstudio.com/GitRnD/_build/latest?definitionId=11)

# hue
Powershell module to interact with Philips Hue hub.

# Overview
Philips Hue offers Smart home lighting. For the most part you will interact with Hue via hardware (movement sensors, switches) or software (Philips Hue mobile app).

However, given that the hardware costs money and the software is limited in what it can achieve, Philips also offer a REST API that interacts with devices connected to the hub.

This Powershell module interacts with the Hue hub and provides some basic functionality, above and beyond that offered by the mobile app. It uses timers and asynchronous events - the idea being that you can kick it off and then forget about it. You're not expected to call Powershell functions to turn the lights on! Hardware still has it's place in the overall solution.

# Usage
Review the Const.psd1 file and edit to suit your home. Then import the module, set context for your hub / API key and start the main monitor thread.
 
```powershell
Import-Module .\Hue.Script.psm1
Set-Context http://192.168.0.1 APIKEY-1234-5678
Start-LightsMonitor -Verbose
```
 

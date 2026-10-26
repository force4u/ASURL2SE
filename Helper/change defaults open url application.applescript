#!/usr/bin/osascript
#coding: utf-8
use AppleScript version "2.8"
use framework "Foundation"
use framework "AppKit"
use scripting additions
set ocidURLComponents to current application's NSURLComponents's alloc()'s init()
ocidURLComponents's setScheme:("applescript")
set ocidOpenURL to ocidURLComponents's |URL|()
set ocidScheme to ocidOpenURL's |scheme|()
(*
set aliasAppPath to (path to application "Script Debugger") as alias
set strAppPath to (POSIX path of aliasAppPath) as text
set aliasAppPath to (path to application "Finder") as alias
set strAppPath to (POSIX path of aliasAppPath) as text
set strAppPath to ("/System/Applications/Utilities/Script Editor.app") as text
set aliasAppPath to (path to application id "com.cocolog-nifty.quicktimer.ASURL2SE") as alias
set strAppPath to (POSIX path of aliasAppPath) as text
*)
set aliasAppPath to (path to application "Script Debugger") as alias
set strAppPath to (POSIX path of aliasAppPath) as text
set ocidAppPathStr to current application's NSString's stringWithString:(strAppPath)
set ocidAppPath to ocidAppPathStr's stringByStandardizingPath()
set ocidAppPathURL to current application's NSURL's fileURLWithPath:(ocidAppPath)
set appWorkSpace to current application's NSWorkspace's sharedWorkspace()
appWorkSpace's setDefaultApplicationAtURL:(ocidAppPathURL) toOpenURLsWithScheme:(ocidScheme) completionHandler:(missing value)
return

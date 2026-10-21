#!/usr/bin/osascript
#coding: utf-8
----+----1----+----2----+----3----+----4----+----5----+----6----+----7
(*  
URLスキームapplescriptのデフォルトのアプリケーションを変更する
システム設定Transparency Consent Control(TCC)
プライバシーとセキュリティ＞アプリ管理　への
アクセス許可が必要なスクリプトです

com.cocolog-nifty.quicktimer.icefloe　*)
----+----1----+----2----+----3----+----4----+----5----+----6----+----7
use AppleScript version "2.8"
use framework "Foundation"
use framework "AppKit"
use framework "UniformTypeIdentifiers"
use scripting additions
property refMe : a reference to current application
set ocidURLComponents to refMe's NSURLComponents's alloc()'s init()
ocidURLComponents's setScheme:("applescript")
set ocidOpenURL to ocidURLComponents's |URL|()
set strURL to ocidOpenURL's absoluteString() as text
set ocidScheme to ocidOpenURL's |scheme|()
set appWorkSpace to refMe's NSWorkspace's sharedWorkspace()
set ocidAppArray to appWorkSpace's URLsForApplicationsToOpenURL:(ocidOpenURL)
log ocidAppArray as list
(*
set aliasAppPath to (path to application "Script Debugger") as alias
set strAppPath to (POSIX path of aliasAppPath) as text
set aliasAppPath to (path to application "Finder") as alias
set strAppPath to (POSIX path of aliasAppPath) as text
*)

set strAppPath to ("/Users/takeshi_matsushima/Desktop/ASURL2SE.app") as text

set ocidAppPathStr to refMe's NSString's stringWithString:(strAppPath)
set ocidAppPath to ocidAppPathStr's stringByStandardizingPath()
set ocidAppPathURL to refMe's NSURL's fileURLWithPath:(ocidAppPath) isDirectory:(false)
appWorkSpace's setDefaultApplicationAtURL:(ocidAppPathURL) toOpenURLsWithScheme:(ocidScheme) completionHandler:(missing value)

return ocidAppArray as list

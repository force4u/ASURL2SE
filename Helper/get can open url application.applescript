#!/usr/bin/osascript
#coding: utf-8
use AppleScript version "2.8"
use framework "Foundation"
use framework "AppKit"
use scripting additions
#	applescript:スキームのURLを開くことができるアプリケーションのリスト
#	applescript: List of applications that can open the URL of a schema
set ocidURLComponents to current application's NSURLComponents's alloc()'s init()
ocidURLComponents's setScheme:("applescript")
set ocidOpenURL to ocidURLComponents's |URL|()
log ocidOpenURL's absoluteString() as text
set ocidScheme to ocidOpenURL's |scheme|()
log ocidOpenURL's className() as text
set appWorkSpace to current application's NSWorkspace's sharedWorkspace()
set ocidAppArray to appWorkSpace's URLsForApplicationsToOpenURL:(ocidOpenURL)
return ocidAppArray as list

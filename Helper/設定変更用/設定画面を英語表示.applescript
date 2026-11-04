#!/usr/bin/osascript
#coding: utf-8
----+----1----+----2----+----3----+----4----+----5----+----6----+----7
(*  
設定画面を日本語表示にします
defaults write com.cocolog-nifty.quicktimer.ASURL2SE AppleLanguages '("ja")'
com.cocolog-nifty.quicktimer.icefloe　*)
----+----1----+----2----+----3----+----4----+----5----+----6----+----7
use AppleScript version "2.8"
use scripting additions
set strCmd to ("/usr/bin/defaults delete com.cocolog-nifty.quicktimer.ASURL2SE AppleLanguages") as text
log return & strCmd & return
try
	do shell script strCmd
on error strErrMsg number numErrNo
	log "No: " & numErrNo & linefeed & "Error:" & strErrMsg
	return false
end try

return
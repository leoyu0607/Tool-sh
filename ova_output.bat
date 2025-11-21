@echo off
IF exist "C:\ovftool" (
	goto ovf
) ELSE (
	echo 請將ovftool資料夾移至C:\
	pause
)

:ovf
	cd "C:\ovftool"
	SET /P esxiIP=Please enter ESXI IP:
	SET /P vmName=Please enter VM name:
	SET /P path=Please enter file dir:
	ovftool --noSSLVerify "vi://%esxiIP%/%vmName%" %path%\%vmName%.ova
	echo finish
	pause
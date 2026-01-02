; Custom NSIS script for Facebook Messenger Desktop
; This runs during uninstall to clean up ALL app data

!macro customUnInstall
  ; Clean up LOCALAPPDATA (cache, GPU cache, etc.)
  ; deleteAppDataOnUninstall only cleans APPDATA, not LOCALAPPDATA
  RMDir /r "$LOCALAPPDATA\Messenger"
  
  ; Also clean up any leftover temp files
  RMDir /r "$TEMP\Messenger"
!macroend


; Custom NSIS script for Facebook Messenger Desktop
; This runs during install/update and uninstall
; Supports both stable (Messenger) and beta (Messenger Beta) builds

; Pre-init macro - runs BEFORE the app close check
; This prevents the confusing "Messenger Beta cannot be closed" message when stable is running
; (NSIS uses substring matching, so "Messenger" matches "Messenger Beta" installer)
!macro preInit
  ; Silently kill both stable and beta processes to prevent the confusing close dialog
  ; The dialog shows the installer's product name, not the actual running process name
  nsExec::ExecToStack 'taskkill /F /IM "Messenger.exe" /T'
  Pop $0
  nsExec::ExecToStack 'taskkill /F /IM "Messenger Beta.exe" /T'
  Pop $0
  ; Give processes time to fully exit
  Sleep 1000
!macroend

; Custom install macro - runs after installation/update
; Fixes the "Can't open this item" taskbar issue after updates on Windows 11
; Key fix: Sets System.AppUserModel.ID property on shortcuts using Windows Shell API
!macro customInstall
  ; Note: Process killing is now done in preInit to prevent confusing close dialog
  ; Just wait a moment for any processes to fully exit
  Sleep 500
  
  ; Save the shortcut fix script to a temp file
  ; Uses .NET interop to properly set AppUserModelId (WScript.Shell cannot do this)
  FileOpen $0 "$TEMP\messenger-shortcut-fix.ps1" w
  
  ; PowerShell script that uses Windows Shell API to set AppUserModelId
  ; Dynamically detects beta vs stable based on install directory
  FileWrite $0 "$$ErrorActionPreference = 'SilentlyContinue'$\r$\n"
  FileWrite $0 "$$instDir = '$INSTDIR'$\r$\n"
  FileWrite $0 "$$isBeta = $$instDir -like '*Messenger Beta*'$\r$\n"
  FileWrite $0 "$$exeName = if ($$isBeta) { 'Messenger Beta.exe' } else { 'Messenger.exe' }$\r$\n"
  FileWrite $0 "$$exePath = Join-Path $$instDir $$exeName$\r$\n"
  FileWrite $0 "$$appUserModelId = if ($$isBeta) { 'com.facebook.messenger.desktop.beta' } else { 'com.facebook.messenger.desktop' }$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "# Define COM interfaces for Shell Link and Property Store$\r$\n"
  FileWrite $0 "$$typeDefinition = @'$\r$\n"
  FileWrite $0 "using System;$\r$\n"
  FileWrite $0 "using System.Runtime.InteropServices;$\r$\n"
  FileWrite $0 "using System.Text;$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "[ComImport, Guid($\"00021401-0000-0000-C000-000000000046$\")]$\r$\n"
  FileWrite $0 "public class ShellLink { }$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid($\"000214F9-0000-0000-C000-000000000046$\")]$\r$\n"
  FileWrite $0 "public interface IShellLinkW {$\r$\n"
  FileWrite $0 "    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cchMaxPath, IntPtr pfd, int fFlags);$\r$\n"
  FileWrite $0 "    void GetIDList(out IntPtr ppidl);$\r$\n"
  FileWrite $0 "    void SetIDList(IntPtr pidl);$\r$\n"
  FileWrite $0 "    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cchMaxName);$\r$\n"
  FileWrite $0 "    void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);$\r$\n"
  FileWrite $0 "    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cchMaxPath);$\r$\n"
  FileWrite $0 "    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);$\r$\n"
  FileWrite $0 "    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cchMaxPath);$\r$\n"
  FileWrite $0 "    void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);$\r$\n"
  FileWrite $0 "    void GetHotkey(out short pwHotkey);$\r$\n"
  FileWrite $0 "    void SetHotkey(short wHotkey);$\r$\n"
  FileWrite $0 "    void GetShowCmd(out int piShowCmd);$\r$\n"
  FileWrite $0 "    void SetShowCmd(int iShowCmd);$\r$\n"
  FileWrite $0 "    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cchIconPath, out int piIcon);$\r$\n"
  FileWrite $0 "    void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);$\r$\n"
  FileWrite $0 "    void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, int dwReserved);$\r$\n"
  FileWrite $0 "    void Resolve(IntPtr hwnd, int fFlags);$\r$\n"
  FileWrite $0 "    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);$\r$\n"
  FileWrite $0 "}$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid($\"0000010B-0000-0000-C000-000000000046$\")]$\r$\n"
  FileWrite $0 "public interface IPersistFile {$\r$\n"
  FileWrite $0 "    void GetClassID(out Guid pClassID);$\r$\n"
  FileWrite $0 "    [PreserveSig] int IsDirty();$\r$\n"
  FileWrite $0 "    void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);$\r$\n"
  FileWrite $0 "    void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, [MarshalAs(UnmanagedType.Bool)] bool fRemember);$\r$\n"
  FileWrite $0 "    void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);$\r$\n"
  FileWrite $0 "    void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);$\r$\n"
  FileWrite $0 "}$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid($\"886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99$\")]$\r$\n"
  FileWrite $0 "public interface IPropertyStore {$\r$\n"
  FileWrite $0 "    [PreserveSig] int GetCount(out uint cProps);$\r$\n"
  FileWrite $0 "    [PreserveSig] int GetAt(uint iProp, out PropertyKey pkey);$\r$\n"
  FileWrite $0 "    [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant pv);$\r$\n"
  FileWrite $0 "    [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant pv);$\r$\n"
  FileWrite $0 "    [PreserveSig] int Commit();$\r$\n"
  FileWrite $0 "}$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "[StructLayout(LayoutKind.Sequential, Pack = 4)]$\r$\n"
  FileWrite $0 "public struct PropertyKey {$\r$\n"
  FileWrite $0 "    public Guid fmtid;$\r$\n"
  FileWrite $0 "    public uint pid;$\r$\n"
  FileWrite $0 "    public PropertyKey(Guid fmtid, uint pid) { this.fmtid = fmtid; this.pid = pid; }$\r$\n"
  FileWrite $0 "}$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "[StructLayout(LayoutKind.Explicit)]$\r$\n"
  FileWrite $0 "public struct PropVariant {$\r$\n"
  FileWrite $0 "    [FieldOffset(0)] public ushort vt;$\r$\n"
  FileWrite $0 "    [FieldOffset(8)] public IntPtr pwszVal;$\r$\n"
  FileWrite $0 "    public static PropVariant FromString(string value) {$\r$\n"
  FileWrite $0 "        var pv = new PropVariant();$\r$\n"
  FileWrite $0 "        pv.vt = 31; // VT_LPWSTR$\r$\n"
  FileWrite $0 "        pv.pwszVal = Marshal.StringToCoTaskMemUni(value);$\r$\n"
  FileWrite $0 "        return pv;$\r$\n"
  FileWrite $0 "    }$\r$\n"
  FileWrite $0 "    public void Clear() { if (pwszVal != IntPtr.Zero) Marshal.FreeCoTaskMem(pwszVal); }$\r$\n"
  FileWrite $0 "}$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "public static class ShortcutHelper {$\r$\n"
  FileWrite $0 "    public static readonly PropertyKey PKEY_AppUserModel_ID = new PropertyKey($\r$\n"
  FileWrite $0 "        new Guid($\"9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3$\"), 5);$\r$\n"
  FileWrite $0 "    $\r$\n"
  FileWrite $0 "    public static bool UpdateShortcut(string lnkPath, string targetPath, string workDir, string appId) {$\r$\n"
  FileWrite $0 "        try {$\r$\n"
  FileWrite $0 "            var shellLink = (IShellLinkW)new ShellLink();$\r$\n"
  FileWrite $0 "            var persistFile = (IPersistFile)shellLink;$\r$\n"
  FileWrite $0 "            persistFile.Load(lnkPath, 0);$\r$\n"
  FileWrite $0 "            $\r$\n"
  FileWrite $0 "            shellLink.SetPath(targetPath);$\r$\n"
  FileWrite $0 "            shellLink.SetWorkingDirectory(workDir);$\r$\n"
  FileWrite $0 "            shellLink.SetIconLocation(targetPath, 0);$\r$\n"
  FileWrite $0 "            $\r$\n"
  FileWrite $0 "            var propertyStore = (IPropertyStore)shellLink;$\r$\n"
  FileWrite $0 "            var key = PKEY_AppUserModel_ID;$\r$\n"
  FileWrite $0 "            var pv = PropVariant.FromString(appId);$\r$\n"
  FileWrite $0 "            propertyStore.SetValue(ref key, ref pv);$\r$\n"
  FileWrite $0 "            propertyStore.Commit();$\r$\n"
  FileWrite $0 "            pv.Clear();$\r$\n"
  FileWrite $0 "            $\r$\n"
  FileWrite $0 "            persistFile.Save(lnkPath, true);$\r$\n"
  FileWrite $0 "            return true;$\r$\n"
  FileWrite $0 "        } catch { return false; }$\r$\n"
  FileWrite $0 "    }$\r$\n"
  FileWrite $0 "    $\r$\n"
  FileWrite $0 "    public static string GetShortcutTarget(string lnkPath) {$\r$\n"
  FileWrite $0 "        try {$\r$\n"
  FileWrite $0 "            var shellLink = (IShellLinkW)new ShellLink();$\r$\n"
  FileWrite $0 "            var persistFile = (IPersistFile)shellLink;$\r$\n"
  FileWrite $0 "            persistFile.Load(lnkPath, 0);$\r$\n"
  FileWrite $0 "            var sb = new StringBuilder(260);$\r$\n"
  FileWrite $0 "            shellLink.GetPath(sb, sb.Capacity, IntPtr.Zero, 0);$\r$\n"
  FileWrite $0 "            return sb.ToString();$\r$\n"
  FileWrite $0 "        } catch { return string.Empty; }$\r$\n"
  FileWrite $0 "    }$\r$\n"
  FileWrite $0 "}$\r$\n"
  FileWrite $0 "'@$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "Add-Type -TypeDefinition $$typeDefinition -Language CSharp$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "# Locations to check for Messenger shortcuts$\r$\n"
  FileWrite $0 "$$locations = @($\r$\n"
  FileWrite $0 "    $$env:APPDATA + '\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar',$\r$\n"
  FileWrite $0 "    $$env:APPDATA + '\Microsoft\Windows\Start Menu\Programs',$\r$\n"
  FileWrite $0 "    $$env:ProgramData + '\Microsoft\Windows\Start Menu\Programs',$\r$\n"
  FileWrite $0 "    $$env:USERPROFILE + '\Desktop',$\r$\n"
  FileWrite $0 "    $$env:PUBLIC + '\Desktop'$\r$\n"
  FileWrite $0 ")$\r$\n"
  FileWrite $0 "$\r$\n"
  FileWrite $0 "$$updated = 0$\r$\n"
  FileWrite $0 "foreach ($$loc in $$locations) {$\r$\n"
  FileWrite $0 "    if (Test-Path $$loc) {$\r$\n"
  FileWrite $0 "        Get-ChildItem $$loc -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {$\r$\n"
  FileWrite $0 "            $$target = [ShortcutHelper]::GetShortcutTarget($$_.FullName)$\r$\n"
  FileWrite $0 "            $$shouldUpdate = $$false$\r$\n"
  FileWrite $0 "            if ($$isBeta) { $$shouldUpdate = $$target -like '*Messenger Beta*' }$\r$\n"
  FileWrite $0 "            else { $$shouldUpdate = ($$target -like '*Messenger*') -and ($$target -notlike '*Messenger Beta*') }$\r$\n"
  FileWrite $0 "            if ($$shouldUpdate) {$\r$\n"
  FileWrite $0 "                if ([ShortcutHelper]::UpdateShortcut($$_.FullName, $$exePath, $$instDir, $$appUserModelId)) {$\r$\n"
  FileWrite $0 "                    $$updated++$\r$\n"
  FileWrite $0 "                }$\r$\n"
  FileWrite $0 "            }$\r$\n"
  FileWrite $0 "        }$\r$\n"
  FileWrite $0 "    }$\r$\n"
  FileWrite $0 "}$\r$\n"
  FileClose $0
  
  ; Execute the PowerShell script
  nsExec::ExecToStack 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$TEMP\messenger-shortcut-fix.ps1"'
  Pop $0
  
  ; Clean up the temp script
  Delete "$TEMP\messenger-shortcut-fix.ps1"
  
  ; Clear icon cache files
  nsExec::ExecToStack 'cmd.exe /c del /f /q "%LOCALAPPDATA%\IconCache.db" 2>nul'
  Pop $0
  nsExec::ExecToStack 'cmd.exe /c del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db" 2>nul'
  Pop $0
  
  ; Rebuild icon cache
  nsExec::ExecToStack 'ie4uinit.exe -show'
  Pop $0
  
  ; Notify shell to refresh
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
  
  ; Broadcast settings change
  System::Call 'user32::SendNotifyMessageW(i 0xFFFF, i 0x001A, i 0, t "Environment")'
!macroend

!macro customUnInstall
  ; Determine if this is a beta or stable uninstall based on install directory
  ; Beta installs to "Messenger Beta", stable to "Messenger"
  StrCpy $1 $INSTDIR "" -4  ; Get last 4 chars
  StrCmp $1 "Beta" 0 +3
    StrCpy $2 "Messenger Beta.exe"  ; Beta exe name
    Goto +2
    StrCpy $2 "Messenger.exe"  ; Stable exe name
  
  ; Kill the appropriate Messenger process
  nsExec::ExecToStack 'taskkill /F /IM "$2" /T'
  Pop $0
  Sleep 2000
  
  ; Remove taskbar shortcuts - be more careful to only remove the right ones
  ; Check if beta uninstall (INSTDIR ends with "Messenger Beta")
  StrCmp $1 "Beta" 0 +3
    nsExec::ExecToStack 'cmd.exe /c del /q "%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*Messenger Beta*.lnk" 2>nul'
    Goto +2
    nsExec::ExecToStack 'cmd.exe /c for %f in ("%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*Messenger*.lnk") do @echo %f | findstr /V /I "Beta" >nul && del /q "%f"'
  Pop $0
  
  ; Remove Start Menu pins - same logic
  StrCmp $1 "Beta" 0 +3
    nsExec::ExecToStack 'cmd.exe /c del /q "%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu\*Messenger Beta*.lnk" 2>nul'
    Goto +2
    nsExec::ExecToStack 'cmd.exe /c for %f in ("%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu\*Messenger*.lnk") do @echo %f | findstr /V /I "Beta" >nul && del /q "%f"'
  Pop $0
  
  ; Clean up LOCALAPPDATA - use correct folder
  StrCmp $1 "Beta" 0 +3
    RMDir /r "$LOCALAPPDATA\Messenger-Beta"
    Goto +2
    RMDir /r "$LOCALAPPDATA\Messenger"
  
  ; Clean up temp files
  StrCmp $1 "Beta" 0 +3
    RMDir /r "$TEMP\Messenger Beta"
    Goto +2
    RMDir /r "$TEMP\Messenger"
!macroend


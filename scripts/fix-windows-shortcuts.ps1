# Windows Taskbar Shortcut Fix
# Fixes "Can't open this item" error after app updates on Windows 11
# Sets System.AppUserModel.ID property on all Messenger shortcuts using Windows Shell API

$ErrorActionPreference = 'SilentlyContinue'

# Get the installation directory and executable path
# When run from auto-update, use the running app's location
$exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$instDir = Split-Path -Parent $exePath
$appUserModelId = 'com.facebook.messenger.desktop'

Write-Host "[Shortcut Fix] Executable: $exePath"
Write-Host "[Shortcut Fix] Install Dir: $instDir"
Write-Host "[Shortcut Fix] AppUserModelId: $appUserModelId"

# Define COM interfaces for Shell Link and Property Store
$typeDefinition = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

[ComImport, Guid("00021401-0000-0000-C000-000000000046")]
public class ShellLink { }

[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
public interface IShellLinkW {
    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cchMaxPath, IntPtr pfd, int fFlags);
    void GetIDList(out IntPtr ppidl);
    void SetIDList(IntPtr pidl);
    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cchMaxName);
    void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cchMaxPath);
    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cchMaxPath);
    void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
    void GetHotkey(out short pwHotkey);
    void SetHotkey(short wHotkey);
    void GetShowCmd(out int piShowCmd);
    void SetShowCmd(int iShowCmd);
    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cchIconPath, out int piIcon);
    void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
    void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, int dwReserved);
    void Resolve(IntPtr hwnd, int fFlags);
    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
}

[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("0000010B-0000-0000-C000-000000000046")]
public interface IPersistFile {
    void GetClassID(out Guid pClassID);
    [PreserveSig] int IsDirty();
    void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
    void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, [MarshalAs(UnmanagedType.Bool)] bool fRemember);
    void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
    void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
}

[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
public interface IPropertyStore {
    [PreserveSig] int GetCount(out uint cProps);
    [PreserveSig] int GetAt(uint iProp, out PropertyKey pkey);
    [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant pv);
    [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant pv);
    [PreserveSig] int Commit();
}

[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct PropertyKey {
    public Guid fmtid;
    public uint pid;
    public PropertyKey(Guid fmtid, uint pid) { this.fmtid = fmtid; this.pid = pid; }
}

[StructLayout(LayoutKind.Explicit)]
public struct PropVariant {
    [FieldOffset(0)] public ushort vt;
    [FieldOffset(8)] public IntPtr pwszVal;
    public static PropVariant FromString(string value) {
        var pv = new PropVariant();
        pv.vt = 31; // VT_LPWSTR
        pv.pwszVal = Marshal.StringToCoTaskMemUni(value);
        return pv;
    }
    public void Clear() { if (pwszVal != IntPtr.Zero) Marshal.FreeCoTaskMem(pwszVal); }
}

public static class ShortcutHelper {
    public static readonly PropertyKey PKEY_AppUserModel_ID = new PropertyKey(
        new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 5);

    public static bool UpdateShortcut(string lnkPath, string targetPath, string workDir, string appId) {
        try {
            var shellLink = (IShellLinkW)new ShellLink();
            var persistFile = (IPersistFile)shellLink;
            persistFile.Load(lnkPath, 0);

            shellLink.SetPath(targetPath);
            shellLink.SetWorkingDirectory(workDir);
            shellLink.SetIconLocation(targetPath, 0);

            var propertyStore = (IPropertyStore)shellLink;
            var key = PKEY_AppUserModel_ID;
            var pv = PropVariant.FromString(appId);
            propertyStore.SetValue(ref key, ref pv);
            propertyStore.Commit();
            pv.Clear();

            persistFile.Save(lnkPath, true);
            return true;
        } catch { return false; }
    }

    public static string GetShortcutTarget(string lnkPath) {
        try {
            var shellLink = (IShellLinkW)new ShellLink();
            var persistFile = (IPersistFile)shellLink;
            persistFile.Load(lnkPath, 0);
            var sb = new StringBuilder(260);
            shellLink.GetPath(sb, sb.Capacity, IntPtr.Zero, 0);
            return sb.ToString();
        } catch { return string.Empty; }
    }
}
'@

try {
    Add-Type -TypeDefinition $typeDefinition -Language CSharp
    Write-Host "[Shortcut Fix] COM interfaces loaded successfully"
} catch {
    Write-Host "[Shortcut Fix] ERROR: Failed to load COM interfaces: $_"
    exit 1
}

# Locations to check for Messenger shortcuts
$locations = @(
    $env:APPDATA + '\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar',
    $env:APPDATA + '\Microsoft\Windows\Start Menu\Programs',
    $env:ProgramData + '\Microsoft\Windows\Start Menu\Programs',
    $env:USERPROFILE + '\Desktop',
    $env:PUBLIC + '\Desktop'
)

$updated = 0
$failed = 0
$shortcuts = @()

Write-Host "[Shortcut Fix] Scanning for Messenger shortcuts..."

foreach ($loc in $locations) {
    if (Test-Path $loc) {
        Write-Host "[Shortcut Fix] Checking: $loc"
        Get-ChildItem $loc -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $target = [ShortcutHelper]::GetShortcutTarget($_.FullName)
            if ($target -like '*Messenger*' -or $target -like '*messenger*') {
                Write-Host "[Shortcut Fix] Found: $($_.Name) -> $target"
                $shortcuts += @{
                    Path = $_.FullName
                    Name = $_.Name
                    OldTarget = $target
                }

                if ([ShortcutHelper]::UpdateShortcut($_.FullName, $exePath, $instDir, $appUserModelId)) {
                    Write-Host "[Shortcut Fix] ✓ Updated: $($_.Name)"
                    $updated++
                } else {
                    Write-Host "[Shortcut Fix] ✗ Failed: $($_.Name)"
                    $failed++
                }
            }
        }
    }
}

Write-Host ""
Write-Host "[Shortcut Fix] Results:"
Write-Host "[Shortcut Fix] - Shortcuts found: $($shortcuts.Count)"
Write-Host "[Shortcut Fix] - Updated: $updated"
Write-Host "[Shortcut Fix] - Failed: $failed"

if ($updated -gt 0) {
    Write-Host ""
    Write-Host "[Shortcut Fix] Clearing icon cache..."

    # Clear icon cache files
    Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db" -Force -ErrorAction SilentlyContinue

    # Rebuild icon cache
    Start-Process "ie4uinit.exe" -ArgumentList "-show" -NoNewWindow -Wait -ErrorAction SilentlyContinue

    Write-Host "[Shortcut Fix] Icon cache cleared"
}

Write-Host "[Shortcut Fix] Complete!"

# Return results as JSON for consumption by Electron app
$result = @{
    success = ($failed -eq 0)
    updated = $updated
    failed = $failed
    total = $shortcuts.Count
    shortcuts = $shortcuts
} | ConvertTo-Json -Compress

Write-Output $result

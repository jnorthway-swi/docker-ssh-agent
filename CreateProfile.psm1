# Based on code developed by  Josh Rickard (@MS_dministrator) and Thom Schumacher (@driberif)
# Location: https://gist.github.com/crshnbrn66/7e81bf20408c05ddb2b4fdf4498477d8

#function to register a native method
function Register-NativeMethod {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$dll,

        # Param2 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]
        $methodSignature
    )

    $script:nativeMethods += [PSCustomObject]@{ Dll = $dll; Signature = $methodSignature; }
}

#function to add native method
function Add-NativeMethods {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param($typeName = 'NativeMethods')

    $nativeMethodsCode = $script:nativeMethods | ForEach-Object { "
        [DllImport(`"$($_.Dll)`")]
        public static extern $($_.Signature);
    " }

    Add-Type @"
        using System;
        using System.Text;
        using System.Runtime.InteropServices;
        public static class $typeName {
            $nativeMethodsCode
        }
"@
}

#Main function to create the new user profile
function New-UserWithProfile {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$UserName,

        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$Description = ''
    )

    Write-Verbose "Creating local user $Username";

    try {
        net user $UserName /ADD /ACTIVE:YES /EXPIRES:NEVER /FULLNAME:"$Description" /PASSWORDCHG:NO /PASSWORDREQ:NO
        net localgroup Administrators /add $UserName
    } catch {
        Write-Error $_.Exception.Message;
        break;
    }

    $localUser = New-Object System.Security.Principal.NTAccount($UserName)

    $methodName = 'UserEnvCP'
    $script:nativeMethods = @();

    if (-not ([System.Management.Automation.PSTypeName]$MethodName).Type) {
        Register-NativeMethod "userenv.dll" "int CreateProfile([MarshalAs(UnmanagedType.LPWStr)] string pszUserSid,`
         [MarshalAs(UnmanagedType.LPWStr)] string pszUserName,`
         [Out][MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszProfilePath, uint cchProfilePath)";

        Add-NativeMethods -typeName $MethodName;
    }

    $userSID = $localUser.Translate([System.Security.Principal.SecurityIdentifier])
    $sb = New-Object System.Text.StringBuilder(260)
    $pathLen = $sb.Capacity

    Write-Verbose "Creating user profile for $UserName";

    try {
        [UserEnvCP]::CreateProfile($userSID.Value, $UserName, $sb, $pathLen) | Out-Null;
    } catch {
        Write-Error $_.Exception.Message;
        break;
    }

    $profilePath = $sb.ToString()
    Write-Verbose "Profile created at $profilePath"
    if(-not (Test-Path (Join-Path $profilePath "NTUSER.DAT"))) {
        Copy-Item "C:\Users\Default\NTUSER.DAT" $profilePath
    }
}
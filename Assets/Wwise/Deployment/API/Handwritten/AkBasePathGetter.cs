#if ! (UNITY_DASHBOARD_WIDGET || UNITY_WEBPLAYER || UNITY_WII || UNITY_WIIU || UNITY_NACL || UNITY_FLASH || UNITY_BLACKBERRY) // Disable under unsupported platforms.
//////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2012 Audiokinetic Inc. / All Rights Reserved
//
//////////////////////////////////////////////////////////////////////
using UnityEngine;

public partial class AkBasePathGetter
{
	/// <summary>
	/// User hook called to retrieve the custom platform name used to determine the base path. Do not modify platformName to use default platform names.
	/// </summary>
	/// <param name="platformName">The custom platform name.</param>
	static partial void GetCustomPlatformName(ref string platformName);

	public static string GetPlatformName()
	{
		string platformSubDir = string.Empty;
		GetCustomPlatformName(ref platformSubDir);
		if (!string.IsNullOrEmpty(platformSubDir))
			return platformSubDir;

		platformSubDir = "Undefined platform sub-folder";

#if UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_WSA
		platformSubDir = "Windows";
#elif UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
		platformSubDir = "Mac";
#elif UNITY_STANDALONE_LINUX
		platformSubDir = "Linux";
#elif UNITY_XBOXONE
		platformSubDir = "XBoxOne";
#elif UNITY_IOS || UNITY_TVOS
		platformSubDir = "iOS";
#elif UNITY_ANDROID
		platformSubDir = "Android";
#elif UNITY_PS4
		platformSubDir = "PS4";
#elif UNITY_WP_8_1
		platformSubDir = "WindowsPhone";
#elif UNITY_SWITCH
		platformSubDir = "Switch";
#elif UNITY_PSP2
#if AK_ARCH_VITA_SW || !AK_ARCH_VITA_HW
		platformSubDir = "VitaSW";
#else
		platformSubDir = "VitaHW";
#endif
#endif
		return platformSubDir;
	}

	/// Returns the full base path
	public static string GetPlatformBasePath()
	{
		string platformName = GetPlatformName();

#if UNITY_EDITOR
		string platformBasePathEditor = GetPlatformBasePathEditor(platformName);
		if (!string.IsNullOrEmpty(platformBasePathEditor))
			return platformBasePathEditor;
#endif

		// Combine base path with platform sub-folder
		string platformBasePath = System.IO.Path.Combine(GetFullSoundBankPath(), platformName);
		FixSlashes(ref platformBasePath);
		return platformBasePath;
	}

	public static string GetFullSoundBankPath()
	{
		// Get full path of base path
#if UNITY_ANDROID && !UNITY_EDITOR
 		string fullBasePath = AkInitializer.GetBasePath();
#else
		string fullBasePath = System.IO.Path.Combine(Application.streamingAssetsPath, AkInitializer.GetBasePath());
#endif

#if UNITY_SWITCH
		if(fullBasePath.StartsWith("/"))
			fullBasePath = fullBasePath.Substring(1);
#endif
		FixSlashes(ref fullBasePath);
		return fullBasePath;
	}

#if UNITY_EDITOR
	public static string GetPlatformBasePathEditor(string platformName)
	{
		WwiseSettings Settings = WwiseSettings.LoadSettings();
		string WwiseProjectFullPath = AkUtilities.GetFullPath(Application.dataPath, Settings.WwiseProjectPath);
		string SoundBankDest = AkUtilities.GetWwiseSoundBankDestinationFolder(platformName, WwiseProjectFullPath);
		if (System.IO.Path.GetPathRoot(SoundBankDest) == "")
		{
			// Path is relative, make it full
			SoundBankDest = AkUtilities.GetFullPath(System.IO.Path.GetDirectoryName(WwiseProjectFullPath), SoundBankDest);
		}

		if (string.IsNullOrEmpty(SoundBankDest))
		{
			Debug.LogWarning("WwiseUnity: The SoundBank folder could not be determined.");
		}
		else
		{
			try
			{
				// Verify if there are banks in there
				var di = new System.IO.DirectoryInfo(SoundBankDest);
				var foundBanks = di.GetFiles("*.bnk", System.IO.SearchOption.AllDirectories);
				if (foundBanks.Length == 0)
					SoundBankDest = string.Empty;
				else if (!SoundBankDest.Contains(platformName))
					Debug.LogWarning("WwiseUnity: The platform SoundBank subfolder does not match your platform name. You will need to create a custom platform name getter for your game. See section \"Using Wwise Custom Platforms in Unity\" of the Wwise Unity integration documentation for more information");
			}
			catch
			{
				SoundBankDest = string.Empty;
			}
		}

		return SoundBankDest;
	}
#endif

	public static void FixSlashes(ref string path, char separatorChar, char badChar, bool addTrailingSlash)
	{
		if (string.IsNullOrEmpty(path))
			return;

		path = path.Trim().Replace(badChar, separatorChar).TrimStart('\\');

		// Append a trailing slash to play nicely with Wwise
		if (addTrailingSlash && !path.EndsWith(separatorChar.ToString()))
			path += separatorChar;
	}

	public static void FixSlashes(ref string path)
	{
#if UNITY_WSA
		char separatorChar = '\\';
#else
		char separatorChar = System.IO.Path.DirectorySeparatorChar;
#endif // UNITY_WSA
		char badChar = separatorChar == '\\' ? '/' : '\\';
		FixSlashes(ref path, separatorChar, badChar, true);
	}

	public static string GetSoundbankBasePath()
	{
		string basePathToSet = GetPlatformBasePath();
		bool InitBnkFound = true;
#if UNITY_EDITOR || !UNITY_ANDROID // Can't use File.Exists on Android, assume banks are there
		string InitBankPath = System.IO.Path.Combine(basePathToSet, "Init.bnk");
		if (!System.IO.File.Exists(InitBankPath))
		{
			InitBnkFound = false;
		}
#endif

		if (basePathToSet == string.Empty || InitBnkFound == false)
		{
			Debug.Log("WwiseUnity: Looking for SoundBanks in " + basePathToSet);

#if UNITY_EDITOR
			Debug.LogError("WwiseUnity: Could not locate the SoundBanks. Did you make sure to generate them?");
#else
			Debug.LogError("WwiseUnity: Could not locate the SoundBanks. Did you make sure to copy them to the StreamingAssets folder?");
#endif
		}

		return basePathToSet;
	}
}

#endif // #if ! (UNITY_DASHBOARD_WIDGET || UNITY_WEBPLAYER || UNITY_WII || UNITY_WIIU || UNITY_NACL || UNITY_FLASH || UNITY_BLACKBERRY) // Disable under unsupported platforms.
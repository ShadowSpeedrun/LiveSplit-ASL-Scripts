/****************************************************************/
/* Autosplitter for Metal Gear Solid: The Twin Snakes (Dolphin) */
/*                                                              */
/* Created by bmn for Metal Gear Solid Speedrunners             */
/* Extra support by dlimes13, JosephJoestar316 & jazz_bears     */
/* https://raw.githubusercontent.com/bmn/livesplit_asl_misc/mgstts/MGSTwinSnakes-Dolphin.asl -> original source used for Shadow*/
/****************************************************************/

state("Dolphin") {}

startup {
  settings.Add("features", true, " Debug Logging");
    settings.Add("debug_file", true, " Save debug information to LiveSplit program directory", "features");
      settings.SetToolTip("debug_file", "The log will be saved at mgstts.log.");
    settings.Add("debug_stdout", false, " Log debug information to Windows debug log", "features");
      settings.SetToolTip("debug_stdout", "This can be viewed in a tool such as DebugView.");
  
  settings.Add("behaviour", true, " Autosplitter Behaviour");
    settings.Add("o_startonselect", true, " Start as soon as Game Start is selected", "behaviour");
      settings.SetToolTip("o_startonselect", "Experimental, for Real Time timing purposes. If you have problems with this, disable it.");
    settings.Add("o_norepeat", true, " Suppress repeats of the same split", "behaviour");
    settings.Add("o_halfframerate", false, " Run splitter logic at 30 fps", "behaviour");
    settings.SetToolTip("o_halfframerate", "Can improve performance on weaker systems, at the cost of some precision.");
  
  settings.Add("splits", true, " Split Points");
  
  settings.Add("major", true, " Major Splits", "splits");
  settings.CurrentDefaultParent = "major";
    settings.Add("p38", true, " Guard Encounter");
    settings.Add("p48", true, " Revolver Ocelot");
    settings.Add("p77", true, " M1 Tank");
    settings.Add("p91", true, " Ninja");
    settings.Add("p146", true, " Psycho Mantis");
    settings.Add("p166", true, " Sniper Wolf 1");
      settings.SetToolTip("p166", "This split occurs when you're captured afterwards");
    settings.Add("area15a_area17a_capture", true, " End Disc 1");
      settings.SetToolTip("area15a_area17a_capture", "This split occurs after the disc change sequence");
    settings.Add("area17a_area17b_p210", true, " Comm Tower A Chase");
    settings.Add("p230", true, " Hind D");
    settings.Add("p243", true, " Sniper Wolf 2");
    settings.Add("p261", true, " Vulcan Raven");
    settings.Add("p298", true, " Hot PAL Key");
    settings.Add("p311", true, " Metal Gear REX");
    settings.Add("p335", true, " Liquid Snake");
    settings.Add("w_ending_p359", true, " Final Time");
      settings.SetToolTip("w_ending_p359", "This split occurs shortly after the final pre-credits cutscene.");
   
  
  vars.D = new ExpandoObject();
  var D = vars.D;
  
  D.BaseAddr = IntPtr.Zero;
  D.CompletedSplits = new Dictionary<string, bool>();
  D.DebugFileList = new List<string>();
  D.TestIter = 0;
  D.GameActive = false;
  D.GameId = null;
  D.SplitCheck = new Dictionary<string, Func<bool>>();
  D.SplitWatch = new Dictionary<string, Func<int>>();
  D.ActiveWatchCodes = null;
  D.i = 0;
  
  D.Addr = new Dictionary<string, Dictionary<string, int>>() {
    { "GUPX8P", new Dictionary<string, int>() { // USA
      { "GameTime", 0x57D734 },
      { "StageAction", 0x575F78 },
    } }
  };
    
  D.LookForGameMemory = (Func<Process, Process, bool>)((g, m) => {
    string gameId = null;
    
    if (D.BaseAddr != IntPtr.Zero) {
      gameId = m.ReadString((IntPtr)D.BaseAddr, 6);
      if ( (gameId != null) && (D.Addr.ContainsKey(gameId)) ) return true;
      D.Debug("Game memory disappeared, restarting search");
      D.BaseAddr = IntPtr.Zero;
    }
    
    foreach (var page in g.MemoryPages(true))
    {
      if ((page.RegionSize != (UIntPtr)0x2000000) || (page.Type != MemPageType.MEM_MAPPED)) continue;
      
      gameId = m.ReadString((IntPtr)page.BaseAddress, 6);
      if ( (gameId == null) || (!D.Addr.ContainsKey(gameId)) ) continue;
      
      D.BaseAddr = page.BaseAddress;
      D.GameActive = true;
      D.GameId = gameId;

      return true;
    }
    
    D.GameActive = false;
    D.GameId = null;
    return false;
  });
  
  D.AddrFor = (Func<int, IntPtr>)((val) => (IntPtr)((long)D.BaseAddr + val));
  
  D.VarAddr = (Func<string, int>)((key) => D.Addr[D.GameId][key]);
  
  D.ResetVars = (Func<bool>)(() => {
    D.CompletedSplits.Clear();
    D.TestIter = 0;
    return true;
  });
}

init {
  var D = vars.D;
  D.SplitCheck.Clear();
  D.SplitWatch.Clear();
  
  D.Debug = (Action<string>)((message) => {
    message = "[" + current.GameTime + " < " + D.old.GameTime + "] " + message;
    if (settings["debug_file"]) D.DebugFileList.Add(message);
    if (settings["debug_stdout"]) print("[TTS-AS] " + message);
  });
  
  D.Split = (Func<string, bool>)((code) => {
    if ((settings["o_norepeat"]) && (D.CompletedSplits.ContainsKey(code))) {
      D.Debug("Repeat split for " + code + ", not splitting");
      return false;
    }
    else {
      D.Debug("Splitting for " + code);
      D.CompletedSplits.Add(code, true);
      return true;
    }
  });
  
  D.ManualSplit = (Action)(() => {
    var timerModel = new TimerModel { CurrentState = timer };
    timerModel.Split();
  });
  
  D.SettingEnabled = (Func<string, bool>)((key) => ( (settings.ContainsKey(key)) && (settings[key]) ));
  
  D.SetWatchCodes = (Action)(() => {
    var locationCodes = new List<string>() { current.Location };
    if (D.LocationSets.ContainsKey(current.Location)) locationCodes.Add( D.LocationSets[current.Location] );
    
    var progressCodes = new List<string>() { "p" + current.Progress };
    if (D.ProgressSets.ContainsKey(current.Progress)) progressCodes.Add( D.ProgressSets[current.Progress] );
    
    var validCodes = new List<string>() {
      "p" + current.Progress,
      current.Location,
    };
    validCodes.AddRange(locationCodes);
    validCodes.AddRange(progressCodes);
        
    foreach (var loc in locationCodes) {
      foreach (var prog in progressCodes)
        validCodes.Add(loc + "_" + prog);
    }
    
    var activeCodes = new List<string>();
    foreach (var c in validCodes) {
      string code = "w_" + c;
      if ( (D.SettingEnabled(code)) && (D.SplitWatch.ContainsKey(code)) )
        activeCodes.Add(code);
    }
    
    if (activeCodes.Count == 0) D.ActiveWatchCodes = null;
    else {
      D.Debug("Active watcher (" + string.Join(" ", activeCodes) + ")");
      D.ActiveWatchCodes = activeCodes;
    }
  });
  
  D.Read = new ExpandoObject();
  D.Read.Byte = (Func<int, byte>)((addr) => memory.ReadValue<byte>((IntPtr)D.AddrFor(addr)));
  D.Read.Uint = (Func<int, uint>)((addr) => {
    uint val = memory.ReadValue<uint>((IntPtr)D.AddrFor(addr));
    return (val & 0x000000FF) << 24 |
            (val & 0x0000FF00) << 8 |
            (val & 0x00FF0000) >> 8 |
            ((uint)(val & 0xFF000000)) >> 24;
  });
  D.Read.Short = (Func<int, short>)((addr) => {
    ushort val = memory.ReadValue<ushort>((IntPtr)D.AddrFor(addr));
    return (short)((val & 0x00FF) << 8 |
            ((ushort)(val & 0xFF00)) >> 8);
  });
  D.Read.String = (Func<int, int, string>)((addr, len) => memory.ReadString((IntPtr)D.AddrFor(addr), len));

}

gameTime {
  float msecs = ( (vars.D.GameActive) && (current.Progress >= 3) ) ?
    ((float)current.GameTime / 60 * 1000) : 0;
  return TimeSpan.FromMilliseconds(msecs);
}

update {
  var D = vars.D;
  D.old = old;
  D.i++;
  
  refreshRate = settings["o_halfframerate"] ? 30 : 60; 
  
  if ((D.i % 64) == 0) {
    if (true) {
      string DebugPath = System.IO.Path.GetDirectoryName(Application.ExecutablePath) + "\\shadowsx.log";
      using(System.IO.StreamWriter stream = new System.IO.StreamWriter(DebugPath, true)) {
        stream.WriteLine(string.Join("\n", vars.D.DebugFileList));
        stream.Close();
        vars.D.DebugFileList.Clear();
      }
    }
    D.LookForGameMemory(game, memory);
  }
  
  if (!D.GameActive) {
    current.GameTime = 0;
    current.StageAction = 0; 
    return false;
  }
  
  current.GameTime = D.Read.Uint( D.VarAddr("GameTime") );
  current.StageAction = D.Read.Uint( D.VarAddr("StageAction") );
  
  var ptr = D.Read.Uint( D.VarAddr("StageAction") );
  var ptr2 = D.Read.Uint((int)ptr);
  var ptr3 = D.Read.Uint((int)ptr2);
  
  // NOTE The StageAction address is currently set to the STRING state, but I cannot get the pointer to deref to the string.
  // GameTime is working as expected though
  
  D.Debug("Found Shadow (" + ptr3 + ") memory at " + D.BaseAddr.ToString("X"));
  
  return true;
}


isLoading {
  return true;
}

split {
  var D = vars.D;
  if (!D.GameActive) return false;
  
  if (current.Progress != old.Progress) {
    
    D.SetWatchCodes();
    
    string progressCode = "p" + current.Progress;
    char setting = !settings.ContainsKey(progressCode) ? '?' : (settings[progressCode] ? 'T' : 'F');
    D.Debug("Progress " + progressCode + " [" + setting + "]");
    if (D.SettingEnabled(progressCode))
      return D.Split(progressCode);
    
  }
  
  if (current.Location != old.Location) {
    
    D.SetWatchCodes();
    
    var departureAreas = new List<string>() { old.Location };
    if (D.LocationSets.ContainsKey(old.Location)) departureAreas.Add( D.LocationSets[old.Location] );
    
    var destinationAreas = new List<string>() { current.Location };
    if (D.LocationSets.ContainsKey(current.Location)) destinationAreas.Add( D.LocationSets[current.Location] );
    
    var progressCodes = new List<string>() { "p" + current.Progress };
    if (D.ProgressSets.ContainsKey(current.Progress)) progressCodes.Add( D.ProgressSets[current.Progress] );
    
    var validCodes = new List<string>();
    foreach (var dep in departureAreas) {
      foreach (var dest in destinationAreas) {
        string movement = dep + "_" + dest;
        validCodes.Add(movement);
        foreach (var prog in progressCodes)
          validCodes.Add(movement + "_" + prog);
      }
    }
    D.Debug("Location (" + string.Join(" ", validCodes) + ")");
    
    foreach (var code in validCodes) {
      if (D.SettingEnabled(code)) {
        if ( (!D.SplitCheck.ContainsKey(code)) || (D.SplitCheck[code]()) ) {
          if (D.Split(code)) return true;
        }
      }
    }
    D.Debug("No match, not splitting");
    
  }
  
  if (D.ActiveWatchCodes != null) {
    
    foreach (var code in D.ActiveWatchCodes) {
      int result = D.SplitWatch[code]();
      if (result == 0) continue;
      D.ActiveWatchCodes.Remove(code);
      if (result == 1) return D.Split(code);
      if (result == -1) return false;
    }
    
  }
  
  return false; 
}

start {
  var D = vars.D;
  if (!D.GameActive) return false;
  
  if ( (settings["o_startonselect"]) && (current.StageAction == -1) ) {
    var ptr = D.Read.Uint( D.VarAddr("StageAction") );
    if (ptr != 0) {
      ptr &= 0x0fffffff;
      if (
        ( (D.Read.Byte((int)ptr + 0xe3) == 1) && (D.Read.Byte((int)ptr + 0x4f) == 7) ) // NG
        || ( (D.Read.Byte((int)ptr + 0xe1) == 1) && (D.Read.Byte((int)ptr + 0x4d) == 7) ) // Load
      )
        return D.ResetVars();
    }
  }
  
  if ( (current.StageAction == 3) && (old.StageAction == -1) )
    return D.ResetVars();
    
  return false;
}

reset {
  var D = vars.D;
  if (!D.GameActive) return false;
  if ( ((current.Progress == -1) || (current.Progress == 0)) && (old.Progress != -1) )
    return D.ResetVars();
  return false;
}
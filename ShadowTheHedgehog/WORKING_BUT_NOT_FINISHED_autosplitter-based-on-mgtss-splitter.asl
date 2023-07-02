/****************************************************************/
/* Autosplitter for Metal Gear Solid: The Twin Snakes (Dolphin) */
/*                                                              */
/* Created by bmn for Metal Gear Solid Speedrunners             */
/* Extra support by dlimes13, JosephJoestar316 & jazz_bears     */
/* https://raw.githubusercontent.com/bmn/livesplit_asl_misc/mgstts/MGSTwinSnakes-Dolphin.asl -> original source used for Shadow*/
/****************************************************************/

state("Dolphin") {}

startup {
  settings.Add("features", true, "Debug Logging");
    settings.Add("debug_stdout", false, "Log debug information to Windows debug log", "features");
      settings.SetToolTip("debug_stdout", "This can be viewed in a tool such as DebugView.");
  
  settings.Add("behaviour", true, "Autosplitter Behaviour");
    settings.Add("o_startonnew", true, " Start as soon as New is selected in Story Mode", "behaviour");
    settings.Add("o_norepeat", true, " Suppress repeats of the same split", "behaviour");
    settings.Add("o_halfframerate", false, " Run splitter logic at 30 fps", "behaviour");
    settings.SetToolTip("o_halfframerate", "Can improve performance on weaker systems, at the cost of some precision.");
  
  vars.D = new ExpandoObject();
  var D = vars.D;
  
  D.BaseAddr = IntPtr.Zero;
  D.CompletedSplits = new Dictionary<string, bool>();
  D.DebugFileList = new List<string>();
  D.GameActive = false;
  D.GameId = null;
  D.ActiveWatchCodes = null;
  D.i = 0;
  
  D.Addr = new Dictionary<string, Dictionary<string, int>>() {
    { "GUPX8P", new Dictionary<string, int>() { // USA
      { "GameTime", 0x57D734 },
	  { "GameMode", 0x5EC170 },
	  { "StageCompleted", 0x575F95 },
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
    return true;
  });
}

init {
  var D = vars.D;
  
  D.Debug = (Action<string>)((message) => {
    message = "[" + current.GameTime + " < " + D.old.GameTime + "] " + message;
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

// TODO: Why is this not working?
gameTime {
  return TimeSpan.FromSeconds((float)current.GameTime);
}

update {
  var D = vars.D;
  D.old = old;
  D.i++;
  
  refreshRate = settings["o_halfframerate"] ? 30 : 60; 
  
  if ((D.i % 64) == 0) {
    D.LookForGameMemory(game, memory);
  }
  
  if (!D.GameActive) {
    current.GameTime = 0;
    return false;
  }
  
  current.GameTime = D.Read.Uint(D.VarAddr("GameTime"));
  current.GameMode = D.Read.Uint(D.VarAddr("GameMode"));
  current.StageCompleted = D.Read.Byte(D.VarAddr("StageCompleted"));
  
//  D.Debug("Found Shadow memory at " + D.BaseAddr.ToString("X"));
//  D.Debug("StageCompleted: (" + current.StageCompleted + ")");
//  D.Debug("GameMode: (" + current.GameMode + ")");
//  D.Debug("GameActive: (" + D.GameActive + ")");
//	D.Debug("GameTime: (" + current.GameTime + ")");
//	D.Debug("GameTimeF: (" + (double)current.GameTime + ")");



  
  return true;
}


isLoading {
  return true;
}

split {
  var D = vars.D;
  if (!D.GameActive) return false;
  
  // for normal stages; need additional logic for boss stageIds and final boss split
  if ((current.StageCompleted == 1 || current.StageCompleted == 6) && old.StageCompleted == 0) {
	return true;
  }
  
  return false; 
}

start {
  var D = vars.D;
  if (!D.GameActive) return false;
  
  if ( (settings["o_startonnew"]) && ((current.GameMode == 1 || current.GameMode == 6) && old.GameMode != 1) ) {
		return true;
  
//    var ptr = D.Read.Uint( D.VarAddr("StageAction") );
//    if (ptr != 0) {
//      ptr &= 0x0fffffff;
//      if (
//        ( (D.Read.Byte((int)ptr + 0xe3) == 1) && (D.Read.Byte((int)ptr + 0x4f) == 7) ) // NG
//        || ( (D.Read.Byte((int)ptr + 0xe1) == 1) && (D.Read.Byte((int)ptr + 0x4d) == 7) ) // Load
//      )
//        return D.ResetVars();
//    }
  }
  
//  if ( (current.StageAction == 3) && (old.StageAction == -1) )
//    return D.ResetVars();
    
  return false;
}

reset {
  var D = vars.D;
  if (!D.GameActive) return false;
  if (current.GameMode == -1 && old.GameMode != 1)
   return D.ResetVars();
  return false;
}
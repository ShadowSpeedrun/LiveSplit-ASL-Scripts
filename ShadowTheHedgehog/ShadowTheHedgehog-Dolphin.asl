/***************************************************************************/
/* Autosplitter for Shadow the Hedgehog (USA) (Dolphin)                    */
/*                                                                         */
/* Shadow adaptation of this autosplitter by dreamsyntax & BlazinZzetti    */
/* https://github.com/ShadowSpeedrun/LiveSplit-ASL-Scripts                 */
/*                                                                         */
/* Original MGSTS script Created by bmn for MGSSpeedrunners                */
/* Original Extra support by dlimes13, JosephJoestar316 & jazz_bears       */
/* bmn/livesplit_asl_misc/mgstts/MGSTwinSnakes-Dolphin.asl                 */
/***************************************************************************/

state("Dolphin") {}

startup {
  settings.Add("features", true, "Debug Logging");
    settings.Add("debug_stdout", false, "Log debug information to Windows debug log", "features");
      settings.SetToolTip("debug_stdout", "This can be viewed in a tool such as DebugView.");
  
  settings.Add("behaviour", true, "Autosplitter Behaviour");
    settings.Add("o_autostart", true, "Auto Start", "behaviour");
        settings.SetToolTip("o_autostart", "Start as soon as Story Mode / Expert Mode is started");
    settings.Add("o_autoreset", true, "Auto Reset", "behaviour");
        settings.SetToolTip("o_autoreset", "Reset when returning to the Menu");
    settings.Add("o_halfframerate", false, "Run splitter logic at 30 fps", "behaviour");
    settings.SetToolTip("o_halfframerate", "Can improve performance on weaker systems, at the cost of some precision.");
  
  vars.D = new ExpandoObject();
  var D = vars.D;
  
  D.BaseAddr = IntPtr.Zero;
  D.GameActive = false;
  D.GameId = null;
  D.i = 0;
  D.TotalGameTime = 0;
  
  // other race mode 57D918
  
  D.Addr = new Dictionary<string, Dictionary<string, int>>() {
    { "GUPX8P", new Dictionary<string, int>() { // USA
      { "GameTime", 0x57D734 },
      { "SXGameTime", 0x57D908 },
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
    return true;
  });
}

init {
  var D = vars.D;
  
  D.Debug = (Action<string>)((message) => {
    message = "[" + current.SXGameTime + " < " + D.old.SXGameTime + "] " + message;
    if (settings["debug_stdout"]) print("[ShdTH-AS] " + message);
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

  D.Read.Float = (Func<int, float>)((addr) => {
                      byte byte1 = memory.ReadValue<byte>((IntPtr)D.AddrFor(addr));
                      byte byte2 = memory.ReadValue<byte>((IntPtr)D.AddrFor(addr+1));
                      byte byte3 = memory.ReadValue<byte>((IntPtr)D.AddrFor(addr+2));
                      byte byte4 = memory.ReadValue<byte>((IntPtr)D.AddrFor(addr+3));                     
                      
                      byte[] bytes = new byte[] { byte4, byte3, byte2, byte1 };
                                            
                      return BitConverter.ToSingle(bytes, 0);
                    });
}

gameTime {
  var D = vars.D;
  return TimeSpan.FromSeconds(D.TotalGameTime + current.SXGameTime);
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
    current.SXGameTime = 0;
    return false;
  }
  
  current.GameTime = D.Read.Float(D.VarAddr("GameTime"));
  current.SXGameTime = D.Read.Float(D.VarAddr("SXGameTime"));
  current.GameMode = D.Read.Uint(D.VarAddr("GameMode"));
  current.StageCompleted = D.Read.Byte(D.VarAddr("StageCompleted"));
  return true;
}

// TODO: Implement isLoading to prevent double time add IGT before next stage is loaded
isLoading {
  return true;
}

split {
  var D = vars.D;
  if (!D.GameActive) return false;
  
  // TODO: for normal stages; need additional logic for boss stageIds and final boss split
  if (current.StageCompleted == 1 && old.StageCompleted == 0) {
    D.TotalGameTime = D.TotalGameTime + current.SXGameTime;
    return true;
  }
  
  return false; 
}

start {
  var D = vars.D;
  if (!D.GameActive) return false;
  if ( (settings["o_autostart"]) && ((current.GameMode == 1 || current.GameMode == 6) && old.GameMode != 1) ) {
    D.TotalGameTime = 0;
    return true;
  }
  return false;
}

reset {
  var D = vars.D;
  if (!D.GameActive) return false;
  if ((settings["o_autoreset"]) && ((current.GameMode != 1 && old.GameMode == 1) || (current.GameMode != 6 && old.GameMode == 6))) {
    D.TotalGameTime = 0;
    return true;
  }
  return false;
}
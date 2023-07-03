/***************************************************************************/
/* Autosplitter for Shadow the Hedgehog (Dolphin)                          */
/* https://github.com/ShadowSpeedrun/LiveSplit-ASL-Scripts                 */
/* by dreamsyntax & BlazinZzetti                                           */
/*                                                                         */
/* MGSTS script by bmn used as base                                        */
/* https://github.com/bmn/livesplit_asl_misc/tree/mgstts                   */
/*                                                                         */
/***************************************************************************/

state("Dolphin") {}

startup {
  settings.Add("features", false, "Debug Logging");
    settings.Add("debug_stdout", false, "Log debug information to Windows debug log", "features");
      settings.SetToolTip("debug_stdout", "This can be viewed in a tool such as DebugView.");
  
  settings.Add("behaviour", true, "Autosplitter Behaviour");
    settings.Add("o_autostart", true, "Auto Start", "behaviour");
        settings.SetToolTip("o_autostart", "Start as soon as Story Mode / Expert Mode is started");
    settings.Add("o_autoreset", true, "Auto Reset", "behaviour");
        settings.SetToolTip("o_autoreset", "Reset when returning to the Menu. Turn OFF for Multi-Story Runs");
    settings.Add("o_halfframerate", false, "Run splitter logic at 30 fps", "behaviour");
    settings.SetToolTip("o_halfframerate", "Can improve performance on weaker systems, at the cost of some precision.");
  
  vars.D = new ExpandoObject();
  var D = vars.D;
  
  D.BaseAddr = IntPtr.Zero;
  D.GameActive = false;
  D.GameId = null;
  D.i = 0;
  D.TotalGameTime = 0;
  D.Addr = new Dictionary<string, Dictionary<string, int>>() {
    { "GUPX8P", new Dictionary<string, int>() { // Shadow SX
      { "GameTime", 0x57D908 },
      { "GameMode", 0x5EC170 },
      { "StageCompleted", 0x575F95 },
      { "StageID", 0x57D748 },
      { "BossHP", 0x5EE65C },
    } },
    { "GUPE8P", new Dictionary<string, int>() { // Shadow: Reloaded & USA
      { "GameTime", 0x57D734 },
      { "GameMode", 0x5EC170 },
      { "StageCompleted", 0x575F95 },
      { "StageID", 0x57D748 },
      { "BossHP", 0x5EE65C },
    } }
  };
    
  D.LookForGameMemory = (Func<Process, Process, bool>)((g, m) => {
    string gameId = null;
    
    if (D.BaseAddr != IntPtr.Zero) {
      gameId = m.ReadString((IntPtr)D.BaseAddr, 6);
      if ( (gameId != null) && (D.Addr.ContainsKey(gameId)) ) return true;
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
}

init {
  var D = vars.D;
  
  D.Debug = (Action<string>)((message) => {
    message = "[" + current.GameTime + " < " + D.old.GameTime + "] " + message;
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
  return TimeSpan.FromSeconds(D.TotalGameTime + current.GameTime);
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
    current.BossHP = 0;
    return false;
  }
  
  current.GameTime = D.Read.Float(D.VarAddr("GameTime"));
  current.GameMode = D.Read.Uint(D.VarAddr("GameMode"));
  current.StageCompleted = D.Read.Byte(D.VarAddr("StageCompleted"));
  current.StageID = D.Read.Uint(D.VarAddr("StageID"));
  current.BossHP = D.Read.Float(D.VarAddr("BossHP"));

  return true;
}

isLoading {
  return true;
}

split {
  var D = vars.D;
  if (!D.GameActive) return false;
  
  switch ((int)current.StageID) {
    case 210:
    case 310:
    case 410:
    case 411:
    case 412:
    case 510:
    case 511:
    case 610:
    case 611:
    case 612:
    case 613:
    case 614:
    case 615:
    case 616:
    case 617:
    case 618:
    case 710:
    if (current.BossHP == 0 && old.BossHP != 0) {
      D.TotalGameTime = D.TotalGameTime + current.GameTime;
      return true;
    }
    break;
    default:
      if (current.StageCompleted == 1 && old.StageCompleted == 0) {
        D.TotalGameTime = D.TotalGameTime + current.GameTime;
        return true;
      }
      break;
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
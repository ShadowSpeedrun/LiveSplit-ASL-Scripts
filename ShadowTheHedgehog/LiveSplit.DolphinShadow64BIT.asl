/* Version 1.0 by skoob */

state("Dolphin")
{
	/* Offset to the addresses (0x80000000-0x8040FFFF) FOR HEROES 32 BIT is address - 0x10000 */

	//directly tied to game speed, but freezes when pausing
	/*int globalFrameCount: 0x80442C4C;
	byte GFC1: 0x80442C4C;
	byte GFC2: 0x80442C4D;
	byte GFC3: 0x80442C4E;
	byte GFC4: 0x80442C4F;*/

	//int gameID: 0x7FBF0000; // First int of memory, should be 0x45533947 ('ES9G' in little endian or 'G9SE' in big endian) if game is loaded
	int gameID: "Dolphin.exe", 0x10833F0, 0x0; // First int of mem in 64 bit
	byte emblemScreen: "Dolphin.exe", 0x10833F0, 0x42C28F; // 1 when game is in emblem screen (igt paused)
	byte lastByteOfGFC: "Dolphin.exe", 0x10833F0, 0x452C4F; // To check if to start the splitting
}

init
{
	vars.oldGFC1 = 0;
	vars.oldGFC2 = 0;
	vars.oldGFC3 = 0;
	vars.oldGFC4 = 0;

	/*vars.GFC1 = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x452C4C);
	vars.GFC2 = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x452C4D);
	vars.GFC3 = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x452C4E);
	vars.GFC4 = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x452C4F);*/
	vars.GFC1 = new DeepPointer("Dolphin.exe", 0x10833F0, 0x452C4C);
	vars.GFC2 = new DeepPointer("Dolphin.exe", 0x10833F0, 0x452C4D);
	vars.GFC3 = new DeepPointer("Dolphin.exe", 0x10833F0, 0x452C4E);
	vars.GFC4 = new DeepPointer("Dolphin.exe", 0x10833F0, 0x452C4F);
}

startup
{
	vars.totalFrameCount = 0;
	refreshRate = 63;
}

start
{
	vars.totalFrameCount = 0;

	/*vars.GFC1 = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x452C4C);
	vars.GFC2 = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x452C4D);
	vars.GFC3 = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x452C4E);
	vars.GFC4 = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x452C4F);*/
	vars.GFC1 = new DeepPointer("Dolphin.exe", 0x10833F0, 0x452C4C);
	vars.GFC2 = new DeepPointer("Dolphin.exe", 0x10833F0, 0x452C4D);
	vars.GFC3 = new DeepPointer("Dolphin.exe", 0x10833F0, 0x452C4E);
	vars.GFC4 = new DeepPointer("Dolphin.exe", 0x10833F0, 0x452C4F);

	/*byte currentGFC1 = vars.GFC1.Deref<byte>(game);
	byte currentGFC2 = vars.GFC2.Deref<byte>(game);
	byte currentGFC3 = vars.GFC3.Deref<byte>(game);
	byte currentGFC4 = vars.GFC4.Deref<byte>(game);

	int oldGlobalFrameCount = (vars.oldGFC1 << 24) | (vars.oldGFC2 << 16) | (vars.oldGFC3 << 8) | vars.oldGFC4;
	int globalFrameCount = (currentGFC1 << 24) | (currentGFC2 << 16) | (currentGFC3 << 8) | currentGFC4;

	vars.oldGFC1 = currentGFC1;
	vars.oldGFC2 = currentGFC2;
	vars.oldGFC3 = currentGFC3;
	vars.oldGFC4 = currentGFC4;*/

	//print(globalFrameCount.ToString() + " " + oldGlobalFrameCount.ToString());

	if (current.lastByteOfGFC != 0 && old.lastByteOfGFC == 0)
	{
		vars.totalFrameCount = current.lastByteOfGFC;
		return true;
	}
}

split
{
	if (current.emblemScreen != 0 && old.emblemScreen == 0)
		return true;
}

update
{
	if (current.gameID != 0x45533947)
		return;

	//byte gameMode = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x84593B).Deref<byte>(game);
	//byte gameStatus = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x74A7BD).Deref<byte>(game);
	//int inCutscene = new DeepPointer("Dolphin.exe", 0xBF08E8, 0x740604).Deref<int>(game);
	
	byte currentGFC1 = vars.GFC1.Deref<byte>(game);
	byte currentGFC2 = vars.GFC2.Deref<byte>(game);
	byte currentGFC3 = vars.GFC3.Deref<byte>(game);
	byte currentGFC4 = vars.GFC4.Deref<byte>(game);

	int oldGlobalFrameCount = (vars.oldGFC1 << 24) | (vars.oldGFC2 << 16) | (vars.oldGFC3 << 8) | vars.oldGFC4;
	int globalFrameCount = (currentGFC1 << 24) | (currentGFC2 << 16) | (currentGFC3 << 8) | currentGFC4;

	vars.oldGFC1 = currentGFC1;
	vars.oldGFC2 = currentGFC2;
	vars.oldGFC3 = currentGFC3;
	vars.oldGFC4 = currentGFC4;

	//print(current.test1.ToString("X2") + current.test2.ToString("X2") + current.test3.ToString("X2") + current.test4.ToString("X2"));
	//print(current.gameID.ToString("X2"));
	
	int deltaFrames = globalFrameCount - oldGlobalFrameCount;
	
	vars.totalFrameCount += deltaFrames;
	
	//vars.previousRTA = new TimeSpan(currentRTA.Ticks);
}


gameTime
{
	return TimeSpan.FromSeconds(vars.totalFrameCount / 60.0);
}

isLoading
{
    return true;
}

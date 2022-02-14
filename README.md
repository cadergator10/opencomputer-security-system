# opensecurity-scp-security-system

<a href="https://oc.cil.li/topic/994-security-system-for-opensecurity">This was built off of DustPuppy's system here</a>

This security system was built for the <a href="https://www.technicpack.net/modpack/site-91.1622979">Site 91</a> modpack official server, but I made it public so others could enjoy it.
I built it off of DustPuppy's system from the Open Computers official website (link above), but it is in no way the same as what it originally was.

In total: this is what this new system supports:

<ol>
  <li>Two different card database types: One that works on normal open os, and a ported version for MineOS (way faster and pretty).</li>
  <li>Settings for Staff, GOI, MTF, Level, Armory Level, Department, Blocked, Intercom, and Security</li>
  <li>Two door control types: One is for a single door and supports normal redstone, rolldoor, bundled redstone, and doorcontrol, and a Multidoor, that can control any amount of doors from a single computer</li>
  <li>An automatic setup command that works by running a pastebin command (will be down below)</li>
  <li>Auto Update system! (you have to send a network message through another computer to update all doors. Prolly not necessary) update size has reached beyond limit to be able to send the update through the modem. You will have to do this manually with the autoinstaller autoupdate function, and manually with openos database and server. Mineos system has an update button in app store.</li>
  <li>Easy setting edits: Autoinstaller has functions to let you edit, add, or remove doors as well as wipe all files and update the computer!</li>
</ol>

I will be making a full video tutorial series soon. <a href="https://www.youtube.com/channel/UCC492g_YuYcWKRIeQD3kqdQ">Channel is here</a>

----Server: This has to be running all the time, as it receives the door signals and tells them to open or not to. The server has to be on when editing card settings, or the server will not receive them. Needs a modem and an internet card to run, and a minimum of tier 2 computer.

----Database: This is where you edit the accounts and write the cards. There are 2 types, so make sure you choose the correct one!!! Requires a modem and card writer connected to it, and a tier 3 computer and highest specs if you can! I recommend putting MineOS one on a server rack with 4 tier 3.5 memory modules, but the OpenOS one is lighter.

   OpenOS: You need to add both the openOSDatabase and the gui programs to the drive. This isn't updated much and might be broken (maybe) Name the GUI one gui.lua

   MineOS: Much sleeker and faster and basically better in every way. The database is available in the AppStore of MineOS and installs all necessary dependencies for you, but if you do it manually, you will still have to install the serialization and the uuid library by user cadergator10 on there. Its just the OpenOS serialization and uuid libraries, but if you need it, it is available here.

----Door Control: All the doorcontrol scripts. Can be very low spec honestly, but at least one 3.5 tier ram is probably safe :) Requires a Modem, redstone tier 2 card, and internet card.

   All you have to do is run the command "pastebin run X8M664ew" and follow the prompts. For multidoor, you will have to use an analyzer to copy the ids of the magstrip readers and rolldoor/doorcontrol blocks, while you dont with the single door one. However, if you want to look at the code, here are the dropbox links. HOWEVER, the programs do require a library to work, which the autorun command does for you, so I recommend just doing the above command.

----Autoinstaller: just follow the prompts to install! It's actually that simple! PLUS, it comes with more extra features than just that. You can update the door program, wipe all files, add more doors to a multidoor, delete a door from a multidoor, change settings of doors, and more!
 
   If you want to use pastebin run command, do 
   
    pastebin run X8M664ew

----NOT NECESSARY FOR PROGRAM TO WORK: Diagnostic tablet: a special program that works with the new admin card to get info about a door and it's settings and if it works. It is best used with a tablet that has a tier 3 gpu, a wireless modem, and an internet card. When the admin card is scanned, it sends all the info of the computer to the tablet. It's most noteable use is with the multidoor computer, as it tells you if that magnetic card reader is connected to a door, what the key of the door is (if you want to edit door settings after first set up) and more.

----ALSO NOT NECESSARY: Accelerated door setup program to put on a tablet. This helps accelerate multi-door setup time, as it is portable compared to moving back and forth between the pc and the door.

If you have any questions, don't hesitate to ask!

![image](https://user-images.githubusercontent.com/75097681/153966751-f94d255d-88a6-4b9a-8212-936b8a735a97.png)
![image](https://user-images.githubusercontent.com/75097681/153966774-ddea0e15-01ef-47db-a975-8f0b3b63fed0.png)


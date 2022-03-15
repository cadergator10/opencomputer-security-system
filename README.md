# opensecurity-scp-security-system

<a href="https://oc.cil.li/topic/994-security-system-for-opensecurity">This was built off of DustPuppy's system here</a>

Version 1.#.# of the security system was originally built for the <a href="https://www.technicpack.net/modpack/site-91.1622979">Site 91</a> modpack official server, but I made it public so others could enjoy it. It is obsolete as well and will not receive as many updates.
Version 2.#.# is an entire remake of the entire system and is mine. It is not for redistribution as your own. It is the fully modular system.

Go to bottom for a changelog, future changes, and some extra information about how to use the system

In total: this is what the second generation new system supports:

<ol>
  <li>A MineOS database.</li>
  <li>Fully modular settings!!! (passes, levels, groups, and even custom strings)</li>
  <li>Two door control types: One is for a single door and supports normal redstone, rolldoor, bundled redstone, and doorcontrol, and a Multidoor, that can control any amount of doors from a single computer</li>
  <li>An automatic door setup, with easy setup and updating.</li>
  <li>Easy setting edits: Autoinstaller has functions to let you edit, add, or remove doors as well as wipe all files and update the computer!</li>
  <li>Editable crypt key, so your information being passed isn't easilly read (has a default if you don't want to change it)</li>
</ol>

I will be making a full video tutorial series soon. <a href="https://www.youtube.com/channel/UCC492g_YuYcWKRIeQD3kqdQ">Channel is here</a>

----Server: This has to be running all the time no matter what, as it receives the door signals and tells them to open or not to. It also is necessary for the autoinstaller to know what type of door it is (if 1.#.# or 2.#.#) The server has to be on when editing card settings, or the server will not receive them. Needs a modem and an internet card to run, and a minimum of tier 2 computer.

----Database: This is where you edit the accounts and write the cards. There are 2 types for 1.#.#, but the 2.#.# version ONLY HAS MINEOS, so make sure you understand what you're doing. Requires a modem and card writer connected to it, and a tier 3 computer and highest specs if you can! I recommend putting MineOS one on a server rack with 4 tier 3.5 memory modules, but the OpenOS one is lighter.

   OpenOS: You need to add both the openOSDatabase and the gui programs to the drive. This isn't updated much and might be broken (maybe) Name the GUI one gui.lua. It is only available for 1.#.# systems.

   MineOS: Much sleeker and faster and basically better in every way. The database is available in the AppStore of MineOS and installs all necessary dependencies for you, but if you do it manually, you will still have to install the serialization and the uuid library by user cadergator10 on there. Its just the OpenOS serialization and uuid libraries, but if you need it, it is available here. Make sure you do install the correct version!!! 1.#.# database IS NOT COMPATABLE WITH 2.#.# version!

----Door Control: All the doorcontrol scripts. Can be very low spec honestly, but at least one 3.5 tier ram is probably safe :) Requires a Modem, redstone tier 2 card, and internet card.

   All you have to do is run the command "pastebin run cP70MhB0" and follow the prompts. For multidoor, you will have to use an analyzer to copy the ids of the magstrip readers and rolldoor/doorcontrol blocks, while you dont with the single door one. However, if you want to look at the code, the code is in the github. HOWEVER, the programs do require a library to work, which the autorun command does for you, so I recommend just doing the above command. SERVER MUST BE ON IN ORDER FOR AUTOINSTALLER TO INSTALL CORRECT DOOR CONTROL VERSION!

----Autoinstaller: just follow the prompts to install! It's actually that simple! PLUS, it comes with more extra features than just that. You can update the door program, wipe all files, add more doors to a multidoor, delete a door from a multidoor, change settings of doors, and more!
 
   If you want to use pastebin run command, do 
   
    pastebin run cP70MhB0
    (If you have a 7.0 or earlier version of doorcontrol, run pastebin run X8M664ew to update to new version)

----NOT NECESSARY FOR PROGRAM TO WORK: Diagnostic tablet: a special program that works with the new admin card to get info about a door and it's settings and if it works. It is best used with a tablet that has a tier 3 gpu, a wireless modem, and an internet card. When the admin card is scanned, it sends all the info of the computer to the tablet. It's most noteable use is with the multidoor computer, as it tells you if that magnetic card reader is connected to a door, what the key of the door is (if you want to edit door settings after first set up) and more.

----ALSO NOT NECESSARY: Accelerated door setup program to put on a tablet. This helps accelerate multi-door setup time, as it is portable compared to moving back and forth between the pc and the door. Also, if your tablet has an analyzer with it, you can scan the blocks with the tablet instead of just entering the uuid manually (in beta)

If you have any questions, don't hesitate to ask!

<a href="https://www.youtube.com/watch?v=Ww2zGUjsZXo&list=PLJjS9EiCaZUUc1ZqsKekK1_S46aFl-682">Tutorial playlist here</a>

![image](https://user-images.githubusercontent.com/75097681/153966751-f94d255d-88a6-4b9a-8212-936b8a735a97.png)
![image](https://user-images.githubusercontent.com/75097681/153966774-ddea0e15-01ef-47db-a975-8f0b3b63fed0.png)

Beta Changelog:
<ul>
   <li>6.0 and before: don't have specific updates on stuff, basically everything that isn't past this.</li>
   <li>7.0: I believe I changed the system in which users are saved on the cards. Before it split string and now it uses serialized array.</li>
   <li>7.1: Server's text is now colored. MineOS database linking uses background container instead of an alert (linking is for Site 91)</li>
</ul>

1.#.# Changelog:
<ul>
   <li>1.8.0: Updates to add cryptKey function to old system (added in new system) 3/15 </li>
</ul>

2.#.# Changelog:
<ul>
   <li>2.1.0: Completely from scratch work for door now out with full modular support! 3/15
</ul>

Future updates:
<ol>
   <li>search through code to make sure every version number is up to date.</li>
   <li>Bug testing and making sure it is squeaky clean!</li>
</ol>

Important information:
   The first number of a security system update is a full system update, which can possibly break previous systems. The second is a small update that doesn't involve updating every single device. Second number should be able to be mixed and matched (eg a 7.1 device works with a 7.0 server), but the first cannot (8.0 device SHOULD/WILL NOT work with a 7.0 device.)
   1.#.# ARE NEVER COMPATABLE WITH 2.#.# VERSIONS!

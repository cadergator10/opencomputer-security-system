# opensecurity-security-system

A Fully fleshed out Security System solution for OpenComputers and OpenSecurity using the servertine system.

Featuring...
<ul>
   <li>Multiple door controlling with a single door computer</li>
   <li>Powerful passes system you set up yourself</li>
   <li>Security card blocking and disabling from the database</li>
   <li>Easy door creation using the Autoinstaller or door creation module</li>
   <li>Easy door editing, installing, and diagnostics with the diagnostic program</li>
   <li>Long-range data transfer with built-in support for servertine's range extender program</li>
   <li>Modularity with a modified servertine API with support for changing user card data</li>
   <li>Optional modules you can play with that interface with your system (like Sectors module)</li>
   <li>And much more!</li>
</ul>

If you have used this before, you may be wondering, "what's servertine?" I split up the server and database from the security system and am making them into a new project called "Servertine", which is a powerful system you can create powerful modules for and easilly connect to them using the servertine API. They also support other features like the range extender. The reason being for this is an API I can easilly build more programs off of and ease of updating the existing passes system. The move to a modular system brings no drawbacks to the system as well.

<a href="https://github.com/cadergator10/Opencomputers-serpentine">Download servertine here</a>

I will be making a full video tutorial series soon. <a href="https://www.youtube.com/channel/UCC492g_YuYcWKRIeQD3kqdQ">Channel is here</a>

----Server: The brain of the system. Install the security module onto the servertine server and keep it running and everything is handled for you! it stores user data as well as pass data and handles the logic for doorcontrol systems.

----Database: Where you modify the system parameters. Install the Servertine Database on MineOS and install the security module and manage users, passes, and such with ease and speed.

----Door Control: Control security door and redstone from these convenient door systems! Easy to set up and easy to change settings with, these really have it all.

   Autoinstaller setup: Run the command "pastebin run cP70MhB0" and follow the prompts. Syncs nicely with the accelerated door setup program on the diagnostic tablet to allow for scanning of the doors and readers instead of copying the uuid with an analyzer.

   Door Setup module setup: Setup the passes and simple settings on the database, install the stuff onto a drive, and finish on the computer.

----Autoinstaller: Install the doors with ths simple autoinstaller! Just follow the prompts
 
    pastebin run cP70MhB0

----Diagnostic tablet: A program with a whole bunch of programs to make door setup, management, and more easier
      
      Diagnostics: a special program that works with the new admin card to get info about a door and it's settings and if it works. It is best used with a tablet that has a tier 2 gpu, a wireless modem, and an internet card. When the admin card is scanned, it sends all the info of the computer to the tablet. It's most noteable use is with the multidoor computer, as it tells you if that magnetic card reader is connected to a door, what the key of the door is (if you want to edit door settings after first set up) and more.

      Accelerated door setup program to put on a tablet. This helps accelerate multi-door setup time, as it is portable compared to moving back and forth between the pc and the door. Also, if your tablet has an analyzer with it, you can scan the blocks with the tablet instead of just entering the uuid manually

      Door editing: Lets you edit doors with amazing ease. Just swipe the door with an admin card and change settings, add/delete doors, and more. Is a major game changer compared to autoinstaller door editing.

      Remote Control: Open and close doors from any distance without having to swipe cards. You get access to every single door linked to the server. This also lets you open doors contrary to what the settings are set to for the door, like toggling doors that would normally be delayed.

----Security API is a modified version of the Servertine API, with locked data that is sent to the server, ability to check passes from a card that is swiped, and get and set variables in user accounts (if string)

----Optional modules for more functionality

      Sector system- Give doors groups which you can manage with the sector control computer. Lock doors open or lock them shut and let certain passes either bypass these or turn them off.

If you have any questions, don't hesitate to ask!

<a href="https://www.youtube.com/watch?v=Ww2zGUjsZXo&list=PLJjS9EiCaZUUc1ZqsKekK1_S46aFl-682">Tutorial playlist here (older videos may be outdated)</a>

![2022-03-31_18 17 37](https://user-images.githubusercontent.com/75097681/161160569-b7cc527d-f03e-4b8a-8c1c-ba9df040ddf7.png)
![2022-03-31_18 17 25](https://user-images.githubusercontent.com/75097681/161160580-5213b4f9-2f69-4f06-ae74-f48a20d6c1c4.png)
![image](https://user-images.githubusercontent.com/75097681/153966774-ddea0e15-01ef-47db-a975-8f0b3b63fed0.png)

Changelog:
<ul>
   <li>2.1.0: Completely from scratch work for door now out with full modular support! 3/15</li>
   <li>2.1.1: Bug fixes I believe... 3/23</li>
   <li>2.1.2: Door control bug fix: deleting a pass no longer breaks all doors. After update, doors should fix it themselves. 3/28</li>
   <li>2.2.0: Multiple Pass update: You can now use multiple passes on the same door control, with advanced checks and such! 4/6</li>
   <li>2.2.0 Side update 1: Created the securityAPI. Information in wiki 4/11
   <li>2.2.0 Side update 2: Improved diagnostic tablet with a simple user interface; Moved accelerated door setup code to the diagnostic tablet
   <li>2.2.1 Diagnostics update: Accelerated door setup and diagnostics are combined to one tablet with easy to use controls. Works with both 2.2.0 and 2.2.1 and future doors (2.2.1 and up allow you to see every door configuration on multi-doors) 4/30</li>
   <li>2.2.2 Runtime Editing update: Added the editor to the diagnostic tablet program, so you can now swipe the admin card in the door control and edit all the doors without having to use the autoinstaller! (Does not include pass editing which still requires the autoinstaller atm) Works with 2.2.2 and up Only. Also changed uuid resetting button to show a yes/no page. 5/18</li>
   <li>2.3.0 Functional string update: String and HiddenStrings can now be grabbed and set via the securityAPI. This allows you to make custom programs using it (such as a door you can only use 3 times, etc.) This gives a use for the hidden string, as it is now a string value unable to be edited in the database. Get and set with securityapi only works with strings, not int, group, or bool. Check SecurityAPI wiki page for more info. MineOS database now downloads userTable from server on reboot instead of using the one already saved on the database in order to avoid resetting string values set on the server. mineos also has option to turn on and off autoupdate (in dbsettings.txt in app folder) 5/30</li>
   <li>2.3.1 QOL update: MineOS database now has lang file support as well as a dark style you can enable in dbsettings. Diagnostic tablet's editing mode can now add and delete doors and change the pass settings 6/26</li>
   <li>2.3.2 Remote Control update: Diagnostic tablet can now remote control doors! Either toggle a door open/closed or open with a delay. Server must be updated to version 2.3.2, but doors may not have to be updated (still recommended) 7/12</li>
   <li>2.4.0 Sector Update: Replaced the useless forceOpen and bypassLock settings with the new sectors system. You can create however many sectors you like in the mineOS database and set doors to that sector. Then, with the new sectorcontrol program, you can control sectors with redstone, locking them down or locking them open. Certain passes can also be set to open locked down doors or just bypass the lockdown! This also comes with the range extender program for doorcontrols and modules system to build in your own programs to be part of the server. Server also got a GUI upgrade and autoinstaller can install servers and modules. 7/26</li>
   <li>3.0.0 Servertine split: Split up the security system with the server and database. They are now modules. 9/16</li>
</ul>

Queued updates:
<ol>
   <li>3.0.1: Make diagnostic tablet able to scan devices in runtime editing and attempt to break down other unnecessary limits around the systems to allow for more user friendliness.</li>
   <li>3.0.2: Refine the variable editing by ditching the popup that comes up and using the database screen to make it look nicer.</li>
</ol>

Future updates:
<ol>
   <li>Undecided</li>
</ol>

Important information:
   Previous versions have been wiped completely out! The old 1.#.# version is no longer able to be downloaded for less confusion.
   If you have anything you would like to try adding yourself, feel free to add whatever you want to the code and pull request it into the main branch. I can then check if it's a worthwhile update and merge.

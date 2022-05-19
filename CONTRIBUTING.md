If you wish to contribute, there are a few things to remember
1. Minor changes that don't really affect every single program change the third number (2.2.1 goes to 2.2.2) This means that all numbers are compatable with eachother (a 2.2.0 server works with a 2.2.2 door)
2. Major changes that cause every device to need an update or be on the same version need the second number changed (2.2.1 goes to 2.3.0)
3. Version changes to the door control likely need a version checking update in the diagnostic tablet. I'll be happy enough to do this part for you however, so it isn't that important.
4. The autoinstaller and anything that downloads code from the web download from the main branch, so if you are testing a doorcontrol and autoinstaller update, you will have to wget the new code yourself afterward

In order to contribute, you just have to fork the repository, make the necessary changes, and when you think it's good enough, pull request in.
I will fix or perform changes in the following conditions:
1. Diagnostic tablet versioning (if you don't make any changes to the diagnostic tablet, I'll add the version number myself)
2. The bug is minor enough that I can easilly spot it

I will not fix or do changes myself on the following:
1. You need help coding a certain part of the program
2. The bug is very well hidden (eg: I cannot see the problem easily)

I might add more to this later when I figure out what else I need.

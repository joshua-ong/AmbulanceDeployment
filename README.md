# AmbulanceDeployement

## Setting up the Julia Project Locally
### This was written by Will.  Let him know if anything's confusing or if you have suggestions to make this more helpful.
### If you're not already familiar with the Julia shell, skim through [this link][1].  Almost all of this setup takes place in the shell.  This should get you familiar with the basic commands and interface.
1. Pull this github repo onto your local machine.  Doesn't really matter where, this won't be the active package, just need the files.
2. Inside your Julia shell, create a new package called 'AmbulanceDeployment'
   * Follow [this tutorial][2] for more details on generating a package.
   * Make sure you also change the name of the package directory to 'AmbulanceDeployment.jl' (apparently it's good convention).
   * From here, you can replace the contents of the newly generated package with the contents of this repo
   * Specifically, paste in the contents of 'AmbulanceDeployment.jl-legacy' directory from this repo, replacing the original contents of the generated package.
3. Download Gurobi.  You'll need a license.  You can get a free academic license and download the optimizer from [this link][3]
    * You'll see three different download options on the 'Download Gurobi Optimizer' page.  Select 'Gurobi Optimizer'.
    * On Windows, it was a simple download, just run through the installer.  I didn't do anything special.  It'll make you restart your computer before the changes take effect, but this automatically added the Gurobi environment variable to my machine.
4. Back in the 'AmbulanceDeployment.jl' directory in your Julia shell, activate the package with the pkg 'activate .' command.  
    * Make sure to include the dot, it points activate towards the current directory's Project.toml file.  
    * Rather than calling 'import Pkg', I just typed the ']' char, which changes the shell mode to Pkg.  Personal preference, but I thought it was a little cleaner than typing 'Pkg.' every time you need to acces Pkg. 
5. Instantiate the package, calling 'Pkg.instantiate()'
    * Since we have a Manifest.toml file, this command will download all the packages declared in that manifest.
    * If all is going well here, this should download pretty much everything you need.  I did this a week ago, so my steps could be slightly out of order, but this command did most of the heavy lifting for me.
6. Now, cd into the 'tests' directory, and call 'include(runtests.jl)'
    * You may get errors telling you to add a package.  Just do whatever the message says.
    * Keep adding packages and calling include again until you've downloaded all necessary packages
    * Once you've added all necessary packages, you'll probably get errors for syntax issues.  That's good, since we're working on syntax issues rn.

* This is where I left off.  If you make it here you should be in a good place.  If you didn't make it here, let me know of any issues and we can add the solutions to the ReadMe.  If you want to keep going feel, or if you discovered anything along the way, feel free to add what you learn to this doc.
* It'd be nice if we can get it set up so that the package we created is the same thing as the repo, that way we don't have to copy/paste files between the repo and local packages.  Less room for error.  If you have ideas, have at it.  An added benefit is that future users could add our package by cloning the GitHub link. [This][4] might be a good staring point.

-Will

[1]: https://docs.julialang.org/en/v1/stdlib/REPL/
[2]: https://julialang.github.io/Pkg.jl/v1/creating-packages/
[3]: https://www.gurobi.com/academia/academic-program-and-licenses/
[4]: http://ucidatascienceinitiative.github.io/IntroToJulia/Html/GithubIntroduction

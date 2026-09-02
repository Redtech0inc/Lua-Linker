# Lua Linker
this is a file that allows you to turn a project (aka many small files which have 'require' that chain to assemble the project) into one file. This concept is taken form languages like C where you have a linker as part of the compiler

## instructions
### include (require)
to do a "require" you simply type <br>
```lua
--#include [relative path]
```
into the Lua file at any position (must be it's own line)<br>
<br>
```[relative path]``` here means the way to get to the file form this file

Note that the import will not be put where the comment is but above the file importing it

### define
this allows you to define a variable that will be replaced with the intended value at "build time" (in the file that defines it) to do this simply add<br>
```lua
    --#define [pattern] [replacementStr]
```
at any point in the file (must be it's own line)<br>
<br>
```[pattern]``` is the name of the "build time" variable e.g: MY_BUILD_VAR<br>
```[replacementStr]``` is the value you want to replace it with e.g: "this was replaced by the bundler"<br>
<br>
```lua
--#define MY_BUILD_VAR "this was replaced by the bundler"
```
this example will replace any standalone mention of ```MY_BUILD_VAR``` (even if in a string) with '```"this was replaced by the bundler"```' during the assembling of your Lua project

### if / elseif / else / endif
this allows you to only add specific lines if a condition at build time is true to use putdown<br>
```lua
--#if [condition]
your code here
--#elseif [condition]
your code here
--#else
your code here
--#endif
```
```[condition]``` describes a up to 3 word true/false statement (anything not ```false``` or ```nil``` is seen as ```true```) the condition can even include values from  ```--#define```(as long as they have been defined before the condition)<br>
example:
```lua
--#if PLATFORM == "computer"
print("on computer")
--#endif
```
in this example, if the platform in ```env.json``` is set to ```"computer"``` the final output file will have this print call in it other wise it will be removed during compacting<br>
<br>
Note: ```--#elseif``` and ```--#else``` are optional
<br><br>
Note: that currently ```--#define```, ect... inside of the if blocks will be accepted no matter if the condition is true or false (i'am working on that)


## environment
the linker (bundler) will automatically make a environment(```env.json```) on first launch (directly after starting so terminating will cause no issue)
this environment describes build variables it is like ```--#define [environmentVar] [value]``` but for all files so the key of the variable is the ```[environmentVar]```
and it's value is ```[value]```

### existing values
<li> LINKER_VERSION: the version of the linker
<li> COS_VERSION: CraftOS version
<li> PLATFORM: the device i.e "turtle", "pocket" or "computer"
<li> BUILD_TIME: a string generated using os.date("%c") during building <br> (<b>cannot be modified by environment</b>)
<li> BUILD_EPOCH: a number generated during os.epoch("utc") during building <br> (<b>cannot be modified by environment</b>)

<br>
<br>

Note: anything that isn't a number or boolean will be turned into a lua string so ```nil``` will be turned into ```"nil"```

## output
the output is the base file given to the linker with all it's dependencies and their dependencies stitched on top.<br>
the linker dynamically resolves where what should be and compacts the file down (removes comments not needed spaces and tabs)

## warning
this does physically graft the files together so local variables with the same name may override each other in the final product

## Config
you can configure a few things abt the linker in the top of the file such as:
<li> LH_AUTO_SAVE_INTERVALS: how many lines it should write before saving in between while compacting files
<li> TABS: how many spaces are seen as a tab key press (since code editors do their own thing)

## FUTURE FEATURES
<li> UI: makes navigation easier

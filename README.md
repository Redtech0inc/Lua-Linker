# Lua Linker
this is a file that allows you to turn a project (aka many small files which have 'require' that chain to assemble the project) into one file. This concept is taken from languages like C where you have a linker as part of the compiler

## instructions
### include (require)
to do a "require" you simply type <br>
```lua
--#include [relative path]
```
into the Lua file at any position (must be it's own line)<br>
<br>
```[relative path]``` here means the way to get to the file form this file

Note: the import will not be put where the comment is but above the file importing it

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
this allows you to only add specific lines if a condition at build time is true to use do<br>
```lua
--#if [condition]
your code here
--#elseif [condition]
your code here
--#else
your code here
--#endif
```
```[condition]``` describes a statement of up to 3 words (anything not ```false``` or ```nil``` is seen as ```true```) the condition can even include values from  ```--#define```(as long as they have been defined before the condition)<br>
example:
```lua
--#if DEVICE_PLATFORM == "computer"
print("on computer")
--#endif
```
in this example, if the platform in ```env.json``` is set to ```"computer"``` the final output file will have this print call in it otherwise it will be removed during compacting<br>
<br>
Note: ```--#elseif``` and ```--#else``` are optional<br>
<br>
<b>NOTE: STATEMENTS ARE EVALUATED SO THIS IS A SECURITY RISK</b>

## environment
the linker (bundler) will automatically make a environment (```env.json```) on first launch (directly after starting so terminating will cause no issue)
this environment describes build variables it is like ```--#define [environmentVar] [value]``` but for all files so the key of the variable is the ```[environmentVar]```
and it's value is ```[value]```

### existing values
<li> LINKER_VERSION: the version of the linker
<li> COS_VERSION: CraftOS version
<li> DEVICE_PLATFORM: the device i.e "turtle", "pocket" or "computer"
<li> BUILD_TIME: a string generated using os.date("%c") during building <br> (<b>cannot be modified by environment</b>)
<li> BUILD_EPOCH: a number generated during os.epoch("utc") during building <br> (<b>cannot be modified by environment</b>)

<br>
<br>

Note: Any environment value that isn't a number or boolean is inserted as a Lua string literal<br>
e.g: ```nil``` will be turned into ```"nil"```

## output
the output is the base file given to the linker with all it's dependencies and their dependencies stitched on top.<br>
the linker dynamically resolves where everything should be and compacts the file down (removes comments not needed spaces and tabs)

## warning
this does physically graft the files together so local variables with the same name may override each other in the final product

## Config
you can configure a few things about the linker in the top of the file such as:
<li> LH_AUTO_SAVE_INTERVALS: how many lines it should write before saving in between while compacting files
<li> TABS: how many spaces are seen as a tab key press (since code editors do their own thing)

## FUTURE FEATURES
<li> UI: makes navigation easier

## Tags
[![Download on PineStore](https://raster.shields.io/badge/dynamic/json?url=https%3A%2F%2Fpinestore.cc%2Fapi%2Fproject%2F265&query=%24.project.downloads&suffix=%20downloads&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPHN2ZyB3aWR0aD0iNzYuOTA0IiBoZWlnaHQ9Ijg5LjI5NSIgcHJlc2VydmVBc3BlY3RSYXRpbz0ieE1pZFlNaWQiIHZlcnNpb249IjEuMSIgdmlld0JveD0iMCAwIDc2OS4wNCA4OTIuOTUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI%2BCiA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMTQuNzQgLTQuNjgyNikiIGZpbGw9IiM5YWIyZjIiPgogIDxwYXRoIGQ9Im00MTAgODUxYzAtMTIgMjYtMjEgNTgtMjEgMTUgMCAyMiA0IDE3IDktMTQgMTItNzUgMjItNzUgMTJ6Ii8%2BCiAgPHBhdGggZD0ibTU4NSA3NDJjLTEtNDkgNC03MiAxNi04NSAyMi0yNCAzMC02OCAxNi04Ni0xMi0xNC0yNy0zOS00OC03OC0xMC0xOS05LTI2IDQtNDEgMjItMjQgMjEtNjctMi0xNDQtMjEtNjktMzktMTQ0LTQ4LTE5NS00LTI2LTItMzMgMTEtMzMgMzEgMCAxMTIgMzMgMTQxIDU4IDI4IDIzIDgxIDkyIDcxIDkyLTIgMCA1IDI2IDE2IDU3IDI4IDc5IDI5IDIyNCAzIDMwOC0xMCAzMy0xOSA2Mi0xOSA2NS00IDI2LTEzMiAxNTAtMTU1IDE1MC0zIDAtNi0zMC02LTY4eiIvPgogIDxwYXRoIGQ9Im02OCA2NzNjLTcyLTEwOS03MS0yNzggMy00MjMgMzYtNzEgNjItMTAwIDEyOC0xNDAgNDMtMjcgNjUtMzQgMTE4LTM2IDEwMC00IDk4IDExLTE5IDEzNi0zNCAzNy03OCA4OC05NiAxMTMtMjggMzktMzEgNDgtMjEgNjUgMTEgMTcgNiAyNy0zMyA3OS00MCA1My00NCA2Mi0zMiA3OCAxNyAyMyAxOCA1NyAyIDczLTYgNi0xNCAzMS0xNyA1NC02IDQyLTYgNDItMzMgMXoiLz4KIDwvZz4KIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKC0xNC43NCAtNC42ODI2KSIgZmlsbD0iIzU5YTY0ZiI%2BCiAgPHBhdGggZD0ibTM2NSA4MTNjLTUzLTYtMTM5LTMzLTE5Mi02MS02OC0zNS04My02Ny01OC0xMjIgMjYtNTkgNDAtNjcgNzgtNDkgNjggMzMgMTY3IDU4IDI2NiA2OSA1OCA1IDEwNiAxMiAxMDkgMTQgMiAzIDYgMzIgOSA2NSA4IDg1IDAgOTEtMTAxIDkwLTQ0LTEtOTQtNC0xMTEtNnoiLz4KICA8cGF0aCBkPSJtNDEwIDQ1OWMtNjctNy0xNjAtMjktMTk5LTQ4LTI3LTE0LTM0LTM2LTIwLTYzIDIxLTM4IDk3LTEzNiAxNTAtMTkzIDI1LTI3IDU4LTcxIDczLTk3IDI1LTQzIDMxLTQ3IDU0LTQyIDQwIDEwIDQyIDEyIDQyIDUyIDAgMjAgNiA1NyAxNCA4MiAyNCA3MyA1NCAxOTIgNjIgMjM2IDUgMzUgMyA0NS0xNSA2My0yMyAyMy0zNiAyNC0xNjEgMTB6Ii8%2BCiA8L2c%2BCiA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMTQuNzQgLTQuNjgyNikiIGZpbGw9IiM3ZWNiMjUiPgogIDxwYXRoIGQ9Im01NTggNjc0Yy0yLTItNTEtOS0xMDktMTQtMTAyLTExLTIwNC0zNy0yNjQtNjktMTYtOC0zMi0xNC0zNC0xMi00IDMtMzEtNDgtMzEtNjEgMC01IDIxLTMxIDQ2LTU4IDUxLTU0IDcxLTYwIDEzMC0zNSAxOSA4IDgzIDE5IDE0MiAyNSA1OCA2IDEwNyAxMiAxMDcgMTNzMTUgMjYgMzMgNTZjMjcgNDMgMzIgNjMgMzAgOTktMiAzNS04IDQ3LTI1IDUzLTExIDQtMjMgNi0yNSAzeiIvPgogPC9nPgogPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTE0Ljc0IC00LjY4MjYpIiBmaWxsPSIjZWNlZGVmIj4KICA8cGF0aCBkPSJtMjYwIDg5MGMtMzQtOC03MC00MS03MC02NSAwLTYtOS0yMC0yMC0zMHMtMjAtMjItMjAtMjctMTMtMjEtMzAtMzVjLTM1LTI5LTQxLTgzLTEzLTEyMiAxNS0yMiAxNS0yNi0xLTU2LTE4LTMzLTE4LTMzIDI3LTkxIDI4LTM2IDQyLTYzIDM2LTY4LTIzLTI1IDktNzggMTIwLTE5NyAzNi0zOCA3Mi04MSA4Mi05NiAxMC0xNCAyNS0zMCAzMy0zNSAzNi0yMCA3IDMyLTUzIDk3LTQ4IDUxLTEyNiAxNTAtMTQ5IDE4OS0xMCAxOC05IDI0IDEwIDQwIDIzIDE5IDIzIDE5LTI5IDcxLTUzIDUyLTUzIDUyLTM4IDgyIDE0IDI4IDE0IDMzLTEwIDc2LTMyIDU3LTIzIDgxIDQ2IDEyMCAzNCAxOSA0OSAzMyA0NSA0Mi0xNCAzNyAzNiA3NSA5OCA3NSAyNSAwIDQwLTcgNTQtMjUgMTgtMjMgMjctMjUgOTUtMjUgOTQgMCAxMDItOCA5My04OS02LTUzLTUtNTkgMTQtNjQgMzItOCAyNi02NC0xNS0xMzItMzUtNTgtMzUtNTgtOS04MiAyMS0xOSAyNC0yOSAxOS01Ni0xMC00Ny00NC0xNzUtNjEtMjI3LTgtMjUtMTQtNjItMTQtODMgMC0yNy01LTM5LTE3LTQzLTEwLTMtMjUtOC0zMy0xMC0xMi00LTEyLTYtMS0xNCAyNy0xNiA1NiA1IDY5IDUxIDM1IDExNyA0MyAxNDggNDYgMTcwIDIgMTMgMTEgNTEgMjEgODQgMjEgNzEgMjEgMTIxIDAgMTQ1LTE0IDE1LTEzIDE5IDUgNDMgMTEgMTQgMjAgMzAgMjAgMzVzNyAxNSAxNSAyMmMyMSAxNyAxNiA3NS0xMCAxMDItMTggMTktMjAgMzItMTcgNzkgNCA1MCAyIDU4LTE5IDcyLTEyIDktNTAgMTktODMgMjMtNDUgNS02NSAxMy04MyAzMi0yNiAyOC05MiAzOC0xNTMgMjJ6Ii8%2BCiA8L2c%2BCiA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMTQuNzQgLTQuNjgyNikiIGZpbGw9IiM3ZTY3NGQiPgogIDxwYXRoIGQ9Im0yNDggODU0Yy0zMC0xNi00Ny01OS0zMC03NiA4LTggMjMtNyA1NCAyIDI0IDcgNjEgMTQgODMgMTcgNTQgNyA1OSAxNSAzNSA0Ni0xOCAyMy0yOSAyNy02OCAyNy0yNi0xLTU5LTctNzQtMTZ6Ii8%2BCiA8L2c%2BCjwvc3ZnPgo%3D&label=PineStore)](https://pinestore.cc/projects/265/lua-linker-bundler-)

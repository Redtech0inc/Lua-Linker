local LH_AUTO_SAVE_INTERVALS = 20
local TABS = "    "

local function arrowRead(arrow,arrowColor,char)
    local color = term.getTextColor()
    if type(arrowColor) == "number" then
        term.setTextColor(arrowColor)
    end
    term.write(arrow)
    term.setTextColor(color)

    return read(char)
end

local function setupFolder(folderPath)
    if not fs.isDir(folderPath) then
        if fs.exists(folderPath) then
            error("please delete or rename '"..folderPath.."' for setup stage to work")
        end
        fs.makeDir(folderPath)
    end
end

local function warn(msg)
    local color = term.getTextColor()
    term.setTextColor(colors.orange)
    print("warn: "..tostring(msg))
    term.setTextColor(color)
end

local function jsonStyleToString(value)
    if type(value) == "nil" then return "null"
    elseif type(value) == "number" or type(value) == "boolean" then return tostring(value)
    end
    return "\""..tostring(value).."\""
end

local function getSimpleJSONStyleMap(map)
    local output = "{\n"
    local firstItr = true
    for k,v in pairs(map) do
        if firstItr then
            output = output.."    \""..tostring(k).."\":"..jsonStyleToString(v)
        else
            output = output..",\n    \""..tostring(k).."\":"..jsonStyleToString(v)
        end
        firstItr = false
    end
    return output.."\n}"
end

local function makeAssemblyEnv(filePath)
    local env = {}

    if turtle then
        env.DEVICE_PLATFORM = "turtle"
    elseif pocket then
        env.DEVICE_PLATFORM = "pocket"
    else
        env.DEVICE_PLATFORM = "computer"
    end

    local versionNumber = tonumber((os.version() or ""):match("(%d+%.%d+)"))
    env.COS_VERSION = versionNumber or -1
    env.LINKER_VERSION = 1.2

    local file = io.open(filePath,"w")
    file:write(getSimpleJSONStyleMap(env))
    file:close()

    return env
end

local function getEnvTable(filePath)
    if not fs.exists(filePath) then makeAssemblyEnv(filePath) end
    local file = io.open(filePath,"r")
    local table = textutils.unserialiseJSON(file:read("a"))
    file:close()

    if not table then
        table = makeAssemblyEnv(filePath) --generate the default one to replace the brocken one
    end

    table.BUILD_TIME = nil --ensures that we can not have a second BUILD_TIME
    table.BUILD_EPOCH = nil --ensures that we can not have a second BUILD_EPOCH

    return table
end

local function parseEnvValue(value)
    if type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    else
        return "\""..tostring(value).."\""
    end
end

--TODO: fixe the absence of a UI cause typing f***ing sucks
local mountPath = fs.getDir(shell.getRunningProgram())
if mountPath == "rom/" then mountPath = "" end

local outputFolderPath = fs.combine(mountPath,"build")
local cacheFolderPath = fs.combine(mountPath,"cache")
local logsFolderPath = fs.combine(mountPath,"logs")
local envFilePath = fs.combine(mountPath,"env.json")

setupFolder(outputFolderPath)
setupFolder(cacheFolderPath)
setupFolder(logsFolderPath)

if not fs.exists(envFilePath) then makeAssemblyEnv(envFilePath) end

print()
term.setTextColor(colors.orange)
print("please enter the path from root of the file you would like to \"assemble\"")
term.setTextColor(colors.white)
local filePath = arrowRead("> ",colors.lightGray)
if not fs.exists(filePath) then error("could not locate '"..filePath.."'") end
print()

term.setTextColor(colors.blue)
print("please enter the name of the finished file (without .lua)")
term.setTextColor(colors.white)
local outputName = arrowRead("> ",colors.lightGray)
local outputPath = fs.combine(outputFolderPath,outputName..".lua")

local canProceed = true
if fs.exists(outputPath) then
    term.setTextColor(colors.yellow)
    print("'"..outputName..".lua' already exists do you want to override it?")
    term.setTextColor(colors.white)
    local override = arrowRead("Y/N: ",colors.lightGray):lower()
    canProceed = override:sub(1,1) == "y"
end

local instructions = {}
local lineLambdas = {}
lineLambdas.general = {} --all lambdas that apply to all files

local layer = 0
local lookupFileTree = {}
local cacheFileTree = {}

lookupFileTree[filePath] = 0

local createTree

local function parseInstruction(line)
    if line:sub(1, 3) ~= "--#" then
        return nil
    end

    local output = {}

    for value in line:sub(4):gmatch("%S+") do
        if #output == 0 then table.insert(output, value:lower())
        else table.insert(output, value)
        end
    end

    return output
end

local function insertInLookupTree(reference,requiredLayer)
    if lookupFileTree[reference] then
        if lookupFileTree[reference] < requiredLayer then
            lookupFileTree[reference] = requiredLayer
        end
        return false --file was already scanned once by dependency resolver
    else
        lookupFileTree[reference] = requiredLayer
        return true --haven't found the file before (apply dependency resolver check)
    end
end

local function lookupToTopologicalTree()
    local output = {}
    for filePath, layer in pairs(lookupFileTree) do
        if not output[layer] then output[layer] = {} end
        table.insert(output[layer],filePath)
    end
    return output
end

local function insertInLineLambdas(path,func)
    if type(lineLambdas[path]) ~= "table" then lineLambdas[path] = {} end
    table.insert(lineLambdas[path],func)
end

local function applyLineLambdas(path,line,lineCount)
    local lambdas = lineLambdas[path] or {}
    for i=1,#lambdas do
        if type(lambdas[i]) == "function" then
            line = tostring(lambdas[i](line,lineCount) or "")
        end
    end
    for i=1,#lineLambdas.general do
        if type(lineLambdas.general[i]) == "function" then
            line = tostring(lineLambdas.general[i](line,lineCount) or "")
        end
    end
    return line
end

local function include(path,tokens)
    layer = layer + 1
    local fileMountPath = fs.getDir(path)

    local filePath = fs.combine(fileMountPath,tokens[2])
    if fs.exists(filePath) then
        if insertInLookupTree(filePath, layer) then createTree(filePath) end
    else
        error("could not find '"..filePath.."' included by '"..path.."'")
    end

    layer = layer - 1
end

local function define(path,tokens)
    local keyword = tokens[2]:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
    local pattern = table.concat(tokens," ",3) --can use concat cause all tokens are strings
    insertInLineLambdas(path,
    function (line)
        line = line:gsub("%f[%w_]"..keyword.."%f[^%w_]", pattern)
        return line
    end)
end

local function eval(expression)
    local result, err = load("return " .. expression)
    if result then return result() end
end

local ifIndices, ifLayer = {}, 0

local function validateIf(blockName,lineCount)
    if ifLayer < 1 or type(ifIndices[ifLayer]) ~= "table" then
        warn(blockName.." in line "..lineCount.." missing if block")
        return false
    elseif #ifIndices[ifLayer] == 0 then
        warn(blockName.." in line "..lineCount.." missing if block")
        return false
    end
    return true
end

local function startIf(path,tokens,lineCount) --can't call the method 'if' cause lua keyword
    ifLayer = ifLayer + 1
    if not ifIndices[ifLayer] then ifIndices[ifLayer] = {} end
    local statement = table.concat(tokens," ",2) --concat the tokens e.g VAR1 == VAR2
    statement = applyLineLambdas(path,statement,-1) --use unrealistic line count since this is not in a file

    ifIndices[ifLayer][1] = {eval(statement),lineCount}
end

local function elseIf(path,tokens,lineCount)
    if not validateIf("elseif",lineCount) then return end

    local statement = table.concat(tokens," ",2) --concat the tokens e.g VAR1 == VAR2
    statement = applyLineLambdas(path,statement,-1) --use unrealistic line count since this is not in a file

    local layer = ifIndices[ifLayer]
    layer[#layer][3] = lineCount-1
    table.insert(layer,{eval(statement),lineCount})
end

local function elsE(_,_,lineCount) --weird name but gets rid of lua key word name being used
    if not validateIf("else",lineCount) then return end

    local layer = ifIndices[ifLayer]
    layer[#layer][3] = lineCount-1
    table.insert(layer,{true,lineCount}) --since this block is always true if none other's are
end

local function endif(path,_,lineCount)
    if not validateIf("endif",lineCount) then return end

    local lambdas = {}
    local layer = ifIndices[ifLayer]
    layer[#layer][3] = lineCount-1

    local subLayer, startIndex
    local endIndex = 0
    local foundTrue = false
    for i=1,#layer do
        subLayer = layer[i]
        if (not subLayer[1]) or foundTrue then
            if not startIndex then startIndex = subLayer[2] end
            if endIndex < subLayer[3] then endIndex = subLayer[3] end
        elseif i > 1 then
            local lambdaStart = startIndex
            local lambdaEnd = endIndex
            table.insert(lambdas,
            function (line,lineCount)
                if lambdaStart <= lineCount and lambdaEnd >= lineCount then
                    return ""
                end
                return line
            end)
            startIndex = nil
            endIndex = 0
        end
        if not foundTrue then foundTrue = subLayer[1] end
    end
    if startIndex and endIndex > 0 then
        local lambdaStart = startIndex
        local lambdaEnd = endIndex
        table.insert(lambdas,
        function (line,lineCount)
            if lambdaStart <= lineCount and lambdaEnd >= lineCount then
                return ""
            end
            return line
        end)
    end

    for i=1,#lambdas do
        insertInLineLambdas(path,lambdas[i])
    end

    ifIndices[ifLayer] = {} --reset for next time using it (so no deprecated values are left behind)
    ifLayer = ifLayer - 1
end

--* DEFINE AVAILABLE INSTRUCTIONS HERE
instructions.include = include
instructions.define = define
instructions["if"] = startIf --have to do this cause if is a keyword
instructions["elseif"] = elseIf
instructions["else"] = elsE
instructions.endif = endif

createTree = function(filePath)

    local lineCount, execute = 0, true
    local layer
    for line in io.lines(filePath) do
        lineCount = lineCount + 1
        local data = parseInstruction(line)
        if data then
            if data[1] == "if" or data[1] == "elseif" or data[1] == "else" or data[1] == "endif" then
                instructions[data[1]](filePath, data, lineCount)

                execute = true
                for i=1,#ifIndices do
                    layer = ifIndices[i]
                    if layer and type(layer[#layer]) == "table" then
                        if not layer[#layer][1] then
                            execute = false
                            break
                        end
                    end
                end
            elseif type(instructions[data[1]]) == "function" then
                if execute then
                    instructions[data[1]](filePath, data, lineCount)
                end
            end
        end
    end
end

local inLongComment = false

local function removeComment(line)
    local inString = false
    local backslashes = 0
    local output = ""
    local i = 1

    while i <= #line do
        local char = line:sub(i, i)
        local nextChar = line:sub(i+1, i+1)

        if inLongComment then
            if char == "]" and nextChar == "]" then
                inLongComment = false
                i = i + 2
            else
                i = i + 1
            end

        elseif not inString and char == "-" and nextChar == "-" then
            if line:sub(i + 2, i + 3) == "[[" then
                inLongComment = true
                i = i + 4
            else
                return output
            end

        elseif char == '"' then
            local escaped = backslashes % 2 == 1
            backslashes = 0

            if not escaped then
                inString = not inString
            end

            output = output .. char
            i = i + 1

        elseif char == "\\" then
            backslashes = backslashes + 1
            output = output .. char
            i = i + 1

        else
            backslashes = 0
            output = output .. char
            i = i + 1
        end
    end

    return output
end

local totalLines, sizeBefore = 0, 0
local function compactFile(path,layer)
    local fileName = fs.getName(path)
    fileName = fileName:sub(1,#fileName-4) --chop of the .lua so we can put stuff like .lh

    local cachePath = fs.combine(cacheFolderPath,fileName..".lh");

    local file = io.open(cachePath,"w")
    if not file then error("was unable to get file handle for '"..cachePath.."'") end

    local lambdas = lineLambdas[path] or {}

    local linesSinceLastSave, lineCount = 0, 0
    sizeBefore = sizeBefore + fs.getSize(path)
    for line in io.lines(path) do
        lineCount = lineCount + 1

        line = line:gsub(TABS, "")
        line = removeComment(line)
        line = line:gsub("%s+$", "")
        line = line:gsub("%s*([%+%-%*/%%%^~=<>])%s*", "%1")
        --line = line:gsub("%s*%-%-.*$", "")

        for i=1,#lambdas do
            if type(lambdas[i]) == "function" then
                line = tostring(lambdas[i](line, lineCount) or "")
            end
        end
        for i=1,#lineLambdas.general do
            if type(lineLambdas.general[i]) == "function" then
                line = tostring(lineLambdas.general[i](line) or "") --! if you need lineCount you have to add it but now i don't see the use
            end
        end

        if #line > 0 then
            linesSinceLastSave = linesSinceLastSave+1
            totalLines = totalLines + 1
            print(totalLines..": "..line)
            file:write(line,"\n")
            if linesSinceLastSave >= LH_AUTO_SAVE_INTERVALS then
                file:flush()
                linesSinceLastSave = 0
            end
        end
    end
    file:close();

    if not cacheFileTree[layer] then cacheFileTree[layer] = {} end
    table.insert(cacheFileTree[layer],fileName..".lh") --make a "lua header" file

end

local startTime, startDateStr, endTime
--main code
if canProceed then
    startTime = os.epoch("utc")
    startDateStr = "\""..os.date("%c").."\""

    --empty the cache
    fs.delete(cacheFolderPath)
    fs.makeDir(cacheFolderPath)

    local env = getEnvTable(envFilePath)
    for k,v in pairs(env) do
        local keyword = k
        local replacement = parseEnvValue(v)
        table.insert(lineLambdas.general,
        function(line)
            line = line:gsub(keyword, replacement)
            return line
        end)
    end
    table.insert(lineLambdas.general,
    function(line)
        line = line:gsub("BUILD_TIME", startDateStr)
        return line
    end)
    table.insert(lineLambdas.general,
    function(line)
        line = line:gsub("BUILD_EPOCH", tostring(startTime))
        return line
    end)

    createTree(filePath)

    local fileTree = lookupToTopologicalTree()

    for i=#fileTree,0,-1 do
        local filesToCompact = fileTree[i]
        for j=1,#filesToCompact do
            local path = filesToCompact[j]
            compactFile(path,i)
        end
    end

    local outputFile = io.open(fs.combine(cacheFolderPath,cacheFileTree[0][1]),"r") --open the original file as a base
    if not outputFile then error("was unable to open file reading handle for '"..outputPath.."'") end
    local outputContent = outputFile:read("a")
    outputFile:close()
    outputFile = io.open(outputPath,"w")
    if not outputFile then error("was unable to open file writing handle for '"..outputPath.."'") end

    local sizeBetween = 0
    local path, file
    for i=1,#cacheFileTree do

        local filesToResolve = cacheFileTree[i]
        for j=1,#filesToResolve do
            path = fs.combine(cacheFolderPath,filesToResolve[j])
            sizeBetween = sizeBetween + fs.getSize(path)

            file = io.open(path,"r")

            if file then --tries to stick it together but if the handle doesn't work just skips it (and hopes it works)
                outputContent = "--== "..filesToResolve[j].."-begin ==--\n"..file:read("a").."--== "..filesToResolve[j].."-end ==--\n"..outputContent
                file:close()
            else
                warn("couldn't link file '"..path.."' cause of file handle issues")
            end
        end
    end
    outputFile:write(outputContent)

    outputFile:close()

    local completionLog = io.open(fs.combine(logsFolderPath,outputName..".log"),"w")

    local function printToLog(text)
        if completionLog then
            if text then
                completionLog:write("\n",tostring(text))
            else
                completionLog:write("\n")
            end
        end
    end

    endTime = os.epoch("utc")
    local takenTime = endTime-startTime

    --file info
    term.setTextColor(colors.green)
    print()
    print("SUCCESS!")

    if completionLog then completionLog:write("<==FILE CONTENT INFO==>") end
    printToLog("Characters: "..#outputContent)
    printToLog("lines: "..totalLines)
    outputContent = nil --gc can now get rid of it (frees up a lot of ram)

    printToLog()
    printToLog("<=====ENVIRONMENT=====>")
    printToLog("loaded from: "..envFilePath)
    printToLog(getSimpleJSONStyleMap(env))

    --dependency lookup tree (just logged)
    printToLog()
    printToLog("<==DEPENDENCY LOOKUP==>")
    printToLog("{")
    for k,v in pairs(lookupFileTree) do --starts at 1 cause base file isn't inserted here
        printToLog("    "..k.." = layer "..v)
    end
    printToLog("}")

    --dependency topological tree (just logged)
    printToLog()
    printToLog("<===DEPENDENCY TREE===>")
    printToLog("{")
    local tableStr
    for i=0,#fileTree do --starts at 1 cause base file isn't inserted here
        tableStr = textutils.serialize(fileTree[i],{compact=true})
        printToLog("    layer "..i..":"..tableStr)
    end
    printToLog("}")

    --dependency tree (logged and printed)
    printToLog()
    printToLog("<=====HEADER TREE=====>")
    printToLog("{")
    local tableStr
    for i=0,#cacheFileTree do
        tableStr = textutils.serialize(cacheFileTree[i],{compact=true})
        printToLog("    layer "..i..":"..tableStr)
    end
    printToLog("}")

    --file metrics
    local sizeNow = fs.getSize(outputPath)
    local reductionPercent = math.floor((1-(sizeNow/sizeBefore))*10000)
    reductionPercent = reductionPercent/100 --to get back the last two decimal digits

    print()
    printToLog()
    term.setTextColor(colors.purple)
    print("<==FILE SIZE METRICS==>")
    printToLog("<==FILE SIZE METRICS==>")
    term.setTextColor(colors.red)
    print("file size before: "..sizeBefore.." bytes")
    printToLog("file size before: "..sizeBefore.." bytes")
    term.setTextColor(colors.yellow)
    print("file size between: "..sizeBetween.." bytes")
    printToLog("file size between: "..sizeBetween.." bytes")
    term.setTextColor(colors.green)
    print("file size after: "..sizeNow.." bytes")
    printToLog("file size after: "..sizeNow.." bytes")
    term.setTextColor(colors.blue)
    print("reduced by: "..reductionPercent.."%")
    printToLog("reduced by: "..reductionPercent.."%")

    printToLog()
    printToLog("<======TIME INFO======>")
    printToLog("finished in: "..takenTime.." ms")
    printToLog("start-epoch: "..startTime)
    printToLog("end  -epoch: "..endTime)

    term.setTextColor(colors.white)
    print("finished in: "..takenTime.." ms")

    if completionLog then
        completionLog:close()
        term.setTextColor(colors.gray)
        print("generated '"..outputName..".log' in '"..logsFolderPath.."'")
    end
    term.setTextColor(colors.white)
end

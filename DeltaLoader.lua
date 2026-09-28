-- Emotes Dark | Delta visual loader
local SOURCE_URL = "https://raw.githubusercontent.com/mateyspess-afk/emotes-dark/main/Emotes.lua?v=537d0f2"

local function report(message)
    print("[Emotes Dark] " .. tostring(message))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Emotes Dark",
            Text = tostring(message),
            Duration = 8,
        })
    end)
end

report("Loader iniciado")

local okDownload, source = pcall(function()
    return game:HttpGet(SOURCE_URL)
end)
if not okDownload or type(source) ~= "string" or source == "" then
    report("Falha ao baixar o script: " .. tostring(source))
    return
end
report("Script baixado (" .. tostring(#source) .. " bytes)")

local loader = loadstring or load
if type(loader) ~= "function" then
    report("Delta não oferece loadstring/load")
    return
end

local chunk, compileError = loader(source)
if not chunk then
    report("Erro de compilação: " .. tostring(compileError))
    return
end
report("Compilação OK; iniciando")

local okRun, runtimeError = pcall(chunk)
if not okRun then
    report("Erro em execução: " .. tostring(runtimeError))
else
    report("Script iniciado")
end

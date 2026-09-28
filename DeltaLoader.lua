-- Emotes Dark | Delta loader
-- Execute este arquivo no Delta para evitar o limite de tamanho do editor.
local SOURCE_URL = "https://raw.githubusercontent.com/mateyspess-afk/emotes-dark/main/Emotes.lua?v=537d0f2"

local okDownload, source = pcall(function()
    return game:HttpGet(SOURCE_URL)
end)

if not okDownload or type(source) ~= "string" or source == "" then
    warn("[Emotes Dark] Falha ao baixar Emotes.lua: " .. tostring(source))
    return
end

local loader = loadstring or load
if type(loader) ~= "function" then
    warn("[Emotes Dark] Este Delta não disponibiliza loadstring/load.")
    return
end

local chunk, compileError = loader(source)
if not chunk then
    warn("[Emotes Dark] Erro de compilação: " .. tostring(compileError))
    return
end

local okRun, runtimeError = pcall(chunk)
if not okRun then
    warn("[Emotes Dark] Erro em execução: " .. tostring(runtimeError))
end

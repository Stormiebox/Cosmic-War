package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")

-- namespace CW_CodexInjector
CW_CodexInjector = CW_CodexInjector or {}

function CW_CodexInjector.initialize()
    if onClient() then
        Player():registerCallback("onCosmicCodexGatherData", "onCosmicCodexGatherData")
    end
end

function CW_CodexInjector.onCosmicCodexGatherData()
    include("player/codex/infoCw")
    infoCw_injectToCodex()
end

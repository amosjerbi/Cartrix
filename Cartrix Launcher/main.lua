-- ROCKNIX 3D Carousel
-- Dependency-free, flat-shaded OBJ viewer tuned for small ARM devices.

local TAU = math.pi * 2
-- The replacement S3D-derived meshes are already compact and GPU-rendered.
-- Keep nearly all triangles; decimating a disc/cartridge creates visible
-- spokes and holes in otherwise continuous surfaces.
local MAX_TRIANGLES = 30000
local HERO_ANGLE = -0.46
local SPIN_SPEED = 0
local SLIDE_TIME = 0.36

local models = {
    { name = "Game Boy", short = "GB", file = "models/gb.obj", labelPlatform = "gb", labelVariants = {"labels/gb/scan-01.png", "labels/gb/scan-02.png"}, labelFlipY = true, angleOffsetY = 0, color = {0.7608, 0.6980, 0.5020} }, -- #C2B280
    { name = "Game Boy Color", short = "GBC", file = "models/gbc.obj", labelPlatform = "gbc", labelVariants = {"labels/gbc/scan-01.png"}, labelFlipY = true, color = {0.62, 0.64, 0.68} },
    { name = "NES Cartridge", short = "NES", file = "models/nes.obj", labelPlatform = "nes", labelAxisU = 2, labelAxisV = 3, labelScale = 0.82, color = {0.50, 0.48, 0.70} },
    { name = "SNES Cartridge", short = "SNES", file = "models/snes.obj", labelPlatform = "snes", labelVariants = {"labels/snes/scan-01.png"}, labelFlipY = true, color = {0.50, 0.48, 0.70} },
    { name = "Nintendo 64", short = "N64", file = "models/N64.obj", labelPlatform = "n64", labelVariants = {"labels/n64/01.png"}, labelFlipY = true, color = {0.7608, 0.6980, 0.5020} }, -- #C2B280
    { name = "Game Boy Advance", short = "GBA", file = "models/gba.obj", labelPlatform = "gba", labelVariants = {"labels/gba/01.png", "labels/gba/02.png", "labels/gba/03.png"}, labelFlipY = false, labelMirrorX = true, labelCropY = 1.0, labelScale = 1.50, labelRotate180 = false, angleOffsetY = 0, rotateZ180 = false, color = {0.62, 0.64, 0.68} },
    { name = "Game Gear", short = "GG", file = "models/gamegear.obj", labelPlatform = "gamegear", labelVariants = {"labels/gamegear/scan-01.png"}, labelFlipY = true, labelMirrorX = false, labelRotate180 = false, rotateXZ = false, rotateZ180 = false, angleOffsetY = 0, noDecimate = true, color = {0.20, 0.22, 0.25} }, -- same as Genesis
    { name = "Genesis", short = "GEN", file = "models/genesis.obj", labelPlatform = "genesis", labelVariants = {"labels/genesis/scan-01.png"}, labelMirrorX = true, labelRotate180 = true, color = {0.20, 0.22, 0.25} },
    { name = "Nintendo DS", short = "NDS", file = "models/nds.obj", labelPlatform = "nds", labelVariants = {"labels/nds/scan-01.png"}, labelFlipY = true, color = {0.62, 0.64, 0.68} },
    { name = "Switch Cartridge", short = "SWITCH", file = "models/switch.obj", labelPlatform = "switch", color = {0.78, 0.26, 0.30} },
    { name = "PlayStation Vita", short = "VITA", file = "models/vita.obj", labelPlatform = "vita", color = {0.32, 0.36, 0.58} },
    { name = "UMD Disc", short = "UMD", file = "models/umd.obj", labelPlatform = "psp", angleOffsetY = math.pi, rotateZ180 = false, color = {0.55, 0.58, 0.64} },
    { name = "Compact Disc", short = "CD", file = "models/disc.obj", labelPlatform = "psx", color = {0.42, 0.70, 0.68} },
    { name = "PAL Cartridge", short = "PAL", file = "models/snes-pal.obj", labelPlatform = "snes", labelFlipY = true, color = {0.66, 0.48, 0.25} },
    { name = "3DS Cartridge", short = "3DS", file = "models/3ds.obj", labelPlatform = "3ds", color = {0.72, 0.28, 0.48} },
}

local selected, carouselPosition, targetPosition, pulse, analogTurn, modelZoom, targetZoom, zoomed, solidModels, font, smallFont, platformFont = 1, 0, 0, 0, 0, 0, 1, false, true, nil, nil, nil
local rotations = {}
local visibleModels = {}
local platformGroups = {}
local selectedPlatform = 1
local allCartridges = false
local selectedAngleBlend = 1
local status = "LOADING LOCAL MESHES"
local meshShader
local scanBusy = false
local zoomKeyHeld = false
local zoomPadHeld = false
local zoomToggleCooldown = 0

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function wrap(n, max) return ((n - 1) % max) + 1 end
local function lerp(a, b, t) return a + (b - a) * t end

local function setAnalogTurn(value)
    local deadzone = 0.14
    if math.abs(value) < deadzone then
        analogTurn = 0
    else
        local sign = value < 0 and -1 or 1
        analogTurn = sign * ((math.abs(value) - deadzone) / (1 - deadzone))
    end
end

local function parseIndex(token, count)
    local first = token:match("^[^/]+")
    local i = tonumber(first)
    if not i then return 1 end
    return i < 0 and count + i + 1 or i
end

local function loadObj(item)
    local raw = love.filesystem.read(item.file)
    if not raw then return nil, "missing " .. item.file end
    local vertices, texcoords, normals, faces = {}, {}, {}, {}
    local currentColor = item.color
    local currentLabel = 0
    local labelMinX, labelMinY = math.huge, math.huge
    local labelMaxX, labelMaxY = -math.huge, -math.huge
    local labelAxisU, labelAxisV = item.labelAxisU or 1, item.labelAxisV or 2
    local minx, miny, minz = math.huge, math.huge, math.huge
    local maxx, maxy, maxz = -math.huge, -math.huge, -math.huge
    for line in raw:gmatch("[^\r\n]+") do
        local x, y, z = line:match("^v%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)")
        if x then
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            vertices[#vertices + 1] = {x, y, z}
            if currentLabel == 1 then
                local values = {x, y, z}
                labelMinX, labelMinY = math.min(labelMinX, values[labelAxisU]), math.min(labelMinY, values[labelAxisV])
                labelMaxX, labelMaxY = math.max(labelMaxX, values[labelAxisU]), math.max(labelMaxY, values[labelAxisV])
            end
            minx, miny, minz = math.min(minx, x), math.min(miny, y), math.min(minz, z)
            maxx, maxy, maxz = math.max(maxx, x), math.max(maxy, y), math.max(maxz, z)
        else
            local u, v = line:match("^vt%s+([^%s]+)%s+([^%s]+)")
            if u then texcoords[#texcoords + 1] = {tonumber(u), tonumber(v)} end
            local nx, ny, nz = line:match("^vn%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)")
            if nx then
                normals[#normals + 1] = {tonumber(nx), tonumber(ny), tonumber(nz)}
            end
            local cr, cg, cb = line:match("^#%s*material_color%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)")
            if cr then currentColor = {tonumber(cr), tonumber(cg), tonumber(cb)} end
            local objectName = line:match("^o%s+(.+)")
            if objectName then
                currentLabel = objectName:lower() == "sticker" and 1 or 0
            end
            local label = line:match("^#%s*s3d_label%s+(%d+)")
            if label then currentLabel = tonumber(label) end
            local rest = line:match("^f%s+(.+)")
            if rest then
                local points = {}
                for token in rest:gmatch("[^%s]+") do
                    local vi, ti, ni = token:match("^(%-?%d+)/(%-?%d*)/(%-?%d+)$")
                    vi = vi or token:match("^(%-?%d+)")
                    vi, ti, ni = tonumber(vi), tonumber(ti), tonumber(ni) or tonumber(vi)
                    if vi < 0 then vi = #vertices + vi + 1 end
                    if ti and ti < 0 then ti = #texcoords + ti + 1 end
                    if ni < 0 then ni = #normals + ni + 1 end
                    points[#points + 1] = {vi, ti, ni}
                end
                for i = 2, #points - 1 do faces[#faces + 1] = {points[1], points[i], points[i + 1], currentLabel} end
            end
        end
    end
    local cx, cy, cz = (minx + maxx) / 2, (miny + maxy) / 2, (minz + maxz) / 2
    local scale = 2.0 / math.max(maxx - minx, maxy - miny, maxz - minz, 0.001)
    local stride = item.noDecimate and 1 or math.max(1, math.ceil(#faces / (item.maxTriangles or MAX_TRIANGLES)))
    local meshVertices, labelVertices = {}, {}
    for i = 1, #faces, stride do
        local f = faces[i]
        for corner = 1, 3 do
            local point = vertices[f[corner][1]]
            local uv = texcoords[f[corner][2]] or {0, 0}
            if f[4] == 1 and not texcoords[f[corner][2]] and labelMaxX > labelMinX and labelMaxY > labelMinY then
                uv = {
                    (point[labelAxisU] - labelMinX) / (labelMaxX - labelMinX),
                    (point[labelAxisV] - labelMinY) / (labelMaxY - labelMinY),
                }
            end
            local normal = normals[f[corner][3]] or {0, 1, 0}
            local vertex = {
                (point[1] - cx) * scale, (point[2] - cy) * scale, (point[3] - cz) * scale,
                normal[1], normal[2], normal[3],
                uv[1], uv[2],
                1, 1, 1, f[4],
            }
            -- Keep label faces in the opaque shell as a gray backing panel.
            -- The separate label pass adds artwork only to the front-facing
            -- side, so rotating the cartridge cannot reveal a label through
            -- an empty back.
            meshVertices[#meshVertices + 1] = vertex
            if f[4] == 1 then labelVertices[#labelVertices + 1] = vertex end
        end
    end
    local format = {
        {"VertexPosition", "float", 3},
        {"VertexNormal", "float", 3},
        {"VertexTexCoord", "float", 2},
        {"VertexColor", "float", 4},
    }
    return {
        mesh = love.graphics.newMesh(format, meshVertices, "triangles", "static"),
        labelMesh = #labelVertices > 0 and love.graphics.newMesh(format, labelVertices, "triangles", "static") or nil,
        count = #faces,
    }
end

local function drawModel(item, slot, topMost)
    if not item.mesh or not meshShader then return end
    local active = item == visibleModels[selected]
    local angleBlend = active and selectedAngleBlend or 0
    local angle = HERO_ANGLE + ((rotations[selected] or 0) - HERO_ANGLE) * angleBlend + (item.angleOffsetY or 0)
    -- Add a gap on each side of the selected cartridge only. The constant
    -- offset keeps spacing between the unselected cartridges unchanged.
    local selectedGap = slot > 0 and 0.65 or (slot < 0 and -0.65 or 0)
    local offset = slot * 2.05 + selectedGap
    local selectedScale = item.labelPlatform == "snes" and 3.20
        or item.labelPlatform == "genesis" and 3.20
        or item.labelPlatform == "gamegear" and 2.20
        or 1.75
    local baseScale = 1.0 - math.min(math.abs(slot), 3) * 0.12
    local scale = active and (selectedScale * modelZoom) or baseScale
    local alpha = 1
    meshShader:send("angle", angle)
    meshShader:send("labelFacing", math.cos(angle) > 0 and 1 or 0)
    meshShader:send("offset", {offset, 0.20})
    meshShader:send("modelScale", scale)
    meshShader:send("labelPass", 0)
    -- Original neutral cartridge gray: #9EA3AD
    meshShader:send("baseColor", item.color or {0.62, 0.64, 0.68})
    meshShader:send("labelFlipY", item.labelFlipY and 1 or 0)
    meshShader:send("labelMirrorX", item.labelMirrorX and 1 or 0)
    meshShader:send("labelCropY", item.labelCropY or 1)
    meshShader:send("labelScale", item.labelScale or 1)
    meshShader:send("labelRotate", item.labelRotate and 1 or 0)
    meshShader:send("labelRotateLeft", item.labelRotateLeft and 1 or 0)
    meshShader:send("labelRotate180", item.labelRotate180 and 1 or 0)
    meshShader:send("rotateXY", item.rotateXY and 1 or 0)
    meshShader:send("rotateXZ", item.rotateXZ and 1 or 0)
    meshShader:send("rotateZ180", item.rotateZ180 and 1 or 0)
    meshShader:send("topMost", topMost and 1 or 0)
    if topMost then love.graphics.setDepthMode("less", true) end
    love.graphics.draw(item.mesh.mesh)
    if item.mesh.labelMesh and item.labelTextures then
        item.mesh.labelMesh:setTexture(item.labelTextures[item.coverIndex or 1])
        meshShader:send("labelPass", 1)
        -- The label mesh shares depth with the opaque sticker surface. Allow
        -- equal-depth fragments so the artwork pass can replace the backing
        -- color without writing a second depth layer.
        if topMost then
            love.graphics.setDepthMode("always", false)
        else
            love.graphics.setDepthMode("lequal", false)
        end
        love.graphics.setMeshCullMode("none")
        love.graphics.draw(item.mesh.labelMesh)
        love.graphics.setDepthMode("less", true)
        love.graphics.setMeshCullMode("back")
        meshShader:send("labelPass", 0)
    end
end

local function select(delta)
    if #visibleModels == 0 then return end
    selected = wrap(selected + delta, #visibleModels)
    targetPosition = targetPosition + delta
    selectedAngleBlend = 0
end

local function toggleZoom()
    zoomed = not zoomed
    targetZoom = zoomed and 2.80 or 1
end

local function toggleSolidModels()
    solidModels = not solidModels
end

local function cycleLabel()
    local item = visibleModels[selected]
    if item.labelVariants then
        item.labelVariant = (item.labelVariant or 1) % #item.labelVariants + 1
    end
end

local function loadLabelTextures(item)
    if not item.labelVariants then return end
    item.labelTextures = {}
    item.labelVariant = 1
    for variant, path in ipairs(item.labelVariants) do
        local ok, image = pcall(love.graphics.newImage, path, {linear = true})
        if ok and image then
            image:setFilter("linear", "linear")
            image:setWrap("clamp", "clamp")
            item.labelTextures[#item.labelTextures + 1] = image
        end
    end
    if #item.labelTextures == 0 then item.labelTextures = nil end
end

local function showPlatform(index)
    allCartridges = false
    if #platformGroups == 0 then
        visibleModels = {}
        selected, carouselPosition, targetPosition = 1, 0, 0
        return
    end
    selectedPlatform = wrap(index, #platformGroups)
    visibleModels = platformGroups[selectedPlatform].games
    selected = wrap(selected, math.max(#visibleModels, 1))
    selectedAngleBlend = 0
    carouselPosition = selected - 1
    targetPosition = carouselPosition
end

local function rebuildVisibleModels()
    platformGroups = {}
    local groupsByPlatform = {}
    for _, item in ipairs(models) do
        if not groupsByPlatform[item.labelPlatform] then
            local group = {name = item.name, short = item.short, platform = item.labelPlatform, logo = item.logo, games = {}}
            groupsByPlatform[item.labelPlatform] = group
            platformGroups[#platformGroups + 1] = group
            local indexedRoms = {}
            local romIndex = love.filesystem.read("labels/" .. item.labelPlatform .. "/rom-index.txt")
            if romIndex then
                for romPath in romIndex:gmatch("[^\r\n]+") do
                    indexedRoms[#indexedRoms + 1] = romPath
                end
            end
            group.hasRoms = #indexedRoms > 0
            local representedRoms = {}
            local variants = item.hasScrapedData and (item.labelVariants or {}) or {}
            for gameIndex, rawImagePath in ipairs(variants) do
                local imagePath = rawImagePath or nil
                local game = {}
                for key, value in pairs(item) do game[key] = value end
                local romPath = imagePath and item.scrapeRomPaths and item.scrapeRomPaths[imagePath]
                local title = romPath and romPath:match("([^/]+)$") or (imagePath and imagePath:match("([^/]+)$")) or item.name
                title = title:gsub("%.[^%.]+$", "")
                game.platformName = item.name
                game.name = title
                game.gameIndex = gameIndex
                game.labelVariants = imagePath and {imagePath} or nil
                game.labelTextures = imagePath and item.labelTextures and {item.labelTextures[gameIndex]} or nil
                game.coverIndex = 1
                game.scrapeRomPaths = {}
                if imagePath and romPath then game.scrapeRomPaths[imagePath] = romPath end
                game.romPath = romPath
                if romPath then representedRoms[romPath] = true end
                game.mesh = item.mesh
                group.games[#group.games + 1] = game
            end
            for _, romPath in ipairs(indexedRoms) do
                if not representedRoms[romPath] then
                    local game = {}
                    for key, value in pairs(item) do game[key] = value end
                    game.name = (romPath:match("([^/]+)$") or romPath):gsub("%.[^%.]+$", "")
                    game.platformName = item.name
                    game.labelVariants = nil
                    game.labelTextures = nil
                    game.scrapeRomPaths = nil
                    game.romPath = romPath
                    game.gameIndex = #group.games + 1
                    game.mesh = item.mesh
                    group.games[#group.games + 1] = game
                end
            end
            if #group.games == 0 then
                local game = {}
                for key, value in pairs(item) do game[key] = value end
                game.name = item.name
                game.platformName = item.name
                game.labelVariants = nil
                game.labelTextures = nil
                game.scrapeRomPaths = nil
                game.mesh = item.mesh
                game.gameIndex = 1
                group.games[1] = game
            end
        end
    end
    local groupsWithRoms = {}
    for _, group in ipairs(platformGroups) do
        if group.hasRoms then groupsWithRoms[#groupsWithRoms + 1] = group end
    end
    platformGroups = groupsWithRoms
    if #platformGroups > 0 then
        showPlatform(selectedPlatform)
    else
        visibleModels = {}
        selected, carouselPosition, targetPosition = 1, 0, 0
    end
end

local function selectPlatform(delta)
    if #platformGroups == 0 then return end
    showPlatform(selectedPlatform + delta)
end

local function showAllCartridges()
    allCartridges = true
    local allGames = {}
    for _, group in ipairs(platformGroups) do
        for _, game in ipairs(group.games) do
            allGames[#allGames + 1] = game
        end
    end
    visibleModels = allGames
    selected = wrap(selected, math.max(#visibleModels, 1))
    carouselPosition = selected - 1
    targetPosition = carouselPosition
end

local function toggleAllCartridges()
    if allCartridges then
        showPlatform(selectedPlatform)
    else
        showAllCartridges()
    end
end

local function refreshScannedLabels()
    for _, item in ipairs(models) do
        if item.labelPlatform then
            local scanned = {}
            local dir = "labels/" .. item.labelPlatform
            for _, filename in ipairs(love.filesystem.getDirectoryItems(dir)) do
                if filename:match("^scan%-%d+%.png$") then
                    scanned[#scanned + 1] = dir .. "/" .. filename
                end
            end
            table.sort(scanned)
            item.hasScrapedData = #scanned > 0
            item.labelVariants = #scanned > 0 and scanned or item.baseLabelVariants
            item.scrapeRomPaths = {}
            local logoPath = "logos/" .. item.labelPlatform .. ".png"
            local logoOk, logo = pcall(love.graphics.newImage, logoPath, {linear = true})
            item.logo = logoOk and logo or nil
            if item.logo then item.logo:setFilter("linear", "linear") end
            local manifest = love.filesystem.read(dir .. "/scan-index.txt")
            if manifest then
                for line in manifest:gmatch("[^\r\n]+") do
                    local imageName, romPath = line:match("^([^|]+)|(.+)$")
                    if imageName and romPath and imageName ~= "" and romPath ~= "" then
                        item.scrapeRomPaths[dir .. "/" .. imageName] = romPath
                    end
                end
            end
            loadLabelTextures(item)
            item.coverIndex = 1
        end
    end
    rebuildVisibleModels()
end

local function currentCover(item)
    if not item or not item.labelTextures or #item.labelTextures == 0 then return nil end
    item.coverIndex = wrap(item.coverIndex or 1, #item.labelTextures)
    return item.labelTextures[item.coverIndex]
end

local function selectCover(delta)
    local item = visibleModels[selected]
    if item and item.labelTextures and #item.labelTextures > 0 then
        item.coverIndex = wrap((item.coverIndex or 1) + delta, #item.labelTextures)
    end
end

local function launchSelectedRom()
    local item = visibleModels[selected]
    if not item then return end
    local romPath = item.romPath
    if not romPath and item.labelVariants and item.scrapeRomPaths then
        local imagePath = item.labelVariants[item.coverIndex or 1]
        romPath = item.scrapeRomPaths[imagePath]
    end
    if not romPath or romPath == "" then
        status = "ROM PATH NOT FOUND"
        return
    end
    local cores = {
        gb = "gambatte", gbc = "gambatte", nes = "nestopia", snes = "snes9x",
        n64 = "mupen64plus_next", gba = "mgba", nds = "melonds",
        gamegear = "genesis_plus_gx", genesis = "genesis_plus_gx",
        psp = "ppsspp", psx = "pcsx_rearmed32", ["3ds"] = "azahar",
    }
    local command = string.format("/usr/bin/runemu.sh %q -P%s --core=%s --emulator=retroarch >/tmp/rocknix-carousel-launch.log 2>&1 & nohup sh '/roms/ports/Cartrix Launcher/fullscreen-retroarch.sh' >/tmp/rocknix-retroarch-fullscreen.log 2>&1 </dev/null &", romPath, item.labelPlatform, cores[item.labelPlatform] or "")
    status = "LAUNCHING " .. item.name
    os.execute(command)
    love.event.quit()
end

local function selectedRomName()
    local item = visibleModels[selected]
    if not item then return "NO ROM SELECTED" end
    local romPath = item.romPath
    if not romPath and item.labelVariants and item.scrapeRomPaths then
        romPath = item.scrapeRomPaths[item.labelVariants[item.coverIndex or 1]]
    end
    if not romPath or romPath == "" then return "NO ROM SELECTED" end
    local name = romPath:match("([^/]+)$") or romPath
    return name:gsub("%.[^%.]+$", "")
end

local function scanScrapedData()
    if scanBusy then return end
    scanBusy = true
    status = "SCANNING SCRAPED PLATFORM DATA"
    os.execute("sh scan-scrapes.sh >/tmp/rocknix-carousel-scan.log 2>&1")
    refreshScannedLabels()
    status = "SCAN COMPLETE · SCRAPED LABELS LOADED"
    scanBusy = false
end

function love.load()
    love.keyboard.setKeyRepeat(false)
    love.graphics.setBackgroundColor(0.035, 0.047, 0.065)
    font = love.graphics.newFont(22)
    smallFont = love.graphics.newFont(14)
    platformFont = love.graphics.newFont(22)
    meshShader = love.graphics.newShader([[
        attribute vec3 VertexNormal;
        varying vec3 vNormal;
        varying vec2 vUV;
        varying float vLabel;
        varying vec3 vViewPos;
        extern number angle;
        extern vec2 offset;
        extern number modelScale;
        extern number aspect;
        extern number rotateXY;
        extern number rotateXZ;
        extern number rotateZ180;
        extern number topMost;

        vec4 position(mat4 transform_projection, vec4 vertex_position) {
            float cy = cos(angle), sy = sin(angle);
            vec3 p = vertex_position.xyz * modelScale;
            vec3 n = VertexNormal;
            if (rotateXY > 0.5) {
                p = vec3(-p.y, p.x, p.z);
                n = vec3(-n.y, n.x, n.z);
            }
            if (rotateXZ > 0.5) {
                p = vec3(p.x, p.z, -p.y);
                n = vec3(n.x, n.z, -n.y);
            }
            if (rotateZ180 > 0.5) {
                p = vec3(-p.x, -p.y, p.z);
                n = vec3(-n.x, -n.y, n.z);
            }
            p = vec3(cy * p.x + sy * p.z, p.y, -sy * p.x + cy * p.z);
            n = vec3(cy * n.x + sy * n.z, n.y, -sy * n.x + cy * n.z);
            if (topMost > 0.5) p.z -= 4.0;
            p.x += offset.x;
            p.y += offset.y;
            p.z -= 4.6;
            vNormal = normalize(n);
            vUV = VertexTexCoord.xy;
            vLabel = VertexColor.a;
            vViewPos = -p;
            float zclip = -1.002 * p.z - 0.2002;
            return vec4(p.x * 1.55 / aspect, p.y * 1.55, zclip, -p.z);
        }
    ]], [[
        varying vec3 vNormal;
        varying vec2 vUV;
        varying float vLabel;
        varying vec3 vViewPos;
        extern vec3 baseColor;
        extern number labelFlipY;
        extern number labelMirrorX;
        extern number labelCropY;
        extern number labelScale;
        extern number labelRotate;
        extern number labelRotateLeft;
        extern number labelRotate180;
        extern number labelPass;
        extern number labelFacing;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
            vec3 N = normalize(vNormal);
            vec3 V = normalize(vViewPos);
            vec3 L = normalize(vec3(-0.3, 0.8, 0.6));
            vec3 H = normalize(L + V);
            float ambient = 0.25;
            float diffuse = max(dot(N, L), 0.0);
            float specular = pow(max(dot(N, H), 0.0), 32.0) * 0.45;
            vec2 labelUV = vUV;
            if (labelFlipY > 0.5) labelUV.y = 1.0 - labelUV.y;
            if (labelMirrorX > 0.5) labelUV.x = 1.0 - labelUV.x;
            if (labelRotate > 0.5) labelUV = vec2(labelUV.y, 1.0 - labelUV.x);
            if (labelRotateLeft > 0.5) labelUV = vec2(1.0 - labelUV.y, labelUV.x);
            if (labelRotate180 > 0.5) labelUV = 1.0 - labelUV;
            // Apply the aspect crop after rotation so GBA artwork is cropped
            // on the label's actual vertical axis rather than the source axis.
            labelUV.y = (labelUV.y - 0.5) * labelCropY + 0.5;
            vec3 material = baseColor;
            // Only apply artwork when the label face points toward the camera.
            // From the rear, show the cartridge body instead of the label back.
            if (labelPass > 0.5 && vLabel > 0.5 && labelFacing > 0.5) {
                vec2 fittedUV = (labelUV - vec2(0.5)) / max(labelScale, 0.001) + vec2(0.5);
                if (fittedUV.x >= 0.0 && fittedUV.x <= 1.0 && fittedUV.y >= 0.0 && fittedUV.y <= 1.0) {
                    material = Texel(tex, fittedUV).rgb;
                    return vec4(material, 1.0);
                }
            }
            return vec4(material * (ambient + diffuse * 0.75) + vec3(specular), 1.0);
        }
    ]])
    for _, item in ipairs(models) do
        item.mesh = loadObj(item)
        if item.labelVariants then
            item.baseLabelVariants = item.labelVariants
            loadLabelTextures(item)
        end
    end
    for index = 1, #models do rotations[index] = 0 end
    scanScrapedData()
    if #visibleModels == 0 then
        status = "NO SCRAPED PLATFORMS · PRESS Y TO SCAN"
    end
end

function love.update(dt)
    pulse = pulse + dt
    if zoomToggleCooldown > 0 then
        zoomToggleCooldown = math.max(0, zoomToggleCooldown - dt)
    end
    carouselPosition = lerp(carouselPosition, targetPosition, 1 - math.exp(-dt / SLIDE_TIME))
    selectedAngleBlend = lerp(selectedAngleBlend, 1, 1 - math.exp(-dt / 0.24))
    modelZoom = lerp(modelZoom, targetZoom, 1 - math.exp(-dt / 0.18))
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        local value = joystick:getGamepadAxis("leftx")
        if value == nil then value = joystick:getAxis(1) end
        if value ~= nil then
            setAnalogTurn(value)
            break
        end
    end
    -- Every model owns its own turntable angle. Selecting another model
    -- switches control to that model without losing the previous angle.
    if #visibleModels > 0 then
        rotations[selected] = rotations[selected] or 0
        rotations[selected] = (rotations[selected] + dt * (SPIN_SPEED + analogTurn * 2.8)) % TAU
    end
end

function love.keypressed(key)
    if key == "left" or key == "a" then select(-1)
    elseif key == "right" or key == "d" then select(1)
    elseif key == "r" then selectPlatform(1)
    elseif key == "l" then selectPlatform(-1)
    elseif key == "s" then scanScrapedData()
    elseif key == "y" then toggleAllCartridges()
    elseif key == "x" and not zoomKeyHeld and not zoomPadHeld and zoomToggleCooldown <= 0 then
        zoomKeyHeld = true
        zoomToggleCooldown = 0.75
        toggleZoom()
    elseif key == "return" or key == "space" then launchSelectedRom()
    elseif key == "escape" or key == "backspace" then love.event.quit() end
end

function love.gamepadpressed(_, button)
    if button == "dpleft" then select(-1)
    elseif button == "dpright" then select(1)
    elseif button == "leftshoulder" then selectPlatform(-1)
    elseif button == "rightshoulder" then selectPlatform(1)
    elseif button == "y" then toggleAllCartridges()
    elseif button == "b" then launchSelectedRom()
    elseif button == "a" then
        if allCartridges then showPlatform(selectedPlatform) else love.event.quit() end
    elseif button == "x" and not zoomPadHeld and not zoomKeyHeld and zoomToggleCooldown <= 0 then
        zoomPadHeld = true
        zoomToggleCooldown = 0.75
        toggleZoom()
    elseif button == "back" or button == "start" then love.event.quit() end
end

function love.keyreleased(key)
    if key == "x" then zoomKeyHeld = false end
end

function love.gamepadreleased(_, button)
    if button == "x" then zoomPadHeld = false end
end

function love.joystickaxis(_, axis, value)
    -- Analog rotation is intentionally on the horizontal stick axis so the
    -- vertical axis remains available for future zoom/elevation controls.
    if axis == "leftx" or axis == "rightx" or axis == 1 then
        setAnalogTurn(value)
    end
end

function love.gamepadaxis(_, axis, value)
    if axis == "leftx" or axis == "rightx" then
        setAnalogTurn(value)
    end
end

local function drawCoverStrip(item, w, h)
    if not item or not item.labelTextures or #item.labelTextures == 0 then return end
    local count = math.min(#item.labelTextures, 7)
    local size, gap = 54, 8
    local total = count * size + (count - 1) * gap
    local x = (w - total) / 2
    local y = h - 190
    for i = 1, count do
        local texture = item.labelTextures[i]
        local scale = math.min(size / texture:getWidth(), size / texture:getHeight())
        local drawW, drawH = texture:getWidth() * scale, texture:getHeight() * scale
        love.graphics.setColor(0.10, 0.12, 0.16, 1)
        love.graphics.rectangle("fill", x, y, size, size, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(texture, x + (size - drawW) / 2, y + (size - drawH) / 2, 0, scale, scale)
        if i == (item.coverIndex or 1) then
            love.graphics.setColor(0.38, 0.85, 0.73, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4, 4)
        end
        x = x + size + gap
    end
end

function love.mousepressed(_, y, button)
    if button == 1 and y > 70 and y < love.graphics.getHeight() - 205 then
        launchSelectedRom()
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(0.035, 0.047, 0.065, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setDepthMode("less", true)
    love.graphics.setMeshCullMode("back")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader(meshShader)
    meshShader:send("aspect", w / h)
    -- Continuous integer positions prevent wraparound jumps at model 1/13.
    local firstPosition = math.floor(carouselPosition) - 3
    local selectedSlot
    if #visibleModels == 1 then
        selectedSlot = 0
    elseif #visibleModels == 2 then
        for index = 1, 2 do
            local slot = (index - 1) - carouselPosition
            if index == selected then
                selectedSlot = slot
            else
                drawModel(visibleModels[index], slot)
            end
        end
    else
        for modelPosition = firstPosition, firstPosition + 6 do
            if #visibleModels > 0 then
                local index = wrap(modelPosition + 1, #visibleModels)
                local slot = modelPosition - carouselPosition
                if index == selected then
                    selectedSlot = slot
                else
                    drawModel(visibleModels[index], slot)
                end
            end
        end
    end
    if selectedSlot and #visibleModels > 0 then
        drawModel(visibleModels[selected], 0, true)
    end
    love.graphics.setShader()
    love.graphics.setMeshCullMode("none")
    love.graphics.setDepthMode()
    love.graphics.setBlendMode("alpha")
    love.graphics.setFont(font)
    local group = platformGroups[selectedPlatform]
    if group or allCartridges then
        love.graphics.setFont(platformFont)
        love.graphics.setColor(0.96, 0.97, 1, 1)
        local platformName = allCartridges and "All Cartridges" or (group.name or group.platform or "PLATFORM")
        platformName = platformName:gsub("%s+Cartridge$", "")
        -- Slight horizontal overdraw gives the platform heading a bold look
        -- without requiring a separate font asset on the device.
        love.graphics.printf(platformName, -1, 34, w, "center")
        love.graphics.printf(platformName, 1, 34, w, "center")
        love.graphics.printf(platformName, 0, 34, w, "center")
    end
    love.graphics.setColor(0.92, 0.95, 0.98, 1)
    love.graphics.setFont(font)
    love.graphics.printf(selectedRomName(), 0, h - 116, w, "center")
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.40, 0.47, 0.54, 1)
    love.graphics.print("Start - Exit", 42, h - 40)
    love.graphics.setColor(0.40, 0.47, 0.54, 1)
    love.graphics.printf("A  Launch · X  Zoom", 0, h - 40, w, "center")
    love.graphics.printf("L/R  platforms", w - 190, h - 40, 148, "right")
end

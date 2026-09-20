-- ROCKNIX 3D Carousel
-- Dependency-free, flat-shaded OBJ viewer tuned for small ARM devices.

local TAU = math.pi * 2
-- The replacement S3D-derived meshes are already compact and GPU-rendered.
-- Keep nearly all triangles; decimating a disc/cartridge creates visible
-- spokes and holes in otherwise continuous surfaces.
local MAX_TRIANGLES = 30000
-- A shallow turn keeps the front label readable while still exposing the
-- cartridge's top/right depth, like the physical product shot used as the
-- visual reference.
local HERO_ANGLE = -0.30
local SPIN_SPEED = 0
local SLIDE_TIME = 0.36
local LAUNCH_ANIMATION_TIME = 0.82
local DISC_LAUNCH_ANIMATION_TIME = 1.35
local MAX_MODEL_ZOOM = 1.35

-- Cool sport palette sampled from the supplied reference.
local BG_COLOR = {0.8314, 0.8510, 0.8745, 1} -- #D4D9DF pale blue-gray
local GAME_TITLE_COLOR = {0.2980, 0.3686, 0.7216, 1} -- #4C5EB8 royal blue
local SUBTITLE_COLOR = {0.1529, 0.2039, 0.3725, 1} -- #27345F deep blue
local LOGO_COLOR = {0.2980, 0.3686, 0.7216, 1} -- #4C5EB8
local PANEL_COLOR = {0.7294, 0.8118, 0.8431, 1} -- #BACFD7 powder blue
local BORDER_COLOR = {0.3804, 0.5804, 0.5647, 1} -- #619490 teal
local ACCENT_COLOR = {0.9216, 0.7686, 0.1725, 1} -- #EBC42C yellow

-- Pale blue surfaces carry the field; yellow, royal blue, and teal reproduce
-- the shoes and geometric accents from the reference.
local CAROUSEL_BG = {0.8314, 0.8510, 0.8745, 1} -- #D4D9DF
local CAROUSEL_DOT = {0.3804, 0.5804, 0.5647, 0.48} -- #619490 darker teal
local CAROUSEL_TEXT = {0.1529, 0.2039, 0.3725, 1} -- #27345F
local CAROUSEL_PILL = {1.0000, 1.0000, 1.0000, 0.97} -- #FFFFFF
local CAROUSEL_BUTTON = {0.2980, 0.3686, 0.7216, 1} -- #4C5EB8 system logos
local CAROUSEL_BUTTON_BG = {0.9216, 0.7686, 0.1725, 1} -- #EBC42C

local models = {
    { name = "Game Boy", short = "GB", file = "models/gb.obj", labelPlatform = "gb", labelVariants = {"labels/gb/scan-01.png", "labels/gb/scan-02.png"}, labelFlipY = true, angleOffsetY = 0, centerOffsetX = 0.24, color = {0.62, 0.64, 0.68} },
    { name = "Game Boy Color", short = "GBC", file = "models/gbc.obj", labelPlatform = "gbc", labelVariants = {"labels/gbc/scan-01.png"}, labelFlipY = true, color = {0.62, 0.64, 0.68} },
    { name = "NES Cartridge", short = "NES", file = "models/nes.obj", labelPlatform = "nes", labelPlanar = true, labelFlipY = true, color = {0.50, 0.48, 0.70} },
    { name = "SNES Cartridge", short = "SNES", file = "models/snes.obj", labelPlatform = "snes", labelVariants = {"labels/snes/scan-01.png"}, labelFlipY = true, color = {0.50, 0.48, 0.70} },
    { name = "Nintendo 64", short = "N64", file = "models/N64.obj", labelPlatform = "n64", labelVariants = {"labels/n64/01.png"}, labelFlipY = true, color = {0.7608, 0.6980, 0.5020} }, -- #C2B280
    { name = "Game Boy Advance", short = "GBA", file = "models/gba.obj", labelPlatform = "gba", labelVariants = {"labels/gba/01.png", "labels/gba/02.png", "labels/gba/03.png"}, labelPlanar = true, labelFlipY = true, angleOffsetY = 0, rotateZ180 = false, color = {0.62, 0.64, 0.68} },
    { name = "Game Gear", short = "GG", file = "models/gamegear.obj", labelPlatform = "gamegear", labelVariants = {"labels/gamegear/scan-01.png"}, labelFlipY = true, labelMirrorX = false, labelRotate180 = false, rotateXZ = false, rotateZ180 = false, angleOffsetY = 0, noDecimate = true, color = {0.20, 0.22, 0.25} }, -- same as Genesis
    { name = "Master System", short = "SMS", file = "models/mastersystem.obj", labelPlatform = "mastersystem", labelPlanar = true, labelFlipY = true, noDecimate = true, color = {0.16, 0.14, 0.15} },
    { name = "Genesis", short = "GEN", file = "models/genesis.obj", labelPlatform = "genesis", labelVariants = {"labels/genesis/scan-01.png"}, labelMirrorX = true, labelRotate180 = true, color = {0.20, 0.22, 0.25} },
    { name = "Nintendo DS", short = "NDS", file = "models/nds.obj", labelPlatform = "nds", labelVariants = {"labels/nds/scan-01.png"}, labelFlipY = true, color = {0.62, 0.64, 0.68} },
    { name = "Switch Cartridge", short = "SWITCH", file = "models/switch.obj", labelPlatform = "switch", color = {1, 1, 1} },
    { name = "PlayStation Vita", short = "VITA", file = "models/vita.obj", labelPlatform = "vita", color = {0.32, 0.36, 0.58} },
    { name = "UMD Disc", short = "UMD", file = "models/umd.obj", labelPlatform = "psp", angleOffsetY = math.pi, rotateZ180 = false, color = {0.55, 0.58, 0.64} },
    { name = "Compact Disc", short = "CD", file = "models/disc.obj", labelPlatform = "psx", color = {0.42, 0.70, 0.68} },
    { name = "PAL Cartridge", short = "PAL", file = "models/snes-pal.obj", labelPlatform = "snes", labelFlipY = true, color = {0.66, 0.48, 0.25} },
    { name = "3DS Cartridge", short = "3DS", file = "models/3ds.obj", labelPlatform = "3ds", color = {0.72, 0.28, 0.48} },
    { name = "Neo Geo", short = "NEO GEO", file = "models/neogeo.obj", labelPlatform = "neogeo", labelVariants = {"labels/neogeo/scan-01.png"}, labelFlipY = false, labelMirrorX = true, labelRotate = true, labelRotate180 = true, labelScale = 0.25, labelOffsetX = 1.5, color = {0.62, 0.64, 0.68} },
    { name = "Dreamcast Disc", short = "DC", file = "models/dreamcast.obj", labelPlatform = "dreamcast", color = {0.84, 0.86, 0.88} },
    { name = "Saturn Disc", short = "SAT", file = "models/dreamcast.obj", labelPlatform = "saturn", color = {0.80, 0.82, 0.85} },
}

local selected, carouselPosition, targetPosition, pulse, analogTurn, modelZoom, targetZoom, zoomed, solidModels, font, titleFont, smallFont, platformFont, metadataPlatformFont = 1, 0, 0, 0, 0, 0, 1, false, true, nil, nil, nil, nil, nil
local rotations = {}
local visibleModels = {}
local platformGroups = {}
local selectedPlatform = 1
local allCartridges = false
local selectedAngleBlend = 1
local status = "LOADING LOCAL MESHES"
local meshShader
local logoShader
local shellTexture
local masterSystemLabelBase
local backdropCanvas
local scanBusy = false
local zoomKeyHeld = false
local zoomPadHeld = false
local zoomToggleCooldown = 0
local launchAnimating = false
local launchElapsed = 0
local pendingLaunchCommand
local gameMetadataCache = {}
local appUptime = 0
local exitReason = "external/window close"

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function wrap(n, max) return ((n - 1) % max) + 1 end
local function lerp(a, b, t) return a + (b - a) * t end
local function isDisc(item)
    return item and (item.labelPlatform == "dreamcast" or item.labelPlatform == "saturn")
end

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
    local currentColor = {1, 1, 1}
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
                for i = 2, #points - 1 do faces[#faces + 1] = {points[1], points[i], points[i + 1], currentLabel, currentColor} end
            end
        end
    end
    local cx, cy, cz = (minx + maxx) / 2, (miny + maxy) / 2, (minz + maxz) / 2
    local scale = 2.0 / math.max(maxx - minx, maxy - miny, maxz - minz, 0.001)
    local stride = item.noDecimate and 1 or math.max(1, math.ceil(#faces / (item.maxTriangles or MAX_TRIANGLES)))
    local meshVertices, labelVertices = {}, {}
    for i = 1, #faces, stride do
        local f = faces[i]
        local artworkFace = f[4] == 1
        if artworkFace and item.labelPlanar then
            -- These stickers are thin boxes: artwork belongs only on +Z.
            local a, b, c = vertices[f[1][1]], vertices[f[2][1]], vertices[f[3][1]]
            local ux, uy, uz = b[1]-a[1], b[2]-a[2], b[3]-a[3]
            local vx, vy, vz = c[1]-a[1], c[2]-a[2], c[3]-a[3]
            local nx, ny, nz = uy*vz-uz*vy, uz*vx-ux*vz, ux*vy-uy*vx
            artworkFace = nz > math.sqrt(nx*nx + ny*ny + nz*nz) * 0.5
        end
        for corner = 1, 3 do
            local point = vertices[f[corner][1]]
            local uv = texcoords[f[corner][2]] or {0, 0}
            if f[4] == 1 and (item.labelPlanar or not texcoords[f[corner][2]]) and labelMaxX > labelMinX and labelMaxY > labelMinY then
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
                f[5][1], f[5][2], f[5][3], f[4],
            }
            -- Keep label faces in the opaque shell as a gray backing panel.
            -- The separate label pass adds artwork only to the front-facing
            -- side, so rotating the cartridge cannot reveal a label through
            -- an empty back.
            meshVertices[#meshVertices + 1] = vertex
            if artworkFace then labelVertices[#labelVertices + 1] = vertex end
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
    local launchYOffset = 0
    local discRoll = 0
    if active and launchAnimating then
        local duration = isDisc(item) and DISC_LAUNCH_ANIMATION_TIME or LAUNCH_ANIMATION_TIME
        local t = clamp(launchElapsed / duration, 0, 1)
        if isDisc(item) then
            -- Complete one full turn before the disc enters the drive.
            local spinEnd = 0.58
            if t < spinEnd then
                local spin = t / spinEnd
                local smoothSpin = spin * spin * (3 - 2 * spin)
                local lift = math.sin(math.min(spin / 0.30, 1) * math.pi * 0.5)
                launchYOffset = 0.34 * lift
                discRoll = TAU * smoothSpin
                angle = angle - 0.12 * math.sin(spin * math.pi)
            else
                local drop = (t - spinEnd) / (1 - spinEnd)
                launchYOffset = 0.34 - 5.5 * drop * drop
                discRoll = TAU
            end
        else
            -- Cartridges make one face/back/face flip before insertion.
            local smoothFlip = t * t * (3 - 2 * t)
            angle = angle + TAU * smoothFlip
            if t < 0.28 then
                launchYOffset = 0.36 * math.sin((t / 0.28) * math.pi * 0.5)
            else
                local drop = (t - 0.28) / 0.72
                launchYOffset = 0.36 - 5.2 * drop * drop * drop
            end
        end
    end
    -- Add a gap on each side of the selected cartridge only. The constant
    -- offset keeps spacing between the unselected cartridges unchanged.
    -- Keep the hero's larger physical footprint clear of its neighbors while
    -- either cartridge is moving through the center slot.  The extra spacing
    -- is intentional: the viewport crops the outer cartridges, matching the
    -- product-shot composition while preventing mesh overlap.
    local selectedGap = slot > 0 and 1.05 or (slot < 0 and -1.05 or 0)
    local offset = slot * 2.35 + selectedGap
    local selectedScale = item.labelPlatform == "snes" and 3.10
        or item.labelPlatform == "genesis" and 3.10
        or item.labelPlatform == "gamegear" and 2.85
        or item.labelPlatform == "neogeo" and 2.35
        or 3.05
    -- Side cartridges remain large enough to read as objects, but their
    -- centers sit outside the panel so the viewport naturally crops them.
    local baseScale = 1.06 - math.min(math.abs(slot), 3) * 0.14
    -- Keep every platform within the same readable zoom envelope. The source
    -- meshes have different native proportions, so a global 2.8x zoom can
    -- make some cartridges overflow the 480px panel.
    local zoomFactor = math.min(modelZoom, MAX_MODEL_ZOOM)
    local scale = active and (selectedScale * zoomFactor) or baseScale
    local alpha = 1
    meshShader:send("angle", angle)
    meshShader:send("discRoll", discRoll)
    meshShader:send("discMaterial", isDisc(item) and 1 or 0)
    -- The legacy 720px layout lifts the model to make room below it. On the
    -- RG DS upper 640x480 panel the selected cartridge should be centered.
    local modelYOffset = love.graphics.getHeight() <= 600 and 0.0 or 0.20
    -- On the two-panel surface the mesh projection is centered on the
    -- combined canvas by LÖVE's window transform. Move the carousel's world
    -- origin left by one panel-center so the hero cartridge lands at x=320.
    meshShader:send("offset", {offset + (item.centerOffsetX or 0), modelYOffset + launchYOffset})
    meshShader:send("modelScale", scale)
    meshShader:send("labelPass", 0)
    -- Game Boy carts use the same neutral gray as GBC, except Zelda titles
    -- keep the established gold collector-style treatment.
    local bodyColor = item.color or {0.62, 0.64, 0.68}
    if item.labelPlatform == "gb" then
        local title = (item.name or ""):lower()
        bodyColor = title:find("zelda", 1, true) and {0.7608, 0.6980, 0.5020} or {0.62, 0.64, 0.68}
    end
    meshShader:send("baseColor", bodyColor)
    meshShader:send("labelFlipY", item.labelFlipY and 1 or 0)
    meshShader:send("labelMirrorX", item.labelMirrorX and 1 or 0)
    meshShader:send("labelCropY", item.labelCropY or 1)
    meshShader:send("labelScale", item.labelScale or 1)
    meshShader:send("labelRotate", item.labelRotate and 1 or 0)
    meshShader:send("labelRotateLeft", item.labelRotateLeft and 1 or 0)
    meshShader:send("labelRotate180", item.labelRotate180 and 1 or 0)
    meshShader:send("labelOffsetX", item.labelOffsetX or 0)
    meshShader:send("labelOffsetY", item.labelOffsetY or 0)
    meshShader:send("rotateXY", item.rotateXY and 1 or 0)
    meshShader:send("rotateXZ", item.rotateXZ and 1 or 0)
    meshShader:send("rotateZ180", item.rotateZ180 and 1 or 0)
    meshShader:send("topMost", topMost and 1 or 0)
    -- The zoomed selection must remain in front of every neighboring mesh.
    -- Keep this depth bias on the hero draw pass, including during the zoom
    -- interpolation, so it cannot be occluded by a side cartridge.
    if topMost or (active and zoomed) then
        meshShader:send("topMost", 1)
        love.graphics.setDepthMode("less", true)
    end
    love.graphics.draw(item.mesh.mesh)
    if item.mesh.labelMesh and item.labelTextures then
        item.mesh.labelMesh:setTexture(item.labelTextures[item.coverIndex or 1])
        meshShader:send("labelPass", 1)
        -- The label mesh shares depth with the opaque sticker surface. Allow
        -- equal-depth fragments so the artwork pass can replace the backing
        -- color without writing a second depth layer.
        love.graphics.setDepthMode("lequal", false)
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
    item.labelTextures = {}
    item.labelVariant = 1
    for variant, path in ipairs(item.labelVariants or {}) do
        local ok, image = pcall(love.graphics.newImage, path, {linear = true})
        if ok and image then
            image:setFilter("linear", "linear")
            image:setWrap("clamp", "clamp")
            item.labelTextures[variant] = image
        else
            item.labelTextures[variant] = item.fallbackTexture
        end
    end
    if #item.labelTextures == 0 then item.labelTextures = {item.fallbackTexture} end
end

local function makeFallbackTexture(item)
    local canvas = love.graphics.newCanvas(512, 512)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.89, 0.92, 0.91, 1)
    love.graphics.setColor(0.11, 0.20, 0.27, 1)
    love.graphics.rectangle("fill", 0, 0, 512, 80)
    love.graphics.setColor(0.11, 0.20, 0.27, 1)
    love.graphics.rectangle("fill", 24, 128, 464, 280)
    love.graphics.setColor(0.68, 0.76, 0.78, 1)
    love.graphics.rectangle("fill", 24, 104, 464, 4)
    if item.logo then
        local scale = math.min(420 / item.logo:getWidth(), 220 / item.logo:getHeight())
        local width, height = item.logo:getWidth() * scale, item.logo:getHeight() * scale
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(item.logo, (512 - width) / 2, 166 + (220 - height) / 2, 0, scale, scale)
    end
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(item.short, 24, 19, 464, "center")
    love.graphics.setColor(0.11, 0.20, 0.27, 1)
    love.graphics.printf(item.name:upper(), 24, 415, 464, "center")
    love.graphics.setCanvas()
    love.graphics.pop()
    canvas:setFilter("linear", "linear")
    return canvas
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

local function makeMasterSystemLabel(title)
    local canvas = love.graphics.newCanvas(932, 133)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    if masterSystemLabelBase then
        love.graphics.draw(masterSystemLabelBase, 0, 0)
    else
        love.graphics.clear(0.62, 0.06, 0.08, 1)
    end

    local displayTitle = (title or "MASTER SYSTEM"):gsub("%s*%b[]", ""):gsub("%s*%b()", "")
    displayTitle = displayTitle:gsub("[_%-]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    local size = 48
    local labelFont = love.graphics.newFont(size)
    while size > 25 and labelFont:getWidth(displayTitle) > 650 do
        size = size - 2
        labelFont = love.graphics.newFont(size)
    end
    love.graphics.setFont(labelFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(displayTitle, 30, (133 - labelFont:getHeight()) / 2 - 2)
    love.graphics.setCanvas()
    love.graphics.pop()
    canvas:setFilter("linear", "linear")
    return canvas
end

local function applyPlatformLabel(game)
    if game.labelPlatform == "mastersystem" then
        game.labelTextures = {makeMasterSystemLabel(game.name)}
        game.labelScale = 1
        game.labelOffsetX, game.labelOffsetY = 0, 0
        game.coverIndex = 1
    end
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
                game.screenshotTexture = romPath and item.screenshotsByRom and item.screenshotsByRom[romPath] or nil
                if romPath then representedRoms[romPath] = true end
                game.mesh = item.mesh
                applyPlatformLabel(game)
                group.games[#group.games + 1] = game
            end
            for _, romPath in ipairs(indexedRoms) do
                if not representedRoms[romPath] then
                    local game = {}
                    for key, value in pairs(item) do game[key] = value end
                    game.name = (romPath:match("([^/]+)$") or romPath):gsub("%.[^%.]+$", "")
                    game.platformName = item.name
                    game.labelVariants = nil
                    game.labelTextures = {item.fallbackTexture}
                    game.labelScale = 1
                    game.labelOffsetX, game.labelOffsetY = 0, 0
                    game.scrapeRomPaths = nil
                    game.romPath = romPath
                    game.screenshotTexture = item.screenshotsByRom and item.screenshotsByRom[romPath] or nil
                    game.gameIndex = #group.games + 1
                    game.mesh = item.mesh
                    applyPlatformLabel(game)
                    group.games[#group.games + 1] = game
                end
            end
            if #group.games == 0 then
                local game = {}
                for key, value in pairs(item) do game[key] = value end
                game.name = item.name
                game.platformName = item.name
                game.labelVariants = nil
                game.labelTextures = {item.fallbackTexture}
                game.labelScale = 1
                game.labelOffsetX, game.labelOffsetY = 0, 0
                game.scrapeRomPaths = nil
                game.mesh = item.mesh
                game.gameIndex = 1
                applyPlatformLabel(game)
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
            item.screenshotsByRom = {}
            local logoPath = "logos/png/" .. item.labelPlatform .. ".png"
            local logoOk, logo = pcall(love.graphics.newImage, logoPath, {linear = true})
            item.logo = logoOk and logo or nil
            if item.logo then item.logo:setFilter("linear", "linear") end
            if not item.fallbackTexture then item.fallbackTexture = makeFallbackTexture(item) end
            local manifest = love.filesystem.read(dir .. "/scan-index.txt")
            if manifest then
                for line in manifest:gmatch("[^\r\n]+") do
                    local imageName, romPath = line:match("^([^|]+)|(.+)$")
                    if imageName and romPath and imageName ~= "" and romPath ~= "" then
                        item.scrapeRomPaths[dir .. "/" .. imageName] = romPath
                    end
                end
            end
            local screenshotManifest = love.filesystem.read(dir .. "/screenshot-index.txt")
            if screenshotManifest then
                for line in screenshotManifest:gmatch("[^\r\n]+") do
                    local imageName, romPath = line:match("^([^|]+)|(.+)$")
                    if imageName and romPath and imageName ~= "" and romPath ~= "" then
                        local ok, image = pcall(love.graphics.newImage, dir .. "/" .. imageName, {linear = true})
                        if ok and image then
                            image:setFilter("linear", "linear")
                            item.screenshotsByRom[romPath] = image
                        end
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

local function beginLaunchSelectedRom()
    if launchAnimating then return end
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
        n64 = "mupen64plus_next", gba = "mgba", nds = "drastic-sa",
        gamegear = "genesis_plus_gx", genesis = "genesis_plus_gx",
        mastersystem = "genesis_plus_gx",
        psp = "ppsspp", psx = "pcsx_rearmed32", ["3ds"] = "azahar", neogeo = "fbneo",
        dreamcast = "flycast", saturn = "yabasanshiro",
    }
    if item.labelPlatform == "nds" then
        -- ROCKNIX's native dual-screen NDS path is DraStic, not a libretro
        -- core. Its compositor rule owns the 1280x480 two-panel placement.
        pendingLaunchCommand = string.format("/usr/bin/runemu.sh %q -Pnds --core=drastic-sa --emulator=drastic >/tmp/rocknix-carousel-launch.log 2>&1 & nohup sh '/roms/ports/Cartrix/fullscreen-drastic.sh' >/tmp/rocknix-drastic-fullscreen.log 2>&1 </dev/null &", romPath)
    else
        pendingLaunchCommand = string.format("/usr/bin/runemu.sh %q -P%s --core=%s --emulator=retroarch >/tmp/rocknix-carousel-launch.log 2>&1 & nohup sh '/roms/ports/Cartrix/fullscreen-retroarch.sh' >/tmp/rocknix-retroarch-fullscreen.log 2>&1 </dev/null &", romPath, item.labelPlatform, cores[item.labelPlatform] or "")
    end
    status = "LAUNCHING " .. item.name
    launchElapsed = 0
    launchAnimating = true
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

local function xmlDecode(value)
    return (value or ""):gsub("&amp;", "&"):gsub("&apos;", "'"):gsub("&quot;", "\""):gsub("&lt;", "<"):gsub("&gt;", ">")
end

local function metadataTag(block, tag)
    local value = block:match("<" .. tag .. ">%s*(.-)%s*</" .. tag .. ">")
    return value and xmlDecode(value) or nil
end

local function formatPlayedTime(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "NOT PLAYED" end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then return string.format("%dh %02dm", hours, minutes) end
    return string.format("%dm", minutes)
end

local function gameMetadata(item)
    if not item or not item.romPath then
        return "UNKNOWN", "NOT PLAYED"
    end
    local gamelistPath = item.romPath:match("^(.+)/[^/]+$") .. "/gamelist.xml"
    if gameMetadataCache[gamelistPath] == nil then
        local entries = {}
        local file = io.open(gamelistPath, "r")
        local xml = file and file:read("*a") or ""
        if file then file:close() end
        for block in xml:gmatch("<game[^>]*>(.-)</game>") do
            local path = metadataTag(block, "path")
            if path then
                local key = path:match("([^/]+)$")
                entries[key] = {
                    mainStory = metadataTag(block, "arcadesystemname") or "UNKNOWN",
                    playedTime = formatPlayedTime(metadataTag(block, "gametime")),
                }
            end
        end
        gameMetadataCache[gamelistPath] = entries
    end
    local key = item.romPath:match("([^/]+)$")
    local metadata = gameMetadataCache[gamelistPath][key]
    return metadata and metadata.mainStory or "UNKNOWN", metadata and metadata.playedTime or "NOT PLAYED"
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

local function fetchScreenScraperData()
    if scanBusy then return end
    local item = visibleModels[selected]
    local platform = item and item.labelPlatform
    if not platform or platform == "" then
        status = "NO PLATFORM SELECTED"
        return
    end
    scanBusy = true
    status = "DOWNLOADING " .. platform:upper() .. " LABELS + SCREENSHOTS"
    local ok = os.execute("sh fetch-textures.sh " .. string.format("%q", platform) .. " >/tmp/rocknix-carousel-fetch.log 2>&1")
    refreshScannedLabels()
    status = (ok == true or ok == 0)
        and (platform:upper() .. " DOWNLOAD COMPLETE")
        or (platform:upper() .. " DOWNLOAD FAILED · CHECK /tmp/rocknix-carousel-fetch.log")
    scanBusy = false
end

function love.load()
    local startupStarted = love.timer.getTime()
    love.keyboard.setKeyRepeat(false)
    love.graphics.setBackgroundColor(BG_COLOR)
    font = love.graphics.newFont(22)
    titleFont = love.graphics.newFont(20)
    smallFont = love.graphics.newFont(14)
    platformFont = love.graphics.newFont(22)
    metadataPlatformFont = love.graphics.newFont(18)
    logoShader = love.graphics.newShader([[
        extern vec3 logoTint;
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
            return vec4(logoTint, Texel(tex, uv).a * color.a);
        }
    ]])
    meshShader = love.graphics.newShader([[
        attribute vec3 VertexNormal;
        varying vec3 vNormal;
        varying vec2 vUV;
        varying float vLabel;
        varying vec3 vMaterialColor;
        varying vec2 vBodyUV;
        varying vec2 vDiscPos;
        varying vec3 vViewPos;
        extern number angle;
        extern number discRoll;
        extern vec2 offset;
        extern number modelScale;
        extern number aspect;
        extern number rotateXY;
        extern number rotateXZ;
        extern number rotateZ180;
        extern number topMost;
        extern number viewportScale;
        extern number viewportCenter;

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
            float cr = cos(discRoll), sr = sin(discRoll);
            p = vec3(cr * p.x - sr * p.y, sr * p.x + cr * p.y, p.z);
            n = vec3(cr * n.x - sr * n.y, sr * n.x + cr * n.y, n.z);
            p = vec3(cy * p.x + sy * p.z, p.y, -sy * p.x + cy * p.z);
            n = vec3(cy * n.x + sy * n.z, n.y, -sy * n.x + cy * n.z);
            if (topMost > 0.5) p.z -= 4.0;
            p.x += offset.x;
            p.y += offset.y;
            p.z -= 4.6;
            vNormal = normalize(n);
            vUV = VertexTexCoord.xy;
            vLabel = VertexColor.a;
            vMaterialColor = VertexColor.rgb;
            vDiscPos = vertex_position.xy;
            vec3 surfaceAxis = abs(VertexNormal);
            vBodyUV = surfaceAxis.z > surfaceAxis.x && surfaceAxis.z > surfaceAxis.y
                ? vertex_position.xy * 5.0
                : (surfaceAxis.y > surfaceAxis.x ? vertex_position.xz * 5.0 : vertex_position.yz * 5.0);
            vViewPos = -p;
            float zclip = -1.002 * p.z - 0.2002;
            float localX = p.x * 1.55 / aspect;
            // The RG DS upper panel is the left 640px of the 1280px canvas.
            // Keep this center in the vertex transform so the selected model
            // cannot drift to the center of the combined two-panel surface.
            float panelCenter = viewportScale < 0.75 ? -0.50 : viewportCenter;
            float clipW = -p.z;
            return vec4(localX * viewportScale + panelCenter * clipW, p.y * 1.55, zclip, clipW);
        }
    ]], [[
        varying vec3 vNormal;
        varying vec2 vUV;
        varying float vLabel;
        varying vec3 vMaterialColor;
        varying vec2 vBodyUV;
        varying vec2 vDiscPos;
        varying vec3 vViewPos;
        extern vec3 baseColor;
        extern number discMaterial;
        extern number labelFlipY;
        extern number labelMirrorX;
        extern number labelCropY;
        extern number labelScale;
        extern number labelRotate;
        extern number labelRotateLeft;
        extern number labelRotate180;
        extern number labelOffsetX;
        extern number labelOffsetY;
        extern number labelPass;

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
            vec3 material = baseColor * vMaterialColor;
            vec3 discShine = vec3(0.0);
            if (discMaterial > 0.5) {
                float radius = length(vDiscPos);
                vec2 tangent = normalize(vec2(-vDiscPos.y, vDiscPos.x) + vec2(0.0001));
                vec2 lightSweep = normalize(vec2(0.6, 0.8) + V.xy * 0.5);
                float arc = pow(max(dot(tangent, lightSweep), 0.0), 3.0);
                float phase = radius * 0.8 + atan(vDiscPos.y, vDiscPos.x) * 0.8;
                vec3 spectrum = 0.5 + 0.5 * sin(vec3(phase, phase + 2.1, phase + 4.2));
                discShine = spectrum * arc * 0.18;
            } else if (labelPass < 0.5) {
                float grain = Texel(tex, vBodyUV).r;
                material *= 0.94 + grain * 0.09;
            }
            // Only apply artwork when the label face points toward the camera.
            // From the rear, show the cartridge body instead of the label back.
            if (labelPass > 0.5 && dot(N, V) <= 0.0) discard;
            if (labelPass > 0.5 && vLabel > 0.5) {
                vec2 fittedUV = (labelUV - vec2(0.5)) / max(labelScale, 0.001) + vec2(0.5);
                fittedUV.x += labelOffsetX;
                fittedUV.y += labelOffsetY;
                if (fittedUV.x >= 0.0 && fittedUV.x <= 1.0 && fittedUV.y >= 0.0 && fittedUV.y <= 1.0) {
                    material = Texel(tex, fittedUV).rgb;
                    if (discMaterial > 0.5) material = min(material + discShine * 0.35, vec3(1.0));
                    return vec4(material, 1.0);
                }
            }
            if (discMaterial > 0.5) {
                float metalLight = 0.65 + 0.28 * abs(dot(N, L));
                float metalSpec = pow(max(abs(dot(N, H)), 0.0), 48.0) * 0.55;
                vec3 silver = vec3(0.82, 0.86, 0.90) * metalLight;
                return vec4(min(silver + discShine + vec3(metalSpec), vec3(1.0)), 1.0);
            }
            return vec4(material * (ambient + diffuse * 0.75) + vec3(specular), 1.0);
        }
    ]])
    shellTexture = love.graphics.newImage("textures/shell-grain.png")
    shellTexture:setFilter("linear", "linear")
    shellTexture:setWrap("repeat", "repeat")
    masterSystemLabelBase = love.graphics.newImage("textures/mastersystem-label.png")
    masterSystemLabelBase:setFilter("linear", "linear")
    masterSystemLabelBase:setWrap("clamp", "clamp")
    local loadedMeshes = {}
    for _, item in ipairs(models) do
        item.mesh = loadedMeshes[item.file]
        if not item.mesh then
            item.mesh = loadObj(item)
            loadedMeshes[item.file] = item.mesh
        end
        if item.mesh then item.mesh.mesh:setTexture(shellTexture) end
        if item.labelVariants then
            item.baseLabelVariants = item.labelVariants
        end
    end
    io.stderr:write(string.format("Startup: meshes ready in %.2fs\n", love.timer.getTime() - startupStarted))
    for index = 1, #models do rotations[index] = 0 end
    -- Reuse the artwork and ROM indexes already on disk. Rebuilding them
    -- walks every ROM directory and copies artwork, delaying the first frame.
    -- S still performs an explicit rescan; a fresh install scans once.
    local hasScanCache = false
    for _, item in ipairs(models) do
        if item.labelPlatform and love.filesystem.getInfo("labels/" .. item.labelPlatform .. "/rom-index.txt") then
            hasScanCache = true
            break
        end
    end
    local needsPlatformScan = not love.filesystem.getInfo("labels/mastersystem/rom-index.txt")
        or not love.filesystem.getInfo("labels/dreamcast/rom-index.txt")
        or not love.filesystem.getInfo("labels/saturn/rom-index.txt")
    if hasScanCache and not needsPlatformScan then
        refreshScannedLabels()
        status = "CACHED LIBRARY LOADED · PRESS Y TO RESCAN"
    else
        scanScrapedData()
    end
    if #visibleModels == 0 then
        status = "NO SCRAPED PLATFORMS · PRESS Y TO SCAN"
    end
    io.stderr:write(string.format("Startup: library ready in %.2fs\n", love.timer.getTime() - startupStarted))
end

function love.quit()
    io.stderr:write(string.format("Exit: %s after %.2fs\n", exitReason, appUptime))
    io.stderr:flush()
    -- The launch watcher owns focus and frontend restoration while a game is
    -- running. Restoring here would race RetroArch and steal its fullscreen.
    if exitReason == "game launch" then return end
    -- Return the device to the normal single top-screen frontend whenever
    -- Cartrix exits directly (Escape/Start).
    local restore = "export XDG_RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-/var/run/0-runtime-dir}\"; " ..
        "export SWAYSOCK=\"${SWAYSOCK:-$XDG_RUNTIME_DIR/sway-ipc.0.sock}\"; " ..
        "swaymsg 'output DSI-2 power on' >/dev/null 2>&1; " ..
        "swaymsg 'output DSI-1 power on' >/dev/null 2>&1; " ..
        "swaymsg 'output DSI-2 pos 0 0' >/dev/null 2>&1; " ..
        "swaymsg 'output DSI-1 pos 640 0' >/dev/null 2>&1; " ..
        "swaymsg '[app_id=\"emulationstation\"] move container to output DSI-2' >/dev/null 2>&1; " ..
        "swaymsg '[app_id=\"emulationstation\"] floating disable, fullscreen enable' >/dev/null 2>&1; " ..
        "swaymsg 'seat seat0 attach 18507:4353:retrogame_joypad' >/dev/null 2>&1; " ..
        "swaymsg 'seat seat1 attach 1046:911:Goodix_Capacitive_TouchScreen' >/dev/null 2>&1; " ..
        "swaymsg '[app_id=\"emulationstation\"] focus' >/dev/null 2>&1; "
    os.execute(restore)
end

function love.update(dt)
    appUptime = appUptime + dt
    pulse = pulse + dt
    if zoomToggleCooldown > 0 then
        zoomToggleCooldown = math.max(0, zoomToggleCooldown - dt)
    end
    if launchAnimating then
        launchElapsed = launchElapsed + dt
        local duration = isDisc(visibleModels[selected]) and DISC_LAUNCH_ANIMATION_TIME or LAUNCH_ANIMATION_TIME
        if launchElapsed >= duration then
            local command = pendingLaunchCommand
            pendingLaunchCommand = nil
            launchAnimating = false
            exitReason = "game launch"
            if command then os.execute(command) end
            love.event.quit()
            return
        end
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

local function requestExit(reason)
    -- EmulationStation's launch input can remain queued while the meshes load.
    -- Ignore those stale events so Cartrix does not immediately return to the
    -- menu as soon as its first frame appears.
    if appUptime < 2.0 then
        io.stderr:write(string.format("Ignored early exit input: %s at %.2fs\n", reason, appUptime))
        io.stderr:flush()
        return
    end
    exitReason = reason
    love.event.quit()
end

function love.keypressed(key)
    if launchAnimating then return end
    if key == "left" or key == "a" then select(-1)
    elseif key == "right" or key == "d" then select(1)
    elseif key == "r" then selectPlatform(1)
    elseif key == "l" then selectPlatform(-1)
    elseif key == "s" then scanScrapedData()
    elseif key == "y" then scanScrapedData()
    elseif key == "b" then fetchScreenScraperData()
    elseif key == "x" and not zoomKeyHeld and not zoomPadHeld and zoomToggleCooldown <= 0 then
        zoomKeyHeld = true
        zoomToggleCooldown = 0.75
        toggleZoom()
    elseif key == "return" or key == "space" then beginLaunchSelectedRom()
    elseif key == "escape" or key == "backspace" then requestExit("keyboard " .. key) end
end

function love.gamepadpressed(_, button)
    if launchAnimating then return end
    if button == "dpleft" then select(-1)
    elseif button == "dpright" then select(1)
    elseif button == "leftshoulder" then selectPlatform(-1)
    elseif button == "rightshoulder" then selectPlatform(1)
    elseif button == "y" then scanScrapedData()
    -- The RG DS SDL mapping reports its physical A button as "b" and its
    -- physical B button as "a". Keep behavior aligned with the printed
    -- button labels: physical A launches, physical B scrapes.
    elseif button == "b" then beginLaunchSelectedRom()
    elseif button == "a" then fetchScreenScraperData()
    elseif button == "x" and not zoomPadHeld and not zoomKeyHeld and zoomToggleCooldown <= 0 then
        zoomPadHeld = true
        zoomToggleCooldown = 0.75
        toggleZoom()
    elseif button == "back" or button == "start" then requestExit("gamepad " .. button) end
end

function love.joystickpressed(joystick, button)
    -- Some ROCKNIX sessions expose the built-in controller as a raw joystick
    -- instead of loading its SDL gamepad mapping. In that state kernel events
    -- arrive, but love.gamepadpressed never fires. Use the evdev button order
    -- as a fallback and avoid duplicate actions when it is a mapped gamepad.
    if joystick:isGamepad() or launchAnimating then return end
    if button == 16 then select(-1)                    -- D-pad Left
    elseif button == 17 then select(1)                 -- D-pad Right
    elseif button == 5 then selectPlatform(-1)         -- L
    elseif button == 6 then selectPlatform(1)          -- R
    elseif button == 4 then scanScrapedData()          -- physical Y
    elseif button == 2 then beginLaunchSelectedRom()   -- physical A
    elseif button == 1 then fetchScreenScraperData()   -- physical B
    elseif button == 3 and not zoomPadHeld and not zoomKeyHeld and zoomToggleCooldown <= 0 then
        zoomPadHeld = true
        zoomToggleCooldown = 0.75
        toggleZoom()
    elseif button == 9 or button == 10 then requestExit("raw start/select") end
end

function love.keyreleased(key)
    if key == "x" then zoomKeyHeld = false end
end

function love.gamepadreleased(_, button)
    if button == "x" then zoomPadHeld = false end
end

function love.joystickreleased(joystick, button)
    if not joystick:isGamepad() and button == 3 then zoomPadHeld = false end
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
        love.graphics.setColor(PANEL_COLOR)
        love.graphics.rectangle("fill", x, y, size, size, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(texture, x + (size - drawW) / 2, y + (size - drawH) / 2, 0, scale, scale)
        if i == (item.coverIndex or 1) then
            love.graphics.setColor(ACCENT_COLOR)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4, 4)
        end
        x = x + size + gap
    end
end

local function drawFitImage(image, x, y, width, height, tint)
    if not image then return false end
    local scale = math.min(width / image:getWidth(), height / image:getHeight())
    local drawW, drawH = image:getWidth() * scale, image:getHeight() * scale
    love.graphics.setColor(tint or {1, 1, 1, 1})
    love.graphics.draw(image, x + (width - drawW) / 2, y + (height - drawH) / 2, 0, scale, scale)
    return true
end

local function drawRoundedImage(image, x, y, width, height, radius)
    if not image then return false end
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", x, y, width, height, radius, radius)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    drawFitImage(image, x, y, width, height)
    love.graphics.setStencilTest()
    return true
end

local function drawCarouselBackdrop(x, y, width, height)
    if not backdropCanvas or backdropCanvas:getWidth() ~= width or backdropCanvas:getHeight() ~= height then
        backdropCanvas = love.graphics.newCanvas(width, height)
        love.graphics.push("all")
        love.graphics.setCanvas(backdropCanvas)
        love.graphics.clear(CAROUSEL_BG)
        love.graphics.setColor(CAROUSEL_DOT)
        for dotY = 7, height, 20 do
            for dotX = 8, width, 20 do
                love.graphics.circle("fill", dotX, dotY, 1.5)
            end
        end
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(backdropCanvas, x, y)
end

local function drawControlPill(x, y, width)
    local height = 43
    local controls = {
        {button = "S", action = "Exit"},
        {button = "X", action = "Zoom"},
        {button = "Y", action = "Scan"},
        {button = "B", action = "Scrape"},
    }

    local sectionWidth = width / #controls
    for index, control in ipairs(controls) do
        local sectionX = x + (index - 1) * sectionWidth
        local actionWidth = titleFont:getWidth(control.action)
        local contentWidth = 18 + 7 + actionWidth
        local contentX = sectionX + (sectionWidth - contentWidth) / 2

        love.graphics.setColor(CAROUSEL_TEXT)
        love.graphics.circle("fill", contentX + 9, y + height / 2, 9)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(smallFont)
        love.graphics.printf(control.button, contentX + 2, y + 14, 14, "center")
        love.graphics.setColor(CAROUSEL_TEXT)
        love.graphics.setFont(titleFont)
        love.graphics.print(control.action, contentX + 25, y + 9)
    end
end

local function drawMetricCard(label, value, x, y, width)
    love.graphics.setColor(CAROUSEL_TEXT)
    love.graphics.setFont(smallFont)
    -- A one-pixel repeat gives the compact heading a bold weight without
    -- adding an external font dependency to the launcher package.
    love.graphics.print(label, x + 18, y + 14)
    love.graphics.print(label, x + 19, y + 14)

    love.graphics.setColor(CAROUSEL_TEXT)
    love.graphics.setFont(titleFont)
    love.graphics.printf(value, x + 18, y + 45, width - 36, "left")
end

local function drawMetadataPanel(item, x, y, width, height)
    drawCarouselBackdrop(x, y, width, height)
    love.graphics.setColor(ACCENT_COLOR)
    love.graphics.rectangle("fill", x, y, 2, height)

    -- Merge metadata and screenshot into one white two-column card.
    local cardX, cardY = x + 28, y + 42
    local cardW, cardH = width - 56, height - 126
    love.graphics.setColor(CAROUSEL_PILL)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 18, 18)

    local leftX = cardX + 4
    local leftW = cardW * 0.38
    local mainStory, playedTime = gameMetadata(item)
    drawMetricCard("MAIN STORY", mainStory, leftX, cardY + 42, leftW)
    drawMetricCard("PLAYED TIME", playedTime, leftX, cardY + 152, leftW)

    -- Screenshots belong exclusively to the lower panel. The 3D model above
    -- continues to use the cover texture through currentCover(item).
    local cover = item and (item.screenshotTexture or currentCover(item)) or nil
    local imageX, imageY = cardX + cardW * 0.42, cardY + 8
    local imageW, imageH = cardW * 0.58 - 8, cardH - 16
    drawRoundedImage(cover, imageX, imageY, imageW, imageH, 12)

    -- Present all lower-screen actions as one control, matching the selected
    -- game pill on the upper screen instead of three disconnected text hints.
    local controlWidth = cardW
    drawControlPill(cardX, y + height - 58, controlWidth)

end

local function drawSelectedPill(title, centerX, y)
    local label = title or "NO GAME SELECTED"
    love.graphics.setFont(titleFont)
    local textWidth = titleFont:getWidth(label)
    local width = textWidth + 58
    local height = 43
    local x = centerX - width / 2

    love.graphics.setColor(CAROUSEL_PILL)
    love.graphics.rectangle("fill", x, y, width, height, 12, 12)
    love.graphics.setColor(CAROUSEL_TEXT)
    love.graphics.circle("fill", x + 21, y + height / 2, 9)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(smallFont)
    love.graphics.printf("A", x + 14, y + 14, 14, "center")
    love.graphics.setColor(CAROUSEL_TEXT)
    love.graphics.setFont(titleFont)
    love.graphics.print(label, x + 38, y + 9)
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    local dualScreen = w >= 1000 and h <= 600
    local panelW = dualScreen and w / 2 or w
    love.graphics.clear(BG_COLOR)
    local carouselW = dualScreen and panelW or w
    drawCarouselBackdrop(0, 0, carouselW, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setDepthMode("less", true)
    love.graphics.setMeshCullMode("back")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader(meshShader)
    meshShader:send("aspect", panelW / h)
    meshShader:send("viewportScale", dualScreen and 0.5 or 1.0)
    meshShader:send("viewportCenter", dualScreen and -0.5 or 0.0)
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
        -- Let the incoming hero travel from its carousel slot into the
        -- center. A fixed zero slot made it overlap the outgoing hero at the
        -- start of every left/right transition.
        local heroSlot = math.abs(carouselPosition - targetPosition) < 0.03 and 0 or selectedSlot
        drawModel(visibleModels[selected], heroSlot, true)
    end
    love.graphics.setShader()
    love.graphics.setMeshCullMode("none")
    love.graphics.setDepthMode()
    love.graphics.setBlendMode("alpha")
    love.graphics.setFont(font)
    local group = platformGroups[selectedPlatform]
    local item = visibleModels[selected]
    if dualScreen then
        love.graphics.setColor(BORDER_COLOR)
        love.graphics.rectangle("fill", panelW - 1, 0, 2, h)
        drawMetadataPanel(item, panelW, 0, panelW, h)
    end
    local drawW = dualScreen and panelW or w
    if group and group.logo then
        -- Fit inside a shallow top band without stretching the source logo.
        local logoMaxW, logoMaxH = math.min(230, drawW - 48), 42
        local logoScale = math.min(logoMaxW / group.logo:getWidth(), logoMaxH / group.logo:getHeight())
        local logoW = group.logo:getWidth() * logoScale
        local logoH = group.logo:getHeight() * logoScale
        local logoX = (drawW - logoW) / 2
        local logoY = 34 + (logoMaxH - logoH) / 2
        local buttonW, buttonH, buttonGap = 38, 34, 14
        local leftButtonX = logoX - buttonGap - buttonW
        local rightButtonX = logoX + logoW + buttonGap
        love.graphics.setColor(CAROUSEL_BUTTON_BG)
        love.graphics.rectangle("fill", leftButtonX, logoY + (logoH - buttonH) / 2, buttonW, buttonH, 9, 9)
        love.graphics.rectangle("fill", rightButtonX, logoY + (logoH - buttonH) / 2, buttonW, buttonH, 9, 9)
        love.graphics.setColor(CAROUSEL_TEXT)
        love.graphics.setFont(font)
        love.graphics.printf("L", leftButtonX, logoY + (logoH - font:getHeight()) / 2 - 2, buttonW, "center")
        love.graphics.printf("R", rightButtonX, logoY + (logoH - font:getHeight()) / 2 - 2, buttonW, "center")
        love.graphics.setColor(1, 1, 1, 1)
        logoShader:send("logoTint", {CAROUSEL_BUTTON[1], CAROUSEL_BUTTON[2], CAROUSEL_BUTTON[3]})
        love.graphics.setShader(logoShader)
        love.graphics.draw(group.logo, logoX, logoY, 0, logoScale, logoScale)
        love.graphics.setShader()
    end
    if dualScreen then
        -- Leave a visible breathing gap above the bottom control hints.
        drawSelectedPill(selectedRomName(), drawW / 2, h - 94)
    end
    if not dualScreen then
        love.graphics.setColor(GAME_TITLE_COLOR)
        love.graphics.setFont(titleFont)
        local title = selectedRomName()
        love.graphics.printf(title, 0, h - 116, w, "center")
        love.graphics.printf(title, 1, h - 116, w, "center")
    end
end

-- ========================================
-- FUNÇÕES AUXILIARES
-- ========================================

function getplrsname()
    for _, v in pairs(game:GetChildren()) do
        if v.ClassName == "Players" then
            return v.Name
        end
    end
end

local playersName = getplrsname()
local Players = game[playersName]
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ========================================
-- CONFIGURAÇÃO AIMBOT
-- ========================================

local AIMBOT = {
    Enabled = true,
    FOV = 300,
    Smoothness = 1,
    TeamCheck = false,
    WallCheck = true,
    MaxDistance = 300  -- Distância máxima em studs
}

-- ========================================
-- VARIÁVEIS GLOBAIS
-- ========================================

local currentTarget = nil
local FOVCircle = nil

-- ========================================
-- FOV CIRCLE
-- ========================================

local function CreateFOVCircle()
    pcall(function()
        if FOVCircle then
            FOVCircle:Remove()
        end
        
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Transparency = 0.8
        FOVCircle.Thickness = 2
        FOVCircle.Color = Color3.fromRGB(255, 50, 50)
        FOVCircle.NumSides = 100
        FOVCircle.Radius = AIMBOT.FOV
        FOVCircle.Filled = false
        FOVCircle.Visible = true
        FOVCircle.ZIndex = 1000
    end)
end

local function UpdateFOVCircle()
    pcall(function()
        if FOVCircle and Workspace.CurrentCamera then
            local ViewportSize = Workspace.CurrentCamera.ViewportSize
            FOVCircle.Position = Vector2.new(ViewportSize.X / 2, ViewportSize.Y / 2)
            FOVCircle.Radius = AIMBOT.FOV
        end
    end)
end

-- ========================================
-- PEGAR CÂMERA
-- ========================================

local function getCamera()
    -- Câmera principal do jogo
    return Workspace.CurrentCamera
end

-- ========================================
-- FUNÇÕES DE VALIDAÇÃO
-- ========================================

local function GetHead(character)
    if not character then return nil end
    
    -- Prioridade: Cabesa (sistema do jogo)
    local cabesa = character:FindFirstChild("Cabesa")
    if cabesa and cabesa:IsA("BasePart") then
        return cabesa
    end
    
    -- Fallback: Head padrão
    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head
    end
    
    return nil
end

local function isPlayerValid(player)
    if not player or not player.Character then return false end
    if player == LocalPlayer then return false end
    
    -- Team check
    if AIMBOT.TeamCheck then
        if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            return false
        end
    end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    local head = GetHead(player.Character)
    return head ~= nil
end

local function getDistance(part1, part2)
    return (part1.Position - part2.Position).Magnitude
end

local function hasLineOfSight(targetPos)
    if not AIMBOT.WallCheck then return true end
    
    local camera = getCamera()
    if not camera then return false end
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    local origin = camera.CFrame.Position
    local direction = (targetPos - origin)
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, direction, rayParams)
    
    if not result then return true end
    
    -- Verifica se acertou o character do alvo
    local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
    if hitModel and hitModel:FindFirstChild("Humanoid") then
        return true
    end
    
    return false
end

local function isInFOV(targetPos, camera)
    local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
    
    if not onScreen then return false end
    
    local ViewportSize = camera.ViewportSize
    local centerX = ViewportSize.X / 2
    local centerY = ViewportSize.Y / 2
    
    local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
    
    return distance <= AIMBOT.FOV
end

-- ========================================
-- SISTEMA DE TARGET
-- ========================================

local function getNearestTarget(camera)
    local nearestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if isPlayerValid(player) then
            local targetPart = GetHead(player.Character)
            
            if targetPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                -- CALCULA DISTÂNCIA PRIMEIRO
                local distance = getDistance(
                    LocalPlayer.Character.HumanoidRootPart,
                    targetPart
                )
                
                -- FILTRO DE 300 STUDS - Ignora jogadores muito longe
                if distance <= AIMBOT.MaxDistance then
                    if isInFOV(targetPart.Position, camera) then
                        if hasLineOfSight(targetPart.Position) then
                            if distance < shortestDistance then
                                shortestDistance = distance
                                nearestPlayer = player
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nearestPlayer
end

-- ========================================
-- SISTEMA DE AIM (CORRIGIDO - MANTÉM CÂMERA NO CORPO)
-- ========================================

local function aimAt(target, camera)
    if not target or not target.Character then return end
    
    local targetPart = GetHead(target.Character)
    if not targetPart then return end
    
    -- CORREÇÃO DEFINITIVA: Usa o HumanoidRootPart do próprio jogador como âncora
    local character = LocalPlayer.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    -- Posição base da câmera (ancorada no corpo do jogador)
    local camOffset = camera.CFrame.Position - rootPart.Position
    local baseCamPos = rootPart.Position + camOffset
    
    -- Direção para o alvo
    local targetPos = targetPart.Position
    local targetDirection = (targetPos - baseCamPos).Unit
    
    -- Direção atual
    local currentDirection = camera.CFrame.LookVector
    
    -- Interpolação suave
    local lerpedDirection = currentDirection:Lerp(targetDirection, AIMBOT.Smoothness)
    
    -- Aplica APENAS a rotação, mantendo posição relativa ao corpo
    camera.CFrame = CFrame.new(baseCamPos, baseCamPos + lerpedDirection)
end

-- ========================================
-- LOOP PRINCIPAL
-- ========================================

local function mainLoop()
    task.spawn(function()
        RunService.RenderStepped:Connect(function()
            pcall(function()
                if AIMBOT.Enabled then
                    local camera = getCamera()
                    
                    if camera then
                        -- Atualiza FOV visual
                        UpdateFOVCircle()
                        
                        -- Valida target atual (incluindo wall check)
                        if currentTarget then
                            if not isPlayerValid(currentTarget) then
                                currentTarget = nil
                            else
                                -- CORREÇÃO: Verifica linha de visão do target atual
                                local targetPart = GetHead(currentTarget.Character)
                                if targetPart and not hasLineOfSight(targetPart.Position) then
                                    currentTarget = nil
                                end
                            end
                        end
                        
                        -- Busca novo target
                        if not currentTarget then
                            currentTarget = getNearestTarget(camera)
                        end
                        
                        -- Aplica aim
                        if currentTarget then
                            aimAt(currentTarget, camera)
                        end
                    end
                end
            end)
        end)
    end)
end

-- ========================================
-- INICIALIZAÇÃO
-- ========================================

pcall(function()
    -- Aguarda character
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    
    task.wait(1)
    
    -- Cria FOV Circle
    CreateFOVCircle()
    
    task.wait(0.5)
    
    -- Inicia loop
    mainLoop()
    
    -- Debug
    task.wait(1)
    print("════════════════════════════════════════")
    print("AIMBOT ATIVADO")
    print("FOV: " .. AIMBOT.FOV)
    print("Smoothness: " .. AIMBOT.Smoothness)
    print("Wall Check: " .. tostring(AIMBOT.WallCheck))
    print("Max Distance: " .. AIMBOT.MaxDistance .. " studs")
    print("════════════════════════════════════════")
end)

-- Limpeza ao morrer
LocalPlayer.CharacterRemoving:Connect(function()
    currentTarget = nil
    pcall(function()
        if FOVCircle then
            FOVCircle:Remove()
        end
    end)
end)

-- Recria ao respawnar
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    CreateFOVCircle()
    currentTarget = nil
end)
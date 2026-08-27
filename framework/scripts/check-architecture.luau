-- Verifica estaticamente a matriz de comunicação obrigatória de
-- .claude/rules/knit-architecture.md (Accessor <-> Mutator proibido no mesmo
-- sistema; Components/Others só é require-ado pelo init.lua do mesmo sistema).
-- Limitação conhecida: só cobre require() estático — não cobre acesso indireto
-- via Superbullet.GetService(nome).Mutator.Algo(...), que é como sistemas
-- diferentes de fato se comunicam hoje sem passar por require() direto.

local fs = require("@lune/fs")
local process = require("@lune/process")

local SRC_ROOT = "src"

-- ===== I/O =====

local function walk(dir, out)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif name:match("%.luau?$") then
			out[path] = fs.readFile(path)
		end
	end
end

local function collectSourceFiles()
	local files = {}
	walk(SRC_ROOT, files)
	return files
end

-- ===== Parsing (sem I/O — recebe conteúdo já lido) =====

--- Para cada `require(...)` de uma linha, extrai o argumento respeitando
--- parênteses aninhados (ex.: `:WaitForChild("X", 10)`) e tokeniza em runs de
--- [%w_%(%)]+ — trata "." ":" "," espaço aspas colchetes como separador, o que
--- cobre dot-syntax, `:WaitForChild("X")` e aliases legados tipo `["Get()"]`.
--- Retorna lista de { line, tokens, expr } por arquivo. Requires que não fecham
--- na mesma linha (multi-linha) não são cobertos — limitação conhecida.
local function extractRequireCalls(content)
	local calls = {}
	local lineNum = 0
	for line in (content .. "\n"):gmatch("([^\n]*)\n") do
		lineNum += 1
		local searchStart = 1
		while true do
			local callStart, parenPos = line:find("require%(", searchStart)
			if not callStart then
				break
			end

			local depth = 1
			local i = parenPos + 1
			local argStart = i
			local argEnd = nil
			while i <= #line do
				local c = line:sub(i, i)
				if c == "(" then
					depth += 1
				elseif c == ")" then
					depth -= 1
					if depth == 0 then
						argEnd = i - 1
						break
					end
				end
				i += 1
			end

			if argEnd then
				local expr = line:sub(argStart, argEnd)
				local tokens = {}
				for token in expr:gmatch("[%w_%(%)]+") do
					table.insert(tokens, token)
				end
				table.insert(calls, { line = lineNum, tokens = tokens, expr = expr })
				searchStart = argEnd + 2
			else
				-- require() não fecha na mesma linha — não coberto por este check.
				searchStart = parenPos + 1
			end
		end
	end
	return calls
end

local function tokensContainAny(tokens, wanted)
	for _, token in tokens do
		for _, want in wanted do
			if token == want then
				return true
			end
		end
	end
	return false
end

-- ===== Descoberta de sistemas =====

local function basenameNoExt(path)
	local name = path:match("([^/]+)$") or path
	return (name:gsub("%.luau?$", ""))
end

local function classifyComponentFile(basename)
	if basename == "Accessor.lua" or basename == "Accessor.luau" or basename == "Get().lua" or basename == "Get().luau" then
		return "Accessor"
	elseif basename == "Mutator.lua" or basename == "Mutator.luau" or basename == "Set().lua" or basename == "Set().luau" then
		return "Mutator"
	end
	return nil
end

-- Um "sistema" = pasta com init.lua direto + subpasta Components/ (em
-- qualquer lugar sob src/**). Dentro de Components/: Accessor/Mutator (ou
-- aliases Get()/Set()) direto, e/ou Others/**/*.lua (achatado por basename,
-- igual ao ComponentInitializer real).
local function discoverSystems(files)
	local systems = {}

	for path in files do
		local systemDir = path:match("^(.-)/init%.luau?$")
		if systemDir then
			local componentsPrefix = systemDir .. "/Components/"
			local hasComponents = false
			for otherPath in files do
				if otherPath:sub(1, #componentsPrefix) == componentsPrefix then
					hasComponents = true
					break
				end
			end

			if hasComponents then
				local system = {
					name = systemDir:match("([^/]+)$") or systemDir,
					dir = systemDir,
					initPath = path,
					accessor = nil,
					mutator = nil,
					others = {}, -- basename sem extensão -> path
				}

				for componentPath in files do
					if componentPath:sub(1, #componentsPrefix) == componentsPrefix then
						local rest = componentPath:sub(#componentsPrefix + 1)
						if not rest:find("/") then
							local kind = classifyComponentFile(rest)
							if kind == "Accessor" then
								system.accessor = { path = componentPath }
							elseif kind == "Mutator" then
								system.mutator = { path = componentPath }
							end
						elseif rest:match("^Others/") then
							system.others[basenameNoExt(componentPath)] = componentPath
						end
					end
				end

				table.insert(systems, system)
			end
		end
	end

	return systems
end

-- ===== Regras =====

local function checkAccessorMutatorRule(system, requireIndex, violations)
	if system.accessor then
		local accessorBasename = system.accessor.path:match("([^/]+)$")
		local mutatorBasename = system.mutator and system.mutator.path:match("([^/]+)$") or "Mutator.lua/Set().lua"
		for _, call in requireIndex[system.accessor.path] do
			if tokensContainAny(call.tokens, { "Mutator", "Set()" }) then
				table.insert(violations, {
					file = system.accessor.path,
					line = call.line,
					rule = "matriz-comunicacao",
					message = ("%s requer %s do mesmo sistema (%s) via '%s'. Proibido por .claude/rules/knit-architecture.md (matriz de comunicação) — coordenação deve passar por init.lua."):format(
						accessorBasename,
						mutatorBasename,
						system.name,
						call.expr
					),
				})
			end
		end
	end

	if system.mutator then
		local mutatorBasename = system.mutator.path:match("([^/]+)$")
		local accessorBasename = system.accessor and system.accessor.path:match("([^/]+)$") or "Accessor.lua/Get().lua"
		for _, call in requireIndex[system.mutator.path] do
			if tokensContainAny(call.tokens, { "Accessor", "Get()" }) then
				table.insert(violations, {
					file = system.mutator.path,
					line = call.line,
					rule = "matriz-comunicacao",
					message = ("%s requer %s do mesmo sistema (%s) via '%s'. Proibido por .claude/rules/knit-architecture.md (matriz de comunicação) — coordenação deve passar por init.lua."):format(
						mutatorBasename,
						accessorBasename,
						system.name,
						call.expr
					),
				})
			end
		end
	end
end

local function checkOthersRule(system, files, requireIndex, violations)
	for basename, othersPath in system.others do
		for requesterPath in files do
			if requesterPath ~= othersPath and requesterPath ~= system.initPath then
				for _, call in requireIndex[requesterPath] do
					if tokensContainAny(call.tokens, { basename }) then
						table.insert(violations, {
							file = requesterPath,
							line = call.line,
							rule = "matriz-comunicacao",
							message = ("Requer '%s' (%s, Components/Others do sistema %s) via '%s' — Others/*.lua só pode ser require-ado pelo init.lua do próprio sistema (%s). Proibido por .claude/rules/knit-architecture.md (matriz de comunicação)."):format(
								basename,
								othersPath,
								system.name,
								call.expr,
								system.initPath
							),
						})
					end
				end
			end
		end
	end
end

-- ===== Main =====

local files = collectSourceFiles()

local requireIndex = {}
for path, content in files do
	requireIndex[path] = extractRequireCalls(content)
end

local systems = discoverSystems(files)
local violations = {}

for _, system in systems do
	checkAccessorMutatorRule(system, requireIndex, violations)
	checkOthersRule(system, files, requireIndex, violations)
end

if #violations > 0 then
	table.sort(violations, function(a, b)
		if a.file ~= b.file then
			return a.file < b.file
		end
		return a.line < b.line
	end)

	for _, v in violations do
		print(("%s:%d — [%s] %s"):format(v.file, v.line, v.rule, v.message))
	end
	print(("\n%d violação(ões) em framework/src/**."):format(#violations))
	process.exit(1)
else
	print("check-architecture: OK — 0 violações.")
	process.exit(0)
end

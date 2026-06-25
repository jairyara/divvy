--- Crea un archivo (o carpeta) desde el panel de yazi y, si es archivo,
--- lo abre acto seguido en el editor de divvy (vía el opener `edit` -> divvy-open).
--- Termina el nombre en "/" para crear una carpeta (no se abre, solo se entra).

-- cx solo es accesible en contexto sincrono: envolvemos el acceso al cwd.
local get_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

local function notify_err(content)
	ya.notify { title = "Crear y abrir", content = content, timeout = 5, level = "error" }
end

return {
	entry = function()
		local name, event = ya.input {
			pos = { "top-center", y = 3, w = 50 },
			title = "Crear y abrir  (termina en / = carpeta):",
		}
		if event ~= 1 or not name or name == "" then
			return
		end

		local cwd = get_cwd()
		local url = cwd .. "/" .. name
		local is_dir = name:sub(-1) == "/"

		-- crea las carpetas padre si el nombre lleva subrutas (a/b/c.txt)
		local parent = url:match("(.*)/[^/]+/?$")
		if parent and parent ~= "" then
			Command("mkdir"):arg("-p"):arg(parent):output()
		end

		if is_dir then
			Command("mkdir"):arg("-p"):arg(url):output()
		else
			local _, err = Command("touch"):arg(url):output()
			if err then
				notify_err(tostring(err))
				return
			end
		end

		-- coloca el cursor sobre lo recien creado
		ya.emit("reveal", { url })

		-- abre el archivo (las carpetas no se abren, solo se revelan)
		if not is_dir then
			ya.emit("open", { hovered = true })
		end
	end,
}

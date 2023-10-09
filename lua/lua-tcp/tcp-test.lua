local typescript_port = 8081

-------------------------------------------- TCP server

local function create_server(host, port, on_connect)
    local server = vim.loop.new_tcp()

    server:bind(host, port)

    server:listen(128, function()
        local sock = vim.loop.new_tcp()
        server:accept(sock)
        on_connect(sock)
    end)

    return server
end

local server = create_server("0.0.0.0", 0, function(sock)
    sock:read_start(function(_, chunk)
        if chunk then
            vim.schedule(function() print(chunk) end)
        else
            sock:close()
        end
    end)
end)

local nvim_port = server:getsockname().port

-------------------------------------------- TCP client

local client = vim.loop.new_tcp()
local connect_message_sent = false
local connect_message = { type = "connection-request-from-lua", port = nvim_port }

local send_connect_message = function()
    if not connect_message_sent then
        vim.loop.write(client, vim.json.encode(connect_message))
        connect_message_sent = true
    end
end

vim.loop.tcp_connect(client, "0.0.0.0", typescript_port, function() send_connect_message() end)

-------------------------------------------- Clean up

local signal_augroup = vim.api.nvim_create_augroup("tcp-test signal_augroup", { clear = true })

vim.api.nvim_create_autocmd({ "FocusGained", "VimEnter", "UIEnter", "BufEnter" }, {
    pattern = "*",
    group = signal_augroup,
    callback = function() send_connect_message() end,
})

vim.api.nvim_create_autocmd({ "FocusLost", "VimLeave", "UILeave" }, {
    pattern = "*",
    group = signal_augroup,
    callback = function() connect_message_sent = false end,
})

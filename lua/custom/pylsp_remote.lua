-- lua/custom/pylsp_remote.lua
local M = {}

function M.setup(capabilities)
  local lspconfig = require 'lspconfig'
  local configs = require 'lspconfig.configs'
  local util = require 'lspconfig.util'

  local host = vim.g.pylsp_remote_host or '127.0.0.1'
  local port = tonumber(vim.g.pylsp_remote_port or 2087) or 2087

  -- Create the transport ONCE (do not wrap in a function)
  local transport = vim.lsp.rpc.connect(host, port)

  if not configs.pylsp_remote then
    configs.pylsp_remote = {
      default_config = {
        name = 'pylsp_remote',
        cmd = transport, -- transport object, not a function
        filetypes = { 'python' },
        root_dir = function(fname)
          return util.root_pattern('pyproject.toml', 'setup.cfg', 'setup.py', 'requirements.txt', '.git')(fname)
            or util.find_git_ancestor(fname)
            or util.path.dirname(fname)
        end,
      },
    }
  end

  lspconfig.pylsp_remote.setup { capabilities = capabilities }

  -- Autostart for Python buffers
  local grp = vim.api.nvim_create_augroup('pylsp-remote-autostart', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = grp,
    pattern = 'python',
    callback = function()
      vim.defer_fn(function()
        local bufnr = vim.api.nvim_get_current_buf()
        for _, c in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
          if c.name == 'pylsp_remote' then
            return
          end
        end
        pcall(vim.cmd, 'LspStart pylsp_remote')
      end, 0)
    end,
  })

  ---------------------------------------------------------------------------
  -- :PylspWhat  — show simple status (endpoint, attached?, probe)
  ---------------------------------------------------------------------------
  local function tcp_probe(cb)
    local uv = vim.uv or vim.loop
    local sock = uv.new_tcp()
    if not sock then
      return cb(false, 'no tcp handle')
    end
    local finished = false
    local timer = uv.new_timer()
    timer:start(500, 0, function()
      if finished then
        return
      end
      finished = true
      timer:stop()
      timer:close()
      pcall(function()
        sock:close()
      end)
      cb(false, 'timeout')
    end)
    sock:connect(host, port, function(err)
      if finished then
        return
      end
      finished = true
      timer:stop()
      timer:close()
      if err then
        pcall(function()
          sock:close()
        end)
        return cb(false, err)
      end
      pcall(function()
        sock:close()
      end)
      cb(true)
    end)
  end

  vim.api.nvim_create_user_command('PylspWhat', function()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype or ''
    local attached = false
    for _, c in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
      if c.name == 'pylsp_remote' then
        attached = true
        break
      end
    end
    vim.notify(
      ('pylsp_remote\n  filetype : %s\n  endpoint : %s:%d\n  attached : %s\n  log file : %s\n  probing…'):format(
        ft,
        host,
        port,
        attached and 'YES' or 'NO',
        vim.lsp.get_log_path()
      ),
      vim.log.levels.INFO,
      { title = 'PylspWhat' }
    )
    tcp_probe(function(ok, err)
      vim.schedule(function()
        vim.notify(
          ok and 'Probe: reachable ✅' or ('Probe: unreachable ❌  (' .. tostring(err) .. ')'),
          ok and vim.log.levels.INFO or vim.log.levels.WARN,
          { title = 'PylspWhat' }
        )
      end)
    end)
  end, {})
end

return M

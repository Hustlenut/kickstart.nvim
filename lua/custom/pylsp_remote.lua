local M = {}

function M.setup()
  local lspconfig = require 'lspconfig'
  local configs = require 'lspconfig.configs'
  local util = require 'lspconfig.util'

  -- Read endpoint once at setup time
  local host = vim.g.pylsp_remote_host or '127.0.0.1'
  local port = tonumber(vim.g.pylsp_remote_port or 2087) or 2087

  -- IMPORTANT: pass the RPC object directly, NOT a function
  local rpc = vim.lsp.rpc.connect(host, port)

  if not configs.pylsp_remote then
    configs.pylsp_remote = {
      default_config = {
        name = 'pylsp_remote',
        cmd = rpc, -- <— this is the fix
        filetypes = { 'python' },
        root_dir = function(fname)
          return util.root_pattern('pyproject.toml', 'setup.cfg', 'setup.py', 'requirements.txt', '.git')(fname) or util.path.dirname(fname)
        end,
      },
    }
  end

  lspconfig.pylsp_remote.setup {
    capabilities = (function()
      local ok, blink = pcall(require, 'blink.cmp')
      return ok and blink.get_lsp_capabilities() or vim.lsp.protocol.make_client_capabilities()
    end)(),
  }

  -- Start automatically on Python buffers
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('pylsp-remote-autostart', { clear = true }),
    pattern = 'python',
    callback = function()
      vim.api.nvim_cmd({ cmd = 'LspStart', args = { 'pylsp_remote' } }, {})
    end,
  })

  -- Status popup
  vim.api.nvim_create_user_command('PylspWhat', function()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype or ''
    local cwd = vim.fn.getcwd()
    local log = vim.lsp.get_log_path()

    local attached = false
    for _, c in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
      if c.name == 'pylsp_remote' then
        attached = true
        break
      end
    end

    local lines = {
      'pylsp_remote:',
      ('  filetype : %s'):format(ft),
      ('  endpoint : %s:%d'):format(host, port),
      ('  attached : %s'):format(attached and 'YES' or 'NO'),
      ('  log file : %s'):format(log),
    }

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'markdown'
    vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      style = 'minimal',
      border = 'rounded',
      title = 'Pylsp Status',
      title_pos = 'center',
      width = math.max(48, math.floor(vim.o.columns * 0.5)),
      height = #lines + 2,
      row = math.floor((vim.o.lines - (#lines + 2)) / 2 - 1),
      col = math.floor((vim.o.columns - math.max(48, math.floor(vim.o.columns * 0.5))) / 2),
    })
  end, {})

  -- Manual retry
  vim.api.nvim_create_user_command('PylspRetry', function()
    vim.notify(('Trying pylsp_remote at %s:%d…'):format(host, port), vim.log.levels.INFO, { title = 'LSP' })
    vim.api.nvim_cmd({ cmd = 'LspStart', args = { 'pylsp_remote' } }, {})
  end, {})
end

return M

-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

return {
  'pmizio/typescript-tools.nvim',
  requires = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
  config = function()
    local nvim_lsp = require 'lspconfig'
    local on_attach = function(client, bufnr)
      -- format on save
      if client.resolved_capabilities.document_formatting then
        vim.api.nvim_create_autocmd('BufWritePre', {
          group = vim.api.nvim_create_augroup('Format', { clear = true }),
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.formatting_seq_sync()
          end,
        })
      end
    end

    -- TypeScript
    nvim_lsp.tsserver.setup {
      on_attach = on_attach,
      filetypes = { 'typescript', 'typescriptreact', 'typescript.tsx', 'javascript', 'javascriptreact' },
      cmd = { 'typescript-language-server', '--stdio' },
    }

    require('typescript-tools').setup {}
  end,
}

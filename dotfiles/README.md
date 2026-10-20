# Captura inicial de configurações

Referências inspecionadas em 2026-10-20. Nenhum arquivo é aplicado ou carregado
automaticamente. Não são uma configuração completa pronta para instalação.

- `common/zsh/`: preferências de Zsh, Oh My Zsh e carregamento do NVM.
  O helper gerado `~/.local/bin/env` foi substituído pelo seu pequeno ajuste de
  PATH equivalente. Oh My Zsh e NVM deverão existir nos destinos permanentes.
- `common/git/gitconfig.example`: apenas placeholders de identidade; não aplicar
  antes de preencher localmente. Nenhum alias Git pessoal foi encontrado.
- `common/vscode/`: preferências do editor sem o dicionário pessoal.
- `macos/vscode/`: fragmentos exclusivos do macOS; em uma futura aplicação,
  mesclar suas chaves sobre as preferências comuns, sem substituir o arquivo
  inteiro. O terminal `fish` e `FIG_NEW_SESSION` precisam de revisão.
- `common/ai/codex-preferences.toml`: somente modelo e esforço de raciocínio;
  não contém permissões, projetos, MCP, autenticação ou estado da interface.

`default` representa as configurações principais do VS Code; `profile-01`
representa o único profile adicional com settings e extensões encontrado.
Os nomes visíveis dos profiles não foram recuperados de bancos de estado privados.
Os dois conjuntos devem continuar separados.

Os inventários em `../inventory/macos/` são observações, não listas de instalação,
políticas de versões ou seleção de ferramentas essenciais.
Consulte o [relatório](../docs/macos-initial-capture.md) antes de reutilizar.

Não há instalador, symlink ou integração com chezmoi nesta captura.

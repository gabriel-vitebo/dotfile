# Fase 6 — auditoria prévia

Data: 2026-10-22. Auditoria anterior à implementação; conclusão registrada ao final.

## Base encontrada

Foram revisados `docs/dotfiles.md`, `docs/dotfiles-migration-plan.md`,
`lib/dotfiles.sh`, `lib/cli.sh`, `bin/workspace`, o manifesto, o empacotamento
do instalador e os testes de dotfiles. A Fase 5 está implementada na árvore
de trabalho, com alterações previamente preparadas no staging. Elas foram
preservadas; o HEAD é `e0ebd0226328b9a4551bd344fa8bb1bcc6126401`.

`bash tests/dotfiles-init.sh` passou nos 16 grupos. Confirmou inicialização,
reutilização sem alterações, recusa, dry-run, validações, journals, hooks
bloqueados e funcionamento da CLI instalada após exclusão do clone inicial.
O teste usa Git real com origem local e mocks de rede; não confirma acesso
real ao GitHub nem autenticação. A simulação Ubuntu não é validação nativa.

## Contratos que o sync precisa preservar

- Checkout padrão: `~/.local/share/config-workplace-dotfiles/repository`.
  A implementação existente também respeita XDG_DATA_HOME e CW_DOTFILES_REPO.
  A raiz da CLI, o clone inicial e caminhos temporários são recusados.
- Origem aprovada: `https://github.com/gabriel-vitebo/dotfile.git`.
  Init usa o commit fixo acima, em detached HEAD, sem selecionar uma branch.
- Allowlist: `manifests/terminal/zshrc`, `manifests/git.config` e
  `manifests/vscode-settings.json`. O manifesto é validado pela CLI instalada.
- Ownership: symlink absoluto exato para o terminal e prefixo de include
  exato para Git. Não existe banco geral de ownership. VS Code é manual.
- Estado: `${XDG_STATE_HOME:-$HOME/.local/state}/config-workplace/dotfiles`,
  privado e separado do checkout. Lock por mkdir, journal por operação e
  backups preservados. Falhas não provocam restauração destrutiva.
- Conflitos preservam os arquivos; confirmação é negativa por padrão.
  Snapshots são revalidados. Não há proteção contra toda concorrência externa.
- Git de init isola configurações pessoais e variáveis GIT_*, desativa hooks
  e templates e não herda credential helpers. Publicação autenticada ainda
  não tem um fluxo implementado.

## Decisão de branch

O pedido da Fase 6 exige remote e branch explicitamente aprovados. O remote
estava definido; a branch ainda não havia sido informada na auditoria inicial. Não inferir `main`, `master`,
o HEAD remoto ou a branch do clone inicial. Foi solicitada ao usuário a
branch autorizada, e ele aprovou explicitamente **main**. A seleção inicial no checkout deve ser manual, pois o
pedido proíbe checkout automático de branches.

## Pontos de implementação identificados

A validação de init exige que as três fontes coincidam com HEAD; portanto,
não pode ser reutilizada sem separação para validar um checkout com edições
locais destinadas a commit. Preservar suas verificações estruturais e manter
o contrato de init intacto.

Atualizar as fontes do terminal/Git muda o conteúdo observado pelos vínculos
já existentes, mesmo sem escrever em `.zshrc` ou `.gitconfig`. O preview da
atualização precisa informar esse efeito. Configurações pessoais e settings
do VS Code continuam fora das escritas de sync.

A revisão de publicação precisa abranger todos os commits de saída, inclusive
blobs intermediários, não somente o diff final. Conteúdo suspeito deve bloquear
a exibição do diff para evitar vazamento. Índice previamente ocupado, operações
Git pendentes, alterações fora da allowlist, commits mistos e divergências
precisam resultar em REVIEW, preservando os dois lados.

Após a aprovação de main, os comandos de sync e seus testes foram implementados
em `lib/dotfiles.sh` e `tests/dotfiles-sync.sh`. O contrato final está em
`docs/dotfiles.md`. Não houve commit/push no repositório de trabalho, acesso ao
GitHub ou alteração do HOME pessoal. Commits/pushes dos testes usam somente fixtures
e remotes locais.

Validação após implementação: 19 grupos de sync e 166 grupos de regressão
aprovados, mais sintaxe Bash e verificação de whitespace. O staging anterior
permaneceu intacto; a entrega da Fase 6 está na árvore de trabalho, sem commit.

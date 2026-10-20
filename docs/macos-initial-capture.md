# Inventário e captura inicial do macOS

Data: 2026-10-20. Escopo: descoberta e captura seletiva, sem implementação da
CLI, do módulo `terminal` ou de instaladores. O README original foi preservado.
O diretório de trabalho não tinha `.git`; não foi inicializado um repositório.

## Método e limites

Foram lidos arquivos conhecidos, sem carregar os shells pessoais ou executar
seus comandos. Arquivos candidatos foram inspecionados antes da captura;
busca por marcadores sensíveis complementou a revisão, sem garantir ausência
de todo segredo possível. Identidade Git, caminhos pessoais e estado privado
não foram incluídos nos artefatos.

Não foram executados `brew`, `code`, `nvm`, instaladores, atualizações ou
autenticações. Homebrew foi inventariado pelos diretórios locais `Cellar` e
`Caskroom` no prefixo Intel padrão; isso pode incluir versões antigas e resíduos,
não comprova funcionamento, instalação ativa ou seleção explícita pelo usuário.
Não foi criado Brewfile nem copiada instalação de Node.

As extensões foram extraídas somente dos campos identificador e versão dos
registros `extensions.json`, excluindo caminhos, UUIDs e metadados. Esses
registros não comprovam quais extensões estão habilitadas em uma sessão.
Não houve erro de acesso nos arquivos candidatos encontrados. A descoberta foi
limitada aos caminhos convencionais; não cobre configurações remotas, canais
alternativos do VS Code, todos os clientes de IA ou diretórios personalizados.

## Encontrado e capturado

| Origem | Resultado |
| --- | --- |
| `~/.zshrc` | Oh My Zsh em `$HOME/.oh-my-zsh`, tema `robbyrussell`, plugin `git`, NVM e helper de PATH; captura reduzida em `dotfiles/common/zsh/zshrc` |
| `~/.zprofile` | Prepend de `$HOME/.local/bin`, capturado em `common/zsh/zprofile`; marcadores do instalador removidos |
| `~/.local/bin/env` | Inspecionado; lógica de PATH incorporada ao fragmento Zsh para remover dependência desse helper |
| `~/.gitconfig` | Apenas nome e email; substituídos por placeholders em `common/git/gitconfig.example`; sem aliases ou includes |
| `~/Library/Application Support/Code/User/settings.json` | Preferências em `common/vscode/default/settings.json`; chaves `.osx` em `macos/vscode/default/settings.json` |
| Settings do profile adicional | Captura separada como `profile-01`, com a mesma separação comum/macOS |
| `~/.vscode/extensions/extensions.json` | 44 identificadores e versões no inventário `vscode-default-extensions.tsv` |
| Registro de extensões do profile adicional | 7 extensões Java no inventário `vscode-profile-01-extensions.tsv` |
| Homebrew | Fórmulas e casks observados em `inventory/macos/homebrew.tsv`, incluindo versões coexistentes |
| NVM | 7 versões e alias padrão `22` em `inventory/macos/nvm.json`; única versão instalada correspondente: `v22.14.0` |
| `~/.codex/config.toml` | Somente preferências de modelo e esforço em `common/ai/codex-preferences.toml` |

O arquivo Zsh preserva o carregamento condicional de `nvm.sh` e
`bash_completion`; ambos existem. O conteúdo das instalações não foi copiado
nem executado. O PATH foi normalizado com `$HOME`. Não foram encontrados aliases
pessoais ativos nos arquivos de shell inspecionados; o plugin `git` fornece seus
próprios aliases, que não foram duplicados. Aliases definidos apenas em sessões
ativas não foram consultados.

## Ausentes, ignorados e pendências

- Ausentes: `~/.zshenv`, `~/.zlogin`, `~/.aliases`, `~/.zsh_aliases`,
  `~/.p10k.zsh`, `~/.vimrc`, `~/.vim/`, `~/.config/nvim/init.vim`,
  `~/.config/nvim/init.lua` e `~/.config/git/config`.
  Não foram criados diretórios vazios para Vim ou Powerlevel10k.
- Oh My Zsh custom: apenas arquivos de exemplo de plugin, tema e customização;
  foram inspecionados e ignorados. O tema de exemplo não é o tema selecionado.
  Não foram copiados o framework, plugins ou temas distribuídos por terceiros.
- VS Code: nenhum `keybindings.json` no conjunto principal ou no profile
  adicional; nenhum snippet no diretório encontrado. Não há atalhos pessoais
  capturados. O diretório `builtin/agents` existe, mas contém estado de agentes,
  sem settings ou keybindings pessoais nesses caminhos.
- `cSpell.userWords`: omitido dos dois arquivos por poder revelar termos de
  projetos pessoais ou internos. Pendente de seleção manual; conteúdo não
  reproduzido no repositório.
- `terminal.integrated.defaultProfile.osx = fish` e `FIG_NEW_SESSION = 1`:
  capturados somente no fragmento macOS. Confirmar necessidade e disponibilidade
  de Fish/Fig; o shell escolhido no VS Code difere do Zsh observado.
- Preferências como smart commit, ausência de confirmação de sync, avisos de
  rebase e exclusão no editor foram preservadas como observação. Revisar antes
  de aplicar em outra máquina, pois reduzem confirmações.
- Codex: tabelas de projetos confiáveis, caminhos, estado de onboarding e
  habilitação de plugin foram omitidos. A configuração MCP de navegador usa
  `npx`, pacote `@latest` e conexão automática; fica pendente de revisão de
  permissões, versão e finalidade, sem copiar o bloco executável.
- `~/.codex/AGENTS.md` existe, mas está vazio. Configurações convencionais de
  Claude (`settings.json`, `CLAUDE.md`), Gemini e OpenCode não foram encontradas.
  Preferências de IA presentes nos settings do VS Code foram preservadas.
- Sessões, históricos, caches, logs, backups, bancos `state.vscdb`, armazenamento
  global, arquivos `chatLanguageModels.json`, autenticação, credenciais e chaves
  privadas não foram importados. Dados de sessões e plugins do Claude ficaram
  fora do escopo; não foram copiados diretórios completos de ferramentas de IA.
- Nomes visíveis dos profiles e o significado do profile adicional precisam de
  confirmação manual. A seleção de extensões sugere uso com Java; não prova o
  nome ou finalidade escolhidos pelo usuário.

## Compatibilidade macOS e Ubuntu

- Zsh, Oh My Zsh, tema `robbyrussell`, plugin `git`, PATH com `$HOME` e NVM
  são candidatos portáteis, condicionados à instalação das dependências.
  Nenhuma compatibilidade em execução foi comprovada nesta etapa.
- O local do VS Code no macOS é `~/Library/Application Support/Code/User`;
  no Ubuntu convencional é `~/.config/Code/User`, podendo variar por distribuição
  do aplicativo ou configuração XDG. Fragmentos `.osx` não devem ser aplicados
  ao Ubuntu; um terminal Linux deverá ser escolhido explicitamente.
- Pacotes Homebrew, casks e versões de bibliotecas não têm correspondência
  automática com APT. O inventário inclui dependências transitivas.
- Extensões podem conter componentes por plataforma; copiar seus diretórios
  macOS para Ubuntu não é uma estratégia de instalação. As listas guardam
  identificadores para uma futura seleção, não binários.
- Homebrew também contém Node e NVM. Revisar precedência de PATH e origem
  desejada; o inventário não determina qual Node está ativo na sessão.
- O alias NVM `22` é estado observado, não política para máquinas novas.
  A política de LTS atual do README continua válida.

## Recomendações para o futuro módulo terminal

1. Separar detecção de dependências, instalação e aplicação dos dotfiles;
   apresentar diff e preservar alterações locais com backup antes de escrever.
2. Instalar Oh My Zsh, tema e plugins em destinos permanentes; aplicar cópias
   independentes dos arquivos, sem links ou referências ao clone (RN-001).
3. Usar como ponto inicial o tema e plugin efetivamente encontrados; deixar
   Powerlevel10k, fontes extras e uma configuração de Vim para escolha posterior.
4. Definir a responsabilidade do NVM entre `initial dev` e `terminal`, evitando
   carga duplicada, conflito com Node do Homebrew e troca silenciosa de major.
5. Tornar aplicação de PATH e blocos de shell idempotente e validar a interação
   entre shells login/interativos e completion.
6. Manter adaptadores por sistema operacional. Testar em Ubuntu limpo,
   reaplicação e exclusão do clone antes de afirmar suporte.
7. Aplicar profiles e extensões do editor em etapa própria, após revisão da
   seleção; solicitar identidade Git localmente e não gravá-la no repositório.

## Validação desta captura

Arquivos JSON foram verificados por parsing, os fragmentos Zsh por análise de
sintaxe sem execução e o template Git por leitura sem includes. Os artefatos
foram verificados quanto a caminhos pessoais, emails e marcadores de segredos.
Hashes dos dez arquivos de origem usados na captura foram comparados antes e
depois da escrita. Não foram realizados testes de instalação ou de execução das
configurações. Nenhum arquivo foi adicionado ao índice Git, commitado ou enviado.

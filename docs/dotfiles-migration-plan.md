# Plano de migração para Workspace Dev + Dotfiles + Git Sync

Data da auditoria: 2026-10-22. Base inspecionada: commit `45ceaeb`, árvore inicialmente sem alterações. O nome público atual é `config-workplace`; o diretório local se chama `config-wrokplace`. Nenhum deles será renomeado nesta fase.

**Auditoria original de planejamento; progresso da implementação registrado na seção 13.** Foram inventariados os 48 arquivos rastreados e examinados código, testes, manifestos, capturas e documentação. Não foram executados bootstrap, módulos, instaladores, autenticação ou configurações pessoais. Java permanece congelado até a conclusão da migração.

## 1. Diagnóstico

O projeto já tem uma base aproveitável: CLI Bash 3.2, bootstrap com lista explícita de arquivos, instalação permanente, detecção antes de instalação, confirmação, backups e testes com fixtures/mocks. Não há motivo para reconstruí-lo ou adotar Stow/Chezmoi.

A arquitetura atual separa razoavelmente instalação de ferramentas e bibliotecas, mas mistura instalação e aplicação de preferências em `terminal` e `initial dev`. As configurações são copiadas ou editadas no destino; não existe gerenciador de links, registro de propriedade de arquivos ou sincronização Git. A pasta `dotfiles/` **já existe**, como captura seletiva, sem ativação automática. Ela não é copiada pelo bootstrap.

O principal conflito arquitetural está no README: RN-001 exige independência do clone e prescreve cópias, enquanto a migração exige links. A proposta preserva o resultado de RN-001: o clone de desenvolvimento será descartável, mas os links apontarão a um **repositório permanente de configurações**, separado tanto do clone original quanto da instalação substituível da CLI. Programas, runtimes, plugins e temas continuarão fora desse repositório.

Os estados abaixo expressam a auditoria estática, não certificação em máquinas reais:

- **Completo:** implementação presente para o escopo delimitado; aceitação de instalação real pode continuar pendente.
- **Parcial:** há artefatos ou fluxos implementados, com entrega/validação pendente.
- **Necessitando refatoração:** funciona no modelo atual, mas precisa mudar para o novo contrato.
- **Ausente:** não há implementação correspondente.

## 2. Inventário completo

### 2.1. Comandos existentes

| Entrada | Estado | Comportamento observado |
| --- | --- | --- |
| `./install.sh` | Necessitando refatoração | Instala apenas a CLI e seus recursos em `~/.local/share/config-workplace`, cria lançador, faz backup/rollback e oferece ajuste de PATH. Não é instalador geral de ferramentas. |
| `config-workplace`, `help`, `--help` | Completo | Ajuda global; nenhum argumento equivale a ajuda. |
| `config-workplace --version` | Completo | Retorna `0.2.2`, mesmo com terminal/Java já presentes. |
| `config-workplace list` | Completo | Lista terminal, initial dev e Java; anuncia docker/env como planejados. |
| `config-workplace initial dev [--dry-run] [--approve-node-change]` | Necessitando refatoração | Git, gh, NVM, Node LTS, npm, pnpm, VS Code, extensões, settings e utilitários. Manter instalações; separar aplicação das preferências. |
| `config-workplace terminal [--dry-run] [--change-shell]` | Necessitando refatoração | Zsh, Vim, Git, Oh My Zsh, tema robbyrussell, plugin git, fragmento e integração no startup. |
| `config-workplace java [--dry-run]` | Parcial — congelado | Há implementação substancial de JDK, Maven, Gradle, SDKMAN! e extensões, além de testes. Não equivale à conclusão operacional relatada pelo usuário. |
| `workspace ...`, `dotfiles link/status/unlink`, `sync` | Ausente | Nova interface a implementar preservando a entrada antiga. |
| `docker`, `env`, `doctor`, `status`, `review`, `monitor`, `update` | Ausente | Documentados como futuro; rejeitados pela CLI atual. `status` global não existe nem é sinônimo de `dotfiles status`. |

Não existem opções globais funcionais `--yes`/`--force`, nem `--help` específico por módulo. Os módulos são invocados individualmente pela CLI; os arquivos em `modules/` definem funções e não são executáveis independentes completos.

### 2.2. Código, dados e documentação

| Arquivos/componente | Estado | Diagnóstico e destino |
| --- | --- | --- |
| `bin/config-workplace`, `lib/cli.sh` | Necessitando refatoração | Preservar dispatcher e comandos; adicionar rotas e lançador `workspace`. |
| `install.sh` | Necessitando refatoração | Reutilizar staging, lock por `mkdir`, validação, backup e recuperação. A allowlist aparece em validação, cópia, checksums e reconhecimento de arquivos: centralizar futuramente sem ampliar a captura. |
| `lib/setup.sh` | Completo no escopo atual | Logs, confirmação, plataforma, HTTPS, pacotes Git/gh, NVM e política LTS. `cw_load_nvm` carrega código NVM até na sondagem; dry-run dos módulos não deve ser tratado como auditoria puramente estática. |
| `lib/dev-safety.sh` | Necessitando refatoração | Bloqueia destino/ancestrais simbólicos e caminhos sob `CW_ROOT`; também edita PATH. Manter proteção para instaladores e criar validação específica para links gerenciados. |
| `lib/dev-tools.sh`, `lib/pnpm-metadata.js` | Completo no escopo atual | Sondagem, utilitários e pnpm isolado; JS valida metadados sem dependências npm adicionais. Não substituir por nova infraestrutura. |
| `platforms/dev-install.sh` | Completo no escopo atual | VS Code via APT/Homebrew; lançador `code` pode ser symlink ao aplicativo instalado. Esse link não é dotfile. |
| `lib/vscode.sh`, `lib/vscode-settings.js` | Necessitando refatoração | Instala extensões por aprovação; edita JSONC por chave, preserva comentários, verifica concorrência e recusa symlinks. Separar ownership dos settings e instalação de extensões. |
| `lib/terminal-detect.sh` | Parcial | Detecção estática conservadora; reconhece especificamente robbyrussell. Tema não reconhecido significa preservar/revisar, não substituir. |
| `lib/terminal-files.sh` | Necessitando refatoração | Diff, cópia/renderização, backup, validação Zsh, lock e rechecagem. Também serve à cópia de assets de Oh My Zsh: não converter todas as suas chamadas em links. |
| `platforms/terminal-install.sh` | Completo no escopo atual | Clona Oh My Zsh em staging e move ao destino permanente; recupera assets ausentes por cópia. Preservar instaladores separados dos dotfiles. |
| `modules/initial-dev.sh`, `modules/terminal.sh` | Necessitando refatoração | Orquestração atual reutilizável; evitar dois escritores para o mesmo arquivo após migração. |
| `modules/java.sh`, `lib/java-detect.sh`, `lib/java-versions.sh`, `lib/java-sdkman.sh`, `lib/java-vscode.sh` | Parcial — congelado | Detecção/origens, seleção dinâmica, isolamento SDKMAN!, seis extensões candidatas. Aceitação real pendente; ativação de shell manual; profiles não importados. Não avançar Java nesta migração. |
| `manifests/vscode-extensions.txt` | Completo | Duas extensões base: Prettier e Error Lens; continuar manifesto de instalação. |
| `manifests/vscode-settings.json` | Necessitando refatoração | Seis preferências candidatas com aprovação por chave; não é um settings completo pronto para substituir o local. |
| `manifests/terminal/zshrc`, `manifests/terminal/plugins.txt` | Necessitando refatoração | Fragmento aprovado difere da captura em `dotfiles/`; tornar o fragmento fonte canônica futura, preservando semântica e tema. Lista de plugin continua manifesto. |
| `manifests/java-extensions.txt` | Parcial — congelado | Seis IDs candidatos; pack excluído; aprovação individual. |
| `dotfiles/common/zsh/{zshrc,zprofile}` | Parcial | Capturas; não aplicar cegamente. `zprofile` faz prepend direto; manifesto do terminal evita duplicação de PATH e respeita caminhos já definidos. |
| `dotfiles/common/git/gitconfig.example` | Parcial | Apenas placeholders de identidade. Não vincular a `.gitconfig` nem inventar aliases. |
| `dotfiles/common/vscode/{default,profile-01}/settings.json` | Parcial | Capturas amplas, com preferências de IA, temas/extensões e redução de confirmações; não têm aprovação geral para ativação. |
| `dotfiles/macos/vscode/{default,profile-01}/settings.json` | Parcial | Fragmentos Fish/Fig exclusivos do macOS; não são settings completos nem devem alcançar Ubuntu. |
| `dotfiles/common/ai/codex-preferences.toml` | Parcial | Fragmento de preferências; manter fora da ativação. Não substituir configuração completa da ferramenta. |
| `inventory/macos/{homebrew.tsv,nvm.json,vscode-default-extensions.tsv,vscode-profile-01-extensions.tsv}` | Completo como captura | Observações históricas, não manifestos de instalação. NVM: sete versões; extensões: 44 no padrão e sete no perfil adicional; Homebrew inclui dependências e versões coexistentes. |
| `tests/{bootstrap,initial-dev,phase-2.2,terminal,java}.sh` | Parcial | Cinco suítes Bash com mocks, fixtures e HOME isolado; não há testes de links/sync, CI configurada ou aceitação real registrada. |
| `README.md` | Necessitando refatoração | Mistura produto futuro, implementação e decisões incompatíveis com links. Ver seção 10. |
| `docs/{macos-initial-capture,terminal,vscode-base,java}.md`, `dotfiles/README.md` | Parcial | Evidências úteis e limites explícitos; atualizar orientação arquitetural sem apagar o histórico da captura. |
| `.gitignore`, registro de links, transações de dotfiles, sync, armazenamento local de secrets | Ausente | Precisam ser introduzidos. Há `.git` local, mas nenhuma política versionada de ignore. |

### 2.3. Cópias e edições que exigem tratamento

| Origem/operação atual | Destino atual | Migração proposta |
| --- | --- | --- |
| `cw_terminal_file`, modo copy | `~/.config/config-workplace-terminal/zshrc` | Primeiro candidato a link por arquivo, apontando para fonte aprovada permanente. Conservar o caminho legado para não quebrar o bloco de startup. |
| `cw_terminal_file`, modo startup | `${ZDOTDIR:-$HOME}/.zshrc` | Hoje antepõe bloco de três linhas. Inicialmente preservar o arquivo pessoal e o bloco reconhecido; linkar apenas o fragmento. Gestão do `.zshrc` inteiro exige revisão explícita posterior. |
| Bootstrap e `cw_local_path` | `.zprofile`, `.bash_profile`, `.bash_login` ou `.profile` | Hoje fazem append com backup. Se não gerenciado, manter fluxo conservador; se gerenciado, detectar e encaminhar à fonte aprovada, sem append através do link. Não gerenciar todos os arquivos por padrão. |
| `cw_settings apply` | `Code/User/settings.json` | Edição granular, não cópia literal. Adesão ao link de arquivo completo é opcional e só após revisão integral; manter modo legado para arquivos não gerenciados. |
| `cw_terminal_install_asset` | Tema/plugin dentro de Oh My Zsh | **Continuar cópia/instalação permanente**, nunca link para staging ou repo de dotfiles. Não atualizar tema existente durante migração. |
| Bootstrap | CLI, bibliotecas, módulos e manifestos instalados | **Continuar cópia** da aplicação. Não vincular a CLI ao clone de trabalho. |
| Configuração de repositório gh/APT | `/etc/apt/keyrings`, `/etc/apt/sources.list.d` | Fora do escopo dotfiles; preservar instalação atual e suas verificações. |

### 2.4. Caminhos temporários e dependências

Não foi identificada, no fluxo padrão analisado, referência persistente intencional a diretório temporário. Isso é conclusão estática, não teste de instalação real.

- Bootstrap prepara arquivos em `~/.local/share/.config-workplace.*`, move-os ao destino e guarda backups permanentes; lançador resolve `../share/config-workplace`.
- NVM usa clone temporário validado e instala em `${NVM_DIR:-$HOME/.nvm}`; corrige o remote final para o upstream, removendo a origem temporária. Node permanece em `NVM_DIR/versions/node`.
- pnpm fica em `~/.local/share/config-workplace-pnpm`; lançador fixa o diretório do Node efetivo. Não depende do clone, mas remover aquele Node posteriormente pode quebrá-lo.
- VS Code baixa `.deb` temporário e instala pacote; no Mac o aplicativo fica em Applications. O link `~/.local/bin/code` aponta ao aplicativo.
- Oh My Zsh fica em `${ZSH:-$HOME/.oh-my-zsh}`; assets baixados temporariamente são copiados. Nenhum plugin deve apontar ao repo de configurações.
- SDKMAN! usa HOME temporário para proteger startup, com `SDKMAN_DIR` permanente. Esse contrato deve ser validado futuramente sem retomar Java agora.
- Temporários de JSONC/Zsh servem a validação e substituição; backups não têm registro central de rollback.
- `CW_ROOT` significa raiz do código em execução: no checkout é o clone; após bootstrap é a instalação permanente. As guardas não conhecem necessariamente o clone original. Não comprovam que caminhos personalizados estejam fora de outros checkouts ou de `/tmp`; NVM usa comparação textual e não a guarda completa de ancestrais. Endurecer a validação futura de destinos permanentes, sem alterar instalações existentes por inferência.
- Terminal usa `$HOME/.config` fixo para seu fragmento; VS Code Ubuntu respeita `XDG_CONFIG_HOME`; bootstrap usa `.local` fixo. Não mover esses caminhos silenciosamente ao introduzir XDG.

## 3. Arquitetura proposta

### 3.1. Três responsabilidades

1. **Workspace Dev:** mantém bootstrap, módulos, detecção e adaptadores de instalação existentes. Continua possível executar cada módulo sozinho; não invoca sync implicitamente.
2. **Dotfiles:** gerencia somente arquivos explicitamente cadastrados, com planejamento, diff, validação, backup, registro e rollback. Não instala dependências, temas ou plugins.
3. **Git Sync:** revisa mudanças versionadas e integra commits de forma controlada. Não executa scripts recebidos, não instala programas e não importa o HOME inteiro.

Manter Bash 3.2 como baseline da CLI e do gerenciador de links: arrays indexados, utilitários comuns, `readlink` simples, locks via `mkdir`. Evitar `readlink -f`, `ln -sfn`, `sed -i`, `stat` GNU obrigatório, arrays associativos ou `flock` como pré-requisito. JS existente fica restrito à necessidade de JSONC/metadados; links/status não podem exigir Node. Sem Stow, Chezmoi, Bats ou parser YAML obrigatório.

### 3.2. Estrutura incremental no projeto

```text
bin/config-workplace                 # preservado
bin/workspace                        # nova entrada compatível, futura
install.sh                           # bootstrap preservado
lib/{cli,setup,dev-safety,...}.sh      # bibliotecas atuais preservadas
lib/dotfiles-{paths,manifest,links,transaction}.sh  # futuras
lib/git-sync.sh                       # futura
modules/{initial-dev,terminal,java}.sh # existentes; Java congelado
modules/dotfiles.sh                   # futura
modules/sync.sh                       # futura
platforms/                           # adaptadores existentes
manifests/dotfiles-links.tsv          # futura allowlist declarativa
manifests/                           # listas de ferramentas/extensões
dotfiles/common/                      # capturas existentes preservadas
dotfiles/ubuntu/                      # somente quando houver conteúdo aprovado
dotfiles/macos/                       # capturas específicas preservadas
dotfiles/managed/terminal/zshrc        # futuro fragmento canônico aprovado
tests/{dotfiles,sync}.sh              # futuras suítes isoladas
inventory/                           # evidência, nunca entrada automática
docs/dotfiles-migration-plan.md       # este documento
.gitignore                           # futuro, antes de importar configurações
```

Não mover ou apagar capturas para fabricar uma estrutura limpa. Introduzir `managed/` distingue a fonte aprovada do material observado; depois reconciliar duplicações com mudanças revisáveis. Durante a transição, se o manifesto legado continuar empacotado, um teste deve exigir igualdade com a fonte canônica, evitando duas versões editáveis independentes.

### 3.3. Armazenamento permanente

| Local proposto | Responsabilidade e ciclo de vida |
| --- | --- |
| `~/.local/share/config-workplace` | Código instalado, substituível pelo bootstrap existente. |
| `${XDG_DATA_HOME:-$HOME/.local/share}/config-workplace-dotfiles/repository` | Checkout Git permanente, gravável pelo usuário; links apontam a arquivos aprovados sob `dotfiles/`. Nunca filho do diretório substituível da CLI. |
| `${XDG_STATE_HOME:-$HOME/.local/state}/config-workplace/dotfiles` | Registro, locks, transações, backups e revisão local; não versionado. |
| `${XDG_CONFIG_HOME:-$HOME/.config}/config-workplace` | Seleção local de destinos/perfis, caminhos permanentes, includes e secrets locais; não versionado. |
| NVM, SDKMAN!, Oh My Zsh, prefixo pnpm, Applications/APT | Instalações permanentes já utilizadas; não mover para dotfiles. |

Adotar inicialmente outro checkout do **mesmo repositório Git**, evitando cisão e migração de histórico nesta fase. Prepará-lo explicitamente com cópia Git independente (`--no-hardlinks`, sem alternates/shared object store) ou clone remoto autorizado. Verificar branch, commit e origem; alterações não commitadas do checkout inicial não podem sumir nem ser importadas implicitamente. Se a origem local descartável for usada para inicialização, não persistir esse caminho como remote de sync: selecionar URL remota revisada ou deixar operação offline sem remote.

Bootstrap continua sem rede e sem exigir Git novo. Preparação do repositório permanente será uma ação explícita do fluxo dotfiles (proposta: `workspace dotfiles init --from <checkout>`), exigindo Git existente e mostrando o destino. `link` exige inicialização concluída; não clona silenciosamente. A configuração local guarda a raiz; nunca resolve automaticamente pelo diretório corrente.

Remover o clone original ou a CLI não quebra os links. **Remover o repositório permanente quebra configurações vinculadas**: isso deve ser dito claramente. Antes de removê-lo, `unlink` deve materializar cópias ou restaurar backups. A nova RN-001 precisa diferenciar clone descartável e armazenamento permanente; não prometer independência de toda fonte de configuração.

## 4. Estratégia de links simbólicos

### 4.1. Allowlist e propriedade

Manifesto TSV versionado: `id`, `platform`, `source-relative`, `destination-key`, `validator`. Interpretar como dados, nunca `source`/`eval`. Destinos simbólicos como `terminal-fragment`, `zsh-startup` e `vscode-default` são resolvidos por adaptador; não executar expansão arbitrária de variáveis do manifesto.

Regras obrigatórias:

- Fonte deve ser arquivo regular aprovado sob `repository/dotfiles/`; recusar travessia `..`, fonte simbólica, caminho vazio e duplicação de destino. Não usar glob que ative arquivos recém-adicionados automaticamente.
- Destino deve ser arquivo exato autorizado dentro do HOME/caminhos locais selecionados. Recusar diretórios, arquivos especiais e ancestrais simbólicos desconhecidos. Canonicalizar a raiz confiável uma vez, inclusive aliases do sistema, e validar cada ancestral abaixo dela.
- Links absolutos para a raiz permanente oferecem diagnóstico simples e não dependem do diretório atual; mover essa raiz exige nova transação, nunca reparo automático pelo nome do arquivo.
- Registro local inclui schema, ID, fonte, destino, texto do link, hash, commit, transação e backup. Manifesto define intenção; registro define o que esta máquina realmente adotou. Registro não é script executável.
- Link correto com registro coerente é SKIP; nenhum novo backup ou alteração de mtime. Link correto sem registro requer adoção explícita. Link externo, inclusive quebrado, é conflito; não remover com `ln -sf`.
- Não flexibilizar `cw_safe_destination` globalmente. Criar verificação própria de ownership que permita somente o link final esperado, mantendo as guardas dos instaladores.
- Mudança no manifesto não autoriza automaticamente destino novo. Validar entradas removidas/renomeadas e apresentar desvinculação separada, sem apagar configuração antiga.

### 4.2. Primeiro alvo: fragmento do terminal

O piloto vincula `~/.config/config-workplace-terminal/zshrc`, mantendo o `.zshrc` pessoal como está. Se a cópia atual for idêntica ao fragmento aprovado, mostrar conversão, guardar backup e substituir por link após aprovação. Se divergir, mostrar conflito; preservar local por padrão. Não importar automaticamente seu conteúdo para Git.

O manifesto atual define robbyrussell e plugin git. Preservar esses bytes no piloto, sem reinstalar/atualizar tema. Uma captura histórica não prova qual tema está ativo hoje: se houver customização, inicialização alternativa, `ZDOTDIR` diferente ou tema não reconhecido, adiar a ativação até revisão. Não carregar o shell pessoal na detecção.

Bloco legado exato no início do `.zshrc` pode continuar usando o mesmo caminho. Bloco alterado/duplicado exige revisão. Se não existir integração, `link` apenas cria o link selecionado e informa que a ativação está pendente; não escreve startup silenciosamente. Não carregar Oh My Zsh duas vezes. Gestão futura do `.zshrc` completo é opt-in, com separação de preferências locais e secrets, preservando o tema existente.

### 4.3. VS Code, Git e secrets

VS Code é um caso de **arquivo inteiro versus edição granular**. Os fragmentos common/macOS não podem ser linkados ao mesmo destino nem um fragmento parcial substituir o JSONC atual. Inicialmente manter `cw_settings` no modo legado para arquivos não gerenciados. Para adoção futura, preparar um arquivo completo específico da plataforma/perfil, revisar todas as chaves/comentários e retirar dados locais/sensíveis antes de versionar. Não assumir suporte a includes de settings locais.

Se um settings contiver valores que precisam continuar exclusivamente locais e não houver separação suportada pelo aplicativo, ele fica fora da allowlist. Gestão parcial com o editor atual é preferível a vazar dados ou apagar chaves. No modo gerenciado, `initial dev` não escreve através do link nem o substitui por arquivo; informa que alterações devem ser revisadas no dotfile. Validar em teste real se o editor preserva o link ao salvar; se o substituir, `status` informa divergência, sem reimportação automática.

Mapear Ubuntu para `${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json` e macOS para `~/Library/Application Support/Code/User/settings.json`. `profile-01` é rótulo da captura, não ID real do VS Code: exigir mapeamento local explícito e deixar fora da primeira migração. IA e fragmentos Fish/Fig também ficam excluídos.

Git: não vincular `gitconfig.example`. Quando houver preferências portáteis aprovadas, usar include local para identidade e configurações por máquina; não copiar `.gitconfig` inteiro indiscriminadamente. Secrets ficam fora do repo, por exemplo `config-workplace/secrets.zsh` e `gitconfig.local`, com diretório 0700 e arquivo 0600. Só carregar includes explicitamente adotados; não criar segredos fictícios.

Introduzir `.gitignore` para backups, estado, arquivos locais, `.env` reais e credenciais, permitindo exemplos revisados. Ignore não protege arquivos já rastreados: revisar índice e histórico relevante antes de publicação. Bloquear staging de paths fora da allowlist e conteúdo suspeito; não imprimir valores de secrets em logs/diffs indiscriminados. Backups podem conter secrets e precisam permanecer locais/protegidos.

## 5. Contrato dos comandos futuros

Todos os comandos abaixo são propostas, ainda indisponíveis. `workspace` será lançador compatível da mesma CLI; `config-workplace` continuará aceitando os comandos antigos e poderá aceitar as mesmas novas rotas. Não substituir binário `workspace` já existente sem revisão/backup.

| Comando | Contrato |
| --- | --- |
| `workspace dotfiles link [--only <id>] [--dry-run]` | Resolver seleção local já aprovada, planejar todos os destinos e conflitos, mostrar alterações e confirmar antes de backup/link. Sem `--only`, usar apenas IDs adotados nesta máquina; primeira adesão exige seleção explícita. |
| `workspace dotfiles status [--only <id>]` | Somente leitura, offline e sem carregar shell. Mostrar fonte, destino, ownership, alterações locais e estado: correto, ausente, cópia igual, divergente, link externo, link quebrado, fonte ausente, registro inconsistente, transação pendente ou item não selecionado. |
| `workspace dotfiles unlink [--only <id>] [--dry-run]` | Por padrão materializar cópia regular do conteúdo efetivo, preservando funcionamento. Só remover o link exato registrado; link trocado pelo usuário bloqueia. Confirmar e registrar transação. |
| `workspace dotfiles unlink --restore <transaction-id> [--dry-run]` | Restaurar estado anterior a uma vinculação identificada; não confundir com materialização. Se antes não existia arquivo, removê-lo só após informar consequência. |
| `workspace sync [--dry-run]` | Plano local por padrão: status Git, diff dos arquivos permitidos, upstream conhecido, pendências e ações possíveis. Não significa pull/commit/push automático. `--dry-run` não faz fetch nem escreve refs/locks. |
| `workspace sync --fetch` | Consulta remota explícita, atualiza apenas refs de acompanhamento, não o checkout ativo. Reporta diferenças para revisão. |
| `workspace sync --apply` | Aplica commit remoto já buscado e revisado, com validação e proteção do checkout ativo descritas abaixo. |
| `workspace sync --commit -m <mensagem>` | Revisão e staging seletivo de mudanças aprovadas; commit local explícito. Nunca `git add .` ou `git add -A`. |
| `workspace sync --push` | Publicação explícita, precedida de revisão de commits e destinos; nunca force-push. |

Flags de sync são mutuamente exclusivas no primeiro escopo. Códigos propostos: 0 = sucesso/sem mudança ou cancelamento explícito; 1 = pendência/falha/conflito; 2 = uso inválido. Para `status`, drift dos IDs selecionados retorna 1; IDs não selecionados são apenas informativos. Cancelamento não pode ser apresentado como configuração aplicada.

### 5.1. Sync sem aplicar conflitos ao shell ativo

Editar um arquivo por symlink modifica imediatamente o working tree permanente. Portanto, o antigo princípio “alteração local só entra no repositório após aprovação” precisa passar a significar **só entra no histórico e na publicação após revisão**. Edição não equivale a commit; preferências exclusivamente locais devem ficar fora dos arquivos vinculados.

Fluxo proposto:

1. Validar raiz, branch/upstream explícitos, URL remota sem credenciais embutidas, ausência de merge/rebase em andamento e seleção por máquina. Não autenticar nem trocar remote automaticamente.
2. Exibir alterações unstaged, staged e untracked. Para aplicar remoto, exigir árvore/índice limpos; não usar stash, reset hard, clean ou resolução automática. Para commit, índice previamente ocupado exige revisão, evitando incluir alterações alheias.
3. Buscar remoto somente com `--fetch`. Branches divergentes exigem resolução manual em área separada, nunca merge conflituoso no checkout cujos arquivos estão ativos.
4. Preparar candidato em área isolada com objetos Git independentes; validar schema/allowlist, sintaxe, segredos, destinos e conteúdo antes da confirmação. Não executar scripts/hooks/configurações recebidos durante validação. Usar política explícita para hooks locais, sem executá-los silenciosamente.
5. Como o checkout contém também código do projeto, `--apply` deve **bloquear commits com alterações fora de `dotfiles/` e do manifesto de links permitido**, incluindo commits mistos. Atualizar código da CLI exige fluxo separado de revisão/bootstrap. Não descartar arquivos de um commit para fingir que o HEAD integral foi aplicado.
6. Com fast-forward elegível, pedir aprovação do diff e commit exatos. Adquirir lock compartilhado com link/unlink; revalidar HEAD, índice e hashes imediatamente antes de aplicar. Registrar snapshot/commit anterior e backups para recuperação.
7. Aplicar somente candidato validado. Alterações de allowlist/destinos precisam de plano de links adicional; novos IDs não são ativados automaticamente. Se falhar, recuperar conteúdo/HEAD/registro anteriores sem apagar mudanças concorrentes; se estas existirem, parar com instruções e preservar ambos.
8. `--push` revisa **todos os commits de saída**, inclusive arquivos de outros commits, não apenas o diff atual. Bloquear caminhos/conteúdo fora do escopo autorizado e rejeição non-fast-forward; não mesclar nem forçar automaticamente.

Um checkout atualizado por Git não oferece atomicidade global entre vários arquivos para processos já em execução. O primeiro escopo deve explicitar essa limitação: validação antecipada impede marcadores de conflito, lock serializa ações da CLI e rollback recupera falhas; durante aplicação não iniciar novas sessões dos aplicativos afetados. Se atomicidade de múltiplos arquivos se tornar necessária, avaliar gerações imutáveis e troca de ponteiro em etapa própria, com revisão do modelo de edição. Não adicionar essa complexidade sem necessidade comprovada.

## 6. Backup, conflitos e rollback

Adotar transação por lote selecionado, com pré-validação integral antes de qualquer alteração. Um conflito bloqueia o lote; `--only` permite tratar um arquivo independente. Padrão em conflito: preservar, informar e retornar pendência. Não oferecer `--force` que apague evidências.

1. Criar ID único com `mktemp`, sem depender apenas de timestamp. Estado fora do repo, `umask 077`, lock via `mkdir` com metadados de operação. Lock residual não deve ser apagado automaticamente por suposição.
2. Registrar plano, commit/hash da fonte, tipo/hash/modo do destino, texto de link existente e ancestrais. Revalidar após confirmação e sob lock. Registro temporário é publicado de forma atômica após sucesso.
3. Preservar bytes e metadados do original antes da substituição. Link externo não é seguido para backup: guardar o próprio link e só substituí-lo mediante adoção específica. Se não for possível preservar metadados exigidos, bloquear e informar.
4. Preparar novo link em nome temporário no diretório do destino. Verificar fonte/destino novamente e renomear sobre o arquivo exato; adaptar operação para GNU/BSD sem seguir diretórios simbólicos. Não usar remoção recursiva de destinos.
5. Registrar etapas no journal antes/depois de cada mutação. Se uma etapa falhar, desfazer somente ações desta transação em ordem inversa. Preservar backups e journal caso recuperação não conclua.
6. Rollback compara estado atual com o aplicado. Se o usuário modificou/trocou o destino ou a fonte depois, não sobrescrever: guardar versões e exigir revisão. `unlink --restore` restaura arquivo/link anterior; rollback de sync também considera o conteúdo Git, pois restaurar só o link não restaura seus bytes.
7. Interrupções tratáveis usam `trap`; queda de energia/SIGKILL deixam journal recuperável para diagnóstico na próxima execução. Não prometer rollback automático infalível.

Materialização por `unlink` deve conservar os bytes atuais, validar sintaxe e registrar novo estado regular. Se a fonte estiver ausente, não produzir arquivo vazio: oferecer restauração do backup conhecido. Não apagar repositório, backups, programas ou diretórios pessoais ao desvincular. Diretórios criados pela transação só podem ser removidos se ainda vazios e registrados como seus.

Backups atuais adjacentes e `config-workplace-backup.*` permanecem intactos; podem ser identificados como legados, sem exclusão ou adoção automática. Retenção e limpeza são operações futuras separadas, nunca efeito colateral de link/sync.

## 7. Reutilização e refatorações prioritárias

Reutilizar logs, detecção, confirmação com padrão negativo, sondagem antes da mutação, adaptadores APT/Homebrew, resolução de caminhos do editor, parser JSONC, validação de sintaxe e padrões de mocks. Reaproveitar a estratégia transacional do bootstrap, não copiar seu `rm -rf` para destinos de configuração.

Prioridades:

1. Distinguir raiz da CLI, repo permanente de configurações, estado e clone descartável.
2. Extrair plano/aplicação de arquivos da instalação de ferramentas; manter comportamento legado quando nenhum arquivo tiver sido adotado.
3. Separar ownership de dotfiles da guarda rígida de instaladores. Tratar links gerenciados como SKIP nos módulos antigos, sem escrita através deles.
4. Consolidar fonte aprovada de terminal sem trocar tema ou ativar capturas extras.
5. Centralizar journal/backup/rollback para links e sync; manter compatibilidade com backups antigos.
6. Unificar documentação e allowlists de empacotamento. O bootstrap precisa incluir os novos módulos/helpers, mas não copiar secrets, inventários ou capturas indiscriminadamente.

Não refatorar Java para aproveitar a migração como pretexto. Apenas garantir, com regressões isoladas ao final, que os helpers compartilhados e o dispatcher continuam compatíveis.

## 8. Etapas e critérios de aceitação

| Etapa | Trabalho futuro | Critérios de aceitação |
| --- | --- | --- |
| 1 — Auditoria (esta entrega) | Diagnóstico, inventário, decisões e plano | Somente este documento criado; nenhum instalador/configuração real alterado; limites e Java congelado explícitos. |
| 2 — Contratos e fundação | Documentar nova RN-001; criar `.gitignore`, aliases CLI, resolução de raízes, schema/allowlist, preparação explícita do repo permanente e status | Comandos antigos mantidos; `workspace` preexistente preservado; instalação da CLI segue independente do clone; status offline sem escrita/Node; inicialização não incorpora arquivos sujos ou credenciais implicitamente. |
| 3 — Motor de links e recuperação | Implementar link/unlink, journal, locks, backup, preview e restore em sandbox | Segunda execução sem mutação; diretórios/links externos/secrets excluídos; testes de falhas/concorrência/rollback preservam bytes; remover CLI/clone descartável não quebra links. |
| 4 — Piloto terminal e compatibilidade | Adotar somente fragmento revisado; separar fluxo de arquivos e pacotes; módulos reconhecem ownership | Tema, plugins, aliases locais e startup preservados; nenhuma reinstalação no piloto; não há carga dupla de framework; PATH não duplica; legado e modo gerenciado funcionam separadamente; ZDOTDIR/XDG não mudam silenciosamente. |
| 5 — Adesão seletiva de outras configurações | Revisar Git/VS Code e perfis locais sem importar tudo; manter não aprovados fora | Settings preservam chaves/comentários ou ficam no modo legado; nenhuma identidade/secret versionada; fragmentos macOS não chegam ao Ubuntu; perfil não inferido por `profile-01`; exclusões documentadas são resultado válido. |
| 6 — Git Sync | Implementar plano, fetch, candidato isolado, apply, commit e push separados | Sem publicação implícita; árvores sujas/divergências/commits mistos bloqueados; conflito nunca aparece em arquivo ativo; rollback validado; rede indisponível preserva operação local. |
| 7 — Aceitação e documentação | Executar matriz real descartável Ubuntu e testes de portabilidade; atualizar guias e roadmap | Instalação limpa e sobre ambiente configurado aprovadas; remoção do clone/CLI validada; unlink conserva funcionamento; nenhum runtime/plugin dentro do repo; critérios de cada etapa registrados com evidência. |

Somente depois da etapa 7 considerar a migração concluída e planejar a retomada de Java. Monitor, timer systemd, update, Docker, env e novas dependências não são pré-requisitos desta migração.

## 9. Plano de testes

### 9.1. Evidência desta auditoria

- Leitura estática de código, manifestos, capturas, docs e desenho das cinco suítes existentes.
- `/bin/bash -n` em `install.sh`, entrada da CLI, bibliotecas, módulos, adaptadores e testes: **aprovado**.
- `node --check` nos dois helpers JavaScript: **aprovado**.
- CLI local: `--help`, `--version` e `list` executados com sucesso, sem instalar a CLI ou chamar módulos.
- Não foram executadas as suítes funcionais: algumas invocam bootstrap/instalações simuladas. Esta fase se limita à auditoria sem executar instaladores. Não há alegação de regressões funcionais aprovadas nesta sessão.
- Não foi inspecionado o HOME pessoal para confirmar o tema atual. A identificação robbyrussell é evidência do repositório/captura anterior, não nova verificação da sessão do usuário.

### 9.2. Suítes isoladas futuras

| Cenário | Resultado exigido |
| --- | --- |
| HOME vazio, fonte aprovada, link duas vezes | Link correto na primeira execução; segunda sem nova escrita/backup. |
| Cópia idêntica, cópia divergente, recusa e EOF | Conversão só após revisão; recusa preserva bytes, permissões e fonte. |
| Link correto, externo, relativo, quebrado, loop e fonte ausente | Classificação correta; nenhum link externo seguido/substituído implicitamente. |
| Diretório no destino, ancestral simbólico, `..`, fonte fora da raiz | Operação bloqueada antes de backup/escrita. |
| HOME com espaços, XDG customizado e ZDOTDIR customizado | Resolução consistente; nenhuma expansão por eval ou divisão acidental de paths. |
| Manifesto com duplicatas/IDs novos/removidos | Validação bloqueia colisão; adesão/desvinculação exigem plano explícito. |
| Mudança durante confirmação/aplicação, lock concorrente | Abortamento sem perder alteração do usuário. |
| Falha de backup/rename/registro, INT/TERM e journal incompleto | Recuperação exata ou artefatos preservados com instruções claras. |
| Unlink padrão, restore e fonte modificada posteriormente | Materialização conserva conteúdo atual; restore protegido contra mudanças posteriores. |
| Terminal legado, tema diferente, bloco duplicado, aliases locais | Sem troca de tema, escrita arbitrária ou inicialização dupla. |
| JSONC com comentários/chaves extras, dados locais e save do editor | Preservação ou exclusão explícita da gestão; drift detectado. |
| Sync com dois clones e remote bare local | Fetch sem aplicação, commit seletivo, push explícito, conflito/non-fast-forward bloqueados. |
| Dirty tree, índice ocupado, detached HEAD, merge em andamento, remote inválido | Sem stash/reset/clean ou publicação acidental. |
| Commit remoto com scripts, secrets ou caminhos não permitidos | Bloqueio antes de ativação; nenhum hook/script remoto executado. |
| Rede falha, fonte permanente ausente, remoção da CLI | Status offline útil; falha clara; ferramentas permanentes continuam disponíveis. |

Executar regressões existentes após revisar o isolamento: HOME/XDG/ZDOTDIR/TMPDIR de fixture; mocks que falham se apt, brew, sudo, curl, chsh ou autenticação reais forem alcançados. `sync` usa remote bare local para testes, sem GitHub ou credenciais. Testar Bash 3.2/macOS e Bash Ubuntu; ShellCheck só se já disponível, sem torná-lo dependência de runtime.

### 9.3. Aceitação real futura, em ambientes descartáveis

**Ubuntu limpo:** preparar VM e pré-requisitos autorizados; instalar CLI, executar initial dev/terminal individualmente, repetir e verificar SKIP; inicializar repo permanente; vincular somente seleção aprovada; abrir nova sessão e validar tema/plugins/PATH. Apagar clone descartável, repetir validação; remover apenas CLI, repetir. Confirmar executáveis fora do repo de configurações. Materializar com unlink, retirar repo permanente e validar novamente.

**Ubuntu já configurado:** VM com tema diferente ou customizado, `.zshrc` pessoal, NVM externo, versões funcionais, settings JSONC extras, links preexistentes e arquivos locais sensíveis fictícios. Fazer snapshot de bytes/modos/links; executar dry-run/recusa; comparar snapshot. Adotar um arquivo por vez, testar falha e rollback, preservar extras e ferramentas. Repetir com editor que salva settings enquanto o gerenciador atua.

**macOS:** primeiro validar Bash 3.2, BSD tools, caminhos com espaços, XDG/ZDOTDIR e ownership em sandbox. Depois aceitação em máquina descartável equivalente, sem pressupor Homebrew instalado. Suporte real não deve ser anunciado apenas com mocks que retornam Darwin. Não incluir novos desenvolvimentos Java nos testes de migração; regressões de Java ficam em fixtures existentes.

## 10. Divergências entre documentação e código

| Evidência | Divergência/ajuste necessário |
| --- | --- |
| README §§5/9 e `docs/macos-initial-capture.md` | Prescrevem cópias e não dependência de configurações do repo; nova proposta requer repo permanente e links seletivos. Atualizar regra, preservando independência do clone descartável. |
| README §§9/12 e `docs/terminal.md` | Referem integração com Chezmoi; não há integração/dependência implementada. Substituir planejamento por gerenciador Bash nativo. |
| README status e roadmap Java marcado concluído | Código e testes existem, mas usuário relata interrupção e docs admitem aceitação real pendente. Registrar “implementado parcialmente, congelado; aceitação pendente”. |
| README roadmap Fase 1 | CLI/help/list e dry-run ainda aparecem pendentes apesar da implementação; atualizar checkboxes por evidência. |
| README roadmap terminal | Marca 3.1 concluída, mas agrupa terminal/importação de profiles como pendência; separar itens. |
| README árvore proposta | `platform.sh`, `logging.sh`, `packages.sh`, `safety.sh`, YAML, monitor, templates e subpastas de testes não representam a árvore atual. Distinguir existente/proposto. |
| README testes | Bats, ShellCheck e GitHub Actions são planos; o repositório contém scripts Bash, sem configuração CI. Não anunciar execução/cobertura inexistente. |
| README plataforma futura | macOS já tem adaptadores, mas aceitação real pendente. Windows é visão histórica e não entra nesta migração. |
| `dotfiles/README.md` e código ativo | Capturas não são automaticamente aplicadas; fonte ativa é `manifests/terminal/zshrc` e seis chaves de settings. Preservar essa distinção até adesão explícita. |
| README fluxo “alteração local só entra no projeto após aprovação” | Links editam working tree imediatamente; aprovação deve controlar commit/push, com overrides locais fora do versionamento. |
| `lib/cli.sh` | Nome é `config-workplace`, não `workspace`; versão exibida permanece 0.2.2. Introduzir compatibilidade explícita, não renomear comandos existentes. |
| `lib/setup.sh` versus `lib/dev-tools.sh` | Git/gh usam `apt-get install -y`; utilitários usam `--no-upgrade`. Não generalizar a garantia de flag a todos os adaptadores; avaliar uniformização futura com regressões. |
| `docs/macos-initial-capture.md` | “Não tinha .git/CLI” descreve a captura de 20/10, não o presente; preservar como histórico e acrescentar contexto atualizado. |

## 11. Referências e decisões próprias

O [artigo da DataCamp](https://www.datacamp.com/pt/tutorial/dotfiles) foi consultado como introdução à organização modular, versionamento, links e backups. Sua recomendação de revisar configurações antes de adotar é pertinente. Não copiar o instalador de exemplo nem tratar `.gitignore` como proteção suficiente para secrets já rastreados. Não há necessidade demonstrada de Stow.

No [repositório vitebo/dotfiles](https://github.com/vitebo/dotfiles), foram consultados [README](https://github.com/vitebo/dotfiles/blob/main/README.md), [install.sh](https://github.com/vitebo/dotfiles/blob/main/install.sh) e [lib/symlinks.sh](https://github.com/vitebo/dotfiles/blob/main/lib/symlinks.sh). A separação entre dados e automação inspira as três responsabilidades propostas. O gerenciador de referência percorre entradas genericamente e substitui symlinks existentes; essas decisões não atendem à allowlist e à proteção de ownership exigidas aqui. Na consulta, o README mencionava `secrets`, mas `install.sh` não despachava essa tarefa e `lib/secrets.sh` retornou 404. Referência também precisa ser confrontada com código, não copiada como contrato completo.

O repo permanente separado, a adoção por arquivo, o journal e as restrições de sync são decisões deste plano para preservar os contratos do config-workplace. Nenhum arquivo das referências foi incorporado ao projeto.

## 12. Próxima fase

Implementar primeiro a etapa 2 e o motor isolado da etapa 3: contratos de caminhos, allowlist, status, preview, backup/rollback e compatibilidade da CLI. Demonstrar segurança com fixtures antes de adotar o fragmento terminal. Não começar por substituir `.zshrc`, importar settings completos ou executar `git pull` sobre configurações ativas. Java só volta ao planejamento após a aceitação integral da migração.


## 13. Progresso efetivo — Fase 2 (2026-10-22)

Implementados `workspace dotfiles link/status/unlink`, dry-run, entrada compatível,
empacotamento no bootstrap, allowlist fixa do fragmento terminal, classificação
de conflitos, confirmação negativa por padrão, backup privado com permissões,
journal, lock e recuperação manual após falha. Nenhum arquivo pessoal foi adotado.
Consulte [o contrato implementado](dotfiles.md), que prevalece sobre propostas
anteriores deste documento para os comandos entregues.

Decisões e diferenças deliberadas em relação à proposta:

- Fonte canônica permanece `manifests/terminal/zshrc`; não duplicamos o arquivo.
- Checkout permanente preparado manualmente; raiz explícita por variável ou
  caminho padrão, nunca inferida do diretório corrente. `init` não foi implementado.
- Allowlist fixa no código, um único alvo. Sem TSV, seleção de IDs ou importação.
- Conteúdo divergente e qualquer link externo exigem revisão manual, sem adoção
  forçada. Cópia idêntica pode ser convertida após confirmação e backup.
- `unlink` remove somente o link esperado conforme o pedido desta fase; não
  materializa nem restaura. Journal registra operações, não é banco de ownership.
- Falhas conservam backup e journal para recuperação manual; não há promessa
  de rollback automático. Nova execução pode concluir uma vinculação interrompida.
- Não alteramos módulos Java, Node, Docker ou VS Code, nem implementamos sync.

Etapas 2–3 da seção 8 entregues no escopo reduzido acima; inicialização automática,
registro completo/seleção e restore seguem pendentes. Piloto terminal limitado
à gestão do fragmento; ativação pessoal não realizada. A migração completa e a
aceitação real multiplataforma continuam pendentes, sem avanço automático.

Validação: suíte nova de dotfiles aprovada em Bash 3.2/macOS, com HOME isolado,
backup/permissões, conflitos, links quebrados, dry-run, unlink e falha injetada.
Bootstrap isolado: 18 verificações aprovadas. Não houve bootstrap no HOME real.

Regressões isoladas também aprovadas: terminal (15), initial-dev (25), phase-2.2
(26) e Java (27), sem alteração desses módulos. Total das suítes legadas: 111
verificações, além dos cenários da nova suíte. `git diff --check` aprovado.

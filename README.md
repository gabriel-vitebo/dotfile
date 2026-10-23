# Config Workplace

CLI pessoal para preparar e manter um ambiente de desenvolvimento após uma
formatação, preservando instalações e configurações existentes. Instala ferramentas
sob demanda e gerencia um conjunto pequeno de preferências portáteis com revisão.

**Versão anunciada pela CLI: 0.2.2.** Alvos: Ubuntu e macOS. Implementação e testes
simulados não equivalem à aceitação completa em máquinas recém-instaladas.
Auditoria da árvore em `efcaa6a`, em 22/10/2026:
[diagnóstico, evidências e limitações](docs/dotfiles-sync-audit.md#auditoria-geral-do-repositorio--2026-10-22).

## Funcionalidades e estado

“Implementado” indica o escopo presente no código; “parcial” indica uma limitação
operacional ou parte do fluxo ainda manual. Não é certificação de instalação real.

| Recurso | Estado | Escopo real |
| --- | --- | --- |
| Bootstrap, CLI e atualização manual | Implementado | Cópia permanente, lançadores, validação, backup e rollback da substituição |
| PATH Bash/Zsh | Implementado | Sonda login e interativo não-login; propõe ajustes confirmados e backups |
| `initial dev` | Implementado | Git, gh, NVM, Node LTS/npm, pnpm, VS Code e utilitários |
| Persistência NVM | Parcial | Bloco Bash/Zsh disponível; integrações existentes e login personalizado exigem revisão |
| Terminal | Implementado | Zsh, Vim, Oh My Zsh, robbyrussell/git e bootstrap; startup pessoal existente fica manual |
| Java | Parcial | Detecção e instalação opcional via SDKMAN!; ativação manual, profiles e aceitação real pendentes |
| Dotfiles terminal/Git | Implementado | Symlink do fragmento e include portátil, seleção, backups e unlink |
| VS Code | Parcial | Extensões e seis settings por chave em `initial dev`; dotfiles só orienta revisão |
| Dotfiles `init`/`doctor` | Implementado | Checkout independente fixado; diagnóstico local sem reparos |
| Git sync | Parcial | Commit/push ou fast-forward manuais e restritos; autenticação e histórico misto limitam uso |
| Docker/Compose | Pendente | Sem módulo, instalação, configuração de daemon ou permissões |
| `env` | Pendente | Sem gerenciamento de variáveis por máquina, secrets, exportação ou restauração |
| Monitoramento e comandos globais de manutenção | Pendente | Sem `doctor`, `status`, `review`, `monitor`, `sync` ou `update` globais |

## Compatibilidade e requisitos

- **CLI/bootstrap:** Bash 3.2+ e utilitários de sistema; bootstrap aceita Linux/macOS.
  Módulos de instalação, init/doctor e sync restringem a Ubuntu/macOS em
  x86_64, aarch64 ou arm64. Aceitar Linux no bootstrap não garante módulos em
  outras distribuições. Não há suporte Windows.
- **Ubuntu:** APT e, para instalações de sistema, root ou sudo após confirmação.
- **macOS:** Homebrew funcional quando necessário para ferramentas ausentes;
  a CLI não o instala. Command Line Tools ausentes podem abrir o instalador Apple
  após aprovação; conclua-o e reexecute. SSH e certificados nativos exigem reparo manual.
- **Rede:** instalações e consultas de versões usam HTTPS. Git é necessário para
  clonar o projeto e para init/sync; bootstrap local não exige Git, Node ou Java.
- **Java novo via SDKMAN!:** Bash 4+, curl, zip, unzip e tar. Bash 3.2 continua
  suficiente para executar a CLI e diagnosticar ferramentas existentes.

A auditoria atual executou suítes no Ubuntu com Bash moderno e Zsh. Há registros
históricos de testes macOS/Bash 3.2, mas a aceitação real completa em ambas as
plataformas permanece pendente. Nenhuma versão mínima específica de Ubuntu/macOS
foi estabelecida por uma matriz de aceitação.

## Instalação e atualização da CLI

Com Git e acesso à origem do projeto já preparados, execute sem sudo:

```bash
git clone https://github.com/gabriel-vitebo/dotfile.git
cd dotfile
./install.sh
export PATH="$HOME/.local/bin:$PATH" # disponibiliza nesta sessão, se necessário
config-workplace --help
config-workplace --version
config-workplace list
```

Acesso privado deve ser preparado pelo usuário; o instalador local não autentica
contas nem acessa a rede. A disponibilidade remota não foi validada nesta auditoria.
`workspace` é um segundo lançador para a mesma CLI. Um comando `workspace`
preexistente é preservado: nesse caso, use `config-workplace`.

O bootstrap copia apenas arquivos da allowlist para
`~/.local/share/config-workplace` e cria os lançadores em `~/.local/bin`.
Inventários e capturas em `dotfiles/` ficam fora da instalação. Depois disso,
o clone inicial pode ser excluído; os dotfiles vinculados usam outro checkout.

Para atualizar, obtenha/revise a versão desejada em um clone de desenvolvimento
e execute novamente `./install.sh`. Alterar apenas o clone não atualiza a CLI.
Não existe comando `update` nem atualização automática. A instalação anterior e o
lançador são guardados em `~/.local/share/config-workplace-backup.*`.
Arquivos desconhecidos ou modificados exigem confirmação; falhas na substituição
ou na validação final tentam restaurar a instalação anterior. O ajuste de PATH
ocorre depois dessa transação e pode ficar pendente mesmo com CLI instalada.

### PATH em novas sessões

O instalador usa `SHELL` e executa subprocessos com ambiente limpo nos modos
login, login interativo e interativo não-login. **Isso executa código pessoal de
startup**, como abrir um terminal. O PATH herdado da sessão atual não é prova de
persistência. Bash propõe primeiro `.bashrc`; depois verifica o arquivo login
pela precedência `.bash_profile`, `.bash_login`, `.profile`. A correção do problema
Ubuntu em terminais não-login está presente.

Zsh usa `.zshrc`/`.zprofile` no `ZDOTDIR` efetivo, inclusive definido por `.zshenv`.
Cada escrita tem preview, confirmação e backup adjacente com permissões preservadas.
Referências existentes sem efeito e symlinks exigem revisão, sem duplicar blocos.
Recusar não impede usar o lançador por caminho absoluto. Abra outra sessão após
aprovar; o instalador não muda o PATH do terminal que o iniciou.

## Início rápido

```bash
config-workplace initial dev --dry-run
config-workplace initial dev
config-workplace terminal --dry-run
config-workplace terminal
# Opcional:
config-workplace java --dry-run
config-workplace java
# Dotfiles, com Git e acesso à origem aprovada:
config-workplace dotfiles init --dry-run
config-workplace dotfiles init
config-workplace dotfiles link --all --dry-run
config-workplace dotfiles link --all
config-workplace dotfiles doctor
```

Revise cada plano e os itens REVIEW/MANUAL. `dotfiles link` não ativa sozinho o
fragmento em um `.zshrc` pessoal existente. A preparação de branch para sync é
separada; não é necessário sincronizar para usar ferramentas já instaladas.

## Referência de comandos

As duas entradas aceitam os mesmos argumentos quando instaladas pelo projeto.
Sem argumentos, a CLI mostra a ajuda global.

| Comando | Opções aceitas / efeito |
| --- | --- |
| `config-workplace help` ou `--help` | Ajuda global |
| `config-workplace --version` | Versão anunciada `0.2.2` |
| `config-workplace list` | Módulos disponíveis e planejados |
| `config-workplace initial dev` | `--dry-run`, `--approve-node-change` |
| `config-workplace terminal` | `--dry-run`, `--change-shell` |
| `config-workplace java` | `--dry-run` |
| `workspace dotfiles --help` | Ajuda do gerenciador de dotfiles |
| `workspace dotfiles list` | `--all` ou `--only ID`; lista todos sem seleção |
| `workspace dotfiles status` | `--all` ou `--only ID`; padrão terminal |
| `workspace dotfiles link` / `unlink` | `--all` ou `--only ID`, `--dry-run`; padrão terminal |
| `workspace dotfiles init` | `--dry-run`; prepara checkout, sem vincular |
| `workspace dotfiles doctor` | Sem opções; diagnóstico local somente leitura |
| `workspace dotfiles sync` | `--dry-run` ou `--status`; preview com rede ou execução confirmada |

IDs: `terminal`, `git`, `vscode`; `terminal-fragment` é alias legado de terminal.
List/status também aceitam `--dry-run`, sem acrescentar mutações.
Não há `--yes`, `--force`, `--restore`, `--from` ou ajuda específica nos três
módulos de instalação. Opções não listadas são rejeitadas. Em geral, 0 significa
sucesso, preview ou recusa; 1, bloqueio/falha; 2, uso inválido. REVIEW pode ser
informativo e retornar 0: sucesso do processo não comprova configuração completa.
`status` retorna 1 para vínculo selecionado incorreto; VS Code é apenas informativo.

## Módulos

### `initial dev`

Detecta ferramentas por presença e execução, preservando instalações funcionais
independentemente do gerenciador. Ferramentas quebradas exigem revisão. Inclui
Git, GitHub CLI, NVM, Node LTS/npm, pnpm, VS Code, Prettier e Error Lens, curl,
wget, unzip, jq, ripgrep (`rg`), fzf, compiladores (`cc`, `c++`, `make`),
certificados CA e cliente SSH. Não cria chaves SSH nem configura identidade Git.

Ubuntu usa APT e repositório oficial de gh; VS Code vem do `.deb` estável oficial.
Utilitários/VS Code usam `--no-upgrade`; **Git/gh usam `apt-get install -y`**.
Homebrew recebe opções para evitar auto-update/upgrade explícito. Dependências
resolvidas pelo gerenciador ainda podem mudar; não há rollback de pacotes.

NVM existente é procurado em `NVM_DIR`, `~/.nvm`, XDG e locais usuais Homebrew.
NVM novo resolve a release estável oficial, valida tag/objetos/sintaxe e executa
seu instalador com `PROFILE=/dev/null`; a origem final fica no upstream oficial.
A confiança é HTTPS/GitHub, sem assinatura independente.

Node funcional é compatível quando pertence à major LTS mais recente do índice
oficial e declara LTS; não se exige o patch mais recente. Divergência requer
`--approve-node-change` e confirmação. Node externo não é migrado por padronização.
Uma LTS local compatível é reutilizada; instalação nova usa `nvm install --lts`
e `default = lts/*`. Correção do alias de LTS já instalada pode fixar a versão
local detectada. Versões anteriores e `.nvmrc` são preservadas; `default-packages`
com pacotes ativos bloqueia nova instalação de Node.

A integração persistente NVM está implementada em `.bashrc` ou
`${ZDOTDIR:-$HOME}/.zshrc`, conforme `SHELL`, com confirmação separada e backup.
Carrega NVM sem forçar LTS no startup; integrações existentes diferentes ficam
REVIEW. A detecção é estática e não confirma execução em uma nova sessão.
[Detalhes de NVM, seleção e remoção](docs/initial-dev.md).

pnpm usa metadados oficiais e valida `engines.node`; instala via npm em
`~/.local/share/config-workplace-pnpm`, com lançador em `~/.local/bin/pnpm`.
O lançador depende do diretório do Node selecionado: removê-lo pode quebrar pnpm.
Não habilita Corepack nem atualiza npm globalmente.

VS Code preserva extensões extras e instala ausentes com aprovação individual.
Settings JSONC são revisados por chave com Node, comentários/chaves extras
preservados, rechecagem e backup privado adjacente. Os seis candidatos são
fontSize 16, rulers [80,120], tabSize 2, minimap desativado, formatOnSave desativado
e ignoreTrimWhitespace desativado. Não importa profiles, Fish/Fig ou capturas
completas. [Seleção e evidências](docs/vscode-base.md).

`--dry-run` evita as escritas planejadas, mas consulta versões por HTTPS, executa
ferramentas existentes e carrega `nvm.sh --no-use`. Código de terceiros carregado
pode ter efeitos próprios: não é uma inspeção estática universalmente sem efeitos.
Falha de consulta pode bloquear o plano. Autenticação gh permanece explícita:
`gh auth login`, quando desejada.

### `terminal`

```bash
config-workplace terminal --dry-run
config-workplace terminal
config-workplace terminal --change-shell
```

Instala somente ferramentas ausentes: Zsh, Vim, Git e Oh My Zsh. Novos frameworks
são clonados do upstream sem executar seu instalador; tema padrão `robbyrussell`
e plugin `git` ficam separados do fragmento portátil neutro.
O bootstrap é copiado para `~/.config/config-workplace-terminal/bootstrap.zsh`.
Um `.zshrc` ausente pode ser criado após aprovação dos componentes; um existente
é preservado e pode receber uma proposta em `startup-proposed.zsh` para integração
manual. O tema local é detectado conservadoramente; desconhecido não é autorização
para substituir. Não instala configuração de Vim, fontes ou plugins externos.

**Instalar Zsh não o torna o shell padrão.** `--change-shell` propõe `chsh` com
confirmação própria somente se o caminho Zsh já está em `/etc/shells`.
Confira o shell configurado com `echo "$SHELL"` e o processo atual com
`ps -p $$ -o comm=`. Após mudar, encerre e reabra a sessão de usuário; abrir Zsh
manualmente com `zsh` permite usá-lo antes disso. [Detalhes e histórico](docs/terminal.md).

### `java`

`config-workplace java [--dry-run]` detecta JDK/javac, Maven e Gradle, inclusive
instalações externas e versões antigas funcionais. JAVA_HOME inválido, majors
divergentes ou instalações quebradas exigem revisão. Novos candidatos usam
SDKMAN!: Temurin da LTS resolvida pela Adoptium, Maven estável nas linhas 3.9/3.10
e Gradle estável cuja documentação da versão permita a JVM detectada.
Falhas de rede/formato/compatibilidade bloqueiam, sem fallback arbitrário.

Há confirmação do plano, do SDKMAN! e de cada candidato. A primeira seleção
`current` pode ser criada; seleções existentes são preservadas. A ativação do
SDKMAN!/JAVA_HOME no shell é manual; o módulo imprime as linhas para revisão.
Seis extensões Java são candidatas opcionais com aprovação individual, sem
importação de profile ou alteração de settings/projetos. Dry-run consulta HTTPS
quando necessário, sem carregar SDKMAN! ou executar instaladores.
[Requisitos, limitações e recuperação](docs/java.md).

## Dotfiles e sincronização

| Local | Responsabilidade |
| --- | --- |
| Clone inicial | Fornece `install.sh`; descartável após instalar |
| `~/.local/share/config-workplace` | Código permanente da CLI, substituível pelo bootstrap |
| `${XDG_DATA_HOME:-$HOME/.local/share}/config-workplace-dotfiles/repository` | Checkout permanente dos conteúdos vinculados |
| `${XDG_STATE_HOME:-$HOME/.local/state}/config-workplace/dotfiles` | Locks, journals e backups privados |

`CW_DOTFILES_REPO` pode selecionar outra raiz absoluta permanente; preserve a
variável nas próximas execuções. Não há descoberta pelo diretório corrente.
Init/doctor/sync recusam temporários, CLI e metadados compartilhados. Link/unlink
possuem validação de caminhos mais limitada: não substituem essa validação completa.
**Não apague o checkout permanente enquanto houver vínculos ativos.**

| ID | Fonte no checkout | Aplicação |
| --- | --- | --- |
| terminal | `manifests/terminal/zshrc` | Symlink absoluto em `~/.config/config-workplace-terminal/zshrc` |
| git | `manifests/git.config` | Include no início de `~/.gitconfig`, mantendo bytes e precedência pessoais |
| vscode | `manifests/vscode-settings.json` | Revisão manual; dotfiles não escreve settings |

`list` mostra o cadastro; `status` verifica vínculos, não alterações Git da fonte.
Um arquivo divergente ou link de terceiros é preservado e bloqueia a seleção.
Cópia idêntica pode virar symlink após confirmação e backup. `unlink` remove
somente o vínculo/prefixo exato; não materializa cópias nem restaura backups.
O include Git fornece aliases e preferências, nunca identidade ou credenciais.

Init usa exclusivamente `https://github.com/gabriel-vitebo/dotfile.git`, commit
`e0ebd0226328b9a4551bd344fa8bb1bcc6126401`, em detached HEAD. Reutilização não
faz fetch/pull e exige as três fontes iguais ao HEAD. `doctor` não repara,
não testa o startup pessoal e pode reportar edições intencionais como pendência.

Para revisar mudanças locais, defina o checkout usado e compare ali:

```bash
repo="${CW_DOTFILES_REPO:-${XDG_DATA_HOME:-$HOME/.local/share}/config-workplace-dotfiles/repository}"
git -C "$repo" status --short
# Revise diffs apenas em ambiente privado, após verificar conteúdo sensível:
git -C "$repo" diff -- manifests/terminal/zshrc manifests/git.config manifests/vscode-settings.json
```

Sync exige origem HTTPS exata e **branch main selecionada manualmente**.
[Preparação da branch e identidade local](docs/dotfiles.md#preparação).

```bash
workspace dotfiles sync --status
workspace dotfiles sync --dry-run
workspace dotfiles sync
```

Os dois previews consultam a rede em armazenamento temporário; não são offline.
Sem alterações: SKIP. Somente locais: commit de todas as mudanças elegíveis
com confirmação e push separado. Somente remotas: fast-forward confirmado.
Locais e remotas/divergência: bloqueio, sem merge, reset, clean ou force push.
Índice ocupado, detached HEAD, configurações Git não aprovadas e alterações fora
dos três arquivos bloqueiam. Histórico intermediário também é revisado.

Como o checkout contém o código da CLI, commits de documentação/código posteriores
ao pin ficam fora da allowlist e podem bloquear o avanço para main. Sync não é
atualizador da CLI nem sincronizador geral do repositório. O scanner é heurístico,
recusa não ASCII e arquivos acima de 256 KiB; não valida a semântica do shell/Git/JSON
recebido. Fontes vinculadas passam a refletir o conteúdo atualizado imediatamente.

Configurações globais, hooks e credential helpers são isolados. Init e a consulta
prévia de sync não autenticam interativamente; repositórios privados podem ficar
inacessíveis mesmo com `gh auth login`. Push aprovado pode pedir credenciais no
terminal, mas depende de a consulta prévia ter funcionado.
[Contrato completo, conflitos, backups e recuperação](docs/dotfiles.md).

## Arquitetura e desenvolvimento

```text
bin/          entradas config-workplace e workspace
lib/          dispatcher, detecção, segurança, dotfiles, Java e helpers JS
modules/      orquestração de initial dev, terminal e java
platforms/    instalação de ferramentas, editor e Oh My Zsh
manifests/    dados aprovados, fragmentos e listas de extensões
install.sh    bootstrap local da CLI com allowlist explícita
tests/        11 suítes shell com fixtures e mocks
dotfiles/     capturas históricas seletivas, sem ativação automática
inventory/    observações históricas, não manifestos de instalação
docs/         contratos operacionais, captura, planos e auditorias
```

Não há Chezmoi, Stow, monitor, YAML de configuração ou dependências npm do projeto.
Bash 3.2 é a base; Node é usado nos helpers JSONC e de metadados pnpm.
O instalador mantém allowlists repetidas de empacotamento: alterações de runtime
precisam atualizar validação, cópia, checksums e reconhecimento de instalações.
Contribuições devem preservar detecção antes de instalar, confirmações, configurações
pessoais e independência do clone; use HOME isolado e mocks para validar mutações.

## Segurança, backups e idempotência

CHECK inspeciona; SKIP preserva; PLAN propõe; INSTALL indica etapa de instalação;
CONFIGURED/OK indicam conclusão da etapa; REVIEW/MANUAL exigem leitura e eventual
intervenção; FAIL indica falha; BACKUP informa recuperação. Dotfiles também usa
estados `absent`, `identical`, `divergent`, `correct`, `personal`, `conflict`,
`foreign-link`, `broken-foreign` e `broken-managed`.

Recusa/EOF preserva a etapa recusada, mas não desfaz instalações anteriores.
Ferramentas funcionais ficam SKIP; exceções de compatibilidade são explícitas,
como Node fora da política LTS. Pacotes/SDKs não têm rollback automático.

- CLI: backups em `~/.local/share/config-workplace-backup.*`; rollback da troca.
- Shell/terminal: backups adjacentes `*.config-workplace-backup.*`.
- VS Code: `.config-workplace-*/backup.json` adjacente, com modo 0600.
- Dotfiles/sync: `operation.*` no estado privado, com journal e cópias anteriores.

Não há restore global. Compare backups em área privada antes de restaurar para
preservar edições posteriores. Journals incompletos e locks exigem investigação;
não remova locks de processos ativos. Link/unlink anuncia journals incompletos;
init/doctor/sync os tratam como pendência bloqueante. SIGKILL/queda de energia
podem deixar locks e artefatos. Locks não controlam editores externos; não há
atomicidade global, compare-and-swap ou garantia de fsync.

Repositório privado e `.gitignore` não são cofres. Não versione `.env`, tokens,
chaves ou configurações corporativas. O detector de sync complementa revisão
humana, não garante ausência de secrets nem segurança do código recebido.
Planos de terminal/settings e sondagens PATH podem ler/exibir ou executar conteúdo
pessoal; mantenha saídas e backups privados. Não há garantia universal de nenhuma
alteração fora das ações planejadas por código de terceiros executado na sondagem.

## Testes

Execute do checkout em caminho permanente, com Bash e utilitários de sistema,
Git, Node, Zsh e Vim disponíveis. Node é necessário para testar JSONC/metadados;
Zsh/Vim são exigidos pela suíte terminal. PATH/NVM executam Zsh quando disponível.
Não precisa instalar Bats, npm dependencies ou ShellCheck para essas suítes.

```bash
for suite in tests/*.sh; do
  /bin/bash "$suite" || break
done
```

As 11 suítes usam HOME descartável, fixtures e mocks; Git cria commits/pushes
somente em repositórios locais. Bootstrap instala apenas na fixture. Algumas
sondagens executam binários reais e startup global do sistema; HOME isolado não
é isolamento de VM. Não execute módulos reais como teste documental.

[Resultados atuais por suíte e lacunas](docs/dotfiles-sync-audit.md#auditoria-geral-do-repositorio--2026-10-22).
Não há CI versionada nem runner central. Instalações reais, sudo, `chsh`,
autenticação e aceitação visual não foram executados nesta auditoria.

## Problemas comuns

| Sintoma | Verificação / ação |
| --- | --- |
| CLI não encontrada | Use `~/.local/bin/config-workplace --help`; confira PATH com `bash -lc 'command -v config-workplace'` e `bash -ic 'command -v config-workplace'`; reexecute bootstrap e revise propostas |
| Node só funciona no terminal antigo | Confira `SHELL` e `NVM_DIR`, execute `initial dev --dry-run`; aprove integração e abra terminal novo. Login personalizado deve carregar `.bashrc` |
| NVM continua REVIEW | Integração existente é preservada, mesmo se só um comentário mencionar NVM; revise o arquivo sem acrescentar blocos duplicados |
| ZDOTDIR difere entre fluxos | PATH resolve `.zshenv`; NVM/terminal usam a variável herdada. Exporte o diretório correto antes desses módulos |
| Tema não mudou | `.zshrc` pessoal é preservado; revise `startup-proposed.zsh` e a cadeia de carregamento, sem iniciar dois frameworks |
| Zsh instalado, Bash continua padrão | Use `terminal --change-shell`, aprove `chsh` quando elegível e reabra a sessão de usuário |
| Java instalado, comando ausente | Revise a integração manual SDKMAN! e a precedência de JAVA_HOME/PATH |
| Doctor acusa fontes alteradas | Compara as três fontes com HEAD; revise alterações locais, sem descartá-las para eliminar o aviso |
| Sync recusa main/detached | Init deixa HEAD detached; prepare main manualmente após revisar histórico e origem |
| Sync bloqueia histórico ou autenticação | Histórico fora da allowlist e origem privada não são resolvidos por `--force`; consulte os limites do sync e use fluxo Git manual revisado quando necessário |
| Lock/journal após interrupção | Preserve os artefatos, confirme ausência de processo ativo e siga a recuperação documentada antes de tentar novamente |

## Roadmap / Próximas implementações

Itens concluídos estão na matriz de funcionalidades; não são pendências abaixo.
A prioridade é estabilizar o fluxo manual antes de aumentar a automação.

| Prioridade | Item | Estado / critério para conclusão |
| --- | --- | --- |
| Alta | Aceitação Ubuntu limpo e macOS já configurado | Parcial: mocks e registros históricos existem; validar instalações reais, recusa, backups, repetição, novas sessões e exclusão do clone/CLI |
| Alta | Fluxo operacional init → sync | Parcial: branch manual, pin antigo, histórico do projeto fora da allowlist e consulta sem autenticação limitam o fluxo; decidir política e validar origem real |
| Alta | PATH/NVM Bash/Zsh completos | Parcial: correções implementadas; validar NVM real, login personalizado, ZDOTDIR definido no startup e interações entre integrações |
| Alta | Docker Engine/CLI/Compose | Pendente: definir instalação Ubuntu e opção macOS, detectar existentes e revisar daemon/permissões; inventário Docker Desktop não constitui módulo |
| Alta | Definir MVP de `env` | Pendente: começar por templates e configuração local opt-in, sem valores secretos em logs/Git; avaliar referência a cofre externo separadamente |
| Média | Diagnóstico e falhas parciais | Parcial: REVIEW/journals existem; tornar saídas e instruções consistentes e validar recuperação sem perder edições |
| Média | Cobertura e CI Ubuntu/macOS | Parcial: 11 suítes locais; falta CI, aceitação real, concorrência/recuperação e casos de upstream/autenticação |
| Média | Revisar destinos e privilégios | Parcial: guardas variam entre NVM, link e init/sync; revisar temporários, symlinks, backups e limites de APT/sudo |
| Futuro, avaliar | Restore/materialização e exportação | Pendente: recuperação atual é manual; definir necessidade antes de criar comando |
| Futuro, avaliar | Diagnóstico global, monitor e novos módulos | Pendente: manter fora do MVP manual até haver necessidade demonstrada |

Para v1.0, é necessário fechar a matriz de aceitação nas duas plataformas, resolver
os limites operacionais de init/sync, validar recuperação e preservação em falhas
reais e decidir se Docker/`env` fazem parte do escopo da versão ou ficam explicitamente
adiados. Um atualizador automático da CLI é **não aplicável ao MVP**: a reinstalação
manual já existe. Windows, perfis automáticos e monitoramento não são requisitos
atuais de v1.0.

Histórico e decisões anteriores: [plano de migração](docs/dotfiles-migration-plan.md),
[captura macOS](docs/macos-initial-capture.md) e [capturas de dotfiles](dotfiles/README.md).

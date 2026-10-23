# Gerenciamento de dotfiles — Fases 5 e 6

> Contrato atual; as execuções macOS citadas ao longo do texto são registros das
> entregas anteriores. A [auditoria de 22/10/2026](dotfiles-sync-audit.md#auditoria-geral-do-repositorio--2026-10-22)
> acrescenta execução das 11 suítes no Ubuntu, sem instalações reais.

A CLI Bash 3.2 permite selecionar configurações independentes. `workspace` e
`config-workplace` aceitam os mesmos comandos. Não instala programas, não usa
Node e não importa configurações do HOME. `init`, após confirmação, e `sync` acessam a origem Git aprovada; os demais
comandos permanecem offline. Sync consulta a rede inclusive em preview, sem
alterar o checkout permanente.

## Fonte permanente e comandos

Execute `workspace dotfiles init --dry-run` e, após revisar o plano,
`workspace dotfiles init`. O caminho padrão é
`${XDG_DATA_HOME:-$HOME/.local/share}/config-workplace-dotfiles/repository`.
Também é possível preparar manualmente um checkout permanente e revisado e
selecioná-lo com `CW_DOTFILES_REPO`. Mantenha a variável nas execuções posteriores.
O clone inicial descartável fornece o instalador; a CLI é copiada para
`~/.local/share/config-workplace`; os links/includes apontam para o **terceiro
local**, o checkout permanente independente. Nunca selecione o clone que
pretende apagar nem a instalação substituível da CLI.

```bash
workspace dotfiles init --dry-run
workspace dotfiles init
workspace dotfiles doctor  # antes da vinculação, reportará alvos ausentes
workspace dotfiles list
workspace dotfiles status
workspace dotfiles status --all
workspace dotfiles link --all --dry-run
workspace dotfiles link --all
workspace dotfiles link --only terminal
workspace dotfiles link --only git
workspace dotfiles link --only vscode
workspace dotfiles unlink --only git
workspace dotfiles unlink --all --dry-run
```

Antes da instalação, use `./bin/workspace`. O bootstrap copia a CLI, bibliotecas
e manifestos, e preserva um comando `workspace` preexistente.

Sem seletor, `link`, `status` e `unlink` continuam limitados ao terminal, para
preservar o comportamento legado. `list` lista todos. `--only terminal-fragment`
é alias de `--only terminal`. Aceita-se um único ID ou `--all`, nunca ambos.
Não existe `--force`. `--dry-run` e `status` não criam locks, backups ou diretórios.

A exclusão do clone inicial não afeta a CLI instalada, o terminal ou o Git quando
a fonte configurada é o checkout permanente separado. **Mover/apagar esse checkout
quebra o symlink do terminal e desativa o include do Git.** O gerenciamento não
promete descobrir se um diretório escolhido explicitamente será apagado depois.

## Inicialização assistida

Origem explicitamente autorizada nesta fase:
`https://github.com/gabriel-vitebo/dotfile.git`. Referência fixa:
`e0ebd0226328b9a4551bd344fa8bb1bcc6126401`. Não se deduz origem a partir de
`origin`, da pasta atual ou de exemplos de terceiros. O remote local auditado
(`gabriel-vitebo/config-worksplace`) não foi alterado nem usado como fallback.
Não há opção de URL arbitrária. Alterar a origem/pin exige nova revisão do código.

Em máquina nova, o plano mostra URL, commit, destino e estado; só depois de uma
confirmação positiva cria diretórios privados, lock e journal. Clone HTTPS sem
checkout inicial, templates ou objetos compartilhados; em seguida checkout
detached do commit fixado. Não há submódulos, hooks, scripts de instalação, pull,
fetch posterior, importação do HOME ou vinculação automática. Git é pré-requisito;
este comando não instala Git nem autentica contas. A configuração pessoal do Git
e variáveis `GIT_*` são isoladas nesses subprocessos. Por isso credential helpers,
reescritas de URL e autenticação pessoal não são herdados: uma origem que exija
credenciais pode requerer preparação manual do checkout por você.

Em máquina existente, init valida e reutiliza sem clone nem checkout. Exige
`.git` independente, raiz correta, URL HTTPS exata aprovada, objetos íntegros via
`fsck`, presença do commit de referência e os três arquivos esperados regulares,
não vazios, sem ancestrais simbólicos, com bytes iguais aos blobs do HEAD local.
Commits locais posteriores não são apagados/rebaixados; mudanças não commitadas
nos três arquivos geram pendência e são preservadas. Isso verifica integridade e
coerência, não certifica a segurança de commits posteriores. Outros arquivos não
são importados, executados ou automaticamente vinculados.

Recusa arquivos, diretórios desconhecidos **mesmo vazios**, links, worktrees com
`.git` externo, clones parciais, alternates, metadados Git simbólicos, locks e journals pendentes.
Revalida depois da confirmação e reserva o destino com `mkdir` exclusivo. Não
sobrescreve um diretório surgido durante a confirmação. Clone/validação falhos
preservam artefatos e registram `incomplete`; não tenta limpar ou reparar sozinho.
Dry-run não acessa rede, cria diretórios, journals ou locks. Se o checkout já
existe, faz somente a mesma validação local de leitura.

## Diagnóstico somente leitura

`workspace dotfiles doctor` agrega pendências, sem confirmação e sem reparo:

- Ambiente macOS/Ubuntu, x86_64/ARM64, Git e utilitários necessários.
- Checkout, origem, objetos Git, arquivos esperados e locks `*.lock` do Git.
- Symlink do terminal, include Git exato, fontes ausentes, conflitos e links quebrados.
- Caminho VS Code para revisão manual, sem mesclar JSONC.
- Estado privado, diretórios de operações, journals ausentes/incompletos,
  backups legíveis ou links de backup preservados, lock ativo ou residual.
- Dependências de caminhos temporários conhecidos (`/tmp`, `/var/tmp`, aliases
  macOS e `TMPDIR`), instalação da CLI, clone em execução e objetos Git externos.

Código 0 indica verificações aprovadas; 1 indica pendências/incompatibilidade;
2 indica opções inválidas. Checkout preparado sem terminal/Git vinculados retorna
1, com `absent`/`personal`; não é convite para sobrescrever preferências. Ausência
do diretório de estado é informativa antes da primeira operação. Locks não são
classificados automaticamente como abandonados: podem pertencer a processo ativo.
O doctor não exige que VS Code esteja aplicado nem executa startup, Git pessoal,
plugins, configurações ou código do checkout para inspeção. A inspeção de caminhos
cobre os vínculos gerenciados e metadados; não interpreta código arbitrário nem
percorre includes pessoais para provar ausência de qualquer dependência indireta.

## Manifesto e políticas

`manifests/dotfiles.manifest` é um arquivo de dados delimitado por `|`, com seis
campos: ID, origem versionada, token de destino, sistemas, política e descrição.
A CLI valida todas as entradas, IDs únicos, ordem e tuplas contra uma allowlist
fechada no código. Tokens são resolvidos por `cw_df_destination`, compartilhado
com os módulos terminal e VS Code. Dados nunca passam por `source` ou `eval`.
Alterar o manifesto não autoriza destinos arbitrários nem novas políticas.
O manifesto usado pertence à instalação da CLI; o checkout permanente fornece
os conteúdos revisados, não instruções executáveis de gerenciamento.

| ID | Origem no checkout permanente | Destino | Política |
| --- | --- | --- | --- |
| `terminal` | `manifests/terminal/zshrc` | `~/.config/config-workplace-terminal/zshrc` | Symlink absoluto |
| `git` | `manifests/git.config` | `~/.gitconfig` | Arquivo regular com include gerenciado no início |
| `vscode` | `manifests/vscode-settings.json` (referência para revisão) | macOS: `~/Library/Application Support/Code/User/settings.json`; Ubuntu: `${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json` | `review-jsonc`: integração existente, sem escrita pela CLI dotfiles |

As três entradas declaram macOS e Ubuntu. Capturas em `dotfiles/common`,
`dotfiles/macos`, perfis adicionais e preferências de IA não são ativadas.

### Git

O arquivo portátil contém aliases `st`, `co`, `br`, `ci`, diff `histogram` e
conflitos de merge `diff3`. Não contém identidade, editor específico, credenciais,
tokens, SSH, caminhos de máquina ou configuração corporativa. O exemplo histórico
`dotfiles/common/git/gitconfig.example` não é aplicado.

`link --only git` prepara um bloco `[include]` delimitado por comentários
`BEGIN/END config-workplace portable Git`, apontando diretamente para a fonte
permanente. Esse bloco é **anteposto** ao `.gitconfig`: seus bytes originais,
comentários, permissões e presença/ausência de newline final são preservados.
Preferências escalares posteriores no arquivo pessoal têm precedência sobre os
padrões portáteis. Nenhum Git pessoal é executado para inspecionar o arquivo; não
é necessário ter Git instalado para aplicar o include. A CLI não interpreta nem
corrige configurações Git inválidas preexistentes.

Não se substitui `.gitconfig` por symlink. Symlinks existentes, inclusive quebrados,
diretórios e marcadores gerenciados modificados/reposicionados são conflitos.
O gerenciamento cobre somente `.gitconfig`, não arquivos escolhidos por
`GIT_CONFIG_GLOBAL`, includes corporativos ou a configuração alternativa
`$XDG_CONFIG_HOME/git/config`; revise a precedência local se usar esses mecanismos.

`unlink --only git` remove exclusivamente o prefixo exato reconhecido, conservando
todos os demais bytes, inclusive edições pessoais feitas depois do link. Se a CLI
criou um `.gitconfig` inicialmente ausente, o unlink deixa um arquivo regular vazio.
Repetir unlink sem o bloco é uma operação sem alterações. Não restaura um backup
sobre edições posteriores. Um include com fonte ausente pode ser removido.

### VS Code

`settings.json` não é adequado a symlink de um arquivo completo: contém JSONC,
preferências da máquina e chaves desconhecidas. `link --only vscode`, `unlink` e
`status` exibem **MANUAL / review-jsonc**, preservando integralmente o arquivo.
Links/ancestrais externos e destinos que não sejam arquivos são conflitos; nenhuma
configuração pessoal é carregada. `--all` mantém essa exclusão explícita.

Permanece disponível a integração existente de `initial dev`, com parser JSONC,
revisão por chave, confirmação, backups e rechecagem de concorrência. Essa integração
legada usa Node e também planeja ferramentas/extensões: não é invocada implicitamente
por `dotfiles`. A CLI de dotfiles continua sem exigir Node. Para revisar somente
preferências sem instalar nada, compare manualmente as seis chaves candidatas de
`manifests/vscode-settings.json` com seu arquivo local. Não copie o arquivo inteiro,
perfis capturados ou dados sensíveis para o checkout. A instalação de extensões não
foi alterada nesta fase.

### Terminal

O fragmento neutro preserva tema, plugins, aliases, Zsh e Oh My Zsh. Não define
robbyrussell nem inicializa o framework. NVM/completion opcionais são carregados
uma vez por sessão; PATH não é duplicado. `.zshrc` pessoal, ZDOTDIR e `.zprofile`
não são editados ou executados para inspeção. Ativação em startups existentes
continua manual; criar o symlink não ativa sozinho o fragmento.

O módulo terminal continua instalando ferramentas mediante suas confirmações e
reconhece o link gerenciado para não escrever na fonte. Bootstrap separado e
proposta de startup da Fase 3.1 permanecem disponíveis. Cópia idêntica do fragmento
pode ser convertida com confirmação e backup; divergência exige revisão manual.
`unlink` remove só o symlink absoluto reconhecido, mesmo quebrado; não materializa
nem restaura cópia, portanto o fragmento deixa de ser carregado.

## Planos, conflitos e falhas

Todos os IDs selecionados são inspecionados antes da primeira confirmação. Um
conflito ou fonte ausente bloqueia o lote inteiro. `--only` permite tratar outro
ID independentemente. A confirmação é negativa por padrão. Destinos e fontes são
revalidados após aprovação, e cada aplicação verifica novamente seu snapshot.
Arquivos não selecionados não são modificados.

Estados incluem `absent`, `identical`, `divergent`, `foreign-link`, `broken-foreign`,
`broken-managed`, `correct`, `conflict` e `personal` (Git sem bloco gerenciado).
`correct` verifica vínculo/include, não se o conteúdo da fonte permanente foi
alterado desde uma execução anterior. Código 0 significa sucesso, ausência de
alterações ou recusa explícita; 1 indica conflito/fonte ausente/falha; 2, uso inválido.
`status` retorna 1 se um alvo efetivamente gerenciado não está correto. VS Code é
informativo: código 0 não significa settings mesclados ou aplicação concluída.

Se houver falha durante aplicação, a execução para; alterações anteriores bem
sucedidas são conservadas. Não há rollback que remova outros arquivos. Reexecute
após revisar os journals: os alvos já corretos são idempotentes.

Para conflitos, preserve uma cópia privada, compare localmente a fonte e o destino
e decida manualmente quais preferências manter. Nunca importe secrets ao Git.
Links externos/relativos não são adotados. Um bloco Git modificado exige revisão
manual antes de removê-lo/reaplicá-lo. A CLI não imprime conteúdo pessoal em planos.

## Backup e recuperação manual

Estado fica em `${XDG_STATE_HOME:-$HOME/.local/state}/config-workplace/dotfiles`,
fora do checkout e da raiz da CLI. Cada arquivo alterado usa lock por `mkdir`,
diretório privado `operation.XXXXXX`, journal e backup. `original` guarda o arquivo
anterior com permissões; `original-link` guarda o symlink antes do unlink. Backups
não são reutilizados nem apagados. No Git, o backup contém também dados pessoais:
mantenha esse diretório privado e fora do versionamento.

Candidatos são preparados em staging privado adjacente ao destino. Arquivos
existentes são trocados por rename após sondagem GNU `mv -fT` / BSD `mv -fh` e
revalidação; nunca por `rm original; ln ...`. Git ausente é publicado por hardlink
sem sobrescrever destino surgido durante a operação. O arquivo final é regular,
sem dependência do staging. Os bytes portáteis permanecem no checkout permanente.

Journals incompletos e staging são preservados e anunciados. Para recuperação:

1. Execute `workspace dotfiles doctor`. Consulte `action`, `destination`, `source`,
   `reference` (init), `before`, `staging` e a última etapa do journal. Não execute
   nem faça `source` do journal: é somente dado.
2. Compare o destino atual com `original`/`original-link` em área privada. Se houver
   edições posteriores, preserve-as antes de decidir qual versão recuperar.
3. Para Git, prefira `unlink --only git` se o prefixo ainda é reconhecido; isso
   mantém edições pessoais posteriores. Para restauração integral, copie manualmente
   o backup revisado ao destino, preservando permissões, somente após verificar que
   ele não é um symlink externo e que não perderá edições.
4. Para terminal, remova só o symlink reconhecido com `unlink --only terminal` e,
   se necessário, copie manualmente o `original` revisado ao caminho ausente.
5. Revise journals incompletos antes de nova tentativa. Remova um lock residual
   com `rmdir` apenas após confirmar que nenhuma operação está ativa.

Para `init` interrompido, preserve o checkout parcial e o journal em área privada.
Verifique se há processo ativo antes de qualquer movimentação. Após revisão e
confirmação humana, mova o diretório parcial para um nome de recuperação livre
(sem sobrescrever nada) e arquive o diretório `operation.*` incompleto fora da
lista de operações pendentes; só então tente init novamente. Não descarte objetos,
arquivos ou edições posteriores para forçar validação. Nenhum comando de restore
foi adicionado: restauração integral permanece manual e exige comparar/preservar
as versões atuais antes de qualquer substituição.

Sinais tratáveis liberam o lock. SIGKILL/queda de energia podem deixá-lo residual.
Uma falha de journal após publicação pode deixar o destino já aplicado; nunca
assuma que código de erro significa ausência de alterações.

## Limites e validação

O lock serializa aplicações por arquivo, não editores externos nem todo o lote.
Snapshots usam identidade/metadados e `cksum`, que não é hash criptográfico.
Bash/POSIX não oferecem compare-and-swap de nomes: permanece uma janela entre
última validação e publicação/remoção. Não há garantia contra concorrência hostil,
`fsync`, atomicidade global ou rollback automático. Sob BSD, um diretório real
criado na janela final pode receber o candidato; a verificação posterior registra
falha e conserva artefatos, sem remoção destrutiva. Não execute gerenciadores ou
editores concorrentes durante as operações.

`tests/dotfiles-multi.sh` cobre listagem, seleção, todos os IDs, idempotência,
conflitos, fontes ausentes, dry-run, falhas parciais, backups/journals, identidade e
precedência Git, JSONC preservado, tema pessoal, resolução macOS/Ubuntu, manifesto
malicioso e exclusão do clone de instalação. `tests/dotfiles.sh` conserva os testes
de links, concorrência, falhas de staging/rename e sinais. As regressões terminal,
bootstrap, initial-dev, phase-2.2 e Java continuam isoladas em fixtures.

`tests/dotfiles-init.sh` acrescenta máquina limpa, reutilização, recusa, dry-run,
destinos ocupados, falhas de clone/validação, preservação pessoal, journals/locks,
fontes alteradas, caminhos proibidos, origem não aprovada, objetos compartilhados
e exclusão do clone inicial após bootstrap. Usa HOME descartável e mocks de rede,
com Git real para objetos, checkout, fsck e leitura do include.

A validação nativa desta entrega é macOS/BSD com Bash 3.2. Os testes de contratos
Ubuntu não equivalem à execução nativa GNU/Ubuntu, que permanece pendente, assim
como aceitação visual/instalação real e acesso autenticado à origem autorizada.
A suíte deve rodar de checkout em caminho permanente (não sob `/tmp`/`TMPDIR`),
pois testa a recusa real de caminhos temporários; sua fixture fica em `tests/.phase5.*`.
Esses resultados descrevem a entrega da Fase 5. A Fase 6 abaixo acrescenta sync
manual. Restore, configurações VS Code adicionais e instalações Java/Docker
continuam fora do escopo.


## Git Sync manual — Fase 6

A origem permanece `https://github.com/gabriel-vitebo/dotfile.git`; **main foi
explicitamente aprovada pelo usuário**. Sync nunca deduz upstream, troca de
branch, usa pushurl, modifica configurações globais ou importa o HOME.
O checkout padrão continua `~/.local/share/config-workplace-dotfiles/repository`,
com os overrides já existentes da Fase 5. Não use a raiz da CLI ou o clone inicial.

### Preparação

```bash
workspace dotfiles init --dry-run
workspace dotfiles init
```

Init permanece fixado no commit aprovado, em detached HEAD. Antes de sync,
revise o estado do checkout permanente e selecione **manualmente** `main`.
Se ela já existe, use `git -C "$repo" switch main`; se ainda não existe e você
quer começar no commit atual revisado, `git -C "$repo" switch -c main`.
Nesses exemplos, defina `repo` como o caminho permanente efetivamente usado.
Não use `-C` no clone descartável nem opções que descartem alterações.
Uma branch que diverge do remoto exige resolução manual, não troca automática.

O pin é anterior aos commits atuais de código/documentação. Se main da origem
aprovada incluir esses commits, o sync bloqueia o avanço por conter caminhos fora
da allowlist. Criar main no pin não resolve essa restrição. A auditoria confirmou
esses caminhos no histórico local, sem consultar a main remota; atualizar o projeto
exige fluxo Git manual revisado e reinstalação da CLI, separado do sync de preferências.

Para criar commits, prepare manualmente `user.name` e `user.email` **locais ao
checkout**, com identidade não corporativa aprovada. Não se importa a identidade
global, e a CLI não executa comandos de configuração por você.

```bash
workspace dotfiles sync --status
workspace dotfiles sync --dry-run
workspace dotfiles sync
```

`--status` e `--dry-run` fazem o mesmo preview completo, incluindo a consulta
HTTPS da branch aprovada. Criam apenas um armazenamento temporário privado de
objetos Git, sem working tree, removido ao terminar. Não escrevem objetos, refs,
FETCH_HEAD, índice, backups, journals ou arquivos no checkout permanente/HOME.
Não usam nem dependem do clone inicial. Não são modos offline: rede indisponível,
autenticação exigida ou main ausente retornam REVIEW, nunca um falso SKIP.
A consulta transfere o histórico necessário e pode ser custosa em repositórios
grandes; não há cache persistente de preview nesta fase.

### Revisão e decisões

O resumo mostra quantidade de commits locais/remotos e arquivos locais. São
exibidos hashes de commits, estatísticas e diffs; mensagens de commits não são
impressas. Conteúdo suspeito bloqueia o diff antes de qualquer exibição.

- **Sem alterações:** SKIP, sem confirmação, commit ou estado novo.
- **Somente locais:** diff dos arquivos modificados, adicionados e removidos.
  A primeira confirmação aprova todos os arquivos permitidos exibidos para
  staging e commit. A mensagem é `chore(dotfiles): sync reviewed portable preferences`.
  Uma segunda confirmação aprova push. Recusar a primeira preserva tudo; recusar
  a segunda conserva o commit local, que pode ser publicado em outra execução.
  Se houver apenas commits locais anteriores, há uma única confirmação de push.
- **Somente remotas:** todos os commits e seus blobs intermediários são revisados.
  Após confirmação, aplica somente fast-forward para o hash exato do preview.
  Não há merge de conteúdo, reset, clean ou checkout automático de branch.
- **Locais e remotas:** REVIEW e saída 1, mesmo se os arquivos forem diferentes.
  Ambos os lados são preservados. Conflitos existentes também bloqueiam.

A seleção é o conjunto exibido de alterações dentro da allowlist, não um seletor
interativo por arquivo. Para enviar só parte delas, prepare manualmente as mudanças
em área separada e revise novamente. Índice previamente ocupado é bloqueado;
a CLI não aproveita staging de outra operação nem faz `git add -A`.

### Proteções e limites da revisão

Somente `manifests/terminal/zshrc`, `manifests/git.config` e
`manifests/vscode-settings.json` podem mudar no fluxo. Arquivos desconhecidos
não ignorados bloqueiam; arquivos ignorados não são incluídos. Commits mistos,
merges e alterações fora da allowlist bloqueiam atualização/publicação integral.
Cada commit de saída/entrada tem seus blobs anteriores e posteriores inspecionados,
inclusive secrets adicionados e depois removidos. Renames aparecem como remoção
mais adição. Symlinks, hardlinks nas fontes, submódulos alterados, clones parciais,
shallow, alternates, grafts, locks, índices com flags especiais e operações Git
pendentes exigem revisão manual.

A configuração Git local usa uma lista fechada de chaves. Includes, aliases,
filtros, helpers, URL rewrites, pushurl e configurações não previstas bloqueiam.
Hooks são desativados; scripts do checkout, filtros, textconv e diff externo não
são executados. Atributos Git nos caminhos relevantes são recusados. O mecanismo
não flexibiliza as validações de init para permitir edições locais em sync.

O detector procura padrões de tokens, senhas, chaves privadas e indicadores
corporativos. Rejeita também conteúdo não ASCII, controles e arquivos acima de
256 KiB: são restrições conservadoras desta versão. Pode produzir falsos positivos
ou não identificar dados sensíveis inéditos. **Revisão humana é obrigatória**:
aprovar significa revisar também se os dados são pessoais portáteis e não
corporativos. O scanner não valida sintaxe ou semântica dos conteúdos shell/Git/JSON. Um arquivo
permitido pode passar pelos padrões e ainda ser inválido ou executar código
indesejado quando carregado; HTTPS/fsck não certificam seu comportamento.
Não existe `--force` ou bypass de secrets. Resolva suspeitas em
área privada e reexecute; nunca cole credenciais em logs ou mensagens de suporte.

O push usa HTTPS, hash/refspec explícitos e nunca force. Credential helpers e
configurações pessoais não são executados. Após aprovação do push, o próprio Git
pode solicitar usuário/token diretamente no terminal, sem persistir credenciais.
Sem terminal/autenticação válida, a operação falha preservando o commit. Consultas
não interativas não autenticam repositórios privados. Como a consulta antecede
qualquer commit/push, poder autenticar o push não basta para tornar o fluxo
utilizável numa origem privada. `gh auth login` não resolve essa consulta isolada. Erros brutos de transporte
não são impressos, pois podem conter informações sensíveis. Não há login automático,
instalação de ferramentas ou mudança de configuração de credenciais.

Sync não escreve em `.zshrc`, `.gitconfig`, SSH ou settings pessoais do VS Code.
**Atualizar fontes já vinculadas muda o conteúdo observado pelo terminal/include
Git**; o preview informa esse efeito. Integração de preferências em arquivos
pessoais continua separada, com preview/backup/confirmação próprios. A referência
VS Code não é aplicada automaticamente. Não inicie novas sessões dos aplicativos
nem edite o checkout durante a atualização: não há atomicidade entre vários arquivos.

### Falhas, conflitos e recuperação

Operações aprovadas usam o lock compartilhado de dotfiles, journal com HEAD anterior
e hash remoto, cópia do índice e backup dos três arquivos em `operation.*/files`.
O checkout é revalidado após confirmação e antes de mutações. O staging real é
comparado com os bytes aprovados; o commit criado é verificado antes de publicar.
Nenhum backup é versionado ou apagado automaticamente.

Se commit falhar, o staging pode permanecer preparado. Se push falhar, o commit
local permanece. Um erro de rede após o servidor aceitar um push pode deixar o
resultado remoto incerto. Inspecione ambos os HEADs antes de repetir. Journals
incompletos bloqueiam novas operações; não os marque completos sem revisar.
Preserve o journal/backup em área privada de recuperação fora de `operation.*`
após reconciliar o estado e confirmar que não existe processo ativo. Só remova
lock residual com `rmdir` depois dessa confirmação. Não há rollback automático.
O armazenamento temporário é removido em saídas/sinais tratáveis; SIGKILL pode
exigir limpeza manual do diretório privado `cw-sync.*`, depois de verificar processos.

Para divergências, preserve o checkout e resolva manualmente em uma cópia
independente de revisão. Não faça merge experimental no checkout com fontes
ativas. Se a resolução criar commits de merge ou misturar código/arquivos fora
da allowlist, a integração/publicação exigirá um fluxo Git manual revisado.
Sync não tenta reescrever o histórico para contornar suas proteções.

Códigos: 0 para sucesso, preview elegível, SKIP ou recusa; 1 para REVIEW/falha;
2 para argumentos inválidos. Preview não significa publicação ou aplicação.
Backups não dão compare-and-swap contra editores externos; há janelas de corrida
e não há garantia de fsync/atomicidade global. A exclusão do clone inicial é
suportada; apagar o checkout permanente continua quebrando vínculos.

Validação isolada: `bash tests/dotfiles-sync.sh`, com remotes bare locais e Git
real; nenhum push vai ao GitHub. Execução nativa desta entrega: macOS/Bash 3.2.
Os contratos Ubuntu são simulados; validação nativa Ubuntu, autenticação real e
aceitação em máquinas descartáveis permanecem pendentes. Nenhuma próxima fase,
sincronização em background, cron ou instalação foi iniciada.


## Diferenças entre validações locais

`link`/`unlink`/`status` verificam caminhos e vínculos, mas não exigem origem,
branch, integridade Git ou a mesma recusa de temporários de init/doctor/sync.
O nome “checkout permanente” descreve o destino que o usuário deve escolher;
não é garantia produzida somente por um link bem-sucedido. Valide o checkout
com doctor antes de depender dele após apagar o clone inicial.

`status` não compara os conteúdos da fonte com HEAD; um vínculo `correct` pode
apontar a arquivo editado. Já init/doctor exigem as três fontes iguais a HEAD,
portanto uma edição intencional pode causar pendência até ser revisada.
Link/unlink apenas anunciam journals incompletos e podem continuar;
init/doctor/sync os bloqueiam. Recuperação manual deve considerar essa diferença.

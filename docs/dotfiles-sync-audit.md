# Auditorias do projeto

## Fase 6 — auditoria prévia

> Registro histórico anterior à implementação do sync. O diagnóstico atual está
> na [auditoria geral](#auditoria-geral-do-repositorio--2026-10-22); o contrato
> operacional está em [dotfiles.md](dotfiles.md). Resultados e referências a
> staging/remote nos relatos antigos pertencem àquelas entregas.

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

## Auditoria geral do repositorio — 2026-10-22

Base: `efcaa6a` (`5812708` adicionou persistência NVM; `efcaa6a` ampliou sondagem
PATH). Árvore inicialmente limpa. Auditoria exclusivamente documental: nenhum
script, teste, manifesto, configuração ou comportamento da CLI foi alterado;
nenhum commit/push do projeto foi feito. As referências a staging e remote nas
seções históricas não representam o estado desta execução.

### Escopo e arquitetura confirmados

Revisados README, documentos existentes, entradas CLI, bootstrap, bibliotecas,
três módulos, adaptadores, manifestos, capturas, inventários, 11 suítes, ignore
e histórico recente. Não há CI versionada. Não foi inspecionado o HOME pessoal
para inferir preferências, nem executado módulo real para testar documentação.

A CLI Bash despacha comandos em `lib/cli.sh`; `lib/setup.sh` compartilha
sondagens/plataforma/HTTPS. `lib/dev-safety.sh` cuida de destinos e startup;
`lib/dev-tools.sh`, helpers JS e `platforms/` cuidam das ferramentas/editor.
`lib/dotfiles.sh` concentra manifesto, vínculos, init/doctor e sync.
Java usa helpers próprios de detecção, catálogo, SDKMAN! e extensões.

Há três locais distintos: clone descartável, payload permanente da CLI e checkout
permanente dos dotfiles. Ferramentas/frameworks têm diretórios próprios fora deles.
Manifests são dados aprovados; `dotfiles/` e `inventory/` são capturas históricas,
não entradas gerais de instalação. Remover o checkout permanente quebra vínculos;
remover a CLI não desinstala ferramentas. Destinos personalizados requerem revisão:
as guardas não provam independência de todo caminho de clone escolhido pelo usuário.

### Matriz de funcionalidades e evidências

| Área | Estado | Evidência e limite |
| --- | --- | --- |
| CLI/bootstrap | Implementado | `bin/`, `lib/cli.sh`, `install.sh`: 0.2.2, cópia allowlisted, staging, backup/rollback e lock; workspace existente preservado |
| Atualização da CLI | Implementado | Reexecutar bootstrap da versão revisada; sem update automático |
| PATH | Implementado | `cw_local_path`: sonda `-ic`, `-lc`, `-lic`; ajusta `.bashrc` e login conforme necessário, respeita ZDOTDIR efetivo |
| Initial dev | Implementado | Git/gh/NVM/Node/npm/pnpm/editor/utilitários, detecção e confirmações; instalações reais ainda não aceitas integralmente |
| NVM em novas sessões | Parcial | `cw_nvm_shell_plan/apply`: bloco persistente, backup/recusa/idempotência; integrações não gerenciadas e profiles personalizados ficam manuais |
| Terminal | Implementado | Ferramentas separadas de fragmento/bootstrap; tema versionado robbyrussell/git, preservação do startup existente, chsh opt-in |
| Java | Parcial | JDK Temurin LTS, Maven/Gradle opcionais e extensões; ativação manual, sem profile aprovado/importado, aceitação real pendente |
| Dotfiles terminal/Git | Implementado | Allowlist e políticas de symlink/include; não gerencia HOME inteiro, não adota links externos |
| VS Code | Parcial | JSONC por chave e extensões em initial dev; dotfiles apenas orienta, sem profiles/backup de editor completo |
| Init/doctor | Implementado | Pin e origem fixos, objetos independentes e diagnóstico sem reparos; doctor não é diagnóstico global |
| Sync manual | Parcial | origin/main exatos, allowlist, scanner, commit/push separados e fast-forward confirmado; limitações de autenticação/histórico abaixo |
| Docker/Compose | Pendente | Nenhuma rota funcional/módulo; Docker Desktop no inventário é somente observação |
| Env/secrets/exportação | Pendente | Nenhum módulo ou armazenamento local implementado; MVP recomendado: templates e valores locais opt-in, sem secrets em Git/logs |
| Recuperação | Parcial | Rollback no bootstrap; backups/journals nos outros fluxos e recuperação manual, sem restore/materialização |
| CI | Pendente | Sem workflow versionado; testes shell locais existem |
| Diagnóstico global/monitor/notificações | Pendente | Sem rotas, serviço ou timer; avaliar após estabilizar o fluxo manual |
| Windows/atualizador automático | Não aplicável ao MVP | Alvos atuais Ubuntu/macOS; atualização manual já atende a CLI |

### Validação executada nesta auditoria

Ambiente nativo: Ubuntu 26.04.1 LTS, x86_64, Bash 5.3.9, Zsh 5.9,
Node 24.22.1 e Git 2.53.0. Essas versões descrevem o ambiente de teste, não
pins de instalação nem requisitos mínimos do projeto.

Todas as **11 suítes terminaram com código 0**. Nove suítes reportam juntas
186 grupos/verificações; PATH acrescenta sete grupos e NVM possui uma suíte
sem contador numérico. Esses agrupamentos não são contagem de asserts nem
porcentagem de cobertura. O antigo número histórico 79 não foi reutilizado.

| Suíte | Resultado | Cobertura observada |
| --- | --- | --- |
| `tests/bootstrap.sh` | 18 verificações | Instalação isolada, aliases, reinstalação, destinos desconhecidos, rollback, PATH e exclusão do clone |
| `tests/initial-dev.sh` | 27 verificações | Sondagens, origens, política LTS, autorização Node, alias, bloqueios, NVM e adaptadores simulados |
| `tests/phase-2.2.sh` | 27 verificações | JSONC real, comentários, granularidade, concorrência, extensões, pnpm, editor/PATH e pacotes simulados |
| `tests/terminal.sh` | 26 verificações | Tema/framework, bootstrap, recusa parcial, preferências existentes, Zsh real com fixtures, independência do clone/CLI |
| `tests/java.sh` | 27 verificações | Detecção, catálogo/compatibilidade simulados, SDKMAN isolado, defaults, extensões e falhas parciais |
| `tests/dotfiles.sh` | 10 grupos | Vínculos, conflitos, backups, sinais, falhas de staging/rename e concorrência |
| `tests/dotfiles-multi.sh` | 16 grupos | Seleção, include Git/precedência, JSONC preservado, manifesto inválido, concorrência e falha parcial |
| `tests/dotfiles-init.sh` | 16 grupos | Clone local fixado, validações, hooks bloqueados, locks/journals e remoção do clone |
| `tests/dotfiles-sync.sh` | 19 grupos | Git real local, commit/push/fast-forward, divergência, secrets intermediários, allowlist, autenticação simulada e recuperação |
| `tests/path-startup.sh` | 7 grupos | Sessões Bash e Zsh reais, login/não-login, ZDOTDIR herdado/definido em startup, recusa, backup e permissões |
| `tests/nvm-startup.sh` | OK, sem contador | NVM/Node simulados em novas sessões Bash/Zsh, caminhos com espaços, recusa, backup e clone removido |

Também aprovados: `/bin/bash -n` em 31 arquivos, `node --check` nos dois helpers,
seis chamadas CLI de leitura (sem argumentos, help, version, list e ajuda/lista
de dotfiles), e `git diff --check`. Logs brutos ficaram em
`/tmp/config-workplace-audit/` nesta sessão, fora do repositório; são temporários.

Todas as suítes usam HOME descartável. Bootstrap, initial-dev, multi, init e sync
criam fixtures sob `tests/`; outras usam temporários do sistema. Rede/instaladores
são simulados; Git real cria commits e pushes apenas em remotes locais. O runner
da auditoria fixou `SHELL=/bin/bash` e removeu overrides de XDG/dotfiles/NVM/Git
relevantes antes das suítes, sem mudar seus arquivos. Não foi criada CI nem teste novo.

**Não executados:** instalações reais/APT/Homebrew/download de fornecedores,
sudo, chsh, login gh/GitHub, consulta à origem aprovada, recuperação com queda
de energia, aceitação visual e fluxo completo em máquinas limpas/configuradas.
Motivo: preservar o ambiente do usuário e manter a tarefa documental.
macOS/Bash 3.2/BSD não foi reexecutado aqui; seus resultados nos documentos antigos
continuam históricos. ShellCheck não estava disponível e não foi instalado.

Lacunas de cobertura: aceitação ponta a ponta com NVM/SDKMAN!/Oh My Zsh reais;
combinações de startup pessoal, HOME redefinido por startup global e precedência
de ferramentas; credenciais e APIs atuais dos fornecedores; recuperação de falhas
reais e concorrência externa; efeito visual do tema/editor. Mocks não comprovam
compatibilidade de novas respostas upstream. Não há testes funcionais Docker/env
porque não existem esses módulos.

### Inconsistências documentais corrigidas

- macOS deixou de ser anunciado como plataforma apenas futura; Windows saiu do
  fluxo suportado. Compatibilidade implementada e aceitação real foram separadas.
- Removidos do fluxo de uso comandos globais inexistentes e opções apenas propostas;
  ajuda real e namespace `dotfiles` agora são a referência.
- Eliminadas descrições contraditórias de PATH “somente profile”/“PATH herdado basta”;
  registrada a correção para Bash interativo não-login e execução dos startups.
- Corrigida a analogia antiga Java/NVM: NVM propõe edição confirmada de startup;
  SDKMAN! continua manual. Registrados limites de ZDOTDIR e login personalizado.
- Cópias obrigatórias/Chezmoi/árvore YAML/monitor não representam a arquitetura atual;
  decisões e requisitos RN históricos foram preservados no plano de migração.
- Diferenciados link versus ativação, status de vínculos versus drift Git,
  unlink versus restore, atualização da CLI versus sync de preferências.
- Resultados antigos de testes, relatos de staging/remote e capturas foram marcados
  como históricos; o README aponta para os resultados realmente executados aqui.
- Removida a impressão de que todo APT usa `--no-upgrade`; Git/gh têm outro adaptador.

### Problemas e limites de implementação encontrados — sem correção de código

1. **Init → sync não é um fluxo automático completo.** `cw_df_assist` cria detached
   HEAD no pin antigo; `cw_sync_guard` exige main manual. Além disso,
   `cw_sync_history` bloqueia qualquer commit que altere código/docs fora dos três
   arquivos. O histórico local do pin até `efcaa6a` contém esses caminhos. Se a main
   aprovada remota contém esse histórico, o avanço é recusado; o remoto não foi
   consultado nesta auditoria. Requer decisão sobre origem/histórico/escopo antes
   de oferecer sync como manutenção rotineira do mesmo repositório.
2. **Origem privada e consulta sem autenticação.** `cw_df_git`/`cw_sync_git` isolam
   config/ambiente e helpers; init/fetch não permitem prompt. O prompt de push vem
   depois de um fetch bem-sucedido. Login gh ou credenciais globais não resolvem
   automaticamente esse fluxo. Acesso real ao pin/origem segue sem validação.
3. **Dry-run não é sandbox de código existente.** `cw_load_nvm` carrega nvm.sh
   mesmo no planejamento; sondagens executam ferramentas. `cw_local_path` executa
   startup pessoal e não possui timeout próprio para startup que bloqueie. Os
   comandos evitam suas mutações planejadas, mas não controlam código de terceiros.
4. **Guardas de permanência não uniformes.** `cw_df_one` valida links/caminhos, mas
   não usa toda a validação Git/temporários de init/sync. `cw_install_nvm` usa
   checagem textual contra CW_ROOT, sem a mesma inspeção de ancestrais. Caminhos
   personalizados podem contrariar o princípio de independência. Startup NVM usa
   ZDOTDIR herdado; PATH resolve também `.zshenv`. Não foi implementada unificação.
5. **Scanner não valida configuração executável.** `cw_sync_scan` verifica padrões,
   tamanho/ASCII e caminhos, sem validar shell/Git/JSON recebidos. `fsck` comprova
   integridade de objetos, não segurança semântica. Conteúdo permitido exige revisão
   humana antes de afetar vínculos ativos. Há falsos positivos, inclusive Unicode.
6. **Recuperação e concorrência limitadas.** Não há restore/materialização, transação
   global, fsync ou compare-and-swap contra editores. Sucessos parciais permanecem.
   Link/unlink apenas avisam journals incompletos, enquanto init/sync bloqueiam.
   APPEND de startup e backups não compõem a mesma transação do bootstrap.
7. **Sinalização não comprova conclusão do ambiente.** REVIEW pode retornar 0;
   terminal pode terminar com configuração adiada; componentes Apple exigem outra
   execução; pnpm depende do caminho Node capturado. Doctor verifica fontes iguais
   a HEAD e pode acusar edição intencional que status de vínculo aceita.
8. **Manutenção/testes operacionais.** Allowlists de empacotamento são repetidas;
   versão permanece 0.2.2 apesar de entregas posteriores; não há CI ou matriz de
   aceitação real. Isolamento HOME das suítes não isola startup global/binários do host.

### Priorização para v1.0

1. **Alta:** executar aceitação Ubuntu limpo e macOS configurado: aprovar/recusar,
   repetir comandos, conferir backups, abrir sessões Bash/Zsh, excluir clone/CLI e
   comprovar ferramentas e vínculos independentes. A implementação já existe em
   boa parte; não repetir esse trabalho como funcionalidade nova.
2. **Alta:** definir e validar política operacional init/sync para histórico do projeto,
   branch/pin e origem privada; documentar/testar um fluxo realmente utilizável.
3. **Alta:** fechar aceitação NVM/PATH e caminhos personalizados; decidir inclusão ou
   adiamento explícito de Docker/Compose e MVP local seguro de env na v1.0.
4. **Média:** CI Ubuntu/macOS, testes das lacunas acima, revisão de privilégios/destinos,
   mensagens de pendência e recuperação de falhas parciais sem perder dados.
5. **Futuro/avaliar:** restore/materialização/exportação, diagnóstico global e novos
   módulos. Monitor/automação/Windows não são necessários para estabilizar o MVP.

O projeto possui base funcional e testes isolados aprovados, mas ainda não tem
aceitação operacional suficiente para declarar v1.0 estável. Não falta implementar
novamente bootstrap, PATH, NVM startup, terminal ou o motor manual de sync;
faltam fechar seus limites, validar em ambientes descartáveis e fixar o escopo.

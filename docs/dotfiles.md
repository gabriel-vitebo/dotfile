# Gerenciamento de dotfiles — Fase 4

A CLI Bash 3.2 permite selecionar configurações independentes. `workspace` e
`config-workplace` aceitam os mesmos comandos. Não instala programas, não usa
Node, não acessa rede e não importa configurações do HOME.

## Fonte permanente e comandos

Prepare manualmente um checkout **permanente e revisado** deste projeto em
`${XDG_DATA_HOME:-$HOME/.local/share}/config-workplace-dotfiles/repository`, ou
indique outro checkout permanente com `CW_DOTFILES_REPO`. Mantenha a variável
nas execuções posteriores se usar caminho personalizado. Não selecione o clone
que pretende apagar nem a instalação substituível `~/.local/share/config-workplace`.
A CLI não clona nem sincroniza esse repositório.

```bash
export CW_DOTFILES_REPO="$HOME/repos/config-workplace-permanente"
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

1. Consulte `destination`, `source`, `before`, `staging` e a última etapa do journal.
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

A validação nativa desta entrega é macOS/BSD com Bash 3.2. Os testes de resolução
Ubuntu não equivalem à execução nativa GNU/Ubuntu, que permanece pendente, assim
como aceitação visual/instalação real. Fase 5: avaliar registro persistente mais
amplo, restore/materialização, inicialização assistida do checkout e concorrência
mais forte. Git Sync exige tarefa própria; não foi iniciado.

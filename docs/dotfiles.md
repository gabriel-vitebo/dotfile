# Gerenciamento de dotfiles — Fase 2.1

A CLI Bash 3.2 oferece `workspace dotfiles link`, `status`, `unlink` e
`link --dry-run`. A entrada `config-workplace dotfiles` é equivalente.
O bootstrap empacota a biblioteca e cria `workspace` somente se esse comando
não existir em `~/.local/bin`; qualquer comando preexistente é preservado.

## Fonte e uso

Prepare manualmente um checkout permanente e revisado deste projeto em
`${XDG_DATA_HOME:-$HOME/.local/share}/config-workplace-dotfiles/repository`, ou
indique outro checkout permanente com `CW_DOTFILES_REPO`. A CLI não clona,
não faz sync e não importa arquivos pessoais. Não use a instalação substituível
`~/.local/share/config-workplace` como fonte. Exemplo usando um checkout já preparado:

```bash
export CW_DOTFILES_REPO="$HOME/repos/config-workplace-permanente"
./bin/workspace dotfiles status
./bin/workspace dotfiles link --dry-run
./bin/workspace dotfiles link
./bin/workspace dotfiles unlink --dry-run
./bin/workspace dotfiles unlink
```

Depois da instalação, use `workspace` em vez de `./bin/workspace`.
A variável deve ser mantida nas execuções posteriores se usar caminho personalizado.
Remover ou mover o checkout permanente quebra os links. Remover o clone usado
para instalar a CLI não interfere, desde que ele não seja a fonte selecionada.

## Seleção e preservação

A allowlist é propositalmente fixa e contém um único par:
`manifests/terminal/zshrc` → `$HOME/.config/config-workplace-terminal/zshrc`.
Reutilizamos o manifesto canônico existente sem duplicá-lo em `dotfiles/managed`.
As capturas em `dotfiles/common`, Git, VS Code e IA não são ativadas.

O `.zshrc` pessoal (inclusive ZDOTDIR), `.zprofile`, aliases, temas e plugins
não são editados nem executados para inspeção. O comando compara o fragmento
atual com a fonte. Cópia idêntica exige confirmação e backup; conteúdo divergente,
diretório ou link de terceiros (inclusive quebrado) bloqueia a operação.
Link absoluto correto é reconhecido sem exigir adoção ou novo registro.
Links relativos são tratados conservadoramente como conflitos.

Para mesclar personalizações, copie o arquivo divergente para uma área privada,
compare localmente com a fonte e revise tema, plugins e possíveis secrets.
Não envie o conteúdo pessoal automaticamente ao Git. Só converta uma cópia
idêntica após decidir explicitamente qual conteúdo deve ser versionado.
Não há importação/mesclagem automática nem impressão dos valores pessoais.

Criar um link ausente não instala integração no startup. O fragmento agora é
neutro: não define tema/plugins/aliases, não inicializa Oh My Zsh e não tenta
identificar a aparência pelo nome do tema. NVM/completion opcionais são carregados
uma vez por sessão; PATH local não é duplicado. Um bloco legado já integrado
pode continuar carregando esse caminho, antes ou depois das preferências pessoais.
A inicialização do framework pertence ao startup pessoal; uma instalação que
antes dependia exclusivamente do fragmento para carregar OMZ precisa de revisão
manual. Não migremos esse comportamento escrevendo no `.zshrc` do usuário.

O helper do terminal reconhece o link absoluto válido e retorna SKIP, sem copiar
ou escrever na fonte. O módulo terminal, quando esse link está ativo, encerra
com SKIP antes de instalações, ajustes de startup ou troca de shell. Links
externos/quebrados continuam protegidos pelas guardas. Sem link gerenciado,
o fluxo legado de revisão/instalação continua disponível, usando o fragmento
neutro. Separar instalação de ferramentas da gestão de preferências é Fase 3.

## Backup e recuperação

Estado fica em `${XDG_STATE_HOME:-$HOME/.local/state}/config-workplace/dotfiles`,
fora dos repositórios. Cada operação usa `mktemp`, diretório privado, journal
com ação/fonte/destino/estado e backup com permissões preservadas. Backups
anteriores nunca são reutilizados. `original` guarda a cópia convertida;
`original-link` guarda o próprio link antes de unlink.

A conversão de cópia idêntica prepara e verifica um link num diretório privado
adjacente ao destino (mesmo filesystem), sem remover o original. Uma sondagem
local verifica a substituição com `mv -fT` (GNU) ou `mv -fh` (BSD); se nenhuma
funcionar, a operação falha preservando o original. Depois de revalidar tipo,
identidade/metadados, bytes e fonte, o rename substitui o arquivo. Falhas antes
ou durante um rename que não se efetivou mantêm a configuração original.
Não há sequência `rm original; ln ...` nem rollback que sobrescreva uma edição.

Falhas preservam backup, journal e staging; o journal informa seu caminho.
Se o rename aconteceu mas o registro final falhou, o destino pode já ser o link:
inspecione ambos antes de qualquer recuperação. Journals incompletos são
anunciados nas execuções posteriores, sem impedir uma tentativa explicitamente
confirmada; não são apagados. Backups anteriores nunca são removidos.
Interrupções tratáveis liberam o lock; SIGKILL/queda de energia podem deixar
`lock` residual. Revise os journals e confirme que não há processo ativo antes
de removê-lo com `rmdir`. Não restaure sobre um destino novo sem revisão.

`unlink` remove exclusivamente o link absoluto que ainda aponta à fonte
cadastrada, mesmo quebrado. Não materializa cópia nem restaura backup: o fragmento
deixa de ser carregado. Arquivos reais e links externos são preservados.

`status` e dry-run não escrevem arquivos, locks ou backups. Códigos: 0 sucesso
ou recusa explícita, 1 conflito/pendência/falha, 2 uso inválido. `status` retorna
1 quando o link não está correto. Não há dependência de Node, Stow ou Chezmoi.

## Limites e validação

O lock serializa este gerenciador, não editores externos. Rechecagens detectam
alterações durante confirmação/preparação, inclusive troca de inode mantendo
os mesmos bytes. `cksum` não é hash criptográfico e timestamps de `stat` têm
resolução limitada. Bash/POSIX não oferecem compare-and-swap de nomes: existe
uma janela entre a última verificação e `mv`/`ln`/`rm`. Não há garantia contra
um processo que troque caminhos nessa janela, nem durabilidade com `fsync`.
A atomicidade do rename é por arquivo no mesmo filesystem, não da transação.
Não execute editores/gerenciadores concorrentes durante a operação.

GNU `-T` recusa destino diretório; BSD `-h` impede seguir link para diretório,
mas um diretório real criado na janela final ainda pode receber o candidato.
A verificação posterior detecta que o destino não é o link esperado e registra
falha, preservando os artefatos; não remove esse diretório nem tenta recuperar
automaticamente. O mesmo limite BSD se aplica à criação com `ln -sh`.
Plataformas sem adaptador de criação validado são recusadas. Esses limites
não equivalem a proteção contra concorrência hostil; uma primitiva nativa
com operações relativas a descritores/condicionais requer avaliação futura.

`tests/dotfiles.sh` usa HOME e repositório temporários, cobrindo criação,
idempotência, conflitos, links relativos/quebrados, backups/permissões,
dry-run, unlink, falhas de preparação/substituição, concorrência durante
confirmação/preparação, TERM, locks residuais e nova execução. A suíte terminal
verifica Zsh com tema/prompt, aliases/plugins pessoais, integração existente,
carga repetida sem duplicação e links gerenciados sem instalação ou escrita.

Validação desta fase: Bash 3.2 e utilitários BSD reais no macOS, exclusivamente
em fixtures. Regressões bootstrap, terminal, initial-dev, phase-2.2 e Java
executadas sem instalar dependências nem tocar o HOME pessoal. Isso não é
aceitação de instalação real macOS/Ubuntu: Ubuntu e o ramo GNU permanecem
pendentes de execução nativa. Inicialização automatizada do checkout,
registro completo, seleção de múltiplos IDs, materialização/restore e sync
permanecem para fases posteriores.

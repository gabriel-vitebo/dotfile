# Gerenciamento de dotfiles — Fase 2

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

Criar um link ausente não instala integração no startup. O fragmento legado
contém robbyrussell e plugin git: revise a ativação antes de carregá-lo em um
shell pessoal. Se já existir a integração legada, uma cópia idêntica conserva
seu comportamento. O módulo terminal existente recusa symlinks pela guarda
atual, evitando escrita através do link.

## Backup e recuperação

Estado fica em `${XDG_STATE_HOME:-$HOME/.local/state}/config-workplace/dotfiles`,
fora dos repositórios. Cada operação usa `mktemp`, diretório privado, journal
com ação/fonte/destino/estado e backup com permissões preservadas. Backups
anteriores nunca são reutilizados. `original` guarda a cópia convertida;
`original-link` guarda o próprio link antes de unlink.

Falhas preservam os artefatos e informam o caminho da operação. Se a criação
do link falhar depois da remoção da cópia aprovada, o destino pode ficar ausente:
revise `original` e o journal; copie manualmente o backup para o destino somente
após verificar que nada novo apareceu ali. Alternativamente repita `link` para
concluir a vinculação. Não existe restauração destrutiva automática.
Interrupções tratáveis liberam o lock; SIGKILL/queda de energia podem deixar
`lock` residual. Revise os journals e confirme que não há processo ativo antes
de removê-lo com `rmdir`.

`unlink` remove exclusivamente o link absoluto que ainda aponta à fonte
cadastrada, mesmo quebrado. Não materializa cópia nem restaura backup: o fragmento
deixa de ser carregado. Arquivos reais e links externos são preservados.

`status` e dry-run não escrevem arquivos, locks ou backups. Códigos: 0 sucesso
ou recusa explícita, 1 conflito/pendência/falha, 2 uso inválido. `status` retorna
1 quando o link não está correto. Não há dependência de Node, Stow ou Chezmoi.

## Limites e validação

O lock serializa este gerenciador, não editores externos. Rechecagens detectam
mudanças durante confirmação e antes da aplicação, mas ferramentas shell não
oferecem proteção absoluta contra trocas concorrentes maliciosas de caminhos.
Não execute editores/gerenciadores concorrentes durante a operação.

`tests/dotfiles.sh` usa HOME e repositório temporários, cobrindo criação,
idempotência, conflitos, backups/permissões, dry-run, unlink, fonte ausente,
falha injetada e nova execução. Aceitação real em Ubuntu permanece pendente;
nenhuma configuração pessoal ou bootstrap completo é executado pelos testes
no HOME real. Inicialização automatizada do checkout, seleção de múltiplos
IDs, materialização/restore e sync permanecem para fases posteriores.

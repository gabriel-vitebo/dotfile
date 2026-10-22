# Captura para o módulo terminal (2026-10-20)

Leitura de `.zshrc`, `.zprofile`, customizações e código local do Oh My Zsh,
comparada aos artefatos em `dotfiles/common/zsh` e inventários existentes.
Não foram executados os arquivos pessoais nem alteradas as origens.

| Classe | Evidência / decisão |
| --- | --- |
| Portátil | `ZSH_THEME="robbyrussell"`, seguido de source de Oh My Zsh; plugin `git`; PATH local e NVM/completion condicionais |
| Tema efetivo configurado | Arquivo `themes/robbyrussell.zsh-theme`, sem override custom correspondente e sem alteração posterior de PROMPT; seta verde/vermelha, diretório ciano, informação Git azul/vermelha e marca amarela de mudanças |
| Dependências | Zsh, Git, Oh My Zsh; NVM é opcional, pertence a initial dev |
| macOS | Caminho absoluto no `.zprofile` normalizado para `$HOME`; Fish/Fig do VS Code fora do módulo |
| Ubuntu | Somente adaptador APT; não existem aliases pessoais exclusivos de Ubuntu capturados |
| Ausentes | `.zshenv`, `.zlogin`, `.zlogout`, `.vimrc`, `.vim`; nenhum conteúdo inventado |
| Não importados | Históricos, caches, sessões, credenciais, diretórios completos, exemplos de customização e temas extras |
| Fontes | Nenhuma exigência de Nerd Font no tema; Unicode/cores dependem do emulador. Fonte efetiva do Terminal não foi recuperada |

O checkout local do Oh My Zsh estava sem alterações rastreadas, no commit
`0eeaa529bb1442c2934930a5820f596e678458d4`. Esse valor é evidência, não pin de
instalação: instalações novas usam o upstream oficial vigente, preservando o
nome do tema. O arquivo local coincide com o [tema oficial](https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme)
consultado nesta etapa. Não há aliases pessoais ativos: os aliases Git pertencem
ao plugin, e aliases locais posteriores têm precedência.

Não foi executado o shell pessoal para inspecionar uma sessão viva. A identificação
se baseia na cadeia de carregamento inspecionada. Código futuro arbitrário ou
outros emuladores podem mudar o prompt; a detecção de destino é conservadora.
A [documentação oficial](https://github.com/ohmyzsh/ohmyzsh/wiki/) registra que o
instalador convencional renomeia `.zshrc`; por isso o módulo clona diretamente,
sem executar esse instalador.

Validação manual sugerida em VM Ubuntu descartável: executar dry-run, aprovar
instalação, repetir para verificar SKIP, remover clone e CLI, abrir Zsh e conferir
`echo $ZSH_THEME`, `alias gst`, `vim --version` e prompt dentro/fora de Git.
Próxima etapa: concluir essa aceitação real antes de integrar chezmoi/profiles.

## Bootstrap de máquinas novas

`workspace terminal` instala somente dependências ausentes, mediante confirmação.
O tema em `manifests/terminal/theme.txt` e o template
`manifests/terminal/bootstrap.zsh` selecionam o tema revisado e `git` e inicializam
Oh My Zsh. O instalador persiste uma cópia e o caminho do
framework em `~/.config/config-workplace-terminal/bootstrap.zsh`; o startup de
`manifests/terminal/startup.zsh` só é criado quando não existe `.zshrc`.
O fragmento neutro permanece independente e pode continuar ligado aos dotfiles.

Startups existentes não são reescritos: o diff é apresentado e uma proposta
separada pode ser salva após confirmação para integração pela fonte dos dotfiles.
A existência de um fragmento gerenciado não impede verificar e instalar assets.
Os testes isolados cobrem HOME vazio, HOME configurado, recusa, idempotência,
caminho personalizado com espaços e tema/plugin em novas sessões sem o clone.
Downloads e gerenciadores são simulados; a aceitação visual com upstream real
em uma VM continua sendo uma verificação manual.

## Finalização da Fase 3.1 — 2026-10-22

Auditoria sobre `2f049b25e2b756eb065f749e9d82c57ccebaeab0`, antes das mudanças.
A leitura local de `.zshrc`, `.zprofile`, customizações OMZ, tema instalado e
`.local/bin/env` encontrou `ZSH_THEME="robbyrussell"`, plugin `git`, sem override
correspondente em `custom` e sem reatribuição posterior do prompt nos arquivos
inspecionados. `.zshenv` e `.zlogin` não estavam presentes. Nenhum desses arquivos
foi executado. NVM/completion referenciados são código de terceiros e não foram
executados para deduzir aparência; uma sessão pessoal viva não foi inspecionada.
Isso confirma a seleção estática atual, não uma nova preferência estética.
Nenhuma preferência foi extraída de repositórios de terceiros.

`manifests/terminal/theme.txt` torna explícita a seleção atual: `robbyrussell`.
Para mudar o padrão do proprietário, revise a escolha e suas dependências e
versione nesse arquivo **um único nome de tema interno do Oh My Zsh**. O parser
aceita somente letras ASCII, números, `_` e `-`; rejeita `random`, caminhos,
expansões e código. O manifesto é lido como dados, nunca carregado com source.
O instalador valida e usa o mesmo nome ao verificar, obter e renderizar o tema.
Não há descoberta de preferência nem seleção automática pela máquina de destino.

O tema atual não exige fontes ou plugins adicionais além dos componentes já
previstos; nenhuma dependência nova foi adicionada. Temas externos, plugins ou
fontes extras exigem revisão e aprovação próprias e não são instalados por esse
mecanismo. A aprovação de um novo tema deve incluir revisão dessas dependências;
validar o nome e a sintaxe não certifica a aparência ou a segurança do código.

O manifesto é empacotado com a CLI. O bootstrap instalado contém o nome literal
e o caminho do framework da máquina de destino, não uma referência ao manifesto
ou ao clone descartável. Caminhos do Mac não são copiados para outra máquina.
Modificar o manifesto não altera uma instalação existente automaticamente:
qualquer atualização da cópia passa por diff/confirmação/backup. `.zshrc` existente,
temas e plugins instalados são preservados; a integração proposta é manual.

Em HOME novo, a criação de `.zshrc` agora exige bootstrap correspondente e
fragmento aprovado (cópia idêntica ou link reconhecido pelo ownership existente).
Recusa do fragmento deixa a configuração parcial sem ativar startup; reexecutar
permite concluir. Falha no download não publica o framework parcial. O helper
legado de bloco startup permanece disponível sem mudar seu contrato.

Validação: suítes isoladas em macOS/Bash 3.2/Zsh e utilitários BSD. Incluem HOME
vazio/personalizado, tema alternativo, OMZ existente, link gerenciado, dependências
ausentes, repetição, recusa parcial, falha de download, caminhos com espaços,
novas sessões Zsh e remoção do clone/CLI. Downloads, instalações e APT são mocks.
Docker local foi consultado apenas para detectar Ubuntu, mas o daemon não estava
ativo; Linux/GNU nativo não foi executado. Instalação real e aceitação visual em
macOS/Ubuntu, fonte do emulador e integração de startups antigos seguem manuais.

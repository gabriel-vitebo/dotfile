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

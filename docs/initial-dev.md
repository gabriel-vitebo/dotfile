# initial dev — integração persistente do NVM (Fase 6.1)

Execute `config-workplace initial dev --dry-run` para verificar NVM, Node/npm,
shell, integração e o bloco proposto. Execute sem `--dry-run` para aplicar.
A confirmação da integração do shell é separada da confirmação de instalações.
Recusar essa confirmação não altera o startup. Instalações anteriormente
aprovadas permanecem instaladas.

O shell de destino é identificado por `SHELL`, nunca pela presença do executável
Zsh. Se a variável não representar o shell desejado, execute explicitamente
`SHELL=/bin/bash config-workplace initial dev` ou
`SHELL=/bin/zsh config-workplace initial dev`. Zsh usa `ZDOTDIR` quando exportado.
Configurações de ZDOTDIR definidas somente dentro do próprio Zsh precisam ser
exportadas antes de chamar a CLI.

Bash recebe o bloco em `~/.bashrc`; Zsh em `${ZDOTDIR:-$HOME}/.zshrc`.
No Ubuntu, o startup padrão do Bash login já carrega `.bashrc`. Um profile login
personalizado que não carrega `.bashrc` exige revisão pelo usuário: a CLI não
reescreve os profiles existentes. Da mesma forma, `return`/`exit` antecipados ou
alterações posteriores no PATH/startup podem impedir a ativação. A detecção de
integrações é conservadora e estática; não executa arquivos pessoais para
verificar compatibilidade. REVIEW pede revisão antes de qualquer duplicação.

O bloco delimitado por `# >>> config-workplace NVM >>>` e
`# <<< config-workplace NVM <<<` exporta o diretório detectado e carrega
`nvm.sh` somente quando a função NVM ainda não está disponível. Não força LTS,
não lê nem altera `.nvmrc`, temas ou plugins. O NVM segue seu comportamento
normal de inicialização e seleção. A sondagem da CLI usa `--no-use`.

Instalações funcionais são reutilizadas, incluindo `NVM_DIR` personalizado.
Um diretório personalizado informado, mas incompleto, não é substituído por
outra instalação descoberta. Caminhos sob o payload/clone e destinos com
symlinks são recusados para escrita. Instalações não descobertas devem ser
indicadas exportando `NVM_DIR` antes de executar a CLI.

Node LTS já disponível no NVM é reutilizado sem download. A alteração do alias
`default` aparece no plano e exige a aprovação prevista para alterações de
Node. A correção de alias de um LTS já instalado não troca a versão ativa.
Seleção divergente de Node continua exigindo `--approve-node-change` e
confirmação. Não há migração automática de Node externo.

Antes de acrescentar o bloco a um arquivo existente, cria-se um backup
`<startup>.config-workplace-backup.XXXXXX` com conteúdo e permissões originais.
O arquivo original é preservado e o bloco é acrescentado ao final. Um bloco
gerenciado idêntico gera SKIP; integração existente diferente gera REVIEW.

Para desfazer, remova somente as linhas entre os dois marcadores, incluindo os
marcadores. Isso não remove NVM, Node nem npm. Para restaurar um backup inteiro,
compare primeiro com o arquivo atual para preservar edições pessoais posteriores.

A instalação do NVM e o bloco não referenciam o clone original. Depois de
instalar a CLI pelo bootstrap, o clone pode ser excluído. Abra um novo terminal
e confira `command -v nvm`, `node --version` e `npm --version`.

Para atualizar uma CLI instalada no Ubuntu, na cópia atualizada do projeto:

```bash
git pull --ff-only
./install.sh
config-workplace initial dev --dry-run
config-workplace initial dev
```

Revise e aprove a proposta de startup. O bootstrap copia as bibliotecas para a
instalação autônoma; editar somente o clone não atualiza a CLI instalada.

Testes: `bash tests/nvm-startup.sh` e `bash tests/initial-dev.sh` usam HOME
isolado e NVM/Node simulados, sem instalar pacotes. O teste de startup executa
uma sessão Bash interativa real; também executa Zsh quando disponível. Execute
com Bash 3.2 e Bash moderno nas respectivas plataformas. Uma aceitação com
NVM real em Ubuntu/macOS continua necessária para validar o ambiente completo.

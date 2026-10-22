> **Atualização — dotfiles (2026-10-22):** `workspace dotfiles link|status|unlink`
> e `link --dry-run` estão disponíveis. Consulte [o guia](docs/dotfiles.md).
> Para configurações vinculadas, a regra de independência do clone exige um
> checkout permanente separado da instalação da CLI. As referências abaixo
> a cópias/Chezmoi descrevem o modelo legado ou planejamento anterior.

# config-workplace

> Seu ambiente de desenvolvimento, do seu jeito, em qualquer máquina — sem depender do repositório depois da instalação.

**Status:** CLI, bootstrap, `initial dev` (2.1/2.2), `terminal` (3.1) e `java` (3.2) implementados; demais módulos permanecem planejados.
**Repositório pretendido:** privado, pessoal e versionado no GitHub.  
**Plataforma inicial:** Ubuntu. Futuramente, macOS e Windows.

## 1. Visão geral

O **config-workplace** é uma ferramenta pessoal para instalar, configurar, diagnosticar e manter um ambiente de desenvolvimento. Seu objetivo é eliminar o trabalho repetitivo de configurar computadores recém-formatados, preservando preferências de terminal, editor e ferramentas ao longo do tempo.

A solução deve atender a dois cenários:

1. **Uso diário:** o usuário altera suas configurações e instala ferramentas normalmente; o programa detecta mudanças conhecidas, mostra as diferenças e pede aprovação antes de incorporá-las ao repositório.
2. **Computador novo:** o usuário clona o repositório, executa o bootstrap e instala os módulos desejados. Pode apagar o clone original depois: tudo o que foi instalado e configurado continua funcionando.

### Princípios

- **Pessoal:** configurações e preferências do proprietário, sem integração ou dependência de empresa específica.
- **Independência total:** nenhum programa, tema, plugin ou configuração instalada depende do clone original.
- **Controle explícito:** nenhuma alteração local entra no repositório sem aprovação.
- **Segurança:** segredos e credenciais não são versionados em texto puro.
- **Idempotência:** reexecutar um módulo não deve duplicar instalações nem destruir configurações.
- **Modularidade:** o ambiente básico é separado de ferramentas opcionais.
- **Atualidade:** novas instalações preferem versões estáveis atuais/LTS, conforme políticas declaradas.
- **Portabilidade gradual:** Ubuntu primeiro, com possibilidade de suportar outras plataformas depois.
- **Transparência:** logs, diferenças, diagnósticos e documentação para configuração manual.

## 2. Interface de comandos planejada

> A tabela descreve a API proposta. `initial dev`, `terminal`, `java` e `list` estão disponíveis; os demais módulos continuam planejados.

| Comando | Responsabilidade |
| --- | --- |
| `config-workplace initial dev` | Instalar o ambiente inicial essencial |
| `config-workplace java` | Detectar/instalar JDK LTS, Maven e Gradle; extensões Java opcionais |
| `config-workplace docker` | Instalar e configurar Docker e Compose |
| `config-workplace terminal` | Instalar e configurar Zsh, Oh My Zsh, tema, plugins e Vim |
| `config-workplace env` | Preparar variáveis e recuperar segredos de fonte autorizada |
| `config-workplace list` | Listar módulos disponíveis |
| `config-workplace doctor` | Verificar instalação, versões, configurações e dependências |
| `config-workplace status` | Mostrar mudanças detectadas, pendências e estado da sincronização |
| `config-workplace review` | Revisar individualmente e aceitar/recusar mudanças locais |
| `config-workplace monitor` | Executar uma rodada de detecção de mudanças |
| `config-workplace sync` | Recuperar e aplicar configurações aprovadas do repositório, sem sobrescrita silenciosa |
| `config-workplace update` | Propor e executar atualizações autorizadas de ferramentas |

Opções transversais planejadas: `--help`, `--version`, `--dry-run` e, quando pertinente, `--yes` somente para operações seguras e previamente aprovadas. A opção `--force` não deve contornar proteção contra perda de dados ou vazamento de segredos.

Não haverá perfis `frontend`, `backend`, `fullstack` nem `--work`. O comando **`initial dev`** é a base comum; Java, Docker e outros recursos são módulos independentes.

### CLI disponível e instalação

Disponíveis: `--help`, `--version`, `list`, `initial dev`, `terminal` e `java`. A CLI e o
bootstrap aceitam Linux e macOS, com Bash 3.2 ou superior. O módulo `initial dev`
aceita Ubuntu e macOS em x86_64 e ARM64.

A partir desta cópia local (ou de um clone autenticado quando o repositório
privado estiver disponível), execute sem `sudo`:

```bash
./install.sh
export PATH="$HOME/.local/bin:$PATH" # se necessário na sessão atual
config-workplace --help
config-workplace --version
config-workplace list
```

O bootstrap não instala dependências externas nem acessa a rede. Copia somente
a CLI, as bibliotecas de execução, os módulos `initial-dev`, `terminal` e `java`, seus adaptadores e manifestos revisados (lista explícita em `install.sh`) para `~/.local/share/config-workplace`.
O comando em `~/.local/bin/config-workplace` é um lançador que resolve essa
instalação permanente, sem referências ao clone. O diretório
`~/.local/state/config-workplace` fica reservado para estado e logs futuros.
Capturas brutas de dotfiles, inventários e credenciais não são copiados; somente os fragmentos aprovados em `manifests/terminal` integram o módulo. Os helpers JavaScript são copiados como texto; o bootstrap continua sem exigir Node.

Se `~/.local/bin` já estiver no PATH, nenhum arquivo de shell será alterado.
Caso contrário, o instalador apresenta a linha exata e solicita confirmação:
usa `.zprofile` em `$ZDOTDIR` (ou `$HOME`) para Zsh; para Bash, respeita a
precedência `.bash_profile`, `.bash_login`, `.profile`, usando o primeiro
existente ou criando `.profile`. Arquivos existentes recebem backup antes da
alteração; a mesma linha não é adicionada novamente. Links simbólicos de
arquivos de inicialização não são modificados. Ao recusar, ou com shell não
reconhecido, configure manualmente com o `export` acima. Abra uma nova sessão
login para carregar a configuração persistente; o instalador não troca o shell
nem consegue alterar o PATH do terminal que o iniciou.

Para atualizar manualmente, execute `./install.sh` na cópia da versão desejada.
A instalação é preparada e validada em um diretório temporário no mesmo volume
antes da substituição. Falhas na substituição ou verificação final restauram
a instalação anterior. Arquivos desconhecidos e alterações locais exigem
confirmação. Backups anteriores ficam em
`~/.local/share/config-workplace-backup.*`, com o caminho informado no relatório;
podem ser removidos manualmente após conferir a nova instalação. Não existe
atualização automática nem comando `update` nesta etapa.

Instalações simultâneas são bloqueadas por um diretório de lock. Interrupções
tratáveis restauram a versão anterior; queda de energia ou `SIGKILL` podem
exigir recuperação manual a partir de `.config-workplace.*` e remoção do lock
`.config-workplace-install.lock`, ambos em `~/.local/share`. Durante a breve
substituição, uma execução concorrente da CLI pode falhar.

Teste automatizado, sem modificar o HOME real:

```bash
/bin/bash tests/bootstrap.sh
```

A suíte copia o código para uma área temporária, instala com HOME isolado,
renomeia a cópia original e executa os três comandos básicos a partir de outro
diretório. Também cobre reinstalação, falhas antes e depois da substituição,
preservação de arquivos desconhecidos e confirmação/backup/idempotência do PATH.
Executá-la no macOS com `/bin/bash` verifica o Bash 3.2 fornecido pelo sistema;
a validação em Ubuntu deve ser feita separadamente com o mesmo comando.

### 2.1. `initial dev` — Fases 2.1 e 2.2 disponíveis

A Fase 2.1 fornece Git, GitHub CLI, NVM, Node.js LTS e npm. A Fase 2.2 acrescenta pnpm, VS Code, extensões aprovadas, preferências portáteis e utilitários.

```bash
# Revisão somente de leitura, sem sudo, arquivos temporários ou instaladores:
./bin/config-workplace initial dev --dry-run
# Instalação real: mostra o plano completo e exige confirmação antes de alterar:
./bin/config-workplace initial dev
# Depois de instalar/atualizar a CLI com ./install.sh:
config-workplace initial dev --dry-run
config-workplace initial dev
```

**Contrato obrigatório para todos os módulos presentes e futuros (RN-005):**
verificar presença, execução e compatibilidade antes de qualquer instalação ou
modificação. Ferramenta existente, funcional e compatível = **SKIP**, seja qual
for sua origem. Não reinstalar, substituir, atualizar ou migrar apenas para
padronizar gerenciadores. `lib/setup.sh` centraliza a sondagem (ausente,
funcional, quebrada) e repete a verificação antes de instalar pacotes. Módulos
futuros devem reutilizar esse contrato e testar ausência de mutações no SKIP.
Instalações quebradas são preservadas e exigem reparo explícito; não são tratadas
como ausentes. Nenhuma configuração Git ou credencial é alterada.

- **Ubuntu:** APT para Git; repositório oficial assinado do GitHub CLI para gh.
  O plano informa o possível uso de sudo. Configurações de repositório ou chaves
  existentes e divergentes não são sobrescritas; precisam de revisão manual.
- **macOS:** Homebrew somente para ferramentas ausentes. Git dos Command Line
  Tools e outras instalações funcionais são mantidos. Homebrew não é instalado
  automaticamente; se necessário, prepare-o conforme https://brew.sh.
- **Pré-requisitos:** Bash 3.2+, utilitários do sistema, curl e certificados HTTPS.
  curl ausente entra no plano antes dos downloads. Se Node existente precisar de
  consulta LTS sem curl, ele é preservado com REVIEW; reexecute após a instalação
  de curl. Outras falhas de consulta mantêm o bloqueio da Fase 2.1. A consulta
  de versões exige rede mesmo em dry-run. Falha na consulta preserva o estado e
  retorna erro, sem declarar compatibilidade que não foi verificada.
- **Node existente:** compatível significa ter `process.release.lts` e pertencer
  à major LTS mais recente publicada no índice oficial do Node. Não se exige o
  último patch e não se atualiza um Node compatível. Node fora do NVM é identificado
  e preservado. Uma major diferente exige `--approve-node-change`, além da
  confirmação do plano, para autorizar outra versão via NVM. Essa opção não remove
  a versão antiga, não altera `.nvmrc` e não modifica o shell que chamou a CLI.
- **Node novo:** usa `nvm install --lts` e alias `default = lts/*`. Uma LTS local
  compatível é reutilizada com `nvm use`, sem download. Aliases locais de LTS
  desatualizados exigem revisão. npm vem com Node; não há instalação separada nem
  pacotes globais nessa etapa. O pnpm é instalado separadamente em prefixo próprio. Um `default-packages` do NVM com pacotes configurados bloqueia
  a instalação de Node para evitar instalações globais implícitas.
- **NVM:** detecta função carregada, `NVM_DIR`, `~/.nvm`, diretório XDG e locais
  usuais do Homebrew. Para caminhos personalizados, exporte `NVM_DIR`. Instalações
  existentes são reutilizadas. Para novas instalações, resolve a release estável
  via redirecionamento HTTPS de `nvm-sh/nvm/releases/latest`, baixa a tag, verifica
  objetos Git, correspondência do commit e sintaxe Bash, e executa o instalador
  oficial a partir dessa cópia local. A confiança é em HTTPS/GitHub; não há
  verificação de assinatura independente. A versão resolvida aparece no relatório.
  A origem Git final aponta ao repositório oficial, sem dependência do temporário.
- **Shell/NVM:** a Fase 2.1 não edita a inicialização do NVM. A Fase 2.2 pode propor
  o PATH de `~/.local/bin`, com confirmação e backup separados. Depois de uma
  instalação nova, carregue o diretório informado com `export NVM_DIR="$HOME/.nvm"`
  e `. "$NVM_DIR/nvm.sh"`. Para persistir, acrescente essas linhas manualmente ao
  arquivo do seu shell, se ainda não existirem. Use o caminho real em instalações
  personalizadas. Autenticação gh é opcional e explícita: `gh auth login`.

O relatório distingue CHECK, SKIP, PLAN, INSTALL, CONFIGURED, OK, FAIL, REVIEW, BACKUP e MANUAL.
Recusa/EOF na confirmação cancela sem alterações e retorna zero. Pré-requisitos
não atendidos e falhas retornam erro; instalações já concluídas antes de uma
falha posterior são mantidas, sem rollback de pacotes do sistema.

Testes sem ferramentas reais, rede ou alterações no HOME do usuário:

```bash
/bin/bash tests/bootstrap.sh
/bin/bash tests/initial-dev.sh
```

As suítes usam áreas temporárias dentro de `tests/`, HOME isolado e mocks para
mutações. Cobrem preservação por origem, bloqueios, autorização, dry-run,
idempotência, adaptadores e independência da CLI. A instalação real em Ubuntu
limpo e o teste de programas após remover o clone permanecem validações manuais;
mocks não equivalem a esse teste de aceitação.

Referências: [NVM oficial](https://github.com/nvm-sh/nvm),
[GitHub CLI no Linux](https://github.com/cli/cli/blob/trunk/docs/install_linux.md),
[índice oficial Node](https://nodejs.org/dist/index.tab).

#### Fase 2.2: ferramentas, editor e preferências

Incluídos: `curl`, `wget`, `unzip`, `jq`, `ripgrep` (`rg`), `fzf`, OpenSSH
Client, certificados CA e compiladores (`cc`, `c++`, `make`;
`build-essential` no Ubuntu). Versões funcionais, inclusive utilitários nativos
do macOS e instalações de outros gerenciadores, são preservadas. APT usa
`--no-upgrade`; Homebrew desabilita sua atualização automática e upgrade na
instalação. Dependências que o gerenciador precisar resolver fazem parte da
instalação autorizada; não há transação/rollback de pacotes do sistema.
Homebrew nunca é instalado pelo módulo. Command Line Tools ausentes no macOS
abrem, após aprovação do plano, o instalador interativo `xcode-select --install`;
a conclusão e a verificação exigem nova execução.

**pnpm:** uma instalação funcional é SKIP, inclusive de npm, Corepack ou brew.
A sondagem desabilita rede/auto-pin do Corepack e ocorre fora do projeto.
Para uma nova instalação, consulta metadados oficiais de `pnpm/latest` por HTTPS,
valida `engines.node` contra o Node atual e fixa essa versão para o plano.
Requisitos incompatíveis ou não interpretáveis ficam em REVIEW, preservando
Node e NVM. Se Node ainda será instalado, resolução e confirmação são adiadas
até ele estar funcional. Instala apenas `pnpm@<versão>` com npm,
`--engine-strict`, registry oficial e prefixo próprio em
`~/.local/share/config-workplace-pnpm`. Não usa `corepack enable` nem modifica
prefixos npm existentes. O lançador permanente em `~/.local/bin/pnpm` usa o
caminho do Node selecionado. O PATH em Bash/Zsh login é proposto com backup;
recusar essa preparação cancela a instalação de pnpm sem erro técnico.
Para shells diferentes, prepare o PATH manualmente. Remover o Node usado pelo
lançador posteriormente exige reconfiguração manual.

**VS Code:** verifica `code`, o binário interno do aplicativo em `/Applications`
e `~/Applications`, caminhos usuais Linux e registros APT/Snap/Flatpak.
Pacote existente sem CLI funcional é REVIEW; não se instala uma segunda cópia.
Para aplicativo macOS em local personalizado, informe `CW_VSCODE_APP` com o
caminho absoluto do `.app`. Instalações portáteis fora dos caminhos detectados
devem expor `code` no PATH antes de executar o módulo. Novas instalações usam
Homebrew Cask no Mac e o `.deb` estável oficial por HTTPS com APT no Ubuntu.
CLI interna funcional fora do PATH pode receber um link em `~/.local/bin/code`,
após confirmação específica, apontando ao aplicativo permanente, nunca ao clone.
Não substitui um destino já existente. Configurações de instalação remota,
portátil e perfis nomeados não são importadas automaticamente.

**Extensões:** `manifests/vscode-extensions.txt` contém somente Prettier
(`esbenp.prettier-vscode`) e Error Lens (`usernamehw.errorlens`), aprovadas pelo
proprietário nesta fase. Lista extensões do perfil padrão, compara IDs sem
sensibilidade a maiúsculas, confirma cada extensão ausente e verifica depois.
Não usa `--force`, não remove extras nem seleciona/cria perfis. A instalação
normal do editor pode ter mecanismos próprios de autoatualização, que este
módulo não modifica. A [classificação do inventário](docs/vscode-base.md) separa
os demais itens por finalidade; captura não equivale a aprovação.

**Preferências:** o manifesto propõe somente seis chaves portáteis capturadas:
tamanho de fonte, réguas, tabulação, minimapa, formatação ao salvar e tratamento
de espaços no diff. Cada inclusão/conflito mostra a mudança e pede confirmação;
recusa preserva o valor local. Node, já integrante da Fase 2.1, executa o helper
sem dependências npm para ler JSONC com comentários/vírgulas finais. A edição
substitui apenas o valor aprovado ou acrescenta a chave ausente, preservando
comentários e demais chaves. Antes de escrever, cria backup exato em um diretório
`.config-workplace-*` ao lado de `settings.json`; escreve temporário e renomeia.
Arquivo alterado durante a revisão, JSONC inválido, chaves duplicadas, links
simbólicos e destinos dentro do clone são recusados. Há lock por arquivo;
edição simultânea pelo VS Code ainda deve ser evitada durante a confirmação.
No macOS usa `~/Library/Application Support/Code/User/settings.json`; Ubuntu
usa `${XDG_CONFIG_HOME:-~/.config}/Code/User/settings.json`.

`keybindings.json` não foi encontrado na captura e não é criado nem alterado.
Profiles adicionais, Fish/Fig, temas, caminhos locais, integrações de IA e
preferências que desabilitam confirmações ficam fora do manifesto. Não há
mudanças em configurações de projetos/workspaces nem importação de credenciais.

**Plano e reexecução:** `--dry-run` apresenta ambas as fases, extensões e
conflitos sem gravar arquivos ou instalar. Consultas HTTPS continuam necessárias
para políticas de versões. Falhas de consulta deixam REVIEW ou bloqueio explícito;
não autorizam trocar versões. A execução exige confirmação do plano e aprovações
granulares do editor/PATH. Itens SKIP não pedem confirmação. Itens quebrados
ficam preservados para reparo manual, sem autorização genérica implícita.
Instalações concluídas antes de falha posterior permanecem; configurações já
existentes mantêm backup. Reexecute para revisar o que ainda falta.

```bash
/bin/bash tests/bootstrap.sh
/bin/bash tests/initial-dev.sh
/bin/bash tests/phase-2.2.sh
./bin/config-workplace initial dev --dry-run
# Somente quando desejar instalar de verdade e aprovar as mudanças:
./bin/config-workplace initial dev
```

As suítes isolam HOME e simulam rede/instaladores; a suíte 2.2 exige Node local
para testar o parser real, mas nunca instala ferramentas. Validação real em VM
Ubuntu limpa e Mac, inclusive nova sessão após remover o clone, continua manual.
O bootstrap inclui os helpers e manifestos aprovados na instalação permanente.
`zip` na base, demais módulos opcionais, importação de profiles e sincronização continuam futuros.

Referências oficiais: [pnpm](https://pnpm.io/installation),
[VS Code Linux](https://code.visualstudio.com/docs/setup/linux),
[CLI do VS Code](https://code.visualstudio.com/docs/configure/command-line).

### 2.2. Módulos opcionais e futuros

- **Java (Fase 3.2 disponível):** SDKMAN! opcional, JDK LTS, Maven/Gradle e extensões com aprovação individual; preserva `JAVA_HOME` e settings. Importação de profile permanece futura.
- **Docker:** Engine, Compose, permissões e verificação do serviço.
- **Terminal (Fase 3.1 disponível):** Zsh, Oh My Zsh, tema real `robbyrussell`, plugin `git` e Vim; fontes extras e novas preferências não foram selecionadas.
- **Bancos e back-end:** PostgreSQL client, DBeaver, Redis CLI, Python/uv, ferramentas de API.
- **IA:** ferramentas de linha de comando, preferências de agentes e templates MCP sem credenciais.
- **Aplicativos:** Chrome, Obsidian e outros programas escolhidos pelo usuário.

Adicionar um módulo deve exigir somente criar seu instalador, declarar metadados e testes, documentar e commitar.

### 2.3. `terminal` — Fase 3.1 disponível

```bash
./bin/config-workplace terminal --dry-run
./bin/config-workplace terminal
# Opcional: confirmação específica para chsh, independente da configuração:
./bin/config-workplace terminal --change-shell
/bin/bash tests/terminal.sh
```

A inspeção somente de leitura do Mac confirmou **Oh My Zsh + robbyrussell + git**,
sem customizações ativas do prompt. O manifesto reproduz PATH em `~/.local/bin`
e carregamento condicional do NVM/completion. NVM ausente não impede iniciar Zsh
nem é instalado por este módulo. Não foram encontrados aliases/funções pessoais,
`.vimrc` ou `.vim`; Vim é detectado/instalado, sem inventar preferências/plugins.
Veja [evidências e classificação](docs/terminal.md).

Ubuntu usa APT `--no-upgrade`; macOS preserva Zsh/Vim nativos e usa Homebrew
existente apenas se necessário. Cada instalação exige confirmação. Ferramentas
funcionais são SKIP com versão; quebradas ficam REVIEW. Oh My Zsh é obtido por
Git HTTPS oficial, validado com `git fsck` e sintaxe, sem executar seu instalador.
O commit resolvido aparece no relatório. Frameworks existentes não são atualizados;
arquivos de tema/plugin ausentes podem ser obtidos separadamente após confirmação
e diff, sem substituir componentes existentes. Não há plugins externos aprovados.
A confiança da origem é HTTPS/GitHub, sem verificação de assinatura independente.

`--dry-run` não grava arquivos, não consulta a rede nem executa instaladores.
Mostra dependências, tema, plugins, conflitos e diferenças propostas. A detecção
não carrega configurações pessoais: para frameworks/temas/plugins verifica
arquivos essenciais e sintaxe, não certifica toda execução de código customizado.
Temas locais ambíguos ficam em REVIEW, sem seleção automática de outro tema.

O fragmento aprovado é copiado para `~/.config/config-workplace-terminal/zshrc`.
Um bloco único em `${ZDOTDIR:-$HOME}/.zshrc` o carrega antes dos aliases locais,
que mantêm precedência. Arquivos idênticos são SKIP; diferenças mostram diff e
pedem aprovação individual, com backup `.config-workplace-backup.*` antes de
alterar. Links, caminhos no clone e blocos modificados ficam preservados.
Inicializações com framework/source/eval ou controles de fluxo locais exigem
integração manual: o módulo não tenta interpretar nem substituir código arbitrário.
Recusar o fragmento impede criar um bloco que dependa dele. Alterações aprovadas
anteriormente não são desfeitas quando uma etapa posterior é recusada ou falha.

Oh My Zsh fica em `${ZSH:-~/.oh-my-zsh}`. Diretórios personalizados devem ser
exportados também nas novas sessões. Nenhum recurso aplicado depende do clone ou
da CLI; remover ambos preserva o shell. Novas configurações desabilitam a
atualização automática do Oh My Zsh. Configurações existentes são preservadas.
Não se instala fonte: robbyrussell usa cores ANSI e caracteres Unicode; a
aparência final depende da fonte/emulador. Não há configurações específicas de
macOS importadas para Ubuntu nem Neovim nesta etapa.

A suíte usa HOME isolado, mocks de gerenciadores e fixtures de framework; verifica
backup, recusa, conflitos, idempotência, sintaxe e nova sessão após excluir clone
e CLI. Teste real em VM Ubuntu limpa com Oh My Zsh oficial e comparação visual
continua necessário; os mocks não substituem esse critério de aceitação.

### 2.4. `java` — Fase 3.2 disponível

```bash
./bin/config-workplace java --dry-run
./bin/config-workplace java
/bin/bash tests/java.sh
```

Módulo opcional Ubuntu/macOS (x86_64/ARM64), separado de `initial dev`.
Detecta Java/javac, JAVA_HOME, SDKMAN!, Maven e Gradle antes de propor instalações.
Ferramentas funcionais, inclusive antigas e externas ao SDKMAN!, são **SKIP**.
Instalações quebradas/divergentes ficam **REVIEW**; runtime sem compilador recebe
proposta de JDK com confirmação específica. Não há atualização automática.

Para um JDK ausente, cruza a última LTS publicada pela Adoptium com os candidatos
Temurin do catálogo SDKMAN! da plataforma. Maven/Gradle ausentes recebem versões
estáveis com verificação conservadora de compatibilidade; requisitos desconhecidos
ou consultas malsucedidas bloqueiam o plano. Versões/distribuição aparecem antes
da primeira alteração. O dry-run pode consultar HTTPS, mas não grava arquivos,
carrega SDKMAN!, instala ferramentas ou pede sudo.

SDKMAN! é opcional: instalação somente se necessário, após aprovação do plano
e confirmação própria. O instalador oficial é validado por sintaxe/formato/origem
HTTPS, executado localmente com HOME/ZDOTDIR temporários e destino permanente.
Não há assinatura independente. A versão atual exige Bash 4+ para instalar;
a CLI e o diagnóstico continuam compatíveis com Bash 3.2. Pré-requisitos ausentes
são informados, sem instalação automática. Cada SDK exige confirmação própria,
incluindo criação da primeira seleção `current`; defaults existentes são preservados.

Não altera JAVA_HOME persistente, shell padrão, credenciais, wrappers ou arquivos
pessoais. A ativação em novas sessões é manual, com as linhas exatas apresentadas
ao final; carregar SDKMAN! pode definir JAVA_HOME e deve ser uma escolha explícita.
Ferramentas ficam no diretório permanente SDKMAN!, sem referências ao clone/CLI.
Nenhum settings/shell existente é editado. Recusa/EOF cancela; falhas parciais
preservam instalações concluídas e informam a pendência.

VS Code é opcional. Se disponível, lista seis extensões individuais capturadas,
instala somente as ausentes aprovadas uma a uma e preserva extras/settings/perfil
ativo. A captura não contém perfil Java aprovado nem caminhos JDK portáteis para
importar. O pack não é instalado implicitamente. Veja [decisões, evidências,
limitações e preparação manual](docs/java.md). Testes usam mocks/HOME temporário;
a aceitação real em Ubuntu/Mac limpos continua pendente.

## 3. Fluxo A — Uso no dia a dia

### 3.1. Detecção e revisão

```text
Alteração local (arquivo, extensão ou ferramenta)
       ↓
Monitor periódico detecta e compara
       ↓
Gera diff/inventário e verifica riscos
       ↓
Notifica o usuário, sem modificar o repositório
       ↓
config-workplace review
       ├── ACEITAR → importar mudança aprovada → validar → commit local
       └── RECUSAR → manter mudança apenas neste computador
```

**Regras:**

1. O usuário continua alterando Zsh, Vim, VS Code e outras ferramentas diretamente no computador.
2. O monitor verifica **fontes conhecidas e explicitamente cadastradas**; não promete descobrir ou reproduzir qualquer instalação manual.
3. Cada alteração relevante é apresentada com origem, tipo, diff ou descrição e impacto esperado.
4. A aprovação é **granular**: aceitar um alias não obriga aceitar uma extensão.
5. **Aceitar:** atualizar apenas o arquivo/manifesto correspondente no projeto, validar segurança e criar commit local com mensagem descritiva.
6. **Recusar:** não modificar o projeto nem desfazer a alteração no computador.
7. Uma recusa é registrada **somente em estado local**, para evitar alertas repetidos sobre o mesmo conteúdo. Mudanças posteriores podem gerar nova revisão.
8. Deve existir opção para ignorar permanentemente caminhos, ferramentas ou categorias.
9. Sem confirmação, não há importação, commit ou push.
10. O push é **separado e explícito** por padrão. Pode ser automatizado futuramente somente mediante consentimento específico, sem contornar validações.
11. Mudanças conflitantes ou suspeitas ficam pendentes de revisão; nunca são resolvidas automaticamente com perda de dados.
12. Notificações não devem abrir terminais inesperadamente nem bloquear o trabalho.

### 3.2. Monitor periódico

No Ubuntu, usar preferencialmente um **timer `systemd --user`** (cadência inicial sugerida: a cada **6 horas**, configurável). Ele executa uma verificação curta, sem daemon pesado permanentemente ativo.

- Em sessão gráfica, notificar quando houver mudanças pendentes.
- Sem sessão gráfica, registrar pendências para `status`/`review`.
- O monitor **não executa instaladores nem atualizações de ferramentas**.
- Capturar apenas configurações conhecidas, listas de extensões e inventários suportados.
- Ignorar arquivos temporários, caches, diretórios de projetos e segredos.
- A verificação pode ser iniciada manualmente por `config-workplace monitor`.

**Limite importante:** uma ferramenta recém-instalada pode aparecer no inventário sem que exista ainda um instalador reproduzível. Nesse caso, o sistema pede cadastro ou revisão do módulo, em vez de afirmar que consegue reinstalá-la.

### 3.3. Sincronização entre máquinas

O repositório contém **somente configurações aprovadas**. Ao usar outra máquina, `sync` recupera essas configurações e as aplica após checar alterações locais.

- Não sobrescrever arquivos modificados sem consentimento.
- Exibir diferenças antes de aplicar mudanças.
- Se houver conflito, preservar ambas as versões e solicitar resolução.
- Não confundir sincronização de arquivos locais com publicação no GitHub.
- Configurações rejeitadas em uma máquina não são enviadas às outras.

## 4. Fluxo B — Computador novo ou formatado

```text
Ubuntu limpo
   ↓
Instalar pré-requisitos mínimos (ex.: Git)
   ↓
Autenticar-se para acessar o repositório privado
   ↓
Clonar config-workplace
   ↓
Executar ./install.sh (bootstrap)
   ↓
config-workplace initial dev
config-workplace terminal
config-workplace java      # somente quando necessário
config-workplace docker    # somente quando necessário
   ↓
Validar com config-workplace doctor
   ↓
Excluir clone original, se desejar
   ↓
Ferramentas e configurações continuam funcionando
```

O bootstrap deve fornecer instruções claras de autenticação e instalação sem pressupor Node.js, Java ou VS Code. Não deve exigir execução de scripts remotos desconhecidos sem validação. Deve ser possível executar o bootstrap a partir de um clone autenticado.

Em máquinas de terceiros, respeitar políticas de uso e permissões; **não haverá modo especial corporativo**. O usuário pode instalar o ambiente pessoal, excluir o clone e deixar de usar sincronização naquele equipamento. Excluir o clone **não revoga automaticamente credenciais** que tenham sido salvas por Git/gh/SSH; o procedimento deve alertar sobre isso.

## 5. Regra arquitetural inegociável: independência do clone

> **RN-001 — Após a instalação, a exclusão completa do repositório clonado não pode comprometer o funcionamento de nenhum programa, shell, plugin, tema, configuração, profile ou variável instalada pelo config-workplace.**

### Consequências técnicas

- Nunca deixar symlinks de arquivos ativos apontando para o diretório do clone.
- Copiar/aplicar dotfiles nos locais definitivos (`~/.zshrc`, `~/.vimrc`, diretórios do VS Code etc.).
- Instalar NVM em `~/.nvm` e Node nas estruturas do NVM.
- Instalar Oh My Zsh, temas e plugins em diretórios próprios permanentes.
- Instalar ferramentas por gerenciadores de pacotes ou em diretórios independentes.
- Configurar scripts e aliases com caminhos válidos **após a exclusão do clone**.
- Garantir que perfis e extensões do VS Code estejam instalados/importados, não apenas referenciados.
- O chezmoi pode ser usado para gerenciar dotfiles, mas **os arquivos aplicados não podem depender do clone**, de templates temporários ou de scripts ausentes.
- A CLI/monitor são opcionais depois da instalação. Caso se deseje continuar monitorando após apagar o clone, copiar a CLI e os recursos necessários para uma instalação própria e permanente (ex.: `~/.local/share/config-workplace`), com estado e repositório de gerenciamento próprios. A remoção da CLI nunca pode afetar os programas configurados.

**Teste obrigatório:** instalar em Ubuntu limpo, apagar o clone, reiniciar sessão quando necessário e verificar programas, shells, plugins, configurações e ausência de referências quebradas.

## 6. Política de versões e atualizações

A instalação **não congela versões do ano em que o projeto foi criado**. Novas máquinas resolvem versões estáveis atuais conforme a política de cada ferramenta.

| Ferramenta | Nova instalação | Máquina já configurada |
| --- | --- | --- |
| Node.js | Última LTS via NVM (`nvm install --lts`) | Não trocar major silenciosamente |
| npm / pnpm | Versão compatível com Node selecionado | Atualizar mediante verificação |
| Java | JDK LTS atual suportado, resolvido via SDKMAN! | Não trocar major sem aprovação |
| VS Code | Canal estável | Atualizações pelo mecanismo configurado |
| Git | Versão disponível em repositório confiável configurado | Respeitar atualizações do sistema |
| Docker | Versão estável compatível | Atualização controlada |
| Temas / plugins | Versões estáveis compatíveis | Evitar alterações destrutivas |

- `latest-lts` em manifestos é uma **política abstrata**, não necessariamente um argumento aceito literalmente por qualquer instalador.
- Não instalar versões arbitrárias sem checar compatibilidade.
- Atualizações de major ou que alterem configurações devem pedir confirmação.
- O comando `update` não deve ser confundido com o monitor de mudanças.
- Manter um registro local das versões resolvidas para diagnóstico, sem tornar esse registro obrigatório para funcionamento das ferramentas.

Exemplo conceitual de manifesto:

```yaml
tools:
  node:
    manager: nvm
    version: lts/*
    update: manual
  java:
    manager: sdkman
    version_policy: latest-supported-lts
    update: manual
  vscode:
    channel: stable
```

## 7. Segurança e privacidade

**RN-SEC-001:** repositório privado **não é cofre de segredos**.

- Não commitar `.env` reais, tokens, senhas, chaves SSH privadas, cookies, arquivos de autenticação ou credenciais corporativas.
- Guardar apenas templates como `.env.example` e referências a nomes de segredos.
- Recuperar segredos de gerenciador seguro ou solicitar preenchimento local, com consentimento.
- Antes de aceitar uma mudança, executar verificações de segredos e mostrar o diff.
- Se houver suspeita, **bloquear commit/push até revisão**.
- Não confiar somente em scanners: eles não garantem detectar todos os segredos.
- Manter logs sem valores de variáveis sensíveis.
- Permitir ignorar caminhos e ferramentas locais.
- Não enviar inventários completos de máquina sem necessidade; evitar dados pessoais, internos ou de terceiros.
- Não alterar configurações existentes sem backup ou procedimento seguro.
- Nunca executar comandos privilegiados silenciosamente; explicar quando `sudo` for necessário.
- Não armazenar credenciais do GitHub dentro do repositório.
- Respeitar as políticas de equipamentos administrados por terceiros.

## 8. Regras de negócio

| ID | Regra | Critério de aceitação |
| --- | --- | --- |
| RN-001 | Instalação independente do clone | Excluir clone não quebra nenhum recurso instalado |
| RN-002 | Reexecução idempotente | Rodar módulo duas vezes não duplica nem corrompe instalação |
| RN-003 | `initial dev` é o núcleo | Instala essenciais sem Java ou Docker obrigatórios |
| RN-004 | Módulos opcionais independentes | `java`, `docker` e `terminal` podem ser executados separadamente |
| RN-005 | Detectar antes de instalar, em todos os módulos | Existente, funcional e compatível = SKIP independentemente da origem; divergências exigem autorização; nunca migrar só para padronizar gerenciador |
| RN-006 | Aprovação obrigatória | Monitor não altera o projeto sem autorização |
| RN-007 | Rejeição preserva o local | Recusar não modifica repositório nem desfaz configuração local |
| RN-008 | Revisão granular | Alterações independentes podem ter decisões diferentes |
| RN-009 | Sem alertas repetidos | Recusas idênticas ficam registradas em estado local |
| RN-010 | Commit somente do aprovado | Staging seletivo e validação antes de commitar |
| RN-011 | Push separado por padrão | Nenhum push automático sem configuração explícita |
| RN-012 | Conflitos não destrutivos | Nunca sobrescrever alterações locais silenciosamente |
| RN-013 | Monitor configurável | Verificação periódica, sem modificar ferramentas por conta própria |
| RN-014 | Novas instalações atualizadas | Resolver versão estável/LTS vigente e compatível |
| RN-015 | Atualização existente controlada | Sem upgrade de major automático por padrão |
| RN-016 | Segurança dos segredos | Bloquear publicação de material suspeito e não versionar segredos |
| RN-017 | Fonte de verdade aprovada | Git contém apenas configurações aceitas, não espelho irrestrito da máquina |
| RN-018 | Portabilidade progressiva | Ubuntu suportado inicialmente; outros sistemas por adaptadores |
| RN-019 | Falhas rastreáveis | Logs claros e relatório de instalado/ignorado/falhou |
| RN-020 | Configuração manual possível | Arquivos, templates e instruções documentados |
| RN-021 | Instalação sem runtime prévio | Bootstrap não depende de Node.js/Java |
| RN-022 | Configurações específicas locais | Caminhos e dados de máquina não vazam para dotfiles portáteis |
| RN-023 | Captura não implica reprodutibilidade | Detectar pacote não equivale a saber reinstalá-lo |
| RN-024 | Remoção segura do gerenciador | Excluir CLI/monitor não desinstala nem quebra ferramentas |

## 9. Arquitetura proposta

```text
config-workplace/
├── bin/
│   └── config-workplace          # Entrada da CLI
├── lib/
│   ├── platform.sh               # Detecção de sistema
│   ├── logging.sh                # Logs e mensagens
│   ├── packages.sh               # Instalação e verificações
│   └── safety.sh                 # Validação e backups
├── modules/
│   ├── initial-dev.sh
│   ├── java.sh
│   ├── docker.sh
│   ├── terminal.sh
│   └── env.sh
├── dotfiles/                     # Fonte gerenciada pelo chezmoi
├── manifests/
│   ├── tools.yaml
│   └── vscode-extensions.txt
├── monitor/
│   ├── detect.sh
│   ├── review.sh
│   └── systemd/
├── platforms/
│   └── ubuntu/
├── templates/
│   └── .env.example
├── tests/
│   ├── unit/
│   └── integration/
├── docs/
│   ├── manual-setup.md
│   ├── architecture.md
│   └── security.md
├── install.sh
├── config-workplace.yaml
├── .gitignore
└── README.md
```

A estrutura é indicativa e pode ser refinada durante o MVP. A implementação inicial usará **Bash**, com **NVM** para Node.js, **chezmoi** para dotfiles e `systemd --user` para agendamento no Ubuntu. O bootstrap e os instaladores não dependerão de Node.js. Ferramentas como ShellCheck e Bats ajudarão na qualidade.

### Instalação gerenciada versus independente

Existem dois conceitos diferentes:

1. **Clone original:** diretório de onde o usuário executou a instalação; sempre descartável.
2. **Instalação permanente opcional do gerenciador:** CLI, monitor e estado em diretórios próprios, para continuar recebendo alertas após a exclusão do clone.

Nenhum deles pode ser dependência em tempo de execução de Git, Node, Zsh, Java, Docker, Vim, VS Code ou suas configurações.

## 10. Exemplo de configuração planejada

```yaml
sync:
  enabled: true
  interval: 6h
  detect:
    dotfiles: true
    vscode_extensions: true
    known_package_managers: true
  review:
    required: true
    granular: true
  git:
    auto_commit_after_approval: true
    auto_push: false
  conflicts:
    strategy: manual

security:
  scan_secrets: true
  block_suspicious_changes: true

updates:
  new_installations: latest-compatible
  major_upgrades: manual

monitor:
  enabled: true
  notify_on_changes: true
```

Esse YAML é **proposta de formato do próprio projeto**, não configuração nativa de chezmoi ou systemd.

## 11. Critérios de qualidade e testes

### Testes automatizados

- ShellCheck para análise estática.
- Bats para testes de CLI e funções Bash.
- Testes de parsing de comandos, detecção de sistema e erros.
- Testes de idempotência por módulo.
- Testes de captura seletiva e rejeição.
- Testes de proteção contra commits de segredos.
- Testes de conflitos e preservação de arquivos.
- GitHub Actions para validar alterações em pull requests.

### Teste de aceitação: `standalone-install`

1. Provisionar Ubuntu limpo em VM.
2. Clonar o repositório e executar bootstrap.
3. Instalar `initial dev` e `terminal`; repetir instalações.
4. Instalar módulos opcionais disponíveis para o teste.
5. Excluir o clone.
6. Iniciar nova sessão de shell.
7. Validar executáveis, versões, aliases, plugins, temas e configurações.
8. Verificar ausência de links e referências a caminhos do clone.
9. Confirmar que remover o gerenciador opcional não altera os programas instalados.

Containers podem testar partes do processo; troca de shell, serviços e aplicativos gráficos exigirão VM ou ambiente equivalente.

## 12. Roadmap

### Fase 1 — CLI e bootstrap (MVP)
- [ ] Criar repositório privado e estrutura inicial.
- [x] Implementar `install.sh` sem Node.js prévio.
- [ ] Implementar CLI, `help`, `version`, `list`, logs e detecção de Ubuntu.
- [ ] Implementar `--dry-run` nos módulos aplicáveis.
- [x] Garantir que a CLI instalada não dependa do clone.

### Fase 2 — Ambiente essencial
- [x] Implementar `initial dev` limitado à Fase 2.1 (Git, gh, NVM, Node LTS, npm).
- [x] Implementar instaladores de Git, gh, NVM, Node LTS, npm/pnpm e utilitários.
- [x] Implementar VS Code, extensões básicas aprovadas e revisão de settings.
- [x] Detectar versões e manter idempotência no escopo da Fase 2.1.
- [x] Criar testes simulados do módulo da Fase 2.1.

### Fase 3 — Configurações pessoais
- [x] Implementar Fase 3.1: módulo terminal e testes isolados.
- [x] Implementar Fase 3.2: módulo Java opcional e testes isolados.
- [ ] Integrar chezmoi.
- [ ] Versionar Zsh, Oh My Zsh, temas, plugins, Vim e Git.
- [ ] Implementar `terminal` e importação de profiles do VS Code.
- [ ] Testar exclusão do clone.

### Fase 4 — Módulos independentes
- [x] Implementar `java` (Fase 3.2).
- [ ] Importar profile Java aprovado (extensões individuais já disponíveis).
- [ ] Implementar `docker`.
- [ ] Preparar `env` com templates e gerenciamento seguro de segredos.
- [ ] Adicionar ferramentas conforme necessidade.

### Fase 5 — Monitoramento e revisão
- [ ] Implementar `status`, `monitor` e `review`.
- [ ] Detectar mudanças em dotfiles, extensões e inventários conhecidos.
- [ ] Criar notificações e timer de 6 horas.
- [ ] Implementar aprovação granular, rejeição local e ignorados.
- [ ] Criar commits seletivos após aprovação.
- [ ] Implementar `sync` com proteção contra conflitos.

### Fase 6 — Evolução
- [ ] Implementar `doctor` e `update`.
- [ ] Adicionar inventário e cadastro assistido de ferramentas.
- [ ] Ampliar testes de instalação independente.
- [ ] Considerar suporte a macOS e Windows.

## 13. Decisões consolidadas

- Repositório **pessoal e privado**.
- **Sem** perfis `frontend`, `backend`, `fullstack` ou `--work`.
- Ambiente inicial único: **`initial dev`**.
- Java, Docker e demais recursos **sob demanda**.
- Node.js via **NVM**, com LTS atual em novas instalações.
- Configurações editadas normalmente no computador.
- Monitor detecta e **solicita aprovação** para incorporar mudanças.
- Recusa preserva o estado local e não altera o projeto.
- Commit após aprovação; push separado por padrão.
- Credenciais nunca versionadas em texto puro.
- **Nenhuma instalação ou configuração pode depender do clone original.**

---

**Objetivo final:** formatar um computador, recuperar o ambiente pessoal com poucos comandos, continuar trabalhando normalmente e decidir quais mudanças merecem fazer parte da configuração permanente para as próximas máquinas.

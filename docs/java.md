# Java — Fase 3.2

`java` é opcional e independente de `initial dev`. A CLI usa Bash 3.2 e os
helpers existentes de plataforma, confirmação, HTTPS, destinos e detecção do
VS Code. O bootstrap copia somente os novos helpers, módulo e manifesto; nunca
inventários, credenciais ou configurações capturadas.

## Detecção e preservação

Sonda `java -version`, `javac -version`, `mvn -version` e `gradle --version`
fora de projetos. No Gradle, desativa inicialização nativa na sondagem para
não extrair bibliotecas no cache. Ferramentas funcionais ficam SKIP, inclusive
versões antigas e instalações externas. A major de Java/javac deve concordar.
Considera JAVA_HOME, SDKMAN!, diretórios JDK do Linux/macOS e Homebrew. Os
launchers `/usr/bin/java` do Mac não comprovam uma instalação: consulta também
`/usr/libexec/java_home`. A origem é inferida pelo caminho, sem migrar pacotes.
Instalações fora desses locais devem expor seus executáveis no PATH.

Runtime sem compilador gera REVIEW e proposta de JDK com confirmação própria.
Falhas, seleção SDKMAN! preexistente conflitante e JAVA_HOME inválido/divergente
bloqueiam instalações dependentes. O módulo não corrige configurações por conta
própria; revise a seleção na sessão e reexecute. Não lê conteúdos de
`settings.xml`/`gradle.properties`, não modifica wrappers ou configurações de projetos.

## Resolução e confiança

- JDK: consulta `most_recent_lts` e confirma sua presença em
  `available_lts_releases` na API da Adoptium. Cruza com o catálogo SDKMAN! da
  plataforma/arquitetura e escolhe o maior patch estável Temurin daquela major.
  Não interpreta a feature release mais nova como LTS nem recua silenciosamente
  para outra major/fornecedor. Falhas de rede, formato ou candidato bloqueiam.
- Maven: maior versão estável do catálogo SDKMAN!. A política de compatibilidade
  reconhece as linhas 3.9/3.10 (Java 8+); linhas futuras ficam REVIEW até revisar
  requisitos, sem instalar uma versão arbitrária. Não fixa um patch.
- Gradle: maior estável do catálogo e intervalo de JVM extraído da documentação
  **daquela versão**. Formato desconhecido ou JVM incompatível gera REVIEW;
  não troca o JDK nem escolhe uma versão antiga sem decisão do proprietário.
- As versões resolvidas aparecem antes da confirmação e ficam registradas no
  diretório de candidatos/metadados do SDKMAN!, sem dependência da CLI.

O dry-run consulta HTTPS quando faltam ferramentas, mantendo metadados e o
instalador em memória. Não cria temporários, não carrega SDKMAN!, não executa
instaladores e não usa sudo. Pendências bloqueantes retornam 1; argumentos
inválidos retornam 2; recusa/EOF retorna 0.

## SDKMAN! e novas sessões

SDKMAN! ausente só é proposto quando há ferramenta a instalar. Exige confirmação
do plano completo, aprovação específica do gerenciador e confirmação de cada
candidato. Antes de instalar um candidato, repete a detecção. Um JDK funcional
nunca autoriza instalar outro ou mudar seu fornecedor/default.

A sondagem do SDKMAN! lê versão e verifica sintaxe do init sem carregá-lo: sua
inicialização pode criar arquivos ou ativar versões. A execução de `sdk version`
é validada depois da aprovação, no processo que instala candidatos. Configurações
preexistentes são preservadas, com auto-update desativado apenas nesse processo.
Um diretório incompleto exige revisão manual, não reinstalação automática.

O instalador oficial `get.sdkman.io?rcupdate=false` é obtido por HTTPS, validado
por sintaxe, versão estável e identificação da API, e executado de arquivo local.
HOME/ZDOTDIR temporários protegem os arquivos de inicialização, mesmo se o
instalador mudar seu comportamento. SDKMAN_DIR aponta ao destino permanente,
validado contra clone e links simbólicos. A confiança é HTTPS/origem oficial e
validação estrutural, **não uma assinatura independente nem auditoria semântica**
do script remoto. Downloads de candidatos e checksums são tratados pelo SDKMAN!.

O instalador atual exige Bash 4+, curl, zip, unzip e tar. A CLI procura Bash
compatível no PATH e locais usuais do Homebrew, sem instalar ou trocar shell.
Se faltar, prepare esse pré-requisito e reexecute. Bash 3.2 continua suficiente
para a CLI, o diagnóstico e a preservação de ferramentas existentes. Não há sudo.

Cada instalação aprovada pode criar a **primeira** seleção `current` da ferramenta
no SDKMAN!. Seleções existentes não são substituídas. JAVA_HOME/PATH temporários
usados na validação não modificam o shell chamador. SDKMAN_CANDIDATES_DIR customizado
não é suportado para instalações nesta etapa.

A integração de inicialização permanece **manual e explícita**: ao terminar,
o comando imprime as linhas com o SDKMAN_DIR real para revisão.
Ao contrário do NVM em `initial dev`, Java não propõe escrita automática no startup.
Carregar esse init nas novas sessões ativa as seleções do SDKMAN! e pode definir
JAVA_HOME. Revise a precedência com outras instalações antes de acrescentá-lo.
Sem essa integração, os binários continuam acessíveis por caminho absoluto em
`$SDKMAN_DIR/candidates/<ferramenta>/<versão>/bin`.

Nenhum arquivo pessoal é editado, portanto não há backup de settings/shell a
criar nesta fase. A configuração de SDKMAN! recém-criada desabilita self-update
e auto-env. Em falha parcial, instalações concluídas permanecem; revise o destino
incompleto antes de repetir. Não há rollback de SDKs ou desinstalação automática.

## Evidências do VS Code

O inventário `vscode-profile-01-extensions.tsv` registra sete IDs: `redhat.java`,
`vscjava.vscode-gradle`, `vscjava.vscode-java-debug`,
`vscjava.vscode-java-dependency`, `vscjava.vscode-java-pack`,
`vscjava.vscode-java-test` e `vscjava.vscode-maven`.
O nome/finalidade/aprovação do perfil não foi confirmado na captura.

Os settings capturados não contêm `java.jdt.ls.java.home`, `java.configuration.runtimes`,
caminhos de Maven/Gradle nem outra configuração de JDK reutilizável. Preferências
gerais portáteis já pertencem à Fase 2.2. Os fragmentos macOS contêm Fish/Fig
(`terminal.integrated.defaultProfile.osx` e `terminal.integrated.env.osx`), que
não são copiados para Ubuntu. Não há caminho absoluto de JDK a importar.

`manifests/java-extensions.txt` contém seis **candidatas**, exigindo aprovação
individual na execução. O pack é omitido para não aprovar várias extensões
implicitamente; o editor ainda pode instalar dependências declaradas de cada ID.
Itens presentes são SKIP, extras são preservados, sem `--force`, criação/seleção
de perfil ou edição de settings. O destino é o perfil padrão. Não ter VS Code
não bloqueia o ambiente Java. Importação de profiles segue pendente.

## Validação

```bash
/bin/bash tests/java.sh
./bin/config-workplace java --dry-run
# Apenas quando desejar instalações reais, com confirmação:
./bin/config-workplace java
```

A suíte usa HOME temporário, fixtures e mocks; nunca instala ferramentas reais.
Validações em Ubuntu e Mac limpos, com downloads reais, nova sessão e remoção
do clone/CLI, continuam manuais. O teste com fixtures demonstra independência
dos caminhos, não certifica os servidores nem os binários atuais dos fornecedores.

Referências oficiais consultadas: [SDKMAN! instalação](https://sdkman.io/install/),
[SDKMAN! uso](https://sdkman.io/usage/),
[API Adoptium](https://api.adoptium.net/v3/info/available_releases),
[Maven requisitos/histórico](https://maven.apache.org/docs/history.html),
[Gradle compatibilidade](https://docs.gradle.org/current/userguide/compatibility.html).

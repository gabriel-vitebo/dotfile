# Seleção VS Code — Fase 2.2

Inventários são observações de 2026-10-20. Prettier e Error Lens foram aprovados
explicitamente pelo proprietário durante a implementação. As demais extensões
não entram no manifesto base. Não há extensão identificada como exclusiva do
macOS; restrições `.osx` estão nos settings de Fish/Fig e ficam excluídas.

Nenhuma extensão é declarada obsoleta sem verificação do mantenedor. Há candidatos
redundantes (dois Live Server, suporte Elixir e renderizadores Mermaid), que
continuam opcionais, sem remoção automática. IA está fora do escopo solicitado.
O profile adicional de Java permanece separado e não é aplicado nesta fase.

| Identificador capturado | Classificação / decisão |
| --- | --- |
| `anthropic.claude-code` | Fora da base — IA excluída do escopo |
| `bierner.markdown-mermaid` | Opcional — não instalar automaticamente |
| `bradlc.vscode-tailwindcss` | Específica de linguagem/tecnologia |
| `christian-kohler.path-intellisense` | Opcional — não instalar automaticamente |
| `chrmarti.regex` | Opcional — não instalar automaticamente |
| `codereviewforgithubcopilot.github-copilot-code-review` | Fora da base — IA excluída do escopo |
| `csstools.postcss` | Específica de linguagem/tecnologia |
| `dbaeumer.vscode-eslint` | Específica de linguagem/tecnologia |
| `eamodio.gitlens` | Opcional — não instalar automaticamente |
| `esbenp.prettier-vscode` | Essencial geral — base aprovada |
| `formulahendry.auto-close-tag` | Opcional — não instalar automaticamente |
| `github.vscode-pull-request-github` | Opcional — não instalar automaticamente |
| `graphql.vscode-graphql` | Específica de linguagem/tecnologia |
| `graphql.vscode-graphql-syntax` | Específica de linguagem/tecnologia |
| `hashicorp.hcl` | Específica de linguagem/tecnologia |
| `humao.rest-client` | Opcional — não instalar automaticamente |
| `jakebecker.elixir-ls` | Específica de linguagem/tecnologia |
| `mathiasfrohlich.kotlin` | Específica de linguagem/tecnologia |
| `mechatroner.rainbow-csv` | Opcional — não instalar automaticamente |
| `mermaidchart.vscode-mermaid-chart` | Opcional — não instalar automaticamente |
| `miguelsolorio.fluent-icons` | Opcional — não instalar automaticamente |
| `miguelsolorio.symbols` | Opcional — não instalar automaticamente |
| `mjmcloug.vscode-elixir` | Específica de linguagem/tecnologia |
| `ms-azuretools.vscode-containers` | Específica de linguagem/tecnologia |
| `ms-ceintl.vscode-language-pack-pt-br` | Opcional — não instalar automaticamente |
| `ms-playwright.playwright` | Específica de linguagem/tecnologia |
| `ms-vscode-remote.remote-containers` | Específica de linguagem/tecnologia |
| `ms-vscode.live-server` | Opcional — não instalar automaticamente |
| `ms-vsliveshare.vsliveshare` | Opcional — não instalar automaticamente |
| `nrwl.angular-console` | Específica de linguagem/tecnologia |
| `openai.chatgpt` | Fora da base — IA excluída do escopo |
| `openai.codex-audio` | Fora da base — IA excluída do escopo |
| `pkief.material-icon-theme` | Opcional — não instalar automaticamente |
| `pomdtr.excalidraw-editor` | Opcional — não instalar automaticamente |
| `prisma.prisma` | Específica de linguagem/tecnologia |
| `ritwickdey.liveserver` | Opcional — não instalar automaticamente |
| `rocketseat.theme-omni` | Opcional — não instalar automaticamente |
| `streetsidesoftware.code-spell-checker` | Opcional — não instalar automaticamente |
| `streetsidesoftware.code-spell-checker-portuguese-brazilian` | Opcional — não instalar automaticamente |
| `styled-components.vscode-styled-components` | Específica de linguagem/tecnologia |
| `tobe.rain-background` | Opcional — não instalar automaticamente |
| `unifiedjs.vscode-mdx` | Específica de linguagem/tecnologia |
| `usernamehw.errorlens` | Essencial geral — base aprovada |
| `vue.volar` | Específica de linguagem/tecnologia |
| `redhat.java` | Específica de linguagem/tecnologia |
| `vscjava.vscode-gradle` | Específica de linguagem/tecnologia |
| `vscjava.vscode-java-debug` | Específica de linguagem/tecnologia |
| `vscjava.vscode-java-dependency` | Específica de linguagem/tecnologia |
| `vscjava.vscode-java-pack` | Específica de linguagem/tecnologia |
| `vscjava.vscode-java-test` | Específica de linguagem/tecnologia |
| `vscjava.vscode-maven` | Específica de linguagem/tecnologia |

Preferências propostas no manifesto: `editor.fontSize=16`, `editor.rulers=[80,120]`,
`editor.tabSize=2`, `editor.minimap.enabled=false`, `editor.formatOnSave=false` e
`diffEditor.ignoreTrimWhitespace=false`. São candidatas derivadas do conjunto
comum capturado, com confirmação obrigatória por chave em cada máquina. Não há
aprovação implícita para substituir valores locais. Não há keybindings capturados.
Nenhum nome ou estado privado de profile é lido para inferir seleção ativa.

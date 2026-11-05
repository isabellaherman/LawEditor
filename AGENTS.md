# AGENTS

Leia o `README.md` antes. Este arquivo diz o que fazer e o que não fazer.

## Bend
- Versão mínima: **2.0.39**. Atualize com `bend update` ou instale com `curl -fsSL https://bend-lang.com/install.sh | sh`.
- Aprenda a linguagem com `bend guide` e `bend base`. **Não invente sintaxe.** Se não achar algo, diga que não achou.
- Referência de app web: `demos/app_win_is_bug_2d` em https://github.com/bendlang/bend. Siga esse padrão:
  - O JS importa `.bend` direto (`import X from "./x.bend"`).
  - O dev server é bun, com `preload` e `plugins` apontando para `bend2/main.ts` (veja o `web/bunfig.toml` do demo).
  - O build é `bend page.html -o dist`.
  - Construtores chegam ao JS como `{$: "Nome", campo: valor}`; `Nat` chega como número.
- Rode `bend PROOF.bend` antes de cada commit. Commit com law quebrada não entra.

## Arquivos que você NÃO edita
- `spec/`: é a especificação visual.
- `LAWS.bend` e `SPEC.bend`: são as regras e o que elas significam. Só a Bella muda.

Se uma tarefa parecer exigir mudar um desses arquivos, pare e pergunte.

## Etapas (pare e reporte ao fim de cada uma)

**1. Ambiente.**
- Atualize o Bend e reporte a versão.
- Rode o `demos/app_win_is_bug_2d/web` localmente.
- Reporte se funcionou, os comandos exatos usados e qualquer erro.

**2. Tokens em Bend + um botão.** ✅ Feito: `src/TOKENS.bend`, `LAWS.bend`, `SPEC.bend`, `PROOF.bend`, `web/`.
- `src/TOKENS.bend`: os valores de `spec/tokens.css` (espaço, raio, tipo, cor, controles; só o tema claro por enquanto).
- **Proposta** de `LAWS.bend` com, no mínimo:
  - Todo espaçamento usado pertence à escala (2, 4, 8, 12, 16, 24, 32, 48, 64; o 2 é o hairline).
  - Raio aninhado: raio externo = raio interno + padding (ex.: segmented, 6 = 4 + 2).
  - Altura de controle pertence a {24, 30, 36}.
- `PROOF.bend` provando essas laws.
- JS que lê os tokens do Bend e escreve as variáveis CSS (`--space-1`, …) no `:root`.
- Uma página com **um** `.btn--primary` usando `spec/components.css`, idêntico ao do `spec/index.html`.
- Demonstre que a law bloqueia um erro: mude um padding para 10, mostre o `bend PROOF.bend` falhando, e reverta.

**3. Página completa.** ✅ Feito: `web/index.html` é o mock inteiro com tokens vindos do Bend; 0 diferenças contra o spec em 3.066 propriedades e pixel a pixel. O `spec/index.html` inteiro rodando com tokens vindos do Bend, visualmente idêntico ao original.

## Fora do escopo
O modelo de LAW do editor (como uma frase vira law). A Bella vai desenhar isso. Não proponha nada sobre ele.

## Formato do reporte
O que foi feito · como rodar · o que ficou incerto · o que você precisa da Bella.

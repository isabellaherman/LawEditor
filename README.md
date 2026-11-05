# LawEditor

Editor de GDD que transforma frases afirmativas em **laws** do Bend: o `LAWS.bend` escrito por quem desenha o jogo, não por quem programa.

No Bend, `LAWS.bend` é o arquivo do humano. Ali ficam as regras que o app nunca pode quebrar, e o compilador exige prova de que elas continuam valendo a cada mudança. O LawEditor é a interface humana desse arquivo: o game designer escreve "a vida nunca passa da vida máxima", e isso vira uma law que nenhum agente consegue violar.

## Estrutura

| Pasta | O que é | Quem mexe |
|---|---|---|
| `spec/` | Especificação visual: tokens, componentes e o mock do editor. O resultado final tem que ficar idêntico a ela. | Só a Bella |
| `LAWS.bend` | As regras do design system (e, depois, do editor). | Só a Bella aprova |
| `PROOF.bend` | As provas das laws. | Agente |
| `src/` | O código. | Agente |

## Como o Bend entra

O Bend não gera HTML. O padrão oficial (veja `demos/app_win_is_bug_2d` no [repo do Bend](https://github.com/bendlang/bend)) é:

- **Bend:** valores, lógica e laws.
- **HTML/CSS/JS:** só desenham o que o Bend devolve. O JS faz `import X from "./x.bend"`.

Para este projeto, "a lib em Bend" significa que **os tokens vivem em Bend e são governados por laws**. Um padding fora da escala ou um raio aninhado errado não passa no `bend PROOF.bend`. O CSS só consome as variáveis geradas a partir do Bend.

## Rodar

```bash
bend update                          # ou: curl -fsSL https://bend-lang.com/install.sh | sh
bend PROOF.bend                      # verifica as laws: ALL PROOFS CHECK

git clone https://github.com/bendlang/bend ../bend   # o servidor de dev usa o loader dele
cd web && bun index.html             # abre a página; os tokens vêm de src/TOKENS.bend
```

## Laws do design system hoje

| Law | O que garante |
|---|---|
| `btn_padding_in_scale` | Padding do botão está na escala (2, 4, 8, 12, 16, 24, 32, 48, 64) |
| `panel_padding_in_scale` | Padding do painel está na escala |
| `segmented_padding_in_scale` | Padding do segmented está na escala |
| `btn_height_in_scale` | Altura do botão é 24, 32 ou 36 |
| `icon_button_*_fits` | Botão só de ícone: ícone + 2 × padding = altura (sm, md, lg) |
| `segmented_radius_nested` | Raio externo = raio interno + padding |
| `inside_less_than_between` | Espaço dentro do grupo < espaço entre grupos |

Teste: troque `btn_padding_x` para `10` em `src/TOKENS.bend` e rode `bend PROOF.bend`. Dá `SOME PROOFS FAIL`.

Instruções para agentes: [`AGENTS.md`](AGENTS.md).

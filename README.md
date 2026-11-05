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
bend update            # ou: curl -fsSL https://bend-lang.com/install.sh | sh
bend PROOF.bend        # verifica as laws
```

Instruções para agentes: [`AGENTS.md`](AGENTS.md).

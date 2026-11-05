# LawEditor

Editor de GDD que transforma frases afirmativas em **laws** do [Bend](https://github.com/bendlang/bend): o `LAWS.bend` escrito por quem desenha o jogo, não por quem programa.

O visual vem do [Bend-UI](https://github.com/isabellaherman/Bend-UI), o design system em Bend. Este repo só tem o que é do editor.

## Rodar

```bash
bun install
bun run dev
```

Precisa de um clone do [bendlang/bend](https://github.com/bendlang/bend) ao lado desta pasta (`../bend`). O caminho fica em `web/bunfig.toml`.

Para atualizar a lib: `bun update bend-ui`.

## Estrutura

| Arquivo | O que é |
|---|---|
| `web/index.html` | O editor |
| `web/main.js` | `import "bend-ui"` + os estilos do editor |
| `web/editor.css` | Estilos só do editor (documento, LAW, sidebar, inspector) |

Componente novo nasce aqui, em `editor.css`. Quando uma segunda ferramenta precisar dele, ele sobe para o Bend-UI.

Instruções para agentes: [`AGENTS.md`](AGENTS.md).

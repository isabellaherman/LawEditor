// The same in every project (harness/web). LawEditor copies it to <project>/.laweditor/web/ and bundles it:
// the driver runs the project's main.bend (init, render, on_event; title when it has one).
import { start } from "./driver.js";
import Main from "../../main.bend";

if (typeof Main.title === "function") document.title = Main.title();
start(Main);

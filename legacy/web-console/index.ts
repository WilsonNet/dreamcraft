import index from "./index.html";
import consoleHtml from "./console.html";

Bun.serve({
  routes: {
    "/": index,
    "/console": consoleHtml,
  },
  development: {
    hmr: true,
    console: true,
  },
});

console.log("DreamCraft RTS server running at http://localhost:3000");
console.log("Console available at http://localhost:3000/console");

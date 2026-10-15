// Optional local static server using Node's built-ins; no packages or production hosting.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web');
const port = Number(process.argv[2] || 8064);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.json': 'application/json', '.png': 'image/png', '.pck': 'application/octet-stream' };
http.createServer((request, response) => {
  let file;
  try {
    const url = new URL(request.url, 'http://localhost');
    const relative = decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname);
    file = path.resolve(root, '.' + relative);
  } catch {
    response.writeHead(400).end();
    return;
  }
  if (!file.startsWith(root + path.sep)) {
    response.writeHead(403).end();
    return;
  }
  fs.readFile(file, (error, body) => {
    if (error) { response.writeHead(404).end(); return; }
    response.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-cache' });
    response.end(body);
  });
}).listen(port, '127.0.0.1', () => console.log(`Moonfall Dojo: http://127.0.0.1:${port}/ (Ctrl+C stops)`));

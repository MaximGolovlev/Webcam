const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });
console.log('Signaling server running on ws://localhost:8080');

// Хранилище подключений
const clients = [];

wss.on('connection', (ws) => {
  console.log('New client connected');
  clients.push(ws);
  
  ws.on('message', (message) => {
    console.log('Received message:', message.toString());
    
    // Пересылаем сообщение всем другим клиентам
    clients.forEach(client => {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        client.send(message.toString());
      }
    });
  });
  
  ws.on('close', () => {
    console.log('Client disconnected');
    const index = clients.indexOf(ws);
    if (index !== -1) {
      clients.splice(index, 1);
    }
  });
});
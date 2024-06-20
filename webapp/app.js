const express = require('express')
const path = require('path');
const axios = require('axios');
const http = require('http');

const app = express()
const port = process.env.WEBAPP_PORT || 8081

app.get('/config', (req, res) => {
  res.json(
    {
      httpPort: process.env.SVC_CONTROL_WS_REST_PORT,
      wsPort: process.env.SVC_CONTROL_WS_WS_PORT
    });
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
})
app.use(express.static(path.join(__dirname, 'public')));
app.use('/jquery', express.static(__dirname + '/node_modules/jquery/dist/')); 
app.use('/jquery-ui', express.static(__dirname + '/node_modules/jquery-ui/dist/'));

app.listen(port, () => {
  console.log(`WebApp listening on port ${port}`)
})

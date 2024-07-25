// **************************************************************** //
// ham_docker_container - Containers for APRS and ham radio         //
// Version 0.1.0                                                    //
// https://github.com/iontodirel/ham_docker_container               //
// Copyright (c) 2023 Ion Todirel                                   //
// **************************************************************** //

const express = require('express')
const path = require('path');
const axios = require('axios');
const http = require('http');

const app = express()
const port = process.env.WEBAPP_PORT || 8081

app.get('/config', (req, res) => {
  res.json(
    {
      httpPort: process.env.SVC_CONTROL_WS_REST_PORT || 3002,
      wsPort: process.env.SVC_CONTROL_WS_WS_PORT || 3003
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

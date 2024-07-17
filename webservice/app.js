// **************************************************************** //
// ham_docker_container - Containers for APRS and ham radio         //
// Version 0.1.0                                                    //
// https://github.com/iontodirel/ham_docker_container               //
// Copyright (c) 2023 Ion Todirel                                   //
// **************************************************************** //

const Express = require('express')
const Docker = require('dockerode');
const FS = require('fs');
const WebSocket = require('ws');
const mysql = require('mysql2/promise');
const moment = require('moment');
const cors = require("cors");
const child_process = require('child_process');

const settingsFileName = process.env.SVC_CONTROL_WS_PRIV_SETTINGS_FILE_NAME || './../settings.json';
const settings = loadSettingsFromFile(settingsFileName);
const configuration = getServiceConfiguration(settings);

if (!process.env.hasOwnProperty('SVC_CONTROL_WS_PRIV_SETTINGS_FILE_NAME')) {
  configuration.database_host_name = '127.0.0.1'
  configuration.svc_control_ws_port_number = 3002;
  configuration.svc_control_ws_websocket_port_number = 3003
}

const app = Express();
app.use(cors());

const wss = new WebSocket.Server({ port: configuration.svc_control_ws_websocket_port_number });

const databasePool = mysql.createPool({
  host: configuration.database_host_name,
  user: configuration.database_user_name,
  password: configuration.database_password,
  database: configuration.database_name,
  port: configuration.database_port_number,
  waitForConnections: true,
  connectionLimit: 10,
  dateStrings: true
});

// **************************************************************** //
//                                                                  //
// DB MISC                                                          //
//                                                                  //
// **************************************************************** //

async function initDbSchema() {
  try {
    await databasePool.query('CREATE DATABASE IF NOT EXISTS db');
    await databasePool.query('USE db');
    await databasePool.query(`
      CREATE TABLE IF NOT EXISTS service (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(50) NOT NULL,
        UNIQUE KEY uk_service_name (name)
      )
    `);
    await databasePool.query(`
      CREATE TABLE IF NOT EXISTS setting (
        id INT PRIMARY KEY AUTO_INCREMENT,
        service_id INT,
        name VARCHAR(250) NOT NULL,
        value VARCHAR(250) NOT NULL,
        default_value VARCHAR(250) NOT NULL,
        display_name VARCHAR(50),
        description VARCHAR(250),
        editable VARCHAR(10) DEFAULT 'false',
        FOREIGN KEY (service_id) REFERENCES service(id),
        INDEX idx_setting_service_id (service_id),
        INDEX idx_setting_service_id_name (service_id, name)
      )
    `);
    console.log('Database and tables created successfully.');
  }
  catch (error) {
    console.error('Error creating database and tables:', error);
  }
}

async function testDbConnection() {
  let connection;
  try {
    connection = await databasePool.getConnection();
    console.log(`Connected to MYSQL database ${configuration.database_host_name}:${configuration.database_port_number}.`);
    return true;
  } catch (error) {
    console.error('Error connecting to the database:', error.message);
  } finally {
    if (connection) {
      connection.release();
    }
  }
  return false;
}

async function waitForDbConnection(maxAttempts = 10, delay = 1000) {
  let attempts = 0;
  while (attempts < maxAttempts) {
    if (await testDbConnection()) {
      return true;
    }
    // Wait for a delay before the next attempt
    await new Promise(resolve => setTimeout(resolve, delay));
    attempts++;
  }
  return false;
}

async function testDbQuery() {
  try {
    const [results, fields] = await databasePool.query("SELECT 1;");
    if (results.length === 1) {
      return results[0]["1"] === 1;
    }
    return false;
  } catch (error) {
    console.error('Error checking system readiness:', error);
    return false;
  }
}

// **************************************************************** //
//                                                                  //
// MAIN                                                             //
//                                                                  //
// **************************************************************** //

(async () => {
  if (!await waitForDbConnection()) {
    console.error('Failed to establish connection to the database within the specified number of attempts.');
    process.exit(1);
  }
  await initDbSchema();
  await populateSettingsInDb(settingsFileName);
})();

// **************************************************************** //
//                                                                  //
// ROUTES                                                           //
//                                                                  //
// **************************************************************** //

app.get('/api/v1/services/:verb?', async (req, res) => {
  const { verb } = req.params;
  try {
    let results = null;
    if (verb === undefined) {
      results = await retrieveServicesStatus();
    }
    else if (verb === "settings") {
      results = await retrieveSettingsForAllServices();
    }
    else if (verb === "health") {
      const fromDate = req.query.from ? new Date(req.query.from) : convertToUtcDate(new Date(1900, 0, 1));
      const toDate = req.query.to ? new Date(req.query.to) : convertToUtcDate(new Date());
      const count = req.query.count ? parseInt(req.query.count) : 10;
      results = await retrieveServiceHealthHistoryByDate(fromDate, toDate, count);
    }
    else if (verb === "restart") {
      const ignoreList = (req.query.ignore ?? '').split(',');
      await restartServices(ignoreList);
      res.json({ 'success': 'true' });
      return;
    }
    else {
      res.status(400).json({ 'error': `Invalid verb "${verb}". Only "", "settings", "health" or "restart" are supported.` });
    }
    const jsonStr = JSON.stringify(results, null, 2);
    res.setHeader('Content-Type', 'application/json');
    res.send(jsonStr);
  }
  catch (err) {
    console.error('Error occurred:', error);
    res.status(500).json({ 'error': 'Failed to retrieve services status' });
  }
  if (verb !== undefined) {
    console.log(`Calling /api/v1/services/${verb}`);
  }
  else {
    console.log(`Calling /api/v1/services`);
  }
});

app.get('/api/v1/service/:name/:verb/:setting?', async (req, res) => {
  const { name, verb, setting } = req.params;

  const logMessage = setting !== undefined
    ? `Calling /api/v1/service/${name}/${verb}/${setting}`
    : `Calling /api/v1/service/${name}/${verb}`;
  console.log(logMessage);

  try {
    let available = await isServiceAvailable(name);
    if (!available) {
      res.status(500).json({ 'error': `Service ${name} not known` });
      return;
    }

    switch (verb) {
      case 'enable':
      case 'disable':
      case 'restart':
      case 'settings':
      case 'enabled':
        break;
      default:
        res.status(400).json({ 'error': `Invalid action "${verb}". Not supported.` });
        return;
    }

    if (verb === 'enabled') {
      const enabled = await getServiceEnableState(name);
      res.json({ 'enabled': enabled.toString() });
    }
    else if (verb === 'settings') {
      if (!setting) {
        let results = await retrieveSettingsForService(name);
        const jsonStr = JSON.stringify(results, null, 2);
        res.setHeader('Content-Type', 'application/json');
        res.send(jsonStr);
      }
      else {
        const serviceSetting = await retrieveSettingForService(name, setting);
        const jsonStr = JSON.stringify(serviceSetting, null, 2);
        res.setHeader('Content-Type', 'application/json');
        res.send(jsonStr);
      }
    }
    else if (verb === 'restart') {
      await restartService(name);
      res.json({ 'success': 'true' });
    }
    else if (verb === 'enable' || verb === 'disable') {
      await enableOrDisableService(name, verb === 'enable' ? 'true' : 'false');
      res.json({ 'success': 'true' });
    }
  } catch (err) {
    console.error(`Service error: ${err.message}`);
    res.status(500).json({ 'error': 'Failed to set service state' });
  }
});

app.get('/api/v1/system/:verb?', async (req, res) => {
  const { verb } = req.params;
  if (verb === 'restart') {
    console.log(`Calling /api/v1/system/${verb}`);
    restartSystem();
    res.json({ 'success': 'true' });
  }
});

app.get('/api/v1/ready', async (req, res) => {
  console.log(`Calling /api/v1/ready`);
  try {
    if (await testDbQuery()) {
      res.json({ 'ready': 'true' });
      return;
    }
  }
  catch (err) {
    console.error(`Service error: ${err.message}`);
  }
  res.json({ 'ready': 'false' });
});

// **************************************************************** //
//                                                                  //
// EXPRESS/WS EVENTS                                                //
//                                                                  //
// **************************************************************** //

app.listen(configuration.svc_control_ws_port_number, '0.0.0.0', () => {
  console.log(`HTTP server is listening for connections on port ${configuration.svc_control_ws_port_number}.`)
})

wss.on('listening', () => {
  console.log(`WebSocket server is listening for connections on port ${configuration.svc_control_ws_websocket_port_number}.`);
});

// **************************************************************** //
//                                                                  //
// WS HANDLING                                                      //
//                                                                  //
// **************************************************************** //

wss.on('connection', (ws) => {
  console.log(`WebSocket connection established`);

  const timer = setInterval(async () => {
    let services;
    try {
      services = await retrieveServicesStatus();
    } catch (error) {
      console.error(`Error retrieving service status: ${error.message}`);
      return; // Exit the function early if there's an error
    }

    // Send service status to the client
    ws.send(JSON.stringify(services));

    // Log when data is sent to the client
    console.log(`Sent WebSocket data to client`);
  }, 5000);

  ws.on('close', () => {
    console.log(`WebSocket connection closed`);
    clearInterval(timer);
  });

  ws.on('error', (error) => {
    console.error(`WebSocket error: ${error.message}`);
    ws.terminate();
  });
});

// **************************************************************** //
//                                                                  //
// SETTINGS                                                         //
//                                                                  //
// **************************************************************** //

function getSettingValue(settings, settingName, defaultValue) {
  const setting = settings.find(setting => setting.name === settingName);
  return setting ? setting.value : defaultValue;
}

async function populateSettingsInDb(settingsFileName) {
  try {
    const settingsData = FS.readFileSync(settingsFileName, 'utf8');
    const settings = JSON.parse(settingsData);

    for (const service of settings.services) {
      await registerServiceInDb(service);
      for (const setting of service.settings) {
        await updateServiceSettingInDb(service, setting);
      }
    }
  } catch (err) {
    console.error('Error:', err);
  }
}

function loadSettingsFromFile(settingsFileName) {
  try {
    const settingsData = FS.readFileSync(settingsFileName, 'utf8');
    return JSON.parse(settingsData);
  } catch (err) {
    console.error('Error reading JSON file:', err);
    return null;
  }
}

function getServiceConfiguration(settings) {
  try {
    const svcControlWs = settings.services.find(service => service.name === 'svc_control_ws');
    if (!svcControlWs) {
      console.error('Service "svc_control_ws" not found.');
      return null;
    }

    const config = {
      database_password: '',
      database_user_name: '',
      database_name: '',
      database_port_number: '',
      database_host_name: '',
      docker_access_socket_file_name: '',
      svc_control_ws_port_number: '',
      svc_control_ws_websocket_port_number: ''
    };

    for (const setting of svcControlWs.settings) {
      switch (setting.name) {
        case 'database_password':
          config.database_password = setting.default_value;
          break;
        case 'database_user_name':
          config.database_user_name = setting.default_value;
          break;
        case 'database_name':
          config.database_name = setting.default_value;
          break;
        case 'database_port_number':
          config.database_port_number = setting.default_value;
          break;
        case 'database_host_name':
          config.database_host_name = setting.default_value;
          break;
        case 'docker_access_socket_file_name':
          config.docker_access_socket_file_name = setting.default_value;
          break;
        case 'svc_control_ws_port_number':
          config.svc_control_ws_port_number = setting.default_value;
          break;
        case 'svc_control_ws_websocket_port_number':
          config.svc_control_ws_websocket_port_number = setting.default_value;
          break;
        default:
          break;
      }
    }

    return config;
  } catch (err) {
    console.error('Error:', err);
    return null;
  }
}

// **************************************************************** //
//                                                                  //
//                                                                  //
//                                                                  //
//                                                                  //
// SERVICES                                                         //
//                                                                  //
//                                                                  //
//                                                                  //
//                                                                  //
// **************************************************************** //

async function retrieveSettingsForAllServices() {
  try {
    const [results, fields] = await databasePool.query(`SELECT name FROM service`);

    const servicesSettings = [];

    for (const result of results) {
      const serviceSettings = await retrieveSettingsForService(result.name);
      servicesSettings.push(serviceSettings);
    }

    return servicesSettings;
  } catch (err) {
    console.error('Error occurred:', err);
    throw err;
  }
}

async function retrieveSettingForService(serviceName, settingName) {
  const serviceSettings = await retrieveSettingsForService(serviceName);
  const setting = serviceSettings.settings.find(s => s.name === settingName);
  return { name: setting.name, value: setting.value };
}

async function retrieveSettingsForService(serviceName) {
  try {
    const [results,] = await databasePool.query(`
      SELECT name,value FROM setting
      WHERE service_id = (SELECT id FROM service WHERE name = ?)`, [serviceName]);

    const service = settings.services.find(s => s.name === serviceName);
    if (!service) {
      throw new Error(`Could not find service ${serviceName}.`);
    }

    const serviceSettings = {
      name: serviceName,
      settings: service.settings.map((row, index) => ({
        name: row.name,
        display_name: row.display_name,
        description: row.description,
        value: row.value,
        data_type: row.data_type,
        visible: row.visible,
        editable: row.editable
      }))
    };

    serviceSettings.settings.forEach(setting => {
      const result = results.find(result => result.name === setting.name);
      if (result) {
        setting.value = result.value;
      }
    });

    return serviceSettings;
  } catch (err) {
    console.error('Error occurred:', err);
    throw err;
  }
}

async function updateServiceSettingInDb(service, setting) {
  try {
    // Insert setting only if it does not exist
    await databasePool.query(`
      INSERT INTO setting (service_id, name, value, editable, display_name, description, default_value)
      SELECT service.id, ?, ?, ?, ?, ?, ?
      FROM service
      WHERE service.name = ?
      AND NOT EXISTS (
          SELECT 1 FROM setting WHERE setting.service_id = service.id AND setting.name = ?
      )`, [setting.name, setting.value, setting.editable, setting.display_name, setting.description, setting.default_value, service.name, setting.name]);

    // Only update non-editable settings so that they are not overridden
    await databasePool.query(`
      UPDATE setting
      SET value = ?
      WHERE service_id IN (
          SELECT id FROM service WHERE name = ?
      )
      AND name = ?
      AND editable = 'false' `, [setting.value, service.name, setting.name]);
  } catch (error) {
    console.error('Failed:', error);
    throw error;
  }
}

async function retrieveServicesStatus() {
  try {
    const services = await Promise.all(settings.services.map(async (result) => {
      const serviceSettings = await retrieveSettingsForService(result.name);
      return {
        name: result.name,
        displayName: result.display_name,
        description: result.description,
        enabled: getSettingValue(serviceSettings.settings, 'service_enabled', 'false'),
        status: '',
        statusColor: 'red',
        running: '',
        healthStatus: '',
        supportsDisable: getSettingValue(serviceSettings.settings, 'service_can_disable', 'false'),
        supportsRestart: getSettingValue(serviceSettings.settings, 'service_can_restart', 'false'),
        startDate: '',
        startDateUtc: '',
        uptime: '',
        uptimeSeconds: 0,
        containerName: '',
        containerId: '',
        containerImage: '',
      };
    }));

    const dockerInstance = new Docker({ socketPath: configuration.docker_access_socket_file_name });
    const containers = await dockerInstance.listContainers();

    for (const container of containers) {
      const data = await dockerInstance.getContainer(container.Id).inspect();

      const service = services.find(service => service.name === data.Config.Labels['ham_docker_container_name']);
      if (!service) {
        continue;
      }

      service.status = data.State.Status;
      service.running = data.State.Running ? 'true' : 'false';
      service.healthStatus = data.State.Health?.Status ?? 'none';

      const serviceStartDate = new Date(Date.parse(data.State.StartedAt));
      const serviceStartUtcDate = convertToUtcDate(serviceStartDate);
      const currentDate = new Date();

      service.containerImage = container.Image;
      service.containerId = container.Id;
      service.containerName = data.Name;
      service.startDate = formatDateToYYYYMMDDHHmmss(serviceStartDate);
      service.startDateUtc = formatDateToYYYYMMDDHHmmss(serviceStartUtcDate);
      service.uptime = getPrettyDateTimeDifference(currentDate, serviceStartDate);
      service.uptimeSeconds = getDateTimeDifferenceInSeconds(currentDate, serviceStartDate);

      if (service.status === 'running' && service.healthStatus === 'healthy'
        && service.running === 'true' && service.uptimeSeconds > 60) {
        service.statusColor = 'green';
      }
    }

    return services;
  } catch (err) {
    console.error('Error occurred retrieving services status:', err);
    throw err;
  }
}

async function restartServices(ignoreList) {
  const [results, fields] = await databasePool.query(`
    SELECT s.name,
           scd.value AS service_can_restart
    FROM service s
    LEFT JOIN setting scd ON s.id = scd.service_id AND scd.name = 'service_can_restart';`);

  for (const result of results) {
    const serviceName = result.name;
    if ((ignoreList && ignoreList.length > 0) && ignoreList.includes(serviceName)) {
      continue;
    }
    restartService(serviceName);
  }
}

async function restartService(serviceName) {
  const dockerInstance = new Docker({ socketPath: configuration.docker_access_socket_file_name });
  const containers = await dockerInstance.listContainers();

  for (const containerInfo of containers) {
    const container = dockerInstance.getContainer(containerInfo.Id);
    const data = await container.inspect();

    if (data.Config.Labels['ham_docker_container_name'] !== serviceName) {
      continue;
    }

    await container.restart();
  }
}

async function isServiceAvailable(serviceName) {
  try {
    const [results, fields] = await databasePool.query("SELECT COUNT(*) AS count FROM service WHERE name = ?;", [serviceName]);
    let count = 0;
    if (results.length > 0) {
      count = results[0]?.count ?? 0;
    }
    return count === 1;
  } catch (err) {
    console.error('Failed to query service availability:', error);
    throw err;
  }
}

async function enableOrDisableService(serviceName, state) {
  try {
    const results = await databasePool.query(`
      UPDATE setting
      SET value = ?
      WHERE service_id = (
        SELECT id
        FROM service
        WHERE name = ?
      ) AND name = 'service_enabled'`, [state, serviceName]);

    if (results[0].affectedRows === 0) {
      throw new Error("Failed to update the service state.");
    }
  } catch (error) {
    console.error('Failed to handle service enable state:', error);
    throw error;
  }
}

async function getServiceEnableState(serviceName) {
  try {
    const [rows,] = await databasePool.query(`
      SELECT s.name, st.value
      FROM service s
      JOIN setting st ON s.id = st.service_id
      WHERE s.name = ? AND st.name = 'service_enabled'`, [serviceName]);

    if (rows.length === 0) {
      throw new Error(`Service "${serviceName}" not found or its state is not defined.`);
    }

    return rows[0].value === 'true';
  } catch (error) {
    console.error(`Failed to retrieve enable state for service "${serviceName}":`, error);
    throw error;
  }
}

async function registerServiceInDb(service) {
  try {
    // Register service only if it was not registered
    await databasePool.query(`INSERT IGNORE INTO service (name) VALUES (?);`, [service.name]);
  } catch (error) {
    console.error('Failed:', error);
    throw error;
  }
}

// **************************************************************** //
//                                                                  //
// MISC                                                             //
//                                                                  //
// **************************************************************** //

function getDateTimeDifferenceInSeconds(firstDate, secondDate) {
  return Math.floor((firstDate - secondDate) / 1000);
}

function getPrettyDateTimeDifference(firstDate, secondDate) {
  const differenceInMillis = firstDate.getTime() - secondDate.getTime();

  const seconds = Math.floor(differenceInMillis / 1000) % 60;
  const minutes = Math.floor(differenceInMillis / (1000 * 60)) % 60;
  const hours = Math.floor(differenceInMillis / (1000 * 60 * 60)) % 24;
  const days = Math.floor(differenceInMillis / (1000 * 60 * 60 * 24));

  let differenceString = '';

  if (days > 0) {
    differenceString += `${days}d `;
  }

  if (hours > 0) {
    differenceString += `${hours}h `;
  }

  if (minutes > 0) {
    differenceString += `${minutes}m `;
  }

  differenceString += `${seconds}s`;

  return differenceString.trim();
}

function convertToUtcDate(date) {
  return new Date(date.getTime() + date.getTimezoneOffset() * 60000);
}

function formatDateToYYYYMMDDHHmmss(date) {
  const momentDate = moment(date);
  const YYYYMMDDHHmmss = momentDate.format('YYYY-MM-DD HH:mm:ss');
  return YYYYMMDDHHmmss;
}

function restartSystem() {
  child_process.exec('sudo /sbin/shutdown -r now', function (error, stdout) {
    if (error) {
      console.error('Error:', error);
    } else {
      console.log('Restarting the system:', stdout);
    }
  });
}

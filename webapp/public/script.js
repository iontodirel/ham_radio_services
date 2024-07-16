async function initConfig() {
  const response = await fetch('/config');
  const config = await response.json();
  window.httpPort = config.httpPort;
  window.wsPort = config.wsPort;
}

async function beginUpdateServicesTable() {
  const host = window.location.hostname;
  const wsPort = window.wsPort;
  const url = `ws://${host}:${wsPort}`;
  const socket = new WebSocket(url);

  socket.addEventListener('open', () => {
    console.log("WebSocket connection established.");
  });

  socket.addEventListener('close', () => {
    console.log("WebSocket connection closed.");
  });

  socket.addEventListener('error', (error) => {
    console.error("WebSocket error:", error);
  });

  socket.addEventListener('message', (event) => {
    try {
      const services = JSON.parse(event.data);
      console.log("WebSocket data received.");
      updateServicesTable(services);
      updateServicesTiles(services);
    } catch (error) {
      console.error("Error parsing WebSocket message:", error);
    }
  });
}

async function initializeAndPopulateServicesTable() {
  const host = window.location.hostname;
  const httpPort = window.httpPort;
  const url = `http://${host}:${httpPort}/api/v1/services`;

  console.log(`Connecting to ${url}`);

  try {
    const response = await fetch(url, { method: "GET", mode: "cors" });
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const services = await response.json();
    populateServicesTable(services);
    populateServicesTiles(services);
    updateServicesTable(services);
    updateServicesTiles(services);
  } catch (error) {
    console.error('Error fetching services:', error);
  }
}  

async function restartAllServices() {
  const host = window.location.hostname;
  const httpPort = window.httpPort;
  const url = `http://${host}:${httpPort}/api/v1/services/restart?ignore=svc_control_ws,db`;

  console.log(`Calling ${url}`);

  try {
    const response = await fetch(url, { method: "GET", mode: "cors" });
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
  } catch (error) {
    console.error('Error restarting all services:', error);
  }
}
  
async function enableDisableRestartService(serviceName, action) {
  const host = window.location.hostname;
  const httpPort = window.httpPort;
  const url = `http://${host}:${httpPort}/api/v1/service/${serviceName}/${action}`;

  console.log(`Calling ${url}`);

  try {
    const response = await fetch(url, { method: "GET", mode: "cors" });
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
  } catch (error) {
    console.error(`Error performing ${action} on ${serviceName}:`, error);
  }
}

function populateServicesTable(services) {
  const table = document.getElementById("serviceBody");
  for (const service of services) {
    const row = createServiceTableRow(service);
    table.appendChild(row);
  }
}

async function retrieveAndPopulateServiceSettings() {
  const host = window.location.hostname;
  const httpPort = window.httpPort;
  const url = `http://${host}:${httpPort}/api/v1/services/settings`;

  console.log(`Connecting to ${url}`);

  try {
    const response = await fetch(url, { method: "GET", mode: "cors" });
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const serviceSettings = await response.json();
    populateServiceSettings(serviceSettings);
  } catch (error) {
    console.error('Error fetching service settings:', error);
  }
}

function populateServicesTiles(services) {
  const container = document.getElementById("serviceSmall");

  // Clear existing tiles
  container.innerHTML = "";

  for (const service of services) {
    const tile = createServiceTile(service);
    if (tile) {
      container.appendChild(tile);
    }
  }
}

function createServiceTile(service) {
  // Skip services that do not support disabling
  if (service.supportsDisable !== 'true') {
      return null;
  }

  const tile = document.createElement("div");
  tile.classList.add("tile");
  tile.dataset.service = service.name;
  tile.setAttribute("data-context", service.name);
  tile.setAttribute("status", service.enabled);
  //tile.title = "abcd efg hij klmno ";

  const statusBox = document.createElement("div");
  statusBox.classList.add("status-box");

  if (service.statusColor === 'red' || service.uptimeSeconds < 60) {
      statusBox.style.backgroundColor = 'red';
  } else if (service.statusColor === 'green' && service.enabled === 'true') {
      statusBox.style.backgroundColor = 'green';
  } else if (service.enabled === 'false') {
      statusBox.style.backgroundColor = 'yellow';
  }

  tile.appendChild(statusBox);

  const serviceNameDiv = document.createElement("div");
  serviceNameDiv.style.fontWeight = "bold";
  serviceNameDiv.textContent = service.displayName;
  serviceNameDiv.style.fontSize = "17.5px";
  tile.appendChild(serviceNameDiv);

  const statusText = document.createElement("div");
  if (service.enabled === 'true') {
      statusText.style.color = "green";
      statusText.textContent = 'Enabled';
  } else if (service.enabled === 'false') {
      statusText.style.color = "gray";
      statusText.textContent = 'Disabled';
  }
  tile.appendChild(statusText);

  const uptimeText = document.createElement("div");
  uptimeText.style.color = "gray";
  uptimeText.style.fontStyle = "italic";
  uptimeText.style.fontWeight = "normal";
  uptimeText.textContent = service.uptime;
  tile.appendChild(uptimeText);

  tile.addEventListener('click', handleServiceTileClick);

  return tile;
}

function populateServiceSettings(servicesSettings) {
  const settings_placeholder = document.getElementById("settings_placeholder");

  // Clear any existing content
  settings_placeholder.innerHTML = '';

  for (const serviceSettings of servicesSettings) {

    if (serviceSettings.settings.length === 0) {
      continue;
    }

    const hasVisibleSettings = serviceSettings.settings.some(setting => setting.editable === 'true' && setting.visible === 'true');
    if (!hasVisibleSettings) {
      continue;
    }

    const serviceDisplayName = serviceSettings.settings.find(setting => setting.name === "service_display_name").value;

    // Create a container for each service
    const serviceDiv = document.createElement('div');
    serviceDiv.className = 'service-group';

    const serviceHeader = document.createElement('h3');
    serviceHeader.textContent = serviceDisplayName;
    serviceDiv.appendChild(serviceHeader);

    // Add settings for each service
    for (const serviceSetting of serviceSettings.settings) {
      if (serviceSetting.editable === 'true' && serviceSetting.visible === 'true') {
        const settingElement = createSettingElement(serviceSettings, serviceSetting);
        serviceDiv.appendChild(settingElement);
      }
    }

    settings_placeholder.appendChild(serviceDiv);
  }
}

function handleSaveSettings() {
}

function createSettingElement(serviceSettings, serviceSetting) {
  const settingDiv = document.createElement('div');
  settingDiv.className = 'settings_setting';

  const label = document.createElement('label');
  label.className = 'settings_label';
  label.textContent = `${serviceSetting.display_name}:`;
  settingDiv.appendChild(label);

  const input = document.createElement('input');
  input.type = 'text';
  input.className = 'settings_input';
  input.value = serviceSetting.value;
  input.disabled = true;
  input.setAttribute("data-initial-value", serviceSetting.value);
  input.setAttribute("data-service-name", serviceSettings.name);
  input.setAttribute("data-setting-name", serviceSetting.name);
  settingDiv.appendChild(input);

  const descriptionDiv = document.createElement('div');
  descriptionDiv.className = 'settings_description';
  descriptionDiv.textContent = serviceSetting.description;
  settingDiv.appendChild(descriptionDiv);

  return settingDiv;
}

function createServiceTableRow(service) {
  const row = document.createElement("tr");
  const titleRowCell = appendServiceTableCell(row, "displayName", service.displayName, service.description);
  titleRowCell.style.fontWeight = 'bold';
  appendServiceStatusCell(row, "statusColor", service.statusColor);
  appendServiceTableCell(row, "startDateUtc", service.startDateUtc);
  appendServiceTableCell(row, "uptime", service.uptime);
  appendServiceButtonCell(row, service.name, service.supportsDisable === "true" && service.enabled === "false", "Enable");
  appendServiceButtonCell(row, service.name, service.supportsDisable === "true" && service.enabled === "true", "Disable");
  appendServiceButtonCell(row, service.name, true, "Restart");
  row.setAttribute("data-context", service.name);
  return row;
}

function appendServiceTableCell(tableRow, propertyName, text, tooltip) {
  const cell = document.createElement('td');
  cell.textContent = text;
  cell.className = "services-th-td";
  if (tooltip !== undefined && tooltip.length !== 0) {
    cell.title = tooltip;
  }
  tableRow.appendChild(cell);
  cell.setAttribute("data-context", propertyName);
  return cell;
}

function appendServiceStatusCell(tableRow, propertyName, statusColor) {
  const cell = document.createElement('td');
  cell.className = "services-th-td";
  cell.style.textAlign = "center";
  tableRow.appendChild(cell);
  cell.setAttribute("data-context", propertyName);
  cell.setAttribute("hasImage", "true");
  const image = document.createElement('img');
  image.style.width = '20px';
  image.style.height = '20px';
  image.style.display = 'block'; 
  image.style.margin = '0 auto';
  if (statusColor === 'green') {
    image.src = '/online.jpg'
  }
  else {
    image.src = '/failed.jpg'
  }
  cell.appendChild(image);
  return cell;
}

function updateServiceHealthIcon(image, service) {
  if (service["statusColor"] === 'red') {
    image.src = '/failed.jpg'
    image.title = "Failed";
  }
  else if (service["statusColor"] === 'green') {
    if (service["enabled"] === "false" && service["supportsDisable"] === "true") {
      image.src = '/paused.jpg'
    }
    else {
      image.src = '/online.jpg'
    }
  }
}

function updateServiceTableRow(row, service) {
  const cells = row.getElementsByTagName("td");

  for (const cell of cells) {
    const context = cell.getAttribute("data-context");
    if (context) {
      if (cell.getAttribute("hasImage") === "true") {
        const image = cell.getElementsByTagName("img");
        if (image.length === 1) {
          updateServiceHealthIcon(image[0], service);
        }
      }
      else {
        cell.textContent = service[context] || "";
      }
    }
  }
}

function updateServicesTableAndTiles(data) {
  updateServicesTable(data);
}

function updateServicesTiles(data) {
  const container = document.getElementById("serviceSmall");

  // remove any orhaned entries
  const existingTiles = container.querySelectorAll(`div[data-context]`);
  const contextSet = new Set(data.map(service => service.name));
  existingTiles.forEach(tile => {
    const context = tile.dataset.context;
    if (!contextSet.has(context)) {
      container.removeChild(tile);
    }
  });

  for (const service of data) {
    const context = service.name;
    const existingTile = container.querySelector(`div[data-context="${context}"]`);

    if (existingTile) {
      // Update the existing tile
      updateServiceTile(existingTile, service);
    }
    else {
      // add new tile if new service
      const tile = createServiceTile(service);
      if (tile) {
        container.appendChild(tile);
      }
    }
  }
}

function updateServiceTile(tile, service) {
  const statusBox = tile.querySelector("div.status-box");
  const statusText = tile.children[2];
  const uptimeText = tile.children[3];

  if (statusBox && statusText && uptimeText) {
    if (service.statusColor === 'red' || (service.uptimeSeconds < 60 && service.enabled === 'true')) {
      statusBox.style.backgroundColor = 'red';
    } else if (service.statusColor === 'green' && service.enabled === 'true') {
      statusBox.style.backgroundColor = 'green';
    } else if (service.enabled === 'false') {
      statusBox.style.backgroundColor = 'yellow';
    }

    if (service.enabled === 'true') {
      statusText.style.color = "green";
      statusText.textContent = 'Enabled';
    } else if (service.enabled === 'false') { 
      statusText.style.color = "gray";
      statusText.textContent = 'Disabled';
    }

    uptimeText.textContent = service.uptime;
  }

  tile.setAttribute("status", service.enabled);

  console.log("Tile updated");
}

function updateServicesTable(data) {
  const table = document.getElementById("services");
  const rows = table.getElementsByTagName("tr");
  const buttons = table.getElementsByTagName("button");

  // Loop through the existing rows
  for (let i = rows.length - 1; i >= 0; i--) {
    const row = rows[i];
    const context = row.getAttribute("data-context");
    let existsInData = false;

    // Check if the row's data-context exists in the new data
    for (const service of data) {
      if (service.name === context) {
        existsInData = true;
        break;
      }
    }

    // Remove the row if it doesn't exist in the data anymore
    // Ignore header
    if (!existsInData && context) {
      table.removeChild(row);
    }
  }

  // Loop through the data and update/create rows accordingly
  for (const service of data) {
    const context = service.name;
    const existingRow = table.querySelector(`tr[data-context="${context}"]`);

    if (existingRow) {
      // Update the existing row
      updateServiceTableRow(existingRow, service);
    } else {
      // Create a new row
      const newRow = createServiceTableRow(service);
      table.appendChild(newRow);
    }
  }

  // Loop through the buttons and update their state
  for (const button of buttons) {
    const context = button.getAttribute("data-context");
    const service = data.find((service) => service.name === context);
    if (service) {
      // Update the button's state based on service properties
      if (button.name === "enable") {
        button.disabled = !(service.supportsDisable === 'true' && service.enabled === 'false');
        //console.log(`${service.name}: enable button is disabled '${button.disabled}'`);
      }
      else if (button.name === "disable")
        button.disabled = !(service.supportsDisable === 'true' && service.enabled === 'true');
      else if (button.name === "restart")
        button.disabled = false;
    }
  }
}

function appendServiceButtonCell(row, name, enabled, label) {
  const cell = document.createElement("td");
  cell.className = "services-th-td";
  const button = document.createElement("button");
  button.textContent = label;
  button.setAttribute("data-context", name);
  button.addEventListener("click", handleServiceTableButtonClick);
  button.disabled = !enabled;
  button.name = label.toLowerCase();
  cell.appendChild(button);
  row.appendChild(cell);
  return cell;
}

async function handleServiceTableButtonClick(event) {
  const button = event.target;
  const context = button.getAttribute("data-context");
  if (button.name === "enable") {
    await enableDisableRestartService(context, "enable");
  } else if (button.name === "disable") {
    await enableDisableRestartService(context, "disable");
  } else if (button.name === "restart") {
    await enableDisableRestartService(context, "restart");
  }
  console.log(`Calling handleServiceButtonClick: ${button.name} - ${context}`);
}

async function handleRefreshSettings(event) {
  await retrieveAndPopulateServiceSettings();
}

async function handleServiceTileClick(event) {
  const tile = event.currentTarget;
  const service = tile.getAttribute("data-context");
  const serviceEnabled = tile.getAttribute("status");
  if (serviceEnabled === "true") {
    await enableDisableRestartService(service, "disable");
  } else if (serviceEnabled === "false") {
    await enableDisableRestartService(service, "enable");
  }
  console.log(`Calling handleServiceTileClick: ${service}: ${serviceEnabled}`);
}

async function handleRestartAllServicesButtonClick(event) {
  console.log("handleRestartAllServicesButtonClick calling restartAllServices");
  await restartAllServices();
}

// **************************************************************** //
// ham_docker_container - Containers for APRS and ham radio         //
// Version 0.1.0                                                    //
// https://github.com/iontodirel/ham_docker_container               //
// Copyright (c) 2023 Ion Todirel                                   //
// **************************************************************** //

// **************************************************************** //
//                                                                  //
// CONFIG                                                           //
//                                                                  //
// **************************************************************** //

async function initConfig() {
  const response = await fetch('/config');
  const config = await response.json();
  window.httpPort = config.httpPort;
  window.wsPort = config.wsPort;
}

// **************************************************************** //
//                                                                  //
// SERVICES TABLE AND TILES STATUS                                  //
//                                                                  //
// **************************************************************** //

async function beginUpdateServicesTableAndTiles() {
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

async function retrieveAndPopulateServicesTableAndTiles() {
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

// **************************************************************** //
//                                                                  //
// SERVICES TABLE STATUS                                            //
//                                                                  //
// **************************************************************** //

function populateServicesTable(services) {
  const table = document.getElementById("serviceBody");
  for (const service of services) {
    const row = createServicesTableRow(service);
    table.appendChild(row);
  }
}

function createServicesTableRow(service) {
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
  cell.className = "services-table-th-td";
  if (tooltip !== undefined && tooltip.length !== 0) {
    cell.title = tooltip;
  }
  tableRow.appendChild(cell);
  cell.setAttribute("data-context", propertyName);
  return cell;
}

function appendServiceStatusCell(tableRow, propertyName, statusColor) {
  const cell = document.createElement('td');
  cell.className = "services-table-th-td";
  cell.style.textAlign = "center";
  tableRow.appendChild(cell);
  cell.setAttribute("data-context", propertyName);
  cell.setAttribute("hasImage", "true");
  const image = document.createElement('img');
  image.className = "services-table-icon";
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

function appendServiceButtonCell(row, name, enabled, label) {
  const cell = document.createElement("td");
  cell.className = "services-table-th-td";
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
      const newRow = createServicesTableRow(service);
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
      }
      else if (button.name === "disable")
        button.disabled = !(service.supportsDisable === 'true' && service.enabled === 'true');
      else if (button.name === "restart")
        button.disabled = false;
    }
  }
}

async function handleRestartAllServicesButtonClick(event) {
  console.log("handleRestartAllServicesButtonClick calling restartAllServices");
  await restartAllServices();
}

// **************************************************************** //
//                                                                  //
// SERVICES TILES STATUS                                            //
//                                                                  //
// **************************************************************** //

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
  tile.classList.add("service-tile");
  tile.dataset.service = service.name;
  tile.setAttribute("data-context", service.name);
  tile.setAttribute("status", service.enabled);

  const statusBox = document.createElement("div");
  statusBox.classList.add("service-tile-status-box");

  if (service.statusColor === 'red' || service.uptimeSeconds < 60) {
      statusBox.style.backgroundColor = 'red';
  } else if (service.statusColor === 'green' && service.enabled === 'true') {
      statusBox.style.backgroundColor = 'green';
  } else if (service.enabled === 'false') {
      statusBox.style.backgroundColor = 'yellow';
  }

  tile.appendChild(statusBox);

  const serviceNameDiv = document.createElement("div");
  serviceNameDiv.classList.add("service-tile-name");
  serviceNameDiv.textContent = service.displayName;
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
  uptimeText.classList.add("service-tile-uptime");
  uptimeText.textContent = service.uptime;
  tile.appendChild(uptimeText);

  tile.addEventListener('click', handleServiceTileClick);

  return tile;
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
  const statusBox = tile.querySelector("div.service-tile-status-box");
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

// **************************************************************** //
//                                                                  //
// SETTINGS                                                         //
//                                                                  //
// **************************************************************** //

async function retrieveAndPopulateServicesSettings() {
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
    populateServicesSettings(serviceSettings);
  } catch (error) {
    console.error('Error fetching service settings:', error);
  }
}

function populateServicesSettings(servicesSettings) {
  const settingsPlaceholder = document.getElementById("settingsPlaceholder");

  // Clear any existing content
  settingsPlaceholder.innerHTML = '';

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
        const settingElement = createServiceSettingElement(serviceSettings, serviceSetting);
        serviceDiv.appendChild(settingElement);
      }
    }

    settingsPlaceholder.appendChild(serviceDiv);
  }
}

function createServiceSettingElement(serviceSettings, serviceSetting) {
  const settingDiv = document.createElement('div');
  settingDiv.className = 'settings-setting';

  const label = document.createElement('label');
  label.className = 'settings-label';
  label.textContent = `${serviceSetting.display_name}:`;
  settingDiv.appendChild(label);

  const input = document.createElement('input');
  input.type = 'text';
  input.className = 'settings-input';
  input.value = serviceSetting.value;
  input.disabled = true;
  input.setAttribute("data-initial-value", serviceSetting.value);
  input.setAttribute("data-service-name", serviceSettings.name);
  input.setAttribute("data-setting-name", serviceSetting.name);
  settingDiv.appendChild(input);

  const descriptionDiv = document.createElement('div');
  descriptionDiv.className = 'settings-description';
  descriptionDiv.textContent = serviceSetting.description;
  settingDiv.appendChild(descriptionDiv);

  return settingDiv;
}

async function handleRefreshSettings(event) {
  await retrieveAndPopulateServicesSettings();
}

// **************************************************************** //
//                                                                  //
// RESTART SERVICES                                                 //
//                                                                  //
// **************************************************************** //

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

// **************************************************************** //
//                                                                  //
// SERVICE CONTROL                                                  //
//                                                                  //
// **************************************************************** //
  
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

// **************************************************************** //
//                                                                  //
// SERVICE HEALTH                                                   //
//                                                                  //
// **************************************************************** //

async function initHealth() {
  const healthView = document.getElementById('healthView');
  const lastHealthView = localStorage.getItem("lastHealthView") ?? 'day';
  const lastHealthSyncDateWithWindow = localStorage.getItem("lastHealthSyncDateWithWindow");
  const lastHealthSyncDateWithWindowValue = (lastHealthSyncDateWithWindow === null || lastHealthSyncDateWithWindow === undefined) ? 'true' : lastHealthSyncDateWithWindow;
  healthView.value = lastHealthView;
  const lastHealthDate = localStorage.getItem("lastHealthDate");
  const healthDate = (lastHealthDate === null || lastHealthDate === undefined) ? new Date() : new Date(lastHealthDate);
  $("#healthDate").datepicker('setDate', healthDate);
  const viewRange = getHealthViewDateRange();
  await retrieveAndPopulateServiceHealth(viewRange.from, viewRange.to, lastHealthView);  
  healthView.addEventListener('change', handleHealthViewChange);
  $('#healthDate').on('change', handleHealthViewChange);
  const healthSyncDateWithWindow = document.getElementById("healthSyncDateWithWindow");
  healthSyncDateWithWindow.addEventListener('change', handleHealthSyncDateChanged);
  healthSyncDateWithWindow.checked = lastHealthSyncDateWithWindowValue === 'true' ? true : false;
  updateHealthSyncDate();
}

function beginHealthUpdateProgress() {
  const healthContainer = document.getElementById("healthContainer");
  if (healthContainer.clientHeight > 0) {
    document.querySelector('.spinner-container').style.height = healthContainer.clientHeight + 'px';
  }
  healthContainer.style.display = 'none';
  document.querySelector('.spinner-container').style.display = 'flex';
}

function endHealthUpdateProgress() {
  const healthContainer = document.getElementById("healthContainer");
  healthContainer.style.display = 'grid';
  document.querySelector('.spinner-container').style.display = 'none';
}

function calculateHealthViewDateRange(date) {
  let fromDate, toDate;
 
  if (healthView.value === 'day') {
    fromDate = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0);
    toDate = new Date(fromDate);
    toDate.setHours(23, 59, 59, 999);
  }
  else if (healthView.value === 'week') {
    const dayOfWeek = date.getDay();
    const diff = (dayOfWeek === 0 ? -6 : 1) - dayOfWeek; // Adjust if day is Sunday (0) to start on Monday
    fromDate = new Date(date.getFullYear(), date.getMonth(), date.getDate() + diff, 0, 0, 0, 0);
    toDate = new Date(fromDate);
    toDate.setDate(fromDate.getDate() + 6); // Move to Sunday of the same week
    toDate.setHours(23, 59, 59, 999);
  }
  else if (healthView.value === 'month') {
    fromDate = new Date(date.getFullYear(), date.getMonth(), 1, 0, 0, 0, 0);
    toDate = new Date(fromDate);
    toDate.setMonth(fromDate.getMonth() + 1);
    toDate.setDate(0); // Last day of the month
    toDate.setHours(23, 59, 59, 999);
  }
  else if (healthView.value === 'year') {
    fromDate = new Date(date.getFullYear(), 0, 1, 0, 0, 0, 0);
    toDate = new Date(fromDate);
    toDate.setFullYear(fromDate.getFullYear() + 1);
    toDate.setDate(0); // Last day of the year
    toDate.setHours(23, 59, 59, 999);
  }

  return {
    from: fromDate.toISOString(),
    to: toDate.toISOString()
  };
}

function getHealthViewDateRange() {
  const healthDate = document.getElementById('healthDate');
  const selectedDate = new Date(healthDate.value);
  const healthViewRange = calculateHealthViewDateRange(selectedDate);
  const fromDateString = formatDateToMMDDYYYYHHmm(new Date(healthViewRange.from));
  const toDateString = formatDateToMMDDYYYYHHmm(new Date(healthViewRange.to));
  console.log(`Health view date range: ${fromDateString} - ${toDateString}`);
  document.getElementById('healthEventDateRange').textContent = `${fromDateString} - ${toDateString}`;
  return healthViewRange;
}

async function retrieveAndPopulateServiceHealth(from, to, view = 'day') {
  beginHealthUpdateProgress();

  const host = window.location.hostname;
  const httpPort = window.httpPort;
  const url = `http://${host}:${httpPort}/api/v1/services/health?view=${view}&from=${from}&to=${to}`;

  console.log(`Connecting to ${url}`);

  try {
    const response = await fetch(url, { method: "GET", mode: "cors" });
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const health = await response.json();
    populateServiceHealth(health);
    endHealthUpdateProgress();
  } catch (error) {
    console.error('Error fetching services:', error);
  }
}

function populateServiceHealth(data) {
  const healthContainer = document.getElementById("healthContainer");
  healthContainer.innerHTML = '';
  for (const tileData of data.tiles) {  
    const tile = document.createElement('div');
    tile.className = 'health-tile';
    tile.setAttribute("date-context", tileData.date);
    tile.setAttribute("period-context", data.periodSeconds);
    tile.style.backgroundColor = tileData.color;
    tile.addEventListener('mouseover', handleTileMouseOver);
    if (tileData.color === 'red') {
      tile.style.cursor = 'pointer';
      tile.addEventListener('click', handleTileClick);
    }
    //tile.title = tileData.date;
    healthContainer.appendChild(tile);
  }
}

async function handleHealthViewChange(event) {
  const healthView = document.getElementById('healthView');
  localStorage.setItem("lastHealthView", healthView.value);
  const viewRange = getHealthViewDateRange();
  await retrieveAndPopulateServiceHealth(viewRange.from, viewRange.to, healthView.value);
  updateHealthSyncDate();
}

function handleTileClick(event) {
  $('#dialog').dialog({
    modal: true,
    closeText: null,
    draggable: false,
    position: { my: 'center', at: `center`, of: '#healthContainer' },
    create: function(event, ui) {
      // Hide the default close button
      $(this).siblings('.ui-dialog-titlebar').find('.ui-dialog-titlebar-close').hide();
    },
    open: function( e, ui ) {
      $(this).siblings(".ui-dialog-titlebar").find("button").blur();
      setTimeout(function() {
        document.getElementById('dialogContent').focus();
      }, 100);
    },
    buttons: {
      Close: function() {
        $( this ).dialog( "close" );
      }
    }
  });
}

function handleTileMouseOver(event) {
  const dateFrom = new Date(event.srcElement.getAttribute("date-context"));
  const periodSeconds = event.srcElement.getAttribute("period-context");
  const dateTo = new Date(dateFrom.getTime() + periodSeconds * 1000);
  const dateFromString = formatDateToMMDDYYYYHHmm(dateFrom);
  const dateToString = formatDateToMMDDYYYYHHmm(dateTo);
  const healthEventDate = document.getElementById('healthEventDate');
  healthEventDate.textContent = `${dateFromString} - ${dateToString}`;
}

async function handleHealthSyncDateChanged(event) {
  updateHealthSyncDate();
  const healthView = document.getElementById('healthView');
  const viewRange = getHealthViewDateRange();
  await retrieveAndPopulateServiceHealth(viewRange.from, viewRange.to, healthView.value);
}

function updateHealthSyncDate() {
  const healthDate = document.getElementById('healthDate'); 
  const healthSyncDateWithWindow = document.getElementById("healthSyncDateWithWindow");
  healthDate.disabled = healthSyncDateWithWindow.checked;
  localStorage.setItem("lastHealthSyncDateWithWindow", healthSyncDateWithWindow.checked);
  if (healthSyncDateWithWindow.checked) {
    $("#healthDate").datepicker('setDate', new Date());
  }
  localStorage.setItem("lastHealthDate", healthDate.value);
}

function formatDateToMMDDYYYYHHmm(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  return `${month}/${day}/${year} ${hours}:${minutes}`;
}

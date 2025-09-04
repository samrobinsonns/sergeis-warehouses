const ipad = document.getElementById('ipad');
const closeBtn = document.getElementById('closeBtn');
const ownerStatus = document.getElementById('ownerStatus');
const storageTab = document.getElementById('storageTab');
const warehouseActions = document.getElementById('warehouseActions');
const purchasedSlots = document.getElementById('purchasedSlots');
const maxSlots = document.getElementById('maxSlots');
const slotPrice = document.getElementById('slotPrice');
const buySlotsBtn = document.getElementById('buySlotsBtn');
const storageGrid = document.getElementById('storageGrid');

// Modal elements
const sellModal = document.getElementById('sellModal');
const sellPriceDisplay = document.getElementById('sellPriceDisplay');
const cancelSellBtn = document.getElementById('cancelSell');
const confirmSellBtn = document.getElementById('confirmSell');

// Sharing modal elements
const shareModal = document.getElementById('shareModal');
const editPermission = document.getElementById('editPermission');
const editExpires = document.getElementById('editExpires');
const cancelShareBtn = document.getElementById('cancelShare');
const updateShareBtn = document.getElementById('updateShare');
const revokeShareBtn = document.getElementById('revokeShare');

// Warehouse selection modal elements
const warehouseSelectionModal = document.getElementById('warehouseSelectionModal');
const warehouseOptions = document.getElementById('warehouseOptions');
const cancelWarehouseSelectionBtn = document.getElementById('cancelWarehouseSelection');

// Sharing form elements
const playerResults = document.getElementById('playerResults');
const shareBtn = document.getElementById('shareBtn');
const sharePermission = document.getElementById('sharePermission');
const shareExpires = document.getElementById('shareExpires');

// Player selection state
let selectedPlayer = null;
let nearbyPlayers = [];

// Sharing lists
const sharedUsersList = document.getElementById('sharedUsersList');
const sharedWarehousesList = document.getElementById('sharedWarehousesList');

// Sharing tabs
const sharingTab = document.getElementById('sharingTab');
const sharedTab = document.getElementById('sharedTab');

const isNui = typeof GetParentResourceName === 'function';
let warehouseInfo = null;
let isClosing = false; // Flag to prevent multiple close operations
let currentEditingShare = null; // Track which share is being edited

// Notification system
const notificationContainer = document.getElementById('notificationContainer');

// Utility function to safely format dates for datetime-local input
function formatDateForInput(dateValue) {
  if (!dateValue) return '';
  
  try {
    let date;
    
    // Handle different input types
    if (typeof dateValue === 'number') {
      // Timestamp (milliseconds)
      date = new Date(dateValue);
    } else if (typeof dateValue === 'string') {
      // Date string
      date = new Date(dateValue);
    } else if (dateValue instanceof Date) {
      // Already a Date object
      date = dateValue;
    } else {
      console.warn('Unknown date format:', dateValue, typeof dateValue);
      return '';
    }
    
    // Check if date is valid
    if (isNaN(date.getTime())) {
      console.warn('Invalid date value:', dateValue);
      return '';
    }
    
    // Format for datetime-local input (YYYY-MM-DDTHH:MM)
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  } catch (error) {
    console.error('Error formatting date:', error, 'dateValue:', dateValue);
    return '';
  }
}

// Ensure all event listeners are properly set up
function setupEventListeners() {
  // Verify all button elements exist
  if (!shareModal) console.error('shareModal not found!');
  
  // Verify form elements exist
  if (!editPermission) console.error('editPermission not found!');
  if (!editExpires) console.error('editExpires not found!');
}

// Set up warehouse selection modal event listeners
function setupWarehouseSelectionModalEvents() {
  // Get the cancel button element
  const cancelBtn = document.getElementById('cancelWarehouseSelection');
  
  if (cancelBtn) {
    // Remove any existing event listeners
    const newCancelBtn = cancelBtn.cloneNode(true);
    cancelBtn.parentNode.replaceChild(newCancelBtn, cancelBtn);
    
    // Add the event listener to the new button
    newCancelBtn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      closeWarehouseSelectionModal();
    });
  } else {
    console.error('cancelWarehouseSelection button not found in setupWarehouseSelectionModalEvents');
  }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', function() {
  setupEventListeners();
  
  // Ensure warehouse selection modal cancel button is set up
  setupWarehouseSelectionModalEvents();
});

// Also try to set up on window load as backup
window.addEventListener('load', function() {
  setupEventListeners();
});

// Tab switching
document.querySelectorAll('.nav-item').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.nav-item').forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
    const tab = btn.dataset.tab;
    document.querySelectorAll('.tab-pane').forEach((pane) => pane.classList.remove('active'));
    document.getElementById(`tab-${tab}`).classList.add('active');
    
    // Refresh shared warehouses when shared tab is clicked
    if (tab === 'shared') {
      fetch(`https://${GetParentResourceName()}/getSharedWarehouses`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
      });
    }
    
    // Load nearby players when sharing tab is clicked
    if (tab === 'sharing') {
      loadNearbyPlayers();
    }
  });
});

function showUI(show) {
  if (show) {
    // Reset closing state when opening
    isClosing = false;
    
    // Ensure UI is fully hidden before showing
    ipad.style.display = 'none';
    
    // Small delay to ensure proper state
    setTimeout(() => {
      ipad.style.display = 'block';
    }, 50);
  } else {
    ipad.style.display = 'none';
  }
}

function formatMoney(n) { 
  return `$${(n || 0).toLocaleString()}`; 
}

// Notification system functions
function showNotification(message, type = 'info', duration = 5000) {
  const notification = document.createElement('div');
  notification.className = `notification ${type}`;
  
  const iconClass = {
    success: 'fas fa-check-circle',
    error: 'fas fa-exclamation-circle',
    warning: 'fas fa-exclamation-triangle',
    info: 'fas fa-info-circle'
  }[type] || 'fas fa-info-circle';
  
  notification.innerHTML = `
    <i class="notification-icon ${iconClass}"></i>
    <span class="notification-message">${message}</span>
    <button class="notification-close" onclick="this.parentElement.remove()">×</button>
  `;
  
  notificationContainer.appendChild(notification);
  
  // Trigger animation
  setTimeout(() => {
    notification.classList.add('show');
  }, 100);
  
  // Auto-remove after duration
  if (duration > 0) {
    setTimeout(() => {
      if (notification.parentElement) {
        notification.classList.remove('show');
        setTimeout(() => {
          if (notification.parentElement) {
            notification.remove();
          }
        }, 300);
      }
    }, duration);
  }
  
  return notification;
}

function showSuccessNotification(message) {
  return showNotification(message, 'success');
}

function showErrorNotification(message) {
  return showNotification(message, 'error');
}

function showWarningNotification(message) {
  return showNotification(message, 'warning');
}

function showInfoNotification(message) {
  return showNotification(message, 'info');
}

function updateWarehouseInfo(info) {
  warehouseInfo = info;
  
  // Debug: Log the received slot prices
  //console.log('Warehouse info received:', info);
  //if (info.slot_prices) {
    //console.log('Individual slot prices:');
    //for (let slot in info.slot_prices) {
      //console.log(`  Slot ${slot}: $${info.slot_prices[slot]}`);
   // }
 // }
  
  ownerStatus.textContent = info.owned ? 'Owned' : 'Not Owned';
  
  if (info.owned) {
    storageTab.style.display = 'block';
    sharingTab.style.display = 'block';
    sharedTab.style.display = 'block'; // Show shared access tab for owners too
    purchasedSlots.textContent = info.purchased_slots;
    maxSlots.textContent = info.max_slots;
    
    // Show next available slot price or "All slots purchased"
    const nextSlotNumber = info.purchased_slots + 1;
    if (nextSlotNumber <= info.max_slots) {
      // Note: Server sends 1-based slot numbers, but JS arrays are 0-based
      const nextSlotPriceKey = nextSlotNumber - 1;
      if (info.slot_prices && info.slot_prices[nextSlotPriceKey]) {
        slotPrice.textContent = formatMoney(info.slot_prices[nextSlotPriceKey]);
      } else {
        slotPrice.textContent = formatMoney(info.slot_price);
      }
    } else {
      slotPrice.textContent = 'All slots purchased';
    }
    
    // Update warehouse actions with sell price
    warehouseActions.innerHTML = `
      <div class="warehouse-sell-info">
        <p class="sell-price-info">Sell Price: <span class="sell-price">${formatMoney(info.sell_price)}</span></p>
        <button class="btn btn-danger" onclick="showSellConfirmation()">Sell Warehouse</button>
      </div>
    `;
    
    // Update shared users list
    if (info.shared_users) {
      updateSharedUsersList(info.shared_users);
    }
    
    // Also show shared warehouses if available (owners can access other warehouses too)
    if (info.shared_warehouses && info.shared_warehouses.length > 0) {
      updateSharedWarehousesList(info.shared_warehouses);
    } else {
      // If no shared warehouses, show empty state
      sharedWarehousesList.innerHTML = '<p>No warehouses shared with you.</p>';
    }
  } else {
    storageTab.style.display = 'none';
    sharingTab.style.display = 'none';
    sharedTab.style.display = 'block';
    
    // Show shared warehouses if available
    if (info.shared_warehouses && info.shared_warehouses.length > 0) {
      updateSharedWarehousesList(info.shared_warehouses);
    } else {
      sharedWarehousesList.innerHTML = '<p>No warehouses shared with you.</p>';
    }
    
    warehouseActions.innerHTML = `
      <button class="btn btn-success" onclick="buyWarehouse()">Buy Warehouse</button>
    `;
  }
}

function renderStorageGrid() {
  if (!warehouseInfo) return;
  

  
  storageGrid.innerHTML = '';
  const maxSlots = 6; // Fixed to 6 slots
  const purchasedSlots = warehouseInfo.purchased_slots || 0;
  
  for (let i = 0; i < maxSlots; i++) {
    const slotElement = document.createElement('div');
    slotElement.className = 'storage-slot';
    
    const slotNumber = i + 1;
    const isOwned = slotNumber <= purchasedSlots;
    const slotStatus = isOwned ? 'Owned' : 'Available';
    const slotClass = isOwned ? 'owned' : 'available';
    
    // Get individual slot price or fallback to default
    // Note: Server sends 1-based slot numbers, but JS arrays are 0-based, so we need slotNumber-1
    const slotPriceKey = slotNumber - 1;
    const slotPrice = warehouseInfo.slot_prices && warehouseInfo.slot_prices[slotPriceKey] 
      ? warehouseInfo.slot_prices[slotPriceKey] 
      : warehouseInfo.slot_price;
    

    
    // Check if this slot can be purchased (must be the next available slot)
    const canPurchase = !isOwned && slotNumber === purchasedSlots + 1;
    
    slotElement.innerHTML = `
      <div class="slot-header ${slotClass}">
        <span class="slot-number">Slot ${slotNumber}</span>
        <span class="slot-status">${slotStatus}</span>
      </div>
      <div class="slot-content">
        ${isOwned ? 
          '<span class="slot-info">Storage Available</span>' : 
          canPurchase ?
          `<div class="slot-purchase-info">
            <span class="slot-price">$${slotPrice.toLocaleString()}</span>
            <button class="btn btn-sm btn-primary buy-slot-btn" onclick="buySingleSlot(${slotNumber})">Buy Slot</button>
           </div>` :
          '<span class="slot-info">Purchase previous slots first</span>'
        }
      </div>
    `;
    
    slotElement.classList.add(slotClass);
    storageGrid.appendChild(slotElement);
  }
}

function buySingleSlot(slotNumber) {
  if (isNui) {
    fetch(`https://${GetParentResourceName()}/buySpecificSlot`, { 
      method: 'POST', 
      body: JSON.stringify({ slotNumber: slotNumber }) 
    });
  } else {
    console.log(`Dev mode: Buy slot ${slotNumber}`);
  }
}

function buyStorageSlots() {
  const slotCount = prompt('How many storage slots would you like to buy? (1-6)', '1');
  const count = parseInt(slotCount);
  
  if (count && count > 0 && count <= 6) {
    if (isNui) {
      fetch(`https://${GetParentResourceName()}/buyStorageSlots`, { 
        method: 'POST', 
        body: JSON.stringify({ slotCount: count }) 
      });
    } else {
      console.log(`Dev mode: Buy ${count} storage slots`);
    }
  }
}

function buyWarehouse() {
  if (isNui) {
    fetch(`https://${GetParentResourceName()}/buyWarehouse`, { method: 'POST' });
  } else {
    console.log('Dev mode: Buy warehouse');
  }
}

function sellWarehouse() {
  if (isNui) {
    fetch(`https://${GetParentResourceName()}/sellWarehouse`, { method: 'POST' });
  } else {
    console.log('Dev mode: Sell warehouse');
  }
}

// Show sell confirmation modal
function showSellConfirmation() {
  if (warehouseInfo && warehouseInfo.sell_price) {
    sellPriceDisplay.textContent = formatMoney(warehouseInfo.sell_price);
    sellModal.style.display = 'flex';
  }
}

// Hide sell confirmation modal
function hideSellConfirmation() {
  sellModal.style.display = 'none';
}

// Confirm warehouse sale
function confirmWarehouseSale() {
  hideSellConfirmation();
  sellWarehouse();
}

// Direct close function
function closeUI() {
  if (isClosing) {
    return;
  }
  
  isClosing = true;
  
  showUI(false);
  
  // Send NUI callback to remove focus
  if (isNui) {
    fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
    
    // Fallback: Force close after 500ms if callback doesn't work
    setTimeout(() => {
      if (isClosing) {
        isClosing = false;
        // Try to send another close callback
        fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
      }
    }, 500);
  }
  
  // Reset flag after a short delay
  setTimeout(() => {
    isClosing = false;
  }, 100);
}

// Event listeners
closeBtn.addEventListener('click', () => {
  closeUI();
});

// Modal event listeners
cancelSellBtn.addEventListener('click', hideSellConfirmation);
confirmSellBtn.addEventListener('click', confirmWarehouseSale);

// ESC to close
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    console.log('Escape key pressed - checking modals...');
    
    // Check for sell modal first
    if (sellModal.style.display === 'flex') {
      console.log('Closing sell modal with escape key');
      hideSellConfirmation();
      return;
    }
    
    // Check for warehouse selection modal
    if (warehouseSelectionModal && warehouseSelectionModal.style.display === 'flex') {
      console.log('Closing warehouse selection modal with escape key');
      closeWarehouseSelectionModal();
      return;
    }
    
    // Check for share modal
    if (shareModal && (shareModal.classList.contains('show') || shareModal.style.display === 'flex')) {
      console.log('Closing share modal with escape key');
      hideShareModal();
      currentEditingShare = null;
      
      // Clear any existing notifications when closing modal
      const notifications = document.querySelectorAll('.notification');
      notifications.forEach(notification => notification.remove());
      return;
    }
    
    // If no modals are open, close the main UI
    console.log('No modals open, closing main UI with escape key');
    closeUI();
  }
});

// NUI message handler
window.addEventListener('message', function(event) {
  const data = event.data;
  
  switch (data.action) {
    case 'showUI':
      showUI(data.show);
      break;
      
    case 'showWarehouseSelection':
      showWarehouseSelectionModal();
      break;
      
    case 'updateWarehouseInfo':
      updateWarehouseInfo(data.data);
      renderStorageGrid();
      break;
      
    case 'updatePlayerResults':
      updatePlayerResults(data.players);
      break;
      
    case 'updateSharedWarehouses':
      updateSharedWarehousesList(data.data);
      // Update the warehouseInfo with shared warehouses data
      if (warehouseInfo && data.data) {
        warehouseInfo.shared_warehouses = data.data;
      }
      // If warehouse selection modal is open, refresh the options
      if (warehouseSelectionModal.style.display === 'flex') {
        populateWarehouseOptions();
      }
      break;
      
    case 'refreshStorage':
      renderStorageGrid();
      break;
      
    case 'closeUI':
      closeUI();
      break;
      
    case 'forceClose':
      isClosing = false; // Reset closing state
      showUI(false);
      break;
      
    case 'refreshSharing':
      // Refresh sharing information
      fetch(`https://${GetParentResourceName()}/getSharedWarehouses`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
      });
      break;
  }
});

// Dev mode helpers
if (!isNui) {
  // Simulate warehouse info for development
  setTimeout(() => {
    updateWarehouseInfo({
      owned: false,
      purchased_slots: 0,
      max_slots: 50,
      slot_price: 5000,
      warehouse_price: 150000
    });
  }, 1000);
}



// ========================================
// WAREHOUSE SHARING SYSTEM FUNCTIONS
// ========================================

// Load nearby players automatically
function loadNearbyPlayers() {
  // Check if GetParentResourceName is available
  if (typeof GetParentResourceName !== 'function') {
    console.error('GetParentResourceName is not available! This function only works in FiveM NUI context.');
    showErrorNotification('Nearby players search only works in FiveM game context');
    return;
  }
  
  const resourceName = GetParentResourceName();
  
  if (!resourceName) {
    console.error('GetParentResourceName returned empty/null value');
    showErrorNotification('Failed to get resource name for nearby players search');
    return;
  }
  
  showInfoNotification('Loading nearby players...');
  
  // Request nearby players from server
  const url = `https://${resourceName}/loadNearbyPlayers`;
  
  fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({})
  }).then(response => {
    if (response.ok) {
      showSuccessNotification('Nearby players loaded');
    } else {
      showErrorNotification('Failed to load nearby players. Please try again.');
      console.error('Failed to load nearby players - response not ok');
    }
  }).catch(error => {
    console.error('Error loading nearby players:', error);
    console.error('Error details:', error.message, error.stack);
    showErrorNotification('Error loading nearby players. Please try again.');
  });
}

// Select a player from results
function selectPlayer(player) {
  selectedPlayer = player;
  
  // Update UI to show selected player
  playerResults.innerHTML = `
    <div class="player-result-item selected" data-citizenid="${player.citizenid}">
      <div class="player-info">
        <div class="player-name">${player.firstname} ${player.lastname}</div>
        <div class="player-id">${player.citizenid}</div>
      </div>
      <div class="player-distance">${player.distance}m</div>
      <div class="player-selected-indicator">
        <i class="fas fa-check-circle"></i> Selected
      </div>
    </div>
  `;
  
  // Enable share button
  shareBtn.disabled = false;
  
  showSuccessNotification(`Selected player: ${player.firstname} ${player.lastname}`);
}

// Update player results
function updatePlayerResults(players) {
  // Check if playerResults element exists
  if (!playerResults) {
    console.error('playerResults element not found!');
    return;
  }
  
  nearbyPlayers = players;
  
  if (!players || players.length === 0) {
    playerResults.innerHTML = '<div class="player-result-item"><p>No players nearby (within 50 meters)</p></div>';
    playerResults.style.display = 'block';
    return;
  }
  
  const resultsHtml = players.map(player => `
    <div class="player-result-item" data-citizenid="${player.citizenid}" onclick="selectPlayer(${JSON.stringify(player).replace(/"/g, '&quot;')})">
      <div class="player-info">
        <div class="player-name">${player.firstname} ${player.lastname}</div>
        <div class="player-id">${player.citizenid}</div>
      </div>
      <div class="player-distance">${player.distance}m</div>
    </div>
  `).join('');
  
  // Set the HTML content
  playerResults.innerHTML = resultsHtml;
  
  // Make sure it's visible
  playerResults.style.display = 'block';
  playerResults.style.visibility = 'visible';
  playerResults.style.opacity = '1';
  
  // Force a reflow to ensure the changes take effect
  playerResults.offsetHeight;
}

// Share warehouse with player
function shareWarehouse() {
  if (!selectedPlayer) {
    showErrorNotification('Please select a player first');
    return;
  }
  
  const permission = sharePermission.value;
  const expires = shareExpires.value || null;
  
  // Validation
  if (!permission || !['read', 'write', 'admin'].includes(permission)) {
    showErrorNotification('Please select a valid permission level');
    return;
  }
  
  // Validate expiration date if provided
  if (expires) {
    const expiryDate = new Date(expires);
    const now = new Date();
    if (expiryDate <= now) {
      showErrorNotification('Expiration date must be in the future');
      return;
    }
  }
  
  // Show loading notification
  showInfoNotification('Sending sharing request...');
  
  // Send to client
  fetch(`https://${GetParentResourceName()}/shareWarehouse`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      targetCitizenId: selectedPlayer.citizenid,
      permissionLevel: permission,
      expiresAt: expires
    })
  }).then(response => {
    if (response.ok) {
      showSuccessNotification('Warehouse sharing request sent successfully');
      // Clear form
      clearSharingForm();
    } else {
      showErrorNotification('Failed to send sharing request. Please try again.');
    }
  }).catch(error => {
    console.error('Error sharing warehouse:', error);
    showErrorNotification('Error sending sharing request. Please try again.');
  });
}

// Clear sharing form
function clearSharingForm() {
  playerResults.style.display = 'none';
  shareExpires.value = '';
  sharePermission.value = 'write'; // Default to write permission
  shareBtn.disabled = true;
  selectedPlayer = null;
}

// Show warehouse selection modal
function showWarehouseSelectionModal() {
  if (!warehouseInfo) {
    showErrorNotification('No warehouse information available');
    return;
  }
  
      // Always request fresh shared warehouses data when showing the modal
    fetch(`https://${GetParentResourceName()}/getSharedWarehouses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({})
    }).then(response => {
      if (response.ok) {
        // Wait a moment for the data to be received, then populate
              setTimeout(() => {
          populateWarehouseOptions();
          showWarehouseSelectionModalUI();
        }, 200);
      } else {
        console.error('Failed to request shared warehouses');
        // Show modal anyway with what we have
        populateWarehouseOptions();
        showWarehouseSelectionModalUI();
      }
    }).catch(error => {
      console.error('Error requesting shared warehouses:', error);
      // Show modal anyway with what we have
      populateWarehouseOptions();
      showWarehouseSelectionModalUI();
    });
}

// Function to show the warehouse selection modal UI
function showWarehouseSelectionModalUI() {
  // Reset modal state
  warehouseSelectionModal.style.cssText = '';
  warehouseSelectionModal.className = 'modal-overlay';
  
  // Show the modal
  warehouseSelectionModal.style.display = 'flex';
  warehouseSelectionModal.style.visibility = 'visible';
  warehouseSelectionModal.style.opacity = '1';
  warehouseSelectionModal.style.position = 'fixed';
  warehouseSelectionModal.style.top = '0';
  warehouseSelectionModal.style.left = '0';
  warehouseSelectionModal.style.width = '100%';
  warehouseSelectionModal.style.height = '100%';
  warehouseSelectionModal.style.zIndex = '9999';
  warehouseSelectionModal.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
  
  // Add show class
  warehouseSelectionModal.classList.add('show');
  
  // Ensure cancel button is properly set up
  setupWarehouseSelectionModalEvents();
}



// Force close warehouse selection modal (emergency function)
function forceCloseWarehouseSelectionModal() {
  if (warehouseSelectionModal) {
    // Force hide with all possible methods
    warehouseSelectionModal.style.display = 'none';
    warehouseSelectionModal.style.visibility = 'hidden';
    warehouseSelectionModal.style.opacity = '0';
    warehouseSelectionModal.style.zIndex = '-1';
    
    // Remove all classes
    warehouseSelectionModal.className = '';
    
    // Remove NUI focus
    if (typeof SetNuiFocus === 'function') {
      SetNuiFocus(false, false);
    }
    
    // Send close callback
    if (typeof GetParentResourceName === 'function') {
      fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
    }
  }
}



// Populate warehouse options
function populateWarehouseOptions() {
  let optionsHtml = '';
  
  // Add owned warehouse option if player owns one
  if (warehouseInfo.owned) {
    optionsHtml += `
      <div class="warehouse-option owned" onclick="enterOwnedWarehouse()">
        <div class="warehouse-option-info">
          <div class="warehouse-option-title">
            <i class="fas fa-home"></i>
            My Warehouse
          </div>
          <div class="warehouse-option-details">
            <span>Storage Slots: ${warehouseInfo.purchased_slots}/${warehouseInfo.max_slots}</span>
            <span>Status: Owner</span>
          </div>
          <div class="warehouse-option-meta">
            <span>Full Access</span>
            <span>Manage Storage & Sharing</span>
          </div>
        </div>
        <div class="warehouse-option-icon">
          <i class="fas fa-crown"></i>
        </div>
        <div class="warehouse-option-arrow">
          <i class="fas fa-chevron-right"></i>
        </div>
      </div>
    `;
  }
  
  // Add shared warehouse options if any exist
  if (warehouseInfo.shared_warehouses && warehouseInfo.shared_warehouses.length > 0) {
    warehouseInfo.shared_warehouses.forEach(warehouse => {
      const expiresText = warehouse.expires_at ? 
        `Expires: ${new Date(warehouse.expires_at).toLocaleDateString()}` : 
        'Never expires';
      
      optionsHtml += `
        <div class="warehouse-option shared" onclick="enterSharedWarehouse(${warehouse.id})">
          <div class="warehouse-option-info">
            <div class="warehouse-option-title">
              <i class="fas fa-share-alt"></i>
              ${warehouse.owner_firstname} ${warehouse.owner_lastname}'s Warehouse
            </div>
            <div class="warehouse-option-details">
              <span>Storage Slots: ${warehouse.purchased_slots}</span>
              <span>Access Level: ${warehouse.permission_level}</span>
            </div>
            <div class="warehouse-option-meta">
              <span>${expiresText}</span>
              <span>Shared since: ${new Date(warehouse.shared_at).toLocaleDateString()}</span>
            </div>
          </div>
          <div class="warehouse-option-icon">
            <i class="fas fa-key"></i>
          </div>
          <div class="warehouse-option-arrow">
            <i class="fas fa-chevron-right"></i>
          </div>
        </div>
      `;
    });
  }
  
  // If no warehouses available, show message
  if (!warehouseInfo.owned && (!warehouseInfo.shared_warehouses || warehouseInfo.shared_warehouses.length === 0)) {
    optionsHtml = `
      <div class="warehouse-option" style="cursor: default; opacity: 0.7;">
        <div class="warehouse-option-info">
          <div class="warehouse-option-title">
            <i class="fas fa-info-circle"></i>
            No Warehouses Available
          </div>
          <div class="warehouse-option-details">
            <span>You don't own a warehouse and have no shared access</span>
          </div>
        </div>
        <div class="warehouse-option-icon">
          <i class="fas fa-exclamation-triangle"></i>
        </div>
      </div>
    `;
  }
  
  warehouseOptions.innerHTML = optionsHtml;
}

// Enter owned warehouse
function enterOwnedWarehouse() {
  closeWarehouseSelectionModal();
  
  // Trigger client to enter owned warehouse
  fetch(`https://${GetParentResourceName()}/enterOwnedWarehouse`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({})
  }).then(response => {
    if (response.ok) {
      showSuccessNotification('Entering your warehouse...');
    } else {
      showErrorNotification('Failed to enter warehouse. Please try again.');
    }
  }).catch(error => {
    console.error('Error entering warehouse:', error);
    showErrorNotification('Error entering warehouse. Please try again.');
  });
}











// Function to check if modal is actually visible
function isModalVisible(modal) {
  if (!modal) return false;
  
  const computedStyle = window.getComputedStyle(modal);
  const isDisplayed = computedStyle.display !== 'none';
  const isVisible = computedStyle.visibility !== 'hidden';
  const hasOpacity = parseFloat(computedStyle.opacity) > 0;
  const hasOffsetParent = modal.offsetParent !== null;
  
  return isDisplayed && isVisible && hasOpacity && hasOffsetParent;
}

// Function to force the share modal to be visible
function forceShowShareModal() {
  if (shareModal) {
    // Remove any hidden classes
    shareModal.classList.remove('hidden');
    
    // Force all the necessary styles
    shareModal.style.display = 'flex';
    shareModal.style.visibility = 'visible';
    shareModal.style.opacity = '1';
    shareModal.style.position = 'fixed';
    shareModal.style.top = '0';
    shareModal.style.left = '0';
    shareModal.style.width = '100%';
    shareModal.style.height = '100%';
    shareModal.style.zIndex = '9999';
    
    // Add the show class
    shareModal.classList.add('show');
  }
}

// Function to show the share modal
function showShareModal() {
  if (shareModal) {
    // Remove any hidden classes
    shareModal.classList.remove('hidden');
    
    // Set all necessary styles directly
    shareModal.style.display = 'flex';
    shareModal.style.visibility = 'visible';
    shareModal.style.opacity = '1';
    shareModal.style.position = 'fixed';
    shareModal.style.top = '0';
    shareModal.style.left = '0';
    shareModal.style.width = '100%';
    shareModal.style.height = '100%';
    shareModal.style.zIndex = '9999';
    shareModal.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
    
    // Add the show class
    shareModal.classList.add('show');
  }
}

// Function to hide the share modal
function hideShareModal() {
  if (shareModal) {
    // Remove the show class
    shareModal.classList.remove('show');
    
    // Set all styles to hide
    shareModal.style.display = 'none';
    shareModal.style.visibility = 'hidden';
    shareModal.style.opacity = '0';
  }
}

// Function to close the share modal
function closeShareModal() {
  if (shareModal) {
    // Use the hide function for consistency
    hideShareModal();
    
    // Reset the editing state
    currentEditingShare = null;
    
    // Clear form fields
    if (editPermission) editPermission.value = 'write'; // Default to write permission
    if (editExpires) editExpires.value = '';
    
    // Also try removing the modal from the DOM flow
    shareModal.classList.add('hidden');
  } else {
    console.error('shareModal element not found!');
  }
}

// Enter shared warehouse (updated to work with selection modal)
function enterSharedWarehouse(warehouseId) {
  closeWarehouseSelectionModal();
  
  if (!warehouseId) {
    showErrorNotification('Invalid warehouse ID');
    return;
  }
  
  // Show loading notification
  showInfoNotification('Accessing shared warehouse...');
  
  // This would trigger the client to enter the shared warehouse
  fetch(`https://${GetParentResourceName()}/accessSharedWarehouse`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      warehouseId: warehouseId
    })
  }).then(response => {
    if (response.ok) {
      showSuccessNotification('Entering shared warehouse...');
    } else {
      showErrorNotification('Failed to access warehouse. Please try again.');
    }
  }).catch(error => {
    console.error('Error accessing warehouse:', error);
    showErrorNotification('Error accessing warehouse. Please try again.');
  });
}

// Show share management modal
function showShareManagement(shareData) {
  console.log('=== showShareManagement FUNCTION CALLED ===');
  console.log('Function received shareData:', shareData);
  console.log('Type of shareData:', typeof shareData);
  
  try {
    // Parse the data if it's a string
    if (typeof shareData === 'string') {
      console.log('Parsing string data...');
      shareData = JSON.parse(shareData);
      console.log('Successfully parsed string data');
    }
    
    console.log('Final parsed shareData:', shareData);
    console.log('shareData.permission_level:', shareData.permission_level);
    console.log('shareData.expires_at:', shareData.expires_at);
    console.log('shareData.expires_at type:', typeof shareData.expires_at);
    
    // Ensure we have the required data
    if (!shareData || !shareData.shared_with_citizenid) {
      console.error('Invalid shareData - missing required fields:', shareData);
      showErrorNotification('Invalid sharing data received');
      return;
    }
    
    currentEditingShare = shareData;
    console.log('Set currentEditingShare to:', currentEditingShare);
    
    // Verify button elements exist
    console.log('Button elements check:');
    console.log('- cancelShareBtn:', cancelShareBtn);
    console.log('- updateShareBtn:', updateShareBtn);
    console.log('- revokeShareBtn:', revokeShareBtn);
    
    // Populate form with current values
    console.log('Form elements check:');
    console.log('- editPermission element:', editPermission);
    console.log('- editExpires element:', editExpires);
    
    if (editPermission && shareData.permission_level) {
      editPermission.value = shareData.permission_level;
      console.log('Successfully set permission to:', shareData.permission_level);
    } else {
      console.log('Could not set permission - editPermission:', editPermission, 'permission_level:', shareData.permission_level);
    }
    
    if (editExpires && shareData.expires_at) {
      // Use the utility function to safely format the date
      const formattedDate = formatDateForInput(shareData.expires_at);
      editExpires.value = formattedDate;
      
      if (formattedDate) {
        console.log('Successfully set expires to:', formattedDate);
      } else {
        console.log('Could not format expires_at value, clearing field');
        editExpires.value = '';
      }
    } else if (editExpires) {
      editExpires.value = '';
      console.log('Cleared expires field');
    } else {
      console.log('Could not set expires - editExpires:', editExpires, 'expires_at:', shareData.expires_at);
    }
    
    console.log('About to show modal...');
    console.log('shareModal element:', shareModal);
    console.log('shareModal.style.display before:', shareModal.style.display);
    
    // Reset modal state before showing
    shareModal.style.cssText = '';
    shareModal.className = 'modal-overlay';
    
    // Show modal using the dedicated function
    showShareModal();
    console.log('Modal show function called');
    
    // Force modal to be visible and check if it's working
    setTimeout(() => {
      console.log('Modal display after timeout:', shareModal.style.display);
      console.log('Modal visibility:', shareModal.style.visibility);
      console.log('Modal opacity:', shareModal.style.opacity);
      console.log('Modal z-index:', shareModal.style.zIndex);
      console.log('Modal computed style display:', window.getComputedStyle(shareModal).display);
      console.log('Modal classes:', shareModal.className);
      
      // If modal still not visible, try forcing it
      if (!shareModal.classList.contains('show')) {
        console.log('Forcing modal to be visible');
        showShareModal();
        shareModal.style.visibility = 'visible';
        shareModal.style.opacity = '1';
        shareModal.style.zIndex = '1000';
      }
      
      console.log('Final modal state - display:', shareModal.style.display, 'computed:', window.getComputedStyle(shareModal).display);
      
      // Verify the modal is actually visible
      if (shareModal.offsetParent !== null) {
        console.log('Modal is visible in DOM');
      } else {
        console.error('Modal is NOT visible in DOM despite display:flex');
        // Try one more time with force
        console.log('Attempting to force modal visibility...');
        forceShowShareModal();
        
        // Check again after forcing
        setTimeout(() => {
          if (shareModal.offsetParent !== null) {
            console.log('Modal is now visible after force');
          } else {
            console.error('Modal still not visible after force - this is a serious issue');
          }
        }, 100);
      }
    }, 100);
    
  } catch (error) {
    console.error('Error in showShareManagement:', error);
    console.error('Error stack:', error.stack);
    showErrorNotification('Error opening edit modal');
  }
}

// Update shared users list
function updateSharedUsersList(sharedUsers) {
  if (!sharedUsers || sharedUsers.length === 0) {
    sharedUsersList.innerHTML = '<p>No users currently have access to your warehouse.</p>';
    return;
  }
  
  const usersHtml = sharedUsers.map(user => {
    const expiresText = user.expires_at ? 
      `Expires: ${new Date(user.expires_at).toLocaleDateString()}` : 
      'Never expires';
    
    return `
      <div class="shared-user-item">
        <div class="shared-user-info">
          <div class="shared-user-name">${user.player_firstname || 'Unknown'} ${user.player_lastname || 'Player'}</div>
          <div class="shared-user-details">
            Permission: ${user.permission_level} | ${expiresText}
          </div>
        </div>
        <div class="shared-user-actions">
          <button class="btn btn-danger btn-sm revoke-access-btn" data-user='${JSON.stringify(user).replace(/'/g, "&apos;")}'>
            Revoke Access
          </button>
        </div>
      </div>
    `;
  }).join('');
  
  sharedUsersList.innerHTML = usersHtml;
  
  // Add event listeners to revoke access buttons
  const revokeButtons = sharedUsersList.querySelectorAll('.revoke-access-btn');
  revokeButtons.forEach(button => {
    button.addEventListener('click', function() {
      const userData = this.getAttribute('data-user');
      
      try {
        const user = JSON.parse(userData);
        
        // Show confirmation dialog for revoking access
        showConfirmDialog(
          `Are you sure you want to revoke access for ${user.player_firstname || 'Unknown'} ${user.player_lastname || 'Player'}?`,
          () => {
            // User confirmed - proceed with revoke
            
            // Show loading notification
            showInfoNotification('Revoking access...');
            
            // Send revoke to client
            fetch(`https://${GetParentResourceName()}/revokeWarehouseSharing`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                targetCitizenId: user.shared_with_citizenid
              })
            }).then(response => {
              if (response.ok) {
                showSuccessNotification('Access revoked successfully');
                
                // Force a UI refresh
                fetch(`https://${GetParentResourceName()}/getWarehouseInfo`, {
                  method: 'POST',
                  headers: {
                    'Content-Type': 'application/json',
                  },
                  body: JSON.stringify({})
                });
              } else {
                showErrorNotification('Failed to revoke access. Please try again.');
              }
            }).catch(error => {
              console.error('Error revoking access:', error);
              showErrorNotification('Error revoking access. Please try again.');
            });
          }
        );
      } catch (error) {
        console.error('Error parsing user data:', error);
        showErrorNotification('Error revoking access');
      }
    });
  });
}

// Update shared warehouses list
function updateSharedWarehousesList(sharedWarehouses) {
  if (!sharedWarehouses || sharedWarehouses.length === 0) {
    sharedWarehousesList.innerHTML = '<p>No warehouses shared with you.</p>';
    return;
  }
  
  const warehousesHtml = sharedWarehouses.map(warehouse => {
    const expiresText = warehouse.expires_at ? 
      `Expires: ${new Date(warehouse.expires_at).toLocaleDateString()}` : 
      'Never expires';
    
    return `
      <div class="shared-warehouse-item">
        <div class="shared-warehouse-header">
          <div class="shared-warehouse-owner">${warehouse.owner_firstname || 'Unknown'} ${warehouse.owner_lastname || 'Player'}'s Warehouse</div>
          <div class="shared-warehouse-permission permission-${warehouse.permission_level}">
            ${warehouse.permission_level.toUpperCase()}
          </div>
        </div>
        <div class="shared-warehouse-details">
          <div class="shared-warehouse-stat">
            <div class="shared-warehouse-stat-label">Storage Slots</div>
            <div class="shared-warehouse-stat-value">${warehouse.purchased_slots}</div>
          </div>
          <div class="shared-warehouse-stat">
            <div class="shared-warehouse-stat-label">Access Level</div>
            <div class="shared-warehouse-stat-value">${warehouse.permission_level}</div>
          </div>
          <div class="shared-warehouse-stat">
            <div class="shared-warehouse-stat-label">Shared Since</div>
            <div class="shared-warehouse-stat-value">${new Date(warehouse.shared_at).toLocaleDateString()}</div>
          </div>
        </div>

      </div>
    `;
  }).join('');
  
  sharedWarehousesList.innerHTML = warehousesHtml;
}

// Access shared warehouse
function accessSharedWarehouse(warehouseId) {
  if (!warehouseId) {
    showErrorNotification('Invalid warehouse ID');
    return;
  }
  
  // Show loading notification
  showInfoNotification('Accessing shared warehouse...');
  
  // This would trigger the client to enter the shared warehouse
  fetch(`https://${GetParentResourceName()}/accessSharedWarehouse`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      warehouseId: warehouseId
    })
  }).then(response => {
    if (response.ok) {
      showSuccessNotification('Entering shared warehouse...');
    } else {
      showErrorNotification('Failed to access warehouse. Please try again.');
    }
  }).catch(error => {
    console.error('Error accessing warehouse:', error);
    showErrorNotification('Error accessing warehouse. Please try again.');
  });
}

// Event listeners for sharing modal
cancelShareBtn.addEventListener('click', () => {
  console.log('=== CANCEL BUTTON CLICKED ===');
  console.log('Button element:', cancelShareBtn);
  console.log('Modal state before closing:', isModalVisible(shareModal));
  
  // Close the modal
  hideShareModal();
  
  // Reset the editing state
  currentEditingShare = null;
  
  // Clear any existing notifications when closing modal
  const notifications = document.querySelectorAll('.notification');
  notifications.forEach(notification => notification.remove());
  
  console.log('Modal state after closing:', isModalVisible(shareModal));
  console.log('Modal closed and currentEditingShare reset');
});

// Event listeners for warehouse selection modal
if (cancelWarehouseSelectionBtn) {
  console.log('Setting up cancel button event listener for warehouse selection modal');
  
  // Remove any existing event listeners first
  cancelWarehouseSelectionBtn.removeEventListener('click', closeWarehouseSelectionModal);
  
  // Add the event listener
  cancelWarehouseSelectionBtn.addEventListener('click', (e) => {
    console.log('Cancel button clicked!');
    e.preventDefault();
    e.stopPropagation();
    closeWarehouseSelectionModal();
  });
  
  console.log('Cancel button event listener set up successfully');
} else {
  console.error('cancelWarehouseSelectionBtn element not found!');
}

// Function to close warehouse selection modal
function closeWarehouseSelectionModal() {
  // Hide the modal with multiple approaches to ensure it's hidden
  warehouseSelectionModal.style.display = 'none';
  warehouseSelectionModal.style.visibility = 'hidden';
  warehouseSelectionModal.style.opacity = '0';
  
  // Remove any show classes
  warehouseSelectionModal.classList.remove('show', 'active');
  
  // Remove NUI focus to allow player to move
  if (typeof SetNuiFocus === 'function') {
    SetNuiFocus(false, false);
  }
  
  // Send NUI callback to remove focus
  if (typeof GetParentResourceName === 'function') {
    fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
  }
  
  // Force a reflow to ensure the changes take effect
  warehouseSelectionModal.offsetHeight;
}



updateShareBtn.addEventListener('click', () => {
  console.log('Update button clicked');
  console.log('currentEditingShare:', currentEditingShare);
  
  if (!currentEditingShare) {
    console.error('No currentEditingShare set - cannot update');
    showErrorNotification('No user selected for editing');
    return;
  }
  
  const newPermission = editPermission.value;
  const newExpires = editExpires.value || null;
  
  console.log('New permission:', newPermission);
  console.log('New expires:', newExpires);
  
  // Validate permission level
  if (!newPermission || !['read', 'write', 'admin'].includes(newPermission)) {
    showErrorNotification('Please select a valid permission level');
    return;
  }
  
  // Validate expiration date if provided
  if (newExpires) {
    const expiryDate = new Date(newExpires);
    const now = new Date();
    if (expiryDate <= now) {
      showErrorNotification('Expiration date must be in the future');
      return;
    }
  }
  
  // Show loading notification
  showInfoNotification('Updating sharing permissions...');
  
  console.log('Sending update request for citizen ID:', currentEditingShare.shared_with_citizenid);
  
  // Send update to client
  fetch(`https://${GetParentResourceName()}/updateWarehouseSharing`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      targetCitizenId: currentEditingShare.shared_with_citizenid,
      newPermission: newPermission,
      newExpiresAt: newExpires
    })
  }).then(response => {
    console.log('Update response received:', response);
    console.log('Response ok:', response.ok);
    console.log('Response status:', response.status);
    
    if (response.ok) {
      showSuccessNotification('Sharing permissions updated successfully');
      
      // Close the modal immediately
      hideShareModal();
      currentEditingShare = null;
      
      // Clear form fields
      if (editPermission) editPermission.value = 'write'; // Default to write permission
      if (editExpires) editExpires.value = '';
      
      console.log('Modal closed and form cleared after successful update');
      
      // The client will automatically refresh the shared users list
      // via the server response, so we don't need to manually refresh here
    } else {
      showErrorNotification('Failed to update permissions. Please try again.');
    }
  }).catch(error => {
    console.error('Error updating permissions:', error);
    showErrorNotification('Error updating permissions. Please try again.');
  });
});

revokeShareBtn.addEventListener('click', () => {
  console.log('Revoke button clicked');
  console.log('currentEditingShare:', currentEditingShare);
  
  if (!currentEditingShare) {
    console.error('No currentEditingShare set - cannot revoke');
    showErrorNotification('No user selected for editing');
    return;
  }
  
  // Show custom confirmation dialog instead of JavaScript confirm
  showConfirmDialog(
    `Are you sure you want to revoke access for ${currentEditingShare.player_firstname || 'Unknown'} ${currentEditingShare.player_lastname || 'Player'}?`,
    () => {
      // User confirmed - proceed with revoke
      console.log('Revoking access for user:', currentEditingShare);
      
      // Show loading notification
      showInfoNotification('Revoking access...');
      
      // Send revoke to client
      fetch(`https://${GetParentResourceName()}/revokeWarehouseSharing`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          targetCitizenId: currentEditingShare.shared_with_citizenid
        })
      }).then(response => {
        if (response.ok) {
          showSuccessNotification('Access revoked successfully');
          closeModal();
          
          // Force a UI refresh
          fetch(`https://${GetParentResourceName()}/getWarehouseInfo`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({})
          });
        } else {
          showErrorNotification('Failed to revoke access. Please try again.');
        }
      }).catch(error => {
        console.error('Error revoking access:', error);
        showErrorNotification('Error revoking access. Please try again.');
      });
    }
  );
});

// Simple direct modal close functions
function closeModal() {
  console.log('closeModal called - closing modal directly');
  console.log('shareModal element:', shareModal);
  console.log('Modal state before closing:', {
    display: shareModal?.style.display,
    visibility: shareModal?.style.visibility,
    opacity: shareModal?.style.opacity,
    classes: shareModal?.className
  });
  
  if (shareModal) {
    // Gently close the modal - just hide it, don't break it
    shareModal.style.display = 'none';
    shareModal.style.visibility = 'hidden';
    shareModal.style.opacity = '0';
    
    // Remove any show classes
    shareModal.classList.remove('show');
    
    // Reset the editing state
    currentEditingShare = null;
    
    console.log('Modal state after closing:', {
      display: shareModal.style.display,
      visibility: shareModal.style.visibility,
      opacity: shareModal.style.opacity,
      classes: shareModal.className
    });
    
    console.log('Modal closed directly');
  } else {
    console.error('shareModal element not found!');
  }
}

function updateModal() {
  console.log('updateModal called');
  if (!currentEditingShare) {
    showErrorNotification('No user selected for editing');
    return;
  }
  
  const newPermission = editPermission.value;
  const newExpires = editExpires.value || null;
  
  console.log('Updating permissions:', { newPermission, newExpires });
  
  // Show loading notification
  showInfoNotification('Updating sharing permissions...');
  
  // Send update to client
  fetch(`https://${GetParentResourceName()}/updateWarehouseSharing`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      targetCitizenId: currentEditingShare.shared_with_citizenid,
      newPermission: newPermission,
      newExpiresAt: newExpires
    })
  }).then(response => {
    if (response.ok) {
      showSuccessNotification('Sharing permissions updated successfully');
      closeModal();
    } else {
      showErrorNotification('Failed to update permissions. Please try again.');
    }
  }).catch(error => {
    console.error('Error updating permissions:', error);
    showErrorNotification('Error updating permissions. Please try again.');
  });
}

function revokeModal() {
  console.log('revokeModal called');
  if (!currentEditingShare) {
    showErrorNotification('No user selected for editing');
    return;
  }
  
  // Show custom confirmation dialog instead of JavaScript confirm
  showConfirmDialog(
    `Are you sure you want to revoke access for ${currentEditingShare.player_firstname || 'Unknown'} ${currentEditingShare.player_lastname || 'Player'}?`,
    () => {
      // User confirmed - proceed with revoke
      console.log('Revoking access for user:', currentEditingShare);
      
      // Show loading notification
      showInfoNotification('Revoking access...');
      
      // Send revoke to client
      fetch(`https://${GetParentResourceName()}/revokeWarehouseSharing`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          targetCitizenId: currentEditingShare.shared_with_citizenid
        })
      }).then(response => {
        if (response.ok) {
          showSuccessNotification('Access revoked successfully');
          closeModal();
          
          // Force a UI refresh
          fetch(`https://${GetParentResourceName()}/getWarehouseInfo`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({})
          });
        } else {
          showErrorNotification('Failed to revoke access. Please try again.');
        }
      }).catch(error => {
        console.error('Error revoking access:', error);
        showErrorNotification('Error revoking access. Please try again.');
      });
    }
  );
}





// Custom confirmation dialog function
function showConfirmDialog(message, onConfirm) {
  // Create confirmation modal
  const confirmModal = document.createElement('div');
  confirmModal.className = 'modal-overlay';
  confirmModal.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.8);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 10000;
  `;
  
  confirmModal.innerHTML = `
    <div class="modal-content" style="max-width: 400px; text-align: center;">
      <div class="modal-header">
        <h3><i class="icon fas fa-exclamation-triangle"></i> Confirm Action</h3>
      </div>
      <div class="modal-body">
        <p>${message}</p>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" onclick="this.closest('.modal-overlay').remove()">Cancel</button>
        <button class="btn btn-danger" onclick="this.closest('.modal-overlay').remove(); window.executeConfirmCallback();">Confirm</button>
      </div>
    </div>
  `;
  
  // Store the callback globally so the onclick can access it
  window.executeConfirmCallback = onConfirm;
  
  // Add to page
  document.body.appendChild(confirmModal);
  
  // Auto-remove the global callback after a delay
  setTimeout(() => {
    delete window.executeConfirmCallback;
  }, 1000);
}



// Force close modal function





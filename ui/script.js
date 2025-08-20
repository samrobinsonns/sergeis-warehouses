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

const isNui = typeof GetParentResourceName === 'function';
let warehouseInfo = null;
let isClosing = false; // Flag to prevent multiple close operations

// Tab switching
document.querySelectorAll('.nav-item').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.nav-item').forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
    const tab = btn.dataset.tab;
    document.querySelectorAll('.tab-pane').forEach((pane) => pane.classList.remove('active'));
    document.getElementById(`tab-${tab}`).classList.add('active');
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

function updateWarehouseInfo(info) {
  warehouseInfo = info;
  
  // Debug: Log the received slot prices
  console.log('Warehouse info received:', info);
  if (info.slot_prices) {
    console.log('Individual slot prices:');
    for (let slot in info.slot_prices) {
      console.log(`  Slot ${slot}: $${info.slot_prices[slot]}`);
    }
  }
  
  ownerStatus.textContent = info.owned ? 'Owned' : 'Not Owned';
  
  if (info.owned) {
    storageTab.style.display = 'block';
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
  } else {
    storageTab.style.display = 'none';
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
    if (sellModal.style.display === 'flex') {
      hideSellConfirmation();
    } else {
      closeUI();
    }
  }
});

// NUI message handler
window.addEventListener('message', function(event) {
  const data = event.data;
  
  switch (data.action) {
    case 'showUI':
      showUI(data.show);
      break;
      
    case 'updateWarehouseInfo':
      updateWarehouseInfo(data.data);
      renderStorageGrid();
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


